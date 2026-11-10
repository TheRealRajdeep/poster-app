import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:poster_renderer/poster_renderer.dart';
import 'package:poster_renderer/testing.dart';
import 'package:poster_spec/poster_spec.dart';

/// Renders every case in test/replays/ with the real fonts and compares the
/// text layout with test/replays/_snapshots.json. See test/replays/README.md.
///
///   `UPDATE_SNAPSHOTS=1`      rewrite the snapshot file
///   `REPLAY_PNG_DIR=dir`      also write each render as a PNG for eyeballing
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const snapshotPath = 'test/replays/_snapshots.json';
  final update = Platform.environment['UPDATE_SNAPSHOTS'] == '1';
  final pngDir = Platform.environment['REPLAY_PNG_DIR'];

  final cases = Directory('test/replays')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.uri.pathSegments.last.startsWith('_'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final snapshotFile = File(snapshotPath);
  final expected = snapshotFile.existsSync()
      ? (jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>)
      : <String, Object?>{};
  final actual = <String, Object?>{};

  late ui.Image scene;
  final placeholders = <String, ui.Image>{};

  Future<ui.Image> solid(int w, int h, int argb) async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = ui.Color(argb));
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  setUpAll(() async {
    await loadBundledFonts(Directory.current.path);
    scene = await solid(54, 96, 0xFF3B1F0E);
  });

  tearDownAll(() {
    if (!update) return;
    const encoder = JsonEncoder.withIndent('  ');
    snapshotFile.writeAsStringSync('${encoder.convert(Map.fromEntries(actual.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))}\n');
  });

  test('there are replay cases', () => expect(cases, isNotEmpty));

  for (final file in cases) {
    final name = file.uri.pathSegments.last.replaceFirst('.json', '');
    test(name, () async {
      final c = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final parsed = parseSpecJson(File(c['spec']! as String).readAsStringSync());
      expect(parsed.errors, isEmpty, reason: 'spec must be valid');

      final texts = <Binding, String>{
        for (final MapEntry(:key, :value) in (c['texts']! as Map<String, Object?>).entries)
          Binding.fromKey(key)!: value! as String,
      };
      final photos = <Person, ui.Image>{};
      for (final MapEntry(:key, :value) in ((c['photos'] as Map<String, Object?>?) ?? {}).entries) {
        final [w, h] = (value! as List<Object?>).cast<int>();
        photos[Person.values.byName(key)] = placeholders['$w:$h'] ??= await solid(w, h, 0xFF2D6CB5);
      }

      // Optional real scene image; otherwise a flat placeholder.
      var caseScene = scene;
      if (c['scene'] case final String path) {
        final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
        caseScene = (await codec.getNextFrame()).image;
      }
      final result = await const PosterRenderer().render(
        spec: parsed.spec!,
        scene: caseScene,
        inputs: RenderInputs(language: c['language']! as String, texts: texts, photos: photos),
      );
      final layout = [for (final t in result.textLayouts) t.toJson()];
      actual[name] = layout;

      if (pngDir != null) {
        Directory(pngDir).createSync(recursive: true);
        File('$pngDir/$name.png').writeAsBytesSync(await result.toPng());
      }

      if (!update) {
        expect(expected, contains(name), reason: 'new case: run with UPDATE_SNAPSHOTS=1');
        expect(jsonEncode(layout), jsonEncode(expected[name]), reason: 'layout changed for $name');
      }
    });
  }
}
