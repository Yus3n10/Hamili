import 'package:flutter/material.dart';

/// Central color palette. Never hardcode a hex value in a widget —
/// reference these instead, so a rebrand touches one file.
///
/// Green brand identity (the Hamili "H" + rising path + star): a confident
/// green primary with a deep-navy secondary and a fresh mint accent, on white
/// (light) / navy (dark) surfaces. Coral for expense, teal for income so
/// positive amounts stay distinct from the brand green.
class AppColors {
  AppColors._();

  // Brand — green identity (H + rising path + star)
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF15803D);
  static const Color primaryLight = Color(0xFF6EE7B7); // mint accent
  static const Color secondary = Color(0xFF0F172A); // deep navy

  // Semantic
  static const Color income = Color(0xFF0EA5A4); // teal — distinct from brand green
  static const Color expense = Color(0xFFF5455C); // coral red
  static const Color warning = Color(0xFFF59E0B);

  // Light theme neutrals — clean white surfaces on a soft tint
  static const Color lightBackground = Color(0xFFF4F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark theme neutrals — brand navy
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF161E2E);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Brand gradient (logo bg): light green -> deep green
  static const List<Color> brandGradient = [Color(0xFF22C55E), Color(0xFF15803D)];

  // Distinct, accessible series colors for charts (donut/legend).
  static const List<Color> chartPalette = [
    Color(0xFF16A34A), // green
    Color(0xFF0EA5A4), // teal
    Color(0xFF6EE7B7), // mint
    Color(0xFFF5455C), // coral
    Color(0xFF3B82F6), // blue
    Color(0xFF9B6DFF), // violet
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
  ];
}
