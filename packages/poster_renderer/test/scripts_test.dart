import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:poster_renderer/poster_renderer.dart';
import 'package:poster_renderer/testing.dart';
import 'package:poster_spec/poster_spec.dart';

/// Greeting per language, plus a cluster that only renders correctly when
/// the font is loaded AND the script is shaped (conjunct / reordered vowel).
const _samples = <String, ({String greeting, String cluster, List<String> parts})>{
  'hi': (greeting: 'दीपावली की हार्दिक शुभकामनाएं', cluster: 'क्ष', parts: ['क', '्', 'ष']),
  'mr': (greeting: 'दिवाळीच्या हार्दिक शुभेच्छा', cluster: 'च्छा', parts: ['च', '्', 'छ', 'ा']),
  'gu': (greeting: 'દિવાળીની હાર્દિક શુભકામનાઓ', cluster: 'ક્ષ', parts: ['ક', '્', 'ષ']),
  'kn': (greeting: 'ದೀಪಾವಳಿ ಹಬ್ಬದ ಶುಭಾಶಯಗಳು', cluster: 'ಕ್ಷ', parts: ['ಕ', '್', 'ಷ']),
  'te': (greeting: 'దీపావళి శుభాకాంక్షలు', cluster: 'క్ష', parts: ['క', '్', 'ష']),
  'ta': (greeting: 'தீபாவளி நல்வாழ்த்துக்கள்', cluster: 'கொ', parts: ['க', 'ொ']),
};

ui.Paragraph _layout(String text, FontChoice font, String lang, {double size = 48}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, maxLines: 1))
    ..pushStyle(ui.TextStyle(
      fontFamily: font.families.first,
      fontFamilyFallback: font.families.skip(1).toList(),
      fontSize: size,
      fontVariations: [ui.FontVariation('wght', font.weight)],
      locale: ui.Locale(lang),
    ))
    ..addText(text);
  return b.build()..layout(const ui.ParagraphConstraints(width: 100000));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => loadBundledFonts(Directory.current.path));

  test('every app language has body and display fonts', () {
    for (final lang in supportedLanguages) {
      for (final role in FontRole.values) {
        final f = bundledFontResolver(role, lang);
        expect(f, isNotNull, reason: '$role/$lang');
        expect(f!.families.last, BundledFonts.notoSans, reason: 'Latin fallback for $role/$lang');
        for (final family in f.families) {
          expect(BundledFonts.files, contains(family));
        }
      }
    }
  });

  for (final MapEntry(key: lang, value: s) in _samples.entries) {
    for (final role in [FontRole.body, FontRole.display]) {
      test('$lang ${role.name}: font loaded and script shaped', () {
        final font = bundledFontResolver(role, lang)!;
        final cluster = _layout(s.cluster, font, lang).longestLine;
        final separate = s.parts.map((p) => _layout(p, font, lang).longestLine).reduce((a, b) => a + b);
        expect(cluster, lessThan(separate * 0.9),
            reason: '"${s.cluster}" should shape into one cluster ($cluster vs $separate)');

        // The test font (Ahem) draws every code point as a 1em square.
        final greeting = _layout(s.greeting, font, lang);
        expect(greeting.longestLine, isNot(closeTo(s.greeting.runes.length * 48.0, 1)));
      });
    }
  }

  test('English uses real fonts, not the test font', () {
    for (final role in [FontRole.body, FontRole.display]) {
      final p = _layout('Happy Diwali', bundledFontResolver(role, 'en')!, 'en');
      expect(p.longestLine, lessThan('Happy Diwali'.length * 48.0 * 0.8));
    }
  });

  test('Latin name inside an Indic poster falls back to Noto Sans', () {
    final font = bundledFontResolver(FontRole.display, 'kn')!;
    final p = _layout('Vinay Kulkarni', font, 'kn');
    expect(p.longestLine, lessThan('Vinay Kulkarni'.length * 48.0 * 0.8));
  });

  // Set POSTER_SAMPLE_OUT=<file.png> to write a sheet for eyeballing.
  test('sample sheet', () async {
    final out = Platform.environment['POSTER_SAMPLE_OUT'];
    if (out == null) return;
    const w = 1400.0, rowH = 150.0;
    final langs = ['en', ..._samples.keys];
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec)
      ..drawRect(ui.Rect.fromLTWH(0, 0, w, rowH * langs.length), ui.Paint()..color = const ui.Color(0xFF3B1F0E));
    for (final (i, lang) in langs.indexed) {
      final text = lang == 'en' ? 'Happy Diwali — Dhokia Family' : _samples[lang]!.greeting;
      final display = _layout(text, bundledFontResolver(FontRole.display, lang)!, lang, size: 56);
      final body = _layout('$lang · ${lang == 'en' ? 'Rajdeepsinh Jadeja' : text}', bundledFontResolver(FontRole.body, lang)!, lang, size: 32);
      c
        ..drawParagraph(display, ui.Offset(30, i * rowH + 10))
        ..drawParagraph(body, ui.Offset(30, i * rowH + 95));
    }
    final img = await rec.endRecording().toImage(w.toInt(), (rowH * langs.length).toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
