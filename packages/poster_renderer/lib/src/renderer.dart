import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:poster_spec/poster_spec.dart';

import 'effects.dart';
import 'fonts.dart';

/// Everything user-specific the renderer needs. Kept separate from the
/// spec so one spec renders for every user and language.
class RenderInputs {
  const RenderInputs({
    required this.language,
    this.texts = const {},
    this.photos = const {},
  });

  /// Language of the text being drawn (picks the font per script).
  final String language;

  /// Already-localised text for each binding. A missing or blank entry
  /// leaves that slot empty (e.g. no subtitle).
  final Map<Binding, String> texts;

  /// Transparent-background cut-outs. A missing entry leaves that slot empty.
  final Map<Person, ui.Image> photos;
}

/// A text slot whose text did not fit even at `minFontSize`.
class TextOverflow {
  const TextOverflow(this.slotIndex, this.binding);
  final int slotIndex;
  final Binding binding;
  @override
  String toString() => 'TextOverflow(slot $slotIndex, ${binding.key})';
}

class RenderResult {
  const RenderResult(this.image, this.overflows);

  /// Caller owns this image and must `dispose()` it.
  final ui.Image image;

  /// Non-empty means the text was ellipsised; factory QA rejects such specs.
  final List<TextOverflow> overflows;

  Future<Uint8List> toPng() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// Pure, deterministic poster composer: same inputs -> same pixels.
/// No I/O, no Flutter widgets, no app state.
class PosterRenderer {
  const PosterRenderer({this.fonts = bundledFontResolver});

  final FontResolver fonts;

  /// Renders [spec] over [scene]. [scale] < 1 produces cheap feed previews
  /// (e.g. 0.33 for a 360x640 card); 1.0 is the full share-quality image.
  Future<RenderResult> render({
    required PosterSpec spec,
    required ui.Image scene,
    required RenderInputs inputs,
    double scale = 1.0,
  }) async {
    assert(scale > 0 && scale <= 1, 'scale must be in (0, 1]');
    final width = (spec.canvas.width * scale).round();
    final height = (spec.canvas.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    final full = ui.Rect.fromLTWH(
      0,
      0,
      spec.canvas.width.toDouble(),
      spec.canvas.height.toDouble(),
    );
    canvas.drawImageRect(scene, _cover(scene, full), full, paint);

    final overflows = <TextOverflow>[];
    for (final (i, slot) in spec.slots.indexed) {
      switch (slot) {
        case PhotoSlot():
          final photo = inputs.photos[slot.who];
          if (photo != null) _drawPhoto(canvas, slot, photo, paint);
        case TextSlot():
          final text = inputs.texts[slot.bind]?.trim();
          if (text == null || text.isEmpty) continue;
          final font = fonts(slot.font, inputs.language);
          final fit = _fitFontSize(slot, text, font, inputs.language);
          if (fit.overflowed) overflows.add(TextOverflow(i, slot.bind));
          await _drawText(canvas, slot, text, font, inputs.language, fit.size, ellipsis: fit.overflowed);
      }
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      return RenderResult(image, List.unmodifiable(overflows));
    } finally {
      picture.dispose();
    }
  }

  /// Source rect that crops [image] to fill [dst] without distortion.
  ui.Rect _cover(ui.Image image, ui.Rect dst) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = (dst.width / iw) > (dst.height / ih) ? dst.width / iw : dst.height / ih;
    final sw = dst.width / scale, sh = dst.height / scale;
    return ui.Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh);
  }

  void _drawPhoto(ui.Canvas canvas, PhotoSlot slot, ui.Image photo, ui.Paint paint) {
    final box = slot.box;
    final pw = photo.width.toDouble(), ph = photo.height.toDouble();
    // Contain: the whole person stays visible inside the box.
    final s = (box.width / pw) < (box.height / ph) ? box.width / pw : box.height / ph;
    final w = pw * s, h = ph * s;
    final (left, top) = switch (slot.anchor) {
      PhotoAnchor.bottomCenter => (box.left + (box.width - w) / 2, box.bottom - h),
      PhotoAnchor.bottomLeft => (box.left, box.bottom - h),
      PhotoAnchor.bottomRight => (box.right - w, box.bottom - h),
      PhotoAnchor.center => (box.left + (box.width - w) / 2, box.top + (box.height - h) / 2),
    };
    final src = ui.Rect.fromLTWH(0, 0, pw, ph);
    final dst = ui.Rect.fromLTWH(left, top, w, h);
    if (slot.shadow) drawPhotoShadow(canvas, photo, src, dst);
    canvas.drawImageRect(photo, src, dst, paint);
  }

  /// Largest font size in [minFontSize, maxFontSize] whose layout fits the
  /// box. Binary search on whole pixels keeps it fast and deterministic.
  /// Paint does not affect layout, so fitting uses plain paragraphs.
  ({double size, bool overflowed}) _fitFontSize(
    TextSlot slot,
    String text,
    FontChoice? font,
    String language,
  ) {
    var lo = slot.minFontSize.floor();
    var hi = slot.maxFontSize.floor();
    int? best;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final p = _paragraph(slot, text, font, language, mid.toDouble(), ellipsis: false);
      final fits = !p.didExceedMaxLines && p.height <= slot.box.height && p.longestLine <= slot.box.width;
      p.dispose();
      if (fits) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best == null
        ? (size: slot.minFontSize, overflowed: true)
        : (size: best.toDouble(), overflowed: false);
  }

  /// Draws text in up to two passes: outline (with the shadow underneath),
  /// then the fill on top. Both passes share one layout, so they line up.
  Future<void> _drawText(
    ui.Canvas canvas,
    TextSlot slot,
    String text,
    FontChoice? font,
    String language,
    double size, {
    required bool ellipsis,
  }) async {
    final shadows = slot.shadow == null ? null : [textShadow(slot.shadow!)];
    final fill = await fillPaint(slot.fill, slot.box);
    final passes = <ui.Paragraph>[
      if (slot.stroke != null)
        _paragraph(slot, text, font, language, size,
            ellipsis: ellipsis, foreground: strokePaint(slot.stroke!), shadows: shadows),
      _paragraph(slot, text, font, language, size,
          ellipsis: ellipsis, foreground: fill, shadows: slot.stroke == null ? shadows : null),
    ];
    // Vertically centre the text block inside its box.
    final dy = slot.box.top + (slot.box.height - passes.last.height) / 2;
    for (final p in passes) {
      canvas.drawParagraph(p, ui.Offset(slot.box.left, dy));
      p.dispose();
    }
  }

  ui.Paragraph _paragraph(
    TextSlot slot,
    String text,
    FontChoice? font,
    String language,
    double size, {
    required bool ellipsis,
    ui.Paint? foreground,
    List<ui.Shadow>? shadows,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: switch (slot.align) {
          TextAlign.start => ui.TextAlign.left,
          TextAlign.center => ui.TextAlign.center,
          TextAlign.end => ui.TextAlign.right,
        },
        textDirection: ui.TextDirection.ltr,
        maxLines: slot.maxLines,
        ellipsis: ellipsis ? '…' : null,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          foreground: foreground,
          shadows: shadows,
          fontFamily: font?.families.first,
          fontFamilyFallback: font?.families.skip(1).toList(),
          fontSize: size,
          fontVariations: font == null ? null : [ui.FontVariation('wght', font.weight)],
          locale: ui.Locale(language),
        ),
      )
      ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: slot.box.width));
  }
}
