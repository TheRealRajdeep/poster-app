import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:poster_spec/poster_spec.dart';

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
          final fitted = _layoutText(slot, text, inputs.language);
          if (fitted.overflowed) overflows.add(TextOverflow(i, slot.bind));
          _drawParagraph(canvas, slot, fitted.paragraph);
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
    canvas.drawImageRect(
      photo,
      ui.Rect.fromLTWH(0, 0, pw, ph),
      ui.Rect.fromLTWH(left, top, w, h),
      paint,
    );
  }

  /// Largest font size in [minFontSize, maxFontSize] whose layout fits the
  /// box. Binary search on whole pixels keeps it fast and deterministic.
  ({ui.Paragraph paragraph, bool overflowed}) _layoutText(
    TextSlot slot,
    String text,
    String language,
  ) {
    final font = fonts(slot.font, language);
    var lo = slot.minFontSize.floor();
    var hi = slot.maxFontSize.floor();
    ui.Paragraph? best;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final p = _paragraph(slot, text, font, language, mid.toDouble(), ellipsis: false);
      if (_fits(p, slot)) {
        best?.dispose();
        best = p;
        lo = mid + 1;
      } else {
        p.dispose();
        hi = mid - 1;
      }
    }
    if (best != null) return (paragraph: best, overflowed: false);
    final fallback = _paragraph(
      slot,
      text,
      font,
      language,
      slot.minFontSize,
      ellipsis: true,
    );
    return (paragraph: fallback, overflowed: true);
  }

  bool _fits(ui.Paragraph p, TextSlot slot) =>
      !p.didExceedMaxLines && p.height <= slot.box.height && p.longestLine <= slot.box.width;

  ui.Paragraph _paragraph(
    TextSlot slot,
    String text,
    FontChoice? font,
    String language,
    double size, {
    required bool ellipsis,
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
        // Spec sizes are design sizes; never let OS font scaling change layout.
        textHeightBehavior: const ui.TextHeightBehavior(),
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: _fillColor(slot.fill),
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

  /// Effects (gradient, presets, stroke, shadow) arrive in #7; until then
  /// non-solid fills use a representative colour.
  ui.Color _fillColor(Fill fill) => switch (fill) {
        SolidFill(:final color) => ui.Color(color),
        GradientFill(:final colors) => ui.Color(colors.first),
        PresetFill() => const ui.Color(0xFFFFD36B),
      };

  void _drawParagraph(ui.Canvas canvas, TextSlot slot, ui.Paragraph p) {
    // Vertically centre the text block inside its box.
    final dy = slot.box.top + (slot.box.height - p.height) / 2;
    canvas.drawParagraph(p, ui.Offset(slot.box.left, dy));
    p.dispose();
  }
}
