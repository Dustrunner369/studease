import 'package:flutter/material.dart';

abstract final class Tone {
  static const bg = Color(0xFFFFFFFF);
  static const ink = Color(0xFF101828); // near-black text
  static const muted = Color(0xFF667085); // secondary text
  static const line = Color(0xFFEAECF0); // hairline dividers
  static const field = Color(0xFFF2F4F7); // search field / chips

  // accent trio — used for small lines and illustration strokes
  static const teal = Color(0xFF0BA574);
  static const amber = Color(0xFFF5A623);
  static const coral = Color(0xFFF4633A);
}

Color scoreColor(double s) {
  if (s >= 9.0) return const Color(0xFF0BA574); // emerald
  if (s >= 8.0) return const Color(0xFF7CB342); // green
  if (s >= 7.0) return const Color(0xFFF5A623); // amber
  return const Color(0xFFF4633A); // coral
}

enum Level {
  good(Color(0xFF0BA574), 'Great'),
  ok(Color(0xFFF5A623), 'Okay'),
  rough(Color(0xFFF4633A), 'Rough');

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