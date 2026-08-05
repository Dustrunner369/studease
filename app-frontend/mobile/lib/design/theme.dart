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
/// works for all five categories — including noise, where 5 means quiet.
Level levelFor(int rating) {
  if (rating >= 4) return Level.good;
  if (rating >= 3) return Level.ok;
  return Level.rough;
}

enum SpotType {
  cafe('cafe', 'Café', Icons.local_cafe, Color(0xFFFFE8D9), Color(0xFFF4633A)),
  library('library', 'Library', Icons.menu_book, Color(0xFFDDF3E8), Color(0xFF0BA574)),
  campus('campus', 'Campus', Icons.school, Color(0xFFECE8FD), Color(0xFF7A5AF8)),
  other('other', 'Other', Icons.place, Color(0xFFEAECF0), Color(0xFF667085));

  final String api; // the value the API stores in spots.type
  final String label;
  final IconData icon;
  final Color pastel; // circle background
  final Color accent; // icon color
  const SpotType(this.api, this.label, this.icon, this.pastel, this.accent);
}

/// Unknown or missing types fall back to café rather than throwing — a spot the
/// server categorised in a way this build doesn't know about should still render.
SpotType spotTypeFromApi(String? value) => SpotType.values.firstWhere(
      (type) => type.api == value,
      orElse: () => SpotType.cafe,
    );