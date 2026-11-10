/// Test-only helpers. Not imported by the app (uses dart:io).
library;

import 'dart:io';

import 'package:flutter/services.dart';

import 'src/fonts.dart';

/// `flutter test` does not load fonts declared in pubspec, so tests call
/// this to register the bundled fonts under the same family names the app
/// uses. [packageRoot] is the poster_renderer directory.
Future<void> loadBundledFonts(String packageRoot) async {
  for (final MapEntry(key: family, value: path) in BundledFonts.files.entries) {
    final bytes = File('$packageRoot/$path').readAsBytesSync();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
