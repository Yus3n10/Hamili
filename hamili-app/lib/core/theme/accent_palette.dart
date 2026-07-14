import 'package:flutter/material.dart';


class AppAccent {
  final String name;
  final Color primary;
  final Color dark;

  const AppAccent({required this.name, required this.primary, required this.dark});

  List<Color> get gradient => [primary, dark];
}

const appAccents = <AppAccent>[
  AppAccent(name: 'Green', primary: Color(0xFF16A34A), dark: Color(0xFF15803D)),
  AppAccent(name: 'Blue', primary: Color(0xFF2563EB), dark: Color(0xFF1D4ED8)),
  AppAccent(name: 'Purple', primary: Color(0xFF7C3AED), dark: Color(0xFF6D28D9)),
  AppAccent(name: 'Pink', primary: Color(0xFFEC4899), dark: Color(0xFFDB2777)),
  AppAccent(name: 'Red', primary: Color(0xFFDC2626), dark: Color(0xFFB91C1C)),
  AppAccent(name: 'Orange', primary: Color(0xFFEA580C), dark: Color(0xFFC2410C)),
  AppAccent(name: 'Amber', primary: Color(0xFFD97706), dark: Color(0xFFB45309)),
  AppAccent(name: 'Teal', primary: Color(0xFF0D9488), dark: Color(0xFF0F766E)),
];

const defaultAccent = AppAccent(name: 'Green', primary: Color(0xFF16A34A), dark: Color(0xFF15803D));


class BrandTheme extends ThemeExtension<BrandTheme> {
  final Color dark;
  final List<Color> gradient;

  const BrandTheme({required this.dark, required this.gradient});

  @override
  BrandTheme copyWith({Color? dark, List<Color>? gradient}) =>
      BrandTheme(dark: dark ?? this.dark, gradient: gradient ?? this.gradient);

  @override
  BrandTheme lerp(BrandTheme? other, double t) {
    if (other == null) return this;
    return BrandTheme(
      dark: Color.lerp(dark, other.dark, t)!,
      gradient: [
        Color.lerp(gradient.first, other.gradient.first, t)!,
        Color.lerp(gradient.last, other.gradient.last, t)!,
      ],
    );
  }
}
