/// Composes (spec + scene + profile) into a poster image.
///
/// Pure and deterministic: no Firebase, no widgets, no app state. A bug
/// report with a spec id + profile can be replayed exactly in a test.
library;

export 'src/fonts.dart';
export 'src/renderer.dart';
