// Hallmark · route: custom (tuned) · vibe: "cozy coffee shop, hand-drawn, warm"
// paper: #EAE0C8 · accent: #BC6B47 (terracotta) · display+body: Fraunces · wordmark: Pacifico (placeholder)
// axes: light / italic-serif-adjacent / chromatic-terracotta · studied: no · context: explicit
//
// Rebuilt 2026-08-06 for the "cozy coffee shop" rebrand. Fonts, palette, spacing, and
// motion tokens apply app-wide (foundational identity, cheap to propagate); the
// structural/motion rebuild itself is scoped to the Spots tab + detail sheet first, per
// the rollout decision — other screens pick up the new colors/type for free but haven't
// been re-laid-out yet.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Tone {
  // Cream paper, from the user's own reference — not a generated value.
  static const bg = Color(0xFFEAE0C8);
  // One elevation step down: cards, fields, chips.
  static const field = Color(0xFFDED1AC);
  // Warm coffee-brown ink, not cold near-black — same family as the reference
  // illustrations' hand-inked strokes.
  static const ink = Color(0xFF2B2318);
  // Secondary text: warm taupe, tinted toward the paper's hue, never neutral gray.
  static const muted = Color(0xFF7D7259);
  // Hairline dividers: between bg and field.
  static const line = Color(0xFFD6C7A1);

  // Accent trio — replaces the old teal/amber/coral. A "vintage general store"
  // palette instead of a generic startup-dashboard one.
  static const terracotta = Color(0xFFBC6B47); // primary warm accent — CTAs, "great"
  static const slate = Color(0xFF708090); // user's own pick — cool secondary accent
  static const sage = Color(0xFF838C67); // muted botanical green — third accent

  // Focus ring: terracotta at higher chroma for visibility. Never animated in —
  // it must appear instantly per Hallmark's motion discipline.
  static const focus = Color(0xFFD97A4E);

  // Error/destructive — deliberately separate from the accent trio above. The old
  // palette conflated "third decorative accent" with "error state" (both were
  // coral); splitting them is cleaner. Same rust as Level.rough below — both mean
  // "bad", so they share a color.
  static const error = Color(0xFF9B4A2C);
}

// ---------------------------------------------------------------------------
// Avatar accent colors — a curated palette a user's avatar icon (and optionally
// its circle background) can be tinted with. Three reuse Tone's own accent trio
// so a "sage" avatar matches the sage seen elsewhere; the rest extend the same
// muted "vintage general store" register rather than a saturated rainbow.
// ---------------------------------------------------------------------------

class AvatarColor {
  final String slug;
  final String label;
  final Color value;
  const AvatarColor(this.slug, this.label, this.value);
}

const List<AvatarColor> avatarColorPalette = [
  AvatarColor('terracotta', 'Terracotta', Tone.terracotta),
  AvatarColor('slate', 'Slate', Tone.slate),
  AvatarColor('sage', 'Sage', Tone.sage),
  AvatarColor('plum', 'Plum', Color(0xFF7A5568)),
  AvatarColor('cranberry', 'Cranberry', Color(0xFF8B3A42)),
  AvatarColor('mustard', 'Mustard', Color(0xFFC99A3C)),
  AvatarColor('forest', 'Forest', Color(0xFF4F6B4A)),
  AvatarColor('denim', 'Denim', Color(0xFF4A6670)),
];

Color? avatarColorFor(String? slug) {
  for (final c in avatarColorPalette) {
    if (c.slug == slug) return c.value;
  }
  return null;
}

/// A light, cream-forward tint derived from an accent — mostly Tone.bg with a
/// wash of the accent, so a tinted avatar background still reads as the app's
/// warm paper rather than a saturated sticker.
Color avatarBackgroundTint(Color accent) => Color.lerp(Tone.bg, accent, 0.22)!;

Color scoreColor(double s) {
  if (s >= 9.0) return Tone.sage;
  if (s >= 8.0) return const Color(0xFF9BA37A); // lighter sage
  if (s >= 7.0) return Tone.terracotta;
  return const Color(0xFF9B4A2C); // deeper rust
}

