/// Immutable data model for a poster `spec.json`.
///
/// A spec says *where* things go on a text-free scene image. It never
/// contains user data: text slots point at a [Binding] that the renderer
/// fills in from the user's profile at render time.
library;

/// Languages the app ships with (BCP-47 primary subtags).
const supportedLanguages = {'en', 'hi', 'mr', 'gu', 'kn', 'te', 'ta'};

/// The only spec format version this package understands.
const currentSpecVersion = 1;

class PosterSpec {
  const PosterSpec({
    required this.version,
    required this.id,
    required this.occasion,
    required this.archetype,
    required this.tones,
    required this.languages,
    required this.canvas,
    required this.scene,
    required this.slots,
  });

  final int version;

  /// Stable id, e.g. `diwali-2026-0412`. Used in bug reports and analytics.
  final String id;

  /// Occasion key, e.g. `diwali`, `good-morning`, `birthday`.
  final String occasion;

  /// Layout archetype id the scene was generated for, e.g. `photo-left-text-right`.
  final String archetype;

  /// Festival/tone tags used for feed filtering (never sent to ads).
  final List<String> tones;

  /// Languages this poster may be shown in.
  final Set<String> languages;

  final CanvasSize canvas;

  /// Scene image reference (R2 key or bundled asset path), resolved by the app.
  final String scene;

  /// Drawn in list order: later slots paint on top.
  final List<Slot> slots;

  /// True when the poster needs a second person ("Wish someone" tab).
  bool get needsOtherPerson => slots.any(
        (s) =>
            (s is PhotoSlot && s.who == Person.other) ||
            (s is TextSlot && s.bind.person == Person.other),
      );
}

class CanvasSize {
  const CanvasSize(this.width, this.height);
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is CanvasSize && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(width, height);
  @override
  String toString() => '${width}x$height';
}

/// Axis-aligned rectangle in canvas pixels: [left, top, right, bottom].
class Box {
  const Box(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is Box &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
  @override
  String toString() => 'Box($left, $top, $right, $bottom)';
}

enum Person { self, other }

sealed class Slot {
  const Slot({required this.box});
  final Box box;
}

/// Where the person cut-out goes.
class PhotoSlot extends Slot {
  const PhotoSlot({
    required super.box,
    required this.who,
    this.anchor = PhotoAnchor.bottomCenter,
    this.shadow = false,
  });

  final Person who;

  /// The cut-out is scaled to fit inside [box] and pinned to this edge,
  /// so people "stand" on the bottom of the frame like in print posters.
  final PhotoAnchor anchor;
  final bool shadow;
}

enum PhotoAnchor { bottomCenter, bottomLeft, bottomRight, center }

/// What a text slot shows. Resolved by the renderer, never stored in the spec.
enum Binding {
  /// Occasion greeting in the user's language, e.g. "दीपावली की हार्दिक शुभकामनाएं".
  greeting('greeting', null),

  /// Secondary line under the greeting (e.g. a short wish message).
  message('message', null),
  selfName('self.name', Person.self),
  selfSubtitle('self.subtitle', Person.self),
  otherName('other.name', Person.other),
  otherSubtitle('other.subtitle', Person.other);

  const Binding(this.key, this.person);
  final String key;
  final Person? person;

  static Binding? fromKey(String key) {
    for (final b in values) {
      if (b.key == key) return b;
    }
    return null;
  }
}

enum TextAlign { start, center, end }

/// Font role, mapped to a concrete family per script by the renderer.
/// Specs never name a font file, so one spec works in all 7 languages.
enum FontRole { body, display, script, ornate }

class TextSlot extends Slot {
  const TextSlot({
    required super.box,
    required this.bind,
    this.font = FontRole.body,
    this.fill = const SolidFill(0xFFFFFFFF),
    this.stroke,
    this.shadow,
    this.align = TextAlign.center,
    this.maxLines = 1,
    this.minFontSize = 24,
    this.maxFontSize = 160,
  });

  final Binding bind;
  final FontRole font;
  final Fill fill;
  final Stroke? stroke;
  final TextShadow? shadow;
  final TextAlign align;
  final int maxLines;

  /// Text auto-fits between these sizes; if it still overflows at
  /// [minFontSize] the renderer ellipsizes (and QA rejects the spec).
  final double minFontSize;
  final double maxFontSize;
}

sealed class Fill {
  const Fill();
}

/// ARGB colour, e.g. 0xFFFFF3D6.
class SolidFill extends Fill {
  const SolidFill(this.color);
  final int color;
}

class GradientFill extends Fill {
  const GradientFill({required this.colors, this.angle = 90});
  final List<int> colors;

  /// Degrees; 90 = top to bottom.
  final double angle;
}

/// Named effect implemented in the renderer, e.g. `gold-glitter`.
class PresetFill extends Fill {
  const PresetFill(this.name);
  final String name;
}

/// Effects the renderer knows how to draw.
const knownFillPresets = {'gold-glitter', 'silver-shine', 'saffron-glow'};

class Stroke {
  const Stroke({required this.color, required this.width});
  final int color;
  final double width;
}

class TextShadow {
  const TextShadow({
    required this.color,
    this.blur = 8,
    this.dx = 0,
    this.dy = 2,
  });
  final int color;
  final double blur;
  final double dx;
  final double dy;
}
