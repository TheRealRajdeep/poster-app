import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:poster_renderer/poster_renderer.dart';
import 'package:poster_spec/poster_spec.dart';

const _sceneColor = 0xFF203040;
const _red = 0xFFFF0000;

Future<ui.Image> _solid(int w, int h, int argb) async {
  final r = ui.PictureRecorder();
  ui.Canvas(r).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = ui.Color(argb),
  );
  final pic = r.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  return img;
}

class _Pixels {
  _Pixels(this.width, this.bytes);
  final int width;
  final ByteData bytes;

  /// ARGB at (x, y).
  int at(int x, int y) {
    final o = (y * width + x) * 4;
    final r = bytes.getUint8(o), g = bytes.getUint8(o + 1), b = bytes.getUint8(o + 2), a = bytes.getUint8(o + 3);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
}

Future<_Pixels> _pixels(ui.Image img) async =>
    _Pixels(img.width, (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!);

PosterSpec _spec(List<Slot> slots, {int w = 400, int h = 400}) => PosterSpec(
      version: 1,
      id: 'test',
      occasion: 'test',
      archetype: 'test',
      tones: const [],
      languages: const {'en'},
      canvas: CanvasSize(w, h),
      scene: 'scene.webp',
      slots: slots,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const renderer = PosterRenderer();
  late ui.Image scene;
  late ui.Image photo; // 100x200 red "person"

  setUpAll(() async {
    scene = await _solid(50, 50, _sceneColor);
    photo = await _solid(100, 200, _red);
  });

  test('output size follows canvas and scale', () async {
    final spec = _spec(const [], w: 1080, h: 1920);
    final full = await renderer.render(spec: spec, scene: scene, inputs: const RenderInputs(language: 'en'));
    expect([full.image.width, full.image.height], [1080, 1920]);
    final preview = await renderer.render(
      spec: spec,
      scene: scene,
      inputs: const RenderInputs(language: 'en'),
      scale: 1 / 3,
    );
    expect([preview.image.width, preview.image.height], [360, 640]);
  });

  test('scene covers the whole canvas', () async {
    final r = await renderer.render(spec: _spec(const []), scene: scene, inputs: const RenderInputs(language: 'en'));
    final px = await _pixels(r.image);
    for (final (x, y) in [(0, 0), (399, 0), (0, 399), (399, 399), (200, 200)]) {
      expect(px.at(x, y), _sceneColor, reason: '($x,$y)');
    }
  });

  group('photo slot', () {
    Future<_Pixels> renderWith(PhotoAnchor anchor, {Map<Person, ui.Image>? photos}) async {
      final spec = _spec([PhotoSlot(box: const Box(0, 0, 400, 400), who: Person.self, anchor: anchor)]);
      final r = await renderer.render(
        spec: spec,
        scene: scene,
        inputs: RenderInputs(language: 'en', photos: photos ?? {Person.self: photo}),
      );
      return _pixels(r.image);
    }

    // A 100x200 photo contained in 400x400 becomes 200x400.
    test('bottom-center', () async {
      final px = await renderWith(PhotoAnchor.bottomCenter);
      expect(px.at(200, 390), _red);
      expect(px.at(110, 200), _red);
      expect(px.at(90, 200), _sceneColor);
      expect(px.at(310, 200), _sceneColor);
    });

    test('bottom-left', () async {
      final px = await renderWith(PhotoAnchor.bottomLeft);
      expect(px.at(10, 390), _red);
      expect(px.at(210, 390), _sceneColor);
    });

    test('bottom-right', () async {
      final px = await renderWith(PhotoAnchor.bottomRight);
      expect(px.at(390, 390), _red);
      expect(px.at(190, 390), _sceneColor);
    });

    test('missing photo leaves the scene untouched', () async {
      final px = await renderWith(PhotoAnchor.bottomCenter, photos: const {});
      expect(px.at(200, 390), _sceneColor);
    });

    test('other-person photo goes in the other slot only', () async {
      final spec = _spec([
        PhotoSlot(box: const Box(0, 0, 200, 400), who: Person.self),
        PhotoSlot(box: const Box(200, 0, 400, 400), who: Person.other),
      ]);
      final r = await renderer.render(
        spec: spec,
        scene: scene,
        inputs: RenderInputs(language: 'en', photos: {Person.other: photo}),
      );
      final px = await _pixels(r.image);
      expect(px.at(100, 390), _sceneColor);
      expect(px.at(300, 390), _red);
    });
  });

  group('text slot', () {
    TextSlot slot(Box box, {int maxLines = 1, double min = 10, double max = 80}) => TextSlot(
          box: box,
          bind: Binding.selfName,
          fill: const SolidFill(0xFFFFFFFF),
          maxLines: maxLines,
          minFontSize: min,
          maxFontSize: max,
        );

    test('short text fits and draws inside its box', () async {
      final spec = _spec([slot(const Box(20, 20, 380, 120))]);
      final r = await renderer.render(
        spec: spec,
        scene: scene,
        inputs: const RenderInputs(language: 'en', texts: {Binding.selfName: 'Ram'}),
      );
      expect(r.overflows, isEmpty);
      final px = await _pixels(r.image);
      var white = 0;
      for (var x = 20; x < 380; x++) {
        for (var y = 20; y < 120; y++) {
          if (px.at(x, y) == 0xFFFFFFFF) white++;
        }
      }
      expect(white, greaterThan(100), reason: 'glyphs were painted');
      // Nothing painted outside the box.
      expect(px.at(10, 10), _sceneColor);
      expect(px.at(200, 200), _sceneColor);
    });

    test('text that cannot fit at minFontSize is reported', () async {
      final spec = _spec([slot(const Box(0, 0, 100, 20), min: 18, max: 40)]);
      final r = await renderer.render(
        spec: spec,
        scene: scene,
        inputs: const RenderInputs(
          language: 'en',
          texts: {Binding.selfName: 'Rajdeepsinh Jadeja Dhokia Family Kulkarni'},
        ),
      );
      expect(r.overflows.single.slotIndex, 0);
      expect(r.overflows.single.binding, Binding.selfName);
    });

    test('multi-line slot wraps instead of overflowing', () async {
      final spec = _spec([slot(const Box(0, 0, 200, 200), maxLines: 3, min: 20, max: 60)]);
      final r = await renderer.render(
        spec: spec,
        scene: scene,
        inputs: const RenderInputs(language: 'en', texts: {Binding.selfName: 'Happy Diwali to all'}),
      );
      expect(r.overflows, isEmpty);
    });

    test('blank or missing text skips the slot', () async {
      final spec = _spec([slot(const Box(0, 0, 400, 400))]);
      for (final texts in [<Binding, String>{}, {Binding.selfName: '   '}]) {
        final r = await renderer.render(spec: spec, scene: scene, inputs: RenderInputs(language: 'en', texts: texts));
        expect(r.overflows, isEmpty);
        expect((await _pixels(r.image)).at(200, 200), _sceneColor);
      }
    });

    test('font resolver receives role and language', () async {
      final calls = <(FontRole, String)>{};
      final r = PosterRenderer(fonts: (role, lang) {
        calls.add((role, lang));
        return null;
      });
      await r.render(
        spec: _spec([slot(const Box(0, 0, 400, 100))]),
        scene: scene,
        inputs: const RenderInputs(language: 'kn', texts: {Binding.selfName: 'ವಿನಯ'}),
      );
      expect(calls, {(FontRole.body, 'kn')});
    });
  });

  test('deterministic: same inputs give identical PNG bytes', () async {
    final spec = _spec([
      PhotoSlot(box: const Box(0, 100, 250, 400), who: Person.self),
      const TextSlot(box: Box(200, 20, 390, 120), bind: Binding.selfName),
    ]);
    final inputs = RenderInputs(language: 'en', texts: const {Binding.selfName: 'Dhokia Family'}, photos: {Person.self: photo});
    final a = await (await renderer.render(spec: spec, scene: scene, inputs: inputs)).toPng();
    final b = await (await renderer.render(spec: spec, scene: scene, inputs: inputs)).toPng();
    expect(a, b);
  });
}