enum Level {
  good(Tone.sage, 'Great'),
  ok(Tone.terracotta, 'Okay'),
  rough(Color(0xFF9B4A2C), 'Rough');

  final Color color;
  final String display;
  const Level(this.color, this.display);
}

/// Buckets a 1-5 rating for display. Every rating reads "higher is better", so this
/// works for all six categories — including noise, where 5 means quiet, and table size,
/// where 5 means big shared tables.
Level levelFor(int rating) {
  if (rating >= 4) return Level.good;
  if (rating >= 3) return Level.ok;
  return Level.rough;
}

// ---------------------------------------------------------------------------
// Type — Fraunces throughout (the free stand-in for Roslindale Variable: same
// warm, characterful, slightly eccentric register, same variable weight range).
// One family, weight-differentiated — headings lean heavy, body stays light —
// which keeps the "handwritten warmth" consistent instead of splitting the app
// between a serif and a sans. Pacifico is the outlier: wordmark only, nowhere else.
//
// Sizes below aren't a fresh invented scale — they're the sizes already organically
// in use across the app (11, 12.5, 13.5, 14.5, 15.5, 19, 23, 30...), named by role
// instead of typed as raw literals at every call site.
// ---------------------------------------------------------------------------

abstract final class TextScale {
  static const caption = 11.0;
  static const label = 12.5;
  static const bodySm = 13.5;
  static const body = 14.5;
  static const bodyLg = 15.5;
  static const title = 19.0;
  static const headline = 23.0;
  static const display = 30.0;
}

/// Named text styles on Fraunces. Use these instead of calling `GoogleFonts.fraunces`
/// directly so size/weight pairings stay consistent instead of drifting per call site.
abstract final class AppText {
  static TextStyle display({Color color = Tone.ink}) => GoogleFonts.fraunces(
        fontSize: TextScale.display,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle headline({Color color = Tone.ink}) => GoogleFonts.fraunces(
        fontSize: TextScale.headline,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle title({Color color = Tone.ink}) => GoogleFonts.fraunces(
        fontSize: TextScale.title,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: color,
      );

  static TextStyle bodyLg({Color color = Tone.ink, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.fraunces(fontSize: TextScale.bodyLg, fontWeight: weight, color: color);

  static TextStyle body({Color color = Tone.ink, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.fraunces(fontSize: TextScale.body, fontWeight: weight, color: color);

  static TextStyle bodySm({Color color = Tone.muted, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.fraunces(fontSize: TextScale.bodySm, fontWeight: weight, color: color);

  static TextStyle label({Color color = Tone.muted, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.fraunces(
        fontSize: TextScale.label,
        fontWeight: weight,
        letterSpacing: 1.1,
        color: color,
      );

  static TextStyle caption({Color color = Tone.muted}) => GoogleFonts.fraunces(
        fontSize: TextScale.caption,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// The logo/wordmark face — a placeholder script until a purchased font replaces
  /// it. Outlier discipline: wordmark only, don't reach for this anywhere else.
  static TextStyle wordmark({Color color = Tone.ink, double fontSize = 32}) =>
      GoogleFonts.pacifico(fontSize: fontSize, color: color);
}

// ---------------------------------------------------------------------------
// Spacing — 4pt scale, named by role. Mobile-scoped subset of Hallmark's nine
// steps; the two largest (3xl/4xl) don't come up on a phone screen.
// ---------------------------------------------------------------------------

abstract final class Space {
  static const xs3 = 2.0;
  static const xs2 = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const xl2 = 64.0;
}

// ---------------------------------------------------------------------------
// Motion — durations and easings, named tokens. Animate transform/opacity only.
// Curve values are Hallmark's exact cubic-beziers, not Flutter's built-in Curves
// presets, so the feel matches the discipline precisely.
// ---------------------------------------------------------------------------

abstract final class Motion {
  static const micro = Duration(milliseconds: 120); // press, toggle, color shift
  static const short = Duration(milliseconds: 220); // row enter/exit, sheet reveal
  static const long = Duration(milliseconds: 420); // full-screen transitions

  // Elements entering: decelerate into place.
  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  // Elements leaving: accelerate away.
  static const easeIn = Cubic(0.7, 0, 0.84, 0);
  // State toggles: symmetrical.
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
}
