import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:poster_renderer/poster_renderer.dart';
import 'package:poster_spec/poster_spec.dart';

// No real fonts are loaded here: the test font draws glyphs as solid
// blocks, which makes stroke, gradient and shadow edges easy to measure.

const _grey = 0xFF808080;
const _white = 0xFFFFFFFF;
const _blue = 0xFF0000FF;
const _red = 0xFFFF0000;

Future<ui.Image> _solid(int w, int h, int argb) async {
  final r = ui.PictureRecorder();
  ui.Canvas(r).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = ui.Color(argb));
  final pic = r.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  return img;
}

class _Px {
  _Px(this.w, this.h, this.d);
  final int w, h;
  final ByteData d;
  int at(int x, int y) {
    final o = (y * w + x) * 4;
    return (d.getUint8(o + 3) << 24) | (d.getUint8(o) << 16) | (d.getUint8(o + 1) << 8) | d.getUint8(o + 2);
  }

  int r(int x, int y) => (at(x, y) >> 16) & 0xFF;
  int g(int x, int y) => (at(x, y) >> 8) & 0xFF;
  int b(int x, int y) => at(x, y) & 0xFF;

  /// Bounding box of pixels for which [test] holds.
  ({int l, int t, int r, int b}) bbox(bool Function(int argb) test) {
    var l = w, t = h, rr = -1, bb = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (test(at(x, y))) {
          if (x < l) l = x;
          if (x > rr) rr = x;
          if (y < t) t = y;
          if (y > bb) bb = y;
        }
      }
    }
    expect(rr, greaterThanOrEqualTo(0), reason: 'no matching pixels');
    return (l: l, t: t, r: rr, b: bb);
  }
}

PosterSpec _spec(List<Slot> slots) => PosterSpec(
      version: 1,
      id: 't',
      occasion: 't',
      archetype: 't',
      tones: const [],
      languages: const {'en'},
      canvas: const CanvasSize(240, 240),
      scene: 's',
      slots: slots,
    );

TextSlot _text({Fill fill = const SolidFill(_blue), Stroke? stroke, TextShadow? shadow}) => TextSlot(
      box: const Box(20, 20, 220, 220),
      bind: Binding.selfName,
      fill: fill,
      stroke: stroke,
      shadow: shadow,
      minFontSize: 80,
      maxFontSize: 80,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const renderer = PosterRenderer();
  late ui.Image grey, white;

  setUpAll(() async {
    grey = await _solid(10, 10, _grey);
    white = await _solid(10, 10, _white);
  });

  Future<_Px> render(List<Slot> slots, {ui.Image? scene, Map<Person, ui.Image> photos = const {}}) async {
    final r = await renderer.render(
      spec: _spec(slots),
      scene: scene ?? grey,
      inputs: RenderInputs(language: 'en', texts: const {Binding.selfName: 'M'}, photos: photos),
    );
    expect(r.overflows, isEmpty);
    final img = r.image;
    return _Px(img.width, img.height, (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!);
  }

  test('stroke outlines the glyph outside the fill', () async {
    final px = await render([_text(stroke: const Stroke(color: _red, width: 6))]);
    final glyph = px.bbox((c) => c == _blue);
    final cy = (glyph.t + glyph.b) ~/ 2;
    expect(px.at(glyph.l - 3, cy), _red, reason: 'inside the outline band');
    expect(px.at(glyph.r + 3, cy), _red);
    expect(px.at(glyph.l - 12, cy), _grey, reason: 'beyond the outline');
    expect(px.at((glyph.l + glyph.r) ~/ 2, cy), _blue, reason: 'fill stays on top');
  });

  test('vertical gradient runs top to bottom', () async {
    final px = await render([_text(fill: const GradientFill(colors: [_red, _blue]))]);
    final g = px.bbox((c) => c != _grey);
    final cx = (g.l + g.r) ~/ 2;
    expect(px.r(cx, g.t + 2), greaterThan(px.r(cx, g.b - 2)));
    expect(px.b(cx, g.t + 2), lessThan(px.b(cx, g.b - 2)));
  });

  test('angle 0 gradient runs left to right', () async {
    final px = await render([_text(fill: const GradientFill(colors: [_red, _blue], angle: 0))]);
    final g = px.bbox((c) => c != _grey);
    final cy = (g.t + g.b) ~/ 2;
    expect(px.r(g.l + 2, cy), greaterThan(px.r(g.r - 2, cy)));
  });

  test('gold-glitter is warm, metallic and sparkly', () async {
    final px = await render([_text(fill: const PresetFill('gold-glitter'))]);
    final g = px.bbox((c) => c != _grey);
    final colours = <int>{};
    var warm = 0, total = 0;
    for (var y = g.t; y <= g.b; y++) {
      for (var x = g.l; x <= g.r; x++) {
        colours.add(px.at(x, y));
        total++;
        if (px.r(x, y) > px.b(x, y) + 30) warm++;
      }
    }
    expect(warm / total, greaterThan(0.8), reason: 'gold, not grey');
    expect(colours.length, greaterThan(200), reason: 'gradient + sparkles, not flat');
  });

  test('saffron-glow is orange', () async {
    final px = await render([_text(fill: const PresetFill('saffron-glow'))]);
    final g = px.bbox((c) => c != _grey);
    final cx = (g.l + g.r) ~/ 2, cy = (g.t + g.b) ~/ 2;
    expect(px.r(cx, cy), greaterThan(200));
    expect(px.b(cx, cy), lessThan(140));
  });

  test('text shadow is offset below the glyph', () async {
    final px = await render(
      [_text(shadow: const TextShadow(color: _red, blur: 0, dx: 0, dy: 10))],
      scene: white,
    );
    final glyph = px.bbox((c) => c == _blue);
    final cx = (glyph.l + glyph.r) ~/ 2;
    expect(px.at(cx, glyph.b + 5), _red);
    expect(px.at(cx, glyph.b + 15), _white);
  });

  test('with a stroke, the shadow sits under the outline', () async {
    final px = await render(
      [_text(stroke: const Stroke(color: _red, width: 4), shadow: const TextShadow(color: 0xFF00FF00, blur: 0, dy: 14))],
      scene: white,
    );
    final glyph = px.bbox((c) => c == _blue);
    final cx = (glyph.l + glyph.r) ~/ 2;
    expect(px.at(cx, glyph.b + 2), _red, reason: 'outline above shadow');
    expect(px.at(cx, glyph.b + 12), 0xFF00FF00, reason: 'shadow of the outlined text');
  });

  group('photo shadow', () {
    late ui.Image person;
    setUpAll(() async => person = await _solid(100, 200, _red));

    Future<_Px> withShadow(bool shadow) => render(
          [PhotoSlot(box: const Box(20, 20, 220, 220), who: Person.self, shadow: shadow)],
          scene: white,
          photos: {Person.self: person},
        );

    test('darkens the scene just outside the silhouette', () async {
      final on = await withShadow(true);
      final edge = on.bbox((c) => c == _red);
      final y = (edge.t + edge.b) ~/ 2;
      expect(on.r(edge.l - 2, y), lessThan(250));
      final off = await withShadow(false);
      expect(off.at(edge.l - 2, y), _white);
    });
  });

  test('glitter output is deterministic', () async {
    Future<Uint8List> once() async {
      final r = await renderer.render(
        spec: _spec([_text(fill: const PresetFill('gold-glitter'), stroke: const Stroke(color: _red, width: 3))]),
        scene: grey,
        inputs: const RenderInputs(language: 'en', texts: {Binding.selfName: 'M'}),
      );
      return r.toPng();
    }

    expect(await once(), await once());
  });
}
