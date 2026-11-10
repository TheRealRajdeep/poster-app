import 'dart:convert';

import 'model.dart';

/// One problem found in a spec, with a JSON-path-like location.
class SpecError {
  const SpecError(this.path, this.message);
  final String path;
  final String message;
  @override
  String toString() => '$path: $message';
}

/// Either a valid [spec] or a non-empty list of [errors]. Never throws,
/// so one bad spec in the feed is skipped instead of crashing the app.
class SpecParseResult {
  const SpecParseResult._(this.spec, this.errors);
  final PosterSpec? spec;
  final List<SpecError> errors;
  bool get isValid => spec != null;
}

SpecParseResult parseSpecJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    return SpecParseResult._(null, [SpecError(r'$', 'invalid JSON: ${e.message}')]);
  }
  return parseSpec(decoded);
}

SpecParseResult parseSpec(Object? json) {
  final r = _Reader();
  final spec = r.spec(json);
  if (r.errors.isNotEmpty || spec == null) {
    return SpecParseResult._(null, List.unmodifiable(r.errors));
  }
  return SpecParseResult._(spec, const []);
}

final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');
final _colorPattern = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

class _Reader {
  final errors = <SpecError>[];

  void _err(String path, String msg) => errors.add(SpecError(path, msg));

  Map<String, Object?>? _map(Object? v, String path) {
    if (v is Map<String, Object?>) return v;
    _err(path, 'expected an object');
    return null;
  }

  List<Object?>? _list(Object? v, String path) {
    if (v is List<Object?>) return v;
    _err(path, 'expected an array');
    return null;
  }

  String? _string(Object? v, String path, {RegExp? pattern}) {
    if (v is! String || v.isEmpty) {
      _err(path, 'expected a non-empty string');
      return null;
    }
    if (pattern != null && !pattern.hasMatch(v)) {
      _err(path, '"$v" must match ${pattern.pattern}');
      return null;
    }
    return v;
  }

  num? _num(Object? v, String path) {
    if (v is num) return v;
    _err(path, 'expected a number');
    return null;
  }

  T? _enum<T extends Enum>(Object? v, String path, List<T> values, T? fallback) {
    if (v == null && fallback != null) return fallback;
    if (v is String) {
      for (final e in values) {
        if (_kebab(e.name) == v) return e;
      }
    }
    _err(path, 'expected one of ${values.map((e) => _kebab(e.name)).join(', ')}');
    return null;
  }

  int? _color(Object? v, String path) {
    if (v is String && _colorPattern.hasMatch(v)) {
      final hex = v.substring(1);
      return int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    }
    _err(path, 'expected a colour like "#RRGGBB" or "#AARRGGBB"');
    return null;
  }

  PosterSpec? spec(Object? json) {
    final m = _map(json, r'$');
    if (m == null) return null;

    final version = m['version'];
    if (version != currentSpecVersion) {
      _err(r'$.version', 'unsupported version $version (expected $currentSpecVersion)');
    }
    final id = _string(m['id'], r'$.id', pattern: _slugPattern);
    final occasion = _string(m['occasion'], r'$.occasion', pattern: _slugPattern);
    final archetype = _string(m['archetype'], r'$.archetype', pattern: _slugPattern);
    final scene = _string(m['scene'], r'$.scene');

    final tones = <String>[];
    final tonesJson = m['tones'] == null ? const <Object?>[] : _list(m['tones'], r'$.tones');
    for (final (i, t) in (tonesJson ?? const <Object?>[]).indexed) {
      final s = _string(t, '\$.tones[$i]', pattern: _slugPattern);
      if (s != null) tones.add(s);
    }

    final langs = <String>{};
    final langsJson = _list(m['langs'], r'$.langs');
    if (langsJson != null) {
      if (langsJson.isEmpty) _err(r'$.langs', 'must list at least one language');
      for (final (i, l) in langsJson.indexed) {
        if (l is String && supportedLanguages.contains(l)) {
          langs.add(l);
        } else {
          _err('\$.langs[$i]', 'unsupported language "$l"; expected one of ${supportedLanguages.join(', ')}');
        }
      }
    }

    final canvas = _canvas(m['canvas']);

    final slots = <Slot>[];
    final slotsJson = _list(m['slots'], r'$.slots');
    if (slotsJson != null) {
      for (final (i, s) in slotsJson.indexed) {
        final slot = _slot(s, '\$.slots[$i]', canvas);
        if (slot != null) slots.add(slot);
      }
      if (slots.whereType<PhotoSlot>().isEmpty) {
        _err(r'$.slots', 'needs at least one photo slot');
      }
      if (!slots.any((s) =>
          s is TextSlot && (s.bind == Binding.selfName || s.bind == Binding.otherName))) {
        _err(r'$.slots', 'needs at least one name text slot');
      }
    }

    if (errors.isNotEmpty) return null;
    return PosterSpec(
      version: currentSpecVersion,
      id: id!,
      occasion: occasion!,
      archetype: archetype!,
      tones: List.unmodifiable(tones),
      languages: Set.unmodifiable(langs),
      canvas: canvas!,
      scene: scene!,
      slots: List.unmodifiable(slots),
    );
  }

  CanvasSize? _canvas(Object? v) {
    final l = _list(v, r'$.canvas');
    if (l == null) return null;
    if (l.length != 2 || l.any((e) => e is! int || e <= 0)) {
      _err(r'$.canvas', 'expected [width, height] as positive integers');
      return null;
    }
    return CanvasSize(l[0]! as int, l[1]! as int);
  }

