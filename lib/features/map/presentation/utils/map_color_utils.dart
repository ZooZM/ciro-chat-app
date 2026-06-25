import 'package:flutter/material.dart';

/// Deterministic avatar background color derived from a user id, replacing
/// the mock data's precomputed `avatarBgColor` (real users have no such
/// field from the backend) — same palette used by the previous mock seeds.
class MapColorUtils {
  static const List<Color> _palette = [
    Color(0xFF607D8B),
    Color(0xFFB0BEC5),
    Color(0xFFFCB64F),
    Color(0xFF546E7A),
    Color(0xFF00796B),
    Color(0xFF1E3A5F),
    Color(0xFFD81B60),
  ];

  static Color forId(String id) {
    if (id.isEmpty) return _palette.first;
    final hash = id.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _palette[hash % _palette.length];
  }
}
