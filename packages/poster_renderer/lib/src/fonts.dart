import 'package:poster_spec/poster_spec.dart';

/// A concrete font for a text slot: families in fallback order, plus the
/// weight to request on the variable font's `wght` axis.
class FontChoice {
  const FontChoice(this.families, {this.weight = 400});

  /// First entry is the primary family; the rest are fallbacks (e.g. Latin
  /// glyphs inside a Kannada name).
  final List<String> families;
  final double weight;
}

/// Maps a spec's abstract [FontRole] + language to concrete fonts.
/// Returning null uses the platform default.
typedef FontResolver = FontChoice? Function(FontRole role, String language);

/// Families declared in this package's pubspec. Flutter exposes package
/// fonts as `packages/<package>/<family>`.
abstract final class BundledFonts {
  static const _prefix = 'packages/poster_renderer/';

  static const notoSans = '${_prefix}NotoSans';
  static const notoSansDevanagari = '${_prefix}NotoSansDevanagari';
  static const notoSansGujarati = '${_prefix}NotoSansGujarati';
  static const notoSansKannada = '${_prefix}NotoSansKannada';
  static const notoSansTelugu = '${_prefix}NotoSansTelugu';
  static const notoSansTamil = '${_prefix}NotoSansTamil';
  static const baloo2 = '${_prefix}Baloo2';
  static const balooBhai2 = '${_prefix}BalooBhai2';
  static const balooTamma2 = '${_prefix}BalooTamma2';
  static const balooTammudu2 = '${_prefix}BalooTammudu2';
  static const balooThambi2 = '${_prefix}BalooThambi2';

  /// Family name -> font file path relative to the package root.
  static const files = {
    notoSans: 'fonts/NotoSans/NotoSans.ttf',
    notoSansDevanagari: 'fonts/NotoSansDevanagari/NotoSansDevanagari.ttf',
    notoSansGujarati: 'fonts/NotoSansGujarati/NotoSansGujarati.ttf',
    notoSansKannada: 'fonts/NotoSansKannada/NotoSansKannada.ttf',
    notoSansTelugu: 'fonts/NotoSansTelugu/NotoSansTelugu.ttf',
    notoSansTamil: 'fonts/NotoSansTamil/NotoSansTamil.ttf',
    baloo2: 'fonts/Baloo2/Baloo2.ttf',
    balooBhai2: 'fonts/BalooBhai2/BalooBhai2.ttf',
    balooTamma2: 'fonts/BalooTamma2/BalooTamma2.ttf',
    balooTammudu2: 'fonts/BalooTammudu2/BalooTammudu2.ttf',
    balooThambi2: 'fonts/BalooThambi2/BalooThambi2.ttf',
  };
}

/// (body font, display font) per language. Baloo 2 is one design across
/// all five Indic scripts, so a poster keeps its look when the language changes.
const _byLanguage = <String, (String, String)>{
  'en': (BundledFonts.notoSans, BundledFonts.baloo2),
  'hi': (BundledFonts.notoSansDevanagari, BundledFonts.baloo2),
  'mr': (BundledFonts.notoSansDevanagari, BundledFonts.baloo2),
  'gu': (BundledFonts.notoSansGujarati, BundledFonts.balooBhai2),
  'kn': (BundledFonts.notoSansKannada, BundledFonts.balooTamma2),
  'te': (BundledFonts.notoSansTelugu, BundledFonts.balooTammudu2),
  'ta': (BundledFonts.notoSansTamil, BundledFonts.balooThambi2),
};

/// Default resolver for the fonts bundled with this package.
///
/// `script` and `ornate` currently fall back to the display font; the
/// decorative faces are a design decision still to be made with the owner.
FontChoice? bundledFontResolver(FontRole role, String language) {
  final pair = _byLanguage[language];
  if (pair == null) return null;
  final (body, display) = pair;
  // Every chain ends in Noto Sans so mixed-script text (an English name on
  // a Tamil poster) never shows missing-glyph boxes.
  return switch (role) {
    FontRole.body => FontChoice([body, BundledFonts.notoSans], weight: 500),
    FontRole.display ||
    FontRole.script ||
    FontRole.ornate =>
      FontChoice([display, body, BundledFonts.notoSans], weight: 700),
  };
}
