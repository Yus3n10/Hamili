import 'package:flutter/material.dart';

/// Central color palette. Never hardcode a hex value in a widget —
/// reference these instead, so a rebrand touches one file.
///
/// Bright fintech direction (design pass): warm gold brand (the Hami coin),
/// a friendly blue accent for info/charts, fresh green / coral red for
/// income vs expense, on soft bright neutrals with white floating cards.
class AppColors {
  AppColors._();

  // Brand — warm gold echoes the Hami coin mascot
  static const Color primary = Color(0xFFF6A821);
  static const Color primaryDark = Color(0xFFE0890A);
  static const Color primaryLight = Color(0xFFFFD37E);
  static const Color secondary = Color(0xFF4F7CFF); // friendly blue accent

  // Semantic
  static const Color income = Color(0xFF16B364); // fresh green
  static const Color expense = Color(0xFFF5455C); // coral red
  static const Color warning = Color(0xFFF59E0B);

  // Light theme neutrals — bright, soft (never pure white background)
  static const Color lightBackground = Color(0xFFF5F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF171A21);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Dark theme neutrals — premium navy matching the login hero.
  static const Color darkBackground = Color(0xFF0C0E15);
  static const Color darkSurface = Color(0xFF161A24);
  static const Color darkTextPrimary = Color(0xFFF4F6FA);
  static const Color darkTextSecondary = Color(0xFF98A0B0);

  // Warm gold gradient for the balance hero card
  static const List<Color> brandGradient = [Color(0xFFFFB63D), Color(0xFFF08C00)];

  // Distinct, accessible series colors for charts (donut/legend).
  static const List<Color> chartPalette = [
    Color(0xFFF6A821), // gold
    Color(0xFF4F7CFF), // blue
    Color(0xFF16B364), // green
    Color(0xFFF5455C), // coral
    Color(0xFF9B6DFF), // violet
    Color(0xFF15C1C7), // teal
    Color(0xFFFF8A3D), // orange
    Color(0xFFEC4899), // pink
  ];
}