  Box? _box(Object? v, String path, CanvasSize? canvas) {
    final l = _list(v, path);
    if (l == null) return null;
    if (l.length != 4 || l.any((e) => e is! num)) {
      _err(path, 'expected [left, top, right, bottom] as numbers');
      return null;
    }
    final [left, top, right, bottom] = [for (final e in l) (e! as num).toDouble()];
    if (left >= right || top >= bottom) {
      _err(path, 'box has no area (left < right and top < bottom required)');
      return null;
    }
    if (canvas != null &&
        (left < 0 || top < 0 || right > canvas.width || bottom > canvas.height)) {
      _err(path, 'box lies outside the $canvas canvas');
      return null;
    }
    return Box(left, top, right, bottom);
  }

  Slot? _slot(Object? v, String path, CanvasSize? canvas) {
    final m = _map(v, path);
    if (m == null) return null;
    final box = _box(m['box'], '$path.box', canvas);
    switch (m['type']) {
      case 'photo':
        final who = _enum(m['who'], '$path.who', Person.values, null);
        final anchor = _enum(m['anchor'], '$path.anchor', PhotoAnchor.values, PhotoAnchor.bottomCenter);
        final shadow = m['shadow'] ?? false;
        if (shadow is! bool) _err('$path.shadow', 'expected true or false');
        if (box == null || who == null || anchor == null || shadow is! bool) return null;
        return PhotoSlot(box: box, who: who, anchor: anchor, shadow: shadow);
      case 'text':
        return _textSlot(m, path, box);
      default:
        _err('$path.type', 'expected "photo" or "text"');
        return null;
    }
  }

  TextSlot? _textSlot(Map<String, Object?> m, String path, Box? box) {
    final bindKey = m['bind'];
    final bind = bindKey is String ? Binding.fromKey(bindKey) : null;
    if (bind == null) {
      _err('$path.bind', 'expected one of ${Binding.values.map((b) => b.key).join(', ')}');
    }
    final font = _enum(m['font'], '$path.font', FontRole.values, FontRole.body);
    final align = _enum(m['align'], '$path.align', TextAlign.values, TextAlign.center);
    final fill = m['fill'] == null ? const SolidFill(0xFFFFFFFF) : _fill(m['fill'], '$path.fill');

    Stroke? stroke;
    if (m['stroke'] != null) {
      final s = _map(m['stroke'], '$path.stroke');
      if (s != null) {
        final c = _color(s['color'], '$path.stroke.color');
        final w = _num(s['width'], '$path.stroke.width');
        if (w != null && w <= 0) _err('$path.stroke.width', 'must be > 0');
        if (c != null && w != null && w > 0) stroke = Stroke(color: c, width: w.toDouble());
      }
    }

    TextShadow? shadow;
    if (m['shadow'] != null) {
      final s = _map(m['shadow'], '$path.shadow');
      if (s != null) {
        final c = _color(s['color'], '$path.shadow.color');
        final blur = s['blur'] == null ? 8 : _num(s['blur'], '$path.shadow.blur');
        final dx = s['dx'] == null ? 0 : _num(s['dx'], '$path.shadow.dx');
        final dy = s['dy'] == null ? 2 : _num(s['dy'], '$path.shadow.dy');
        if (c != null && blur != null && dx != null && dy != null) {
          shadow = TextShadow(color: c, blur: blur.toDouble(), dx: dx.toDouble(), dy: dy.toDouble());
        }
      }
    }

    final maxLines = m['maxLines'] ?? 1;
    if (maxLines is! int || maxLines < 1) _err('$path.maxLines', 'expected an integer >= 1');
    final minSize = m['minFontSize'] == null ? 24 : _num(m['minFontSize'], '$path.minFontSize');
    final maxSize = m['maxFontSize'] == null ? 160 : _num(m['maxFontSize'], '$path.maxFontSize');
    if (minSize != null && maxSize != null && (minSize <= 0 || minSize > maxSize)) {
      _err('$path.minFontSize', 'must be > 0 and <= maxFontSize');
    }

    if (box == null || bind == null || font == null || align == null || fill == null ||
        maxLines is! int || maxLines < 1 || minSize == null || maxSize == null ||
        minSize <= 0 || minSize > maxSize) {
      return null;
    }
    return TextSlot(
      box: box,
      bind: bind,
      font: font,
      fill: fill,
      stroke: stroke,
      shadow: shadow,
      align: align,
      maxLines: maxLines,
      minFontSize: minSize.toDouble(),
      maxFontSize: maxSize.toDouble(),
    );
  }

  Fill? _fill(Object? v, String path) {
    if (v is String) {
      final c = _color(v, path);
      return c == null ? null : SolidFill(c);
    }
    final m = _map(v, path);
    if (m == null) return null;
    if (m['preset'] != null) {
      final name = m['preset'];
      if (name is String && knownFillPresets.contains(name)) return PresetFill(name);
      _err('$path.preset', 'unknown preset "$name"; expected one of ${knownFillPresets.join(', ')}');
      return null;
    }
    if (m['gradient'] != null) {
      final l = _list(m['gradient'], '$path.gradient');
      if (l == null) return null;
      if (l.length < 2) {
        _err('$path.gradient', 'needs at least 2 colours');
        return null;
      }
      final colors = <int>[];
      for (final (i, c) in l.indexed) {
        final parsed = _color(c, '$path.gradient[$i]');
        if (parsed != null) colors.add(parsed);
      }
      final angle = m['angle'] == null ? 90 : _num(m['angle'], '$path.angle');
      if (colors.length != l.length || angle == null) return null;
      return GradientFill(colors: List.unmodifiable(colors), angle: angle.toDouble());
    }
    _err(path, 'expected a colour string, {"preset": …} or {"gradient": […]}');
    return null;
  }
}

/// `bottomCenter` -> `bottom-center`, matching the JSON spelling.
String _kebab(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');
