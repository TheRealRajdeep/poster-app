import 'dart:io';

import 'package:poster_spec/poster_spec.dart';
import 'package:test/test.dart';

List<File> _fixtures(String dir) =>
    Directory('test/fixtures/$dir').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('shared fixtures', () {
    for (final f in _fixtures('valid')) {
      test('valid: ${f.uri.pathSegments.last}', () {
        final r = parseSpecJson(f.readAsStringSync());
        expect(r.errors, isEmpty);
        expect(r.isValid, isTrue);
      });
    }
    for (final dir in ['invalid', 'invalid_semantic']) {
      for (final f in _fixtures(dir)) {
        test('$dir: ${f.uri.pathSegments.last}', () {
          final r = parseSpecJson(f.readAsStringSync());
          expect(r.isValid, isFalse);
          expect(r.errors, isNotEmpty);
        });
      }
    }
  });

  group('diwali fixture is parsed faithfully', () {
    late PosterSpec spec;
    setUp(() {
      spec = parseSpecJson(
        File('test/fixtures/valid/diwali_photo_left_text_right.json').readAsStringSync(),
      ).spec!;
    });

    test('top-level fields', () {
      expect(spec.id, 'diwali-2026-0001');
      expect(spec.occasion, 'diwali');
      expect(spec.archetype, 'photo-left-text-right');
      expect(spec.tones, ['hindu']);
      expect(spec.languages, {'hi', 'gu', 'en'});
      expect(spec.canvas, const CanvasSize(1080, 1920));
      expect(spec.needsOtherPerson, isFalse);
    });

    test('slots keep paint order and types', () {
      expect(spec.slots.map((s) => s.runtimeType), [PhotoSlot, TextSlot, TextSlot, TextSlot]);
      final photo = spec.slots[0] as PhotoSlot;
      expect(photo.who, Person.self);
      expect(photo.anchor, PhotoAnchor.bottomCenter);
      expect(photo.shadow, isTrue);
      expect(photo.box, const Box(0, 640, 640, 1920));
    });

    test('text effects', () {
      final greeting = spec.slots[1] as TextSlot;
      expect(greeting.bind, Binding.greeting);
      expect(greeting.font, FontRole.ornate);
      expect((greeting.fill as PresetFill).name, 'gold-glitter');
      expect(greeting.maxLines, 3);
      expect(greeting.shadow!.color, 0x80000000);
      expect(greeting.shadow!.blur, 12);

      final name = spec.slots[2] as TextSlot;
      expect((name.fill as SolidFill).color, 0xFFFFF3D6);
      expect(name.stroke!.color, 0xFF5A2A00);
      expect(name.stroke!.width, 3);

      final subtitle = spec.slots[3] as TextSlot;
      expect(subtitle.font, FontRole.body, reason: 'default');
      expect(subtitle.minFontSize, 24, reason: 'default');
      expect(subtitle.maxFontSize, 160, reason: 'default');
    });
  });

  test('two-person poster is detected and parses gradient fill', () {
    final spec = parseSpecJson(
      File('test/fixtures/valid/birthday_two_person.json').readAsStringSync(),
    ).spec!;
    expect(spec.needsOtherPerson, isTrue);
    expect(spec.tones, isEmpty);
    final fill = (spec.slots[1] as TextSlot).fill as GradientFill;
    expect(fill.colors, [0xFFFFD27A, 0xFFF08A00]);
    expect((spec.slots[0] as PhotoSlot).anchor, PhotoAnchor.bottomRight);
  });

  group('errors are precise and never throw', () {
    test('invalid JSON', () {
      final r = parseSpecJson('{not json');
      expect(r.isValid, isFalse);
      expect(r.errors.single.path, r'$');
    });

    test('non-object root', () {
      expect(parseSpec([1, 2]).errors.single.message, contains('object'));
      expect(parseSpec(null).isValid, isFalse);
    });

    test('error paths point at the offending field', () {
      final r = parseSpecJson(
        File('test/fixtures/invalid/unknown_preset.json').readAsStringSync(),
      );
      expect(r.errors.map((e) => e.path), contains(r'$.slots[1].fill.preset'));
    });

    test('collects multiple errors in one pass', () {
      final r = parseSpec(<String, Object?>{'version': 1});
      expect(r.errors.length, greaterThan(3));
    });
  });

  test('schema file is valid JSON listing the same languages', () {
    final schema = File('schema/spec.schema.json').readAsStringSync();
    for (final lang in supportedLanguages) {
      expect(schema, contains('"$lang"'));
    }
    for (final preset in knownFillPresets) {
      expect(schema, contains('"$preset"'));
    }
    for (final b in Binding.values) {
      expect(schema, contains('"${b.key}"'));
    }
  });
}
