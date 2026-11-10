import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:poster_spec/poster_spec.dart';

/// Look of each named fill preset: a metallic multi-stop vertical gradient,
/// optionally sprinkled with deterministic sparkles.
class _Preset {
  const _Preset(this.stops, {this.sparkles = false, this.sparkle = 0xFFFFFFFF});
  final List<int> stops;
  final bool sparkles;
  final int sparkle;
}

const _presets = <String, _Preset>{
  'gold-glitter': _Preset(
    [0xFF8A5A00, 0xFFFFE7A0, 0xFFE8B030, 0xFFFFF3C4, 0xFFA86B00],
    sparkles: true,
    sparkle: 0xFFFFFBE8,
  ),
  'silver-shine': _Preset(
    [0xFF6E6E6E, 0xFFFFFFFF, 0xFFBDBDBD, 0xFFF5F5F5, 0xFF7A7A7A],
    sparkles: true,
  ),
  'saffron-glow': _Preset([0xFFFF7A00, 0xFFFFD27A, 0xFFFF9933]),
};

List<double> _evenStops(int n) => [for (var i = 0; i < n; i++) i / (n - 1)];

/// Pre-rendered preset textures, keyed by preset + box size. Generation is
/// seeded, so the cache never changes output, only speed.
final _textureCache = <String, ui.Image>{};

/// Builds the paint that fills text glyphs inside [box].
///
/// Async because glitter presets render a texture image once per size.
Future<ui.Paint> fillPaint(Fill fill, Box box) async {
  final rect = ui.Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
  switch (fill) {
    case SolidFill(:final color):
      return ui.Paint()..color = ui.Color(color);
    case GradientFill(:final colors, :final angle):
      final (from, to) = _gradientLine(rect, angle);
      return ui.Paint()
        ..shader = ui.Gradient.linear(
          from,
          to,
          [for (final c in colors) ui.Color(c)],
          _evenStops(colors.length),
        );
    case PresetFill(:final name):
      final preset = _presets[name]!;
      if (!preset.sparkles) {
        return ui.Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [for (final c in preset.stops) ui.Color(c)],
            _evenStops(preset.stops.length),
          );
      }
      final w = rect.width.ceil(), h = rect.height.ceil();
      final key = '$name:$w:$h';
      final texture = _textureCache[key] ??= await _sparkleTexture(name, preset, w, h);
      final matrix = Float64List.fromList([
        1, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        rect.left, rect.top, 0, 1,
      ]);
      return ui.Paint()
        ..shader = ui.ImageShader(texture, ui.TileMode.clamp, ui.TileMode.clamp, matrix);
  }
}

/// Gradient endpoints across [rect] for an angle in degrees
/// (0 = left to right, 90 = top to bottom).
(ui.Offset, ui.Offset) _gradientLine(ui.Rect rect, double angle) {
  final rad = angle * math.pi / 180;
  final dir = ui.Offset(math.cos(rad), math.sin(rad));
  final half = (rect.width * dir.dx.abs() + rect.height * dir.dy.abs()) / 2;
  return (rect.center - dir * half, rect.center + dir * half);
}

Future<ui.Image> _sparkleTexture(String name, _Preset preset, int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  c.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [for (final s in preset.stops) ui.Color(s)],
        _evenStops(preset.stops.length),
      ),
  );
  // Seeded per preset name: identical sparkles on every device and run.
  final rnd = math.Random(name.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff));
  final count = (w * h / 90).round();
  final dot = ui.Paint()..isAntiAlias = true;
  for (var i = 0; i < count; i++) {
    final alpha = 0.35 + rnd.nextDouble() * 0.65;
    dot.color = ui.Color(preset.sparkle).withValues(alpha: alpha);
    c.drawCircle(
      ui.Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
      0.6 + rnd.nextDouble() * 1.4,
      dot,
    );
  }
  final pic = rec.endRecording();
  try {
    return await pic.toImage(w, h);
  } finally {
    pic.dispose();
  }
}

/// Paint that outlines glyphs. Strokes are centred on the outline, so the
/// width is doubled and the fill pass covers the inner half.
ui.Paint strokePaint(Stroke stroke) => ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = stroke.width * 2
  ..strokeJoin = ui.StrokeJoin.round
  ..color = ui.Color(stroke.color);

ui.Shadow textShadow(TextShadow s) => ui.Shadow(
      color: ui.Color(s.color),
      offset: ui.Offset(s.dx, s.dy),
      blurRadius: s.blur,
    );

/// Soft drop shadow that follows the cut-out's silhouette, so people look
/// placed in the scene rather than pasted on top of it.
void drawPhotoShadow(ui.Canvas canvas, ui.Image photo, ui.Rect src, ui.Rect dst) {
  final paint = ui.Paint()
    ..colorFilter = const ui.ColorFilter.mode(ui.Color(0x73000000), ui.BlendMode.srcIn)
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, dst.height * 0.012 + 2);
  canvas.drawImageRect(photo, src, dst.shift(ui.Offset(0, dst.height * 0.008 + 2)), paint);
}
