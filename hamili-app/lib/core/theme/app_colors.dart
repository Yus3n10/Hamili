import 'package:flutter/material.dart';

/// Central color palette. Never hardcode a hex value in a widget —
/// reference these instead, so a rebrand touches one file.
class AppColors {
  AppColors._();

  // Brand — warm gold echoes the Hami coin mascot
  static const Color primary = Color(0xFFF5A623);
  static const Color primaryDark = Color(0xFFD98C0F);
  static const Color secondary = Color(0xFF2ECC71); // growth / savings green

  // Semantic
  static const Color income = Color(0xFF2ECC71);
  static const Color expense = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  // Light theme neutrals
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6E6E6E);

  // Dark theme neutrals
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
}
