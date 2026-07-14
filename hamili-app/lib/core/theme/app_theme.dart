import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'accent_palette.dart';
import 'app_colors.dart';


class AppTheme {
  AppTheme._();


  static const Color _onPrimary = Color(0xFFFFFFFF);

  static ThemeData light(AppAccent accent) => _build(
        accent: accent,
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
      );

  static ThemeData dark(AppAccent accent) => _build(
        accent: accent,
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
      );

  static TextTheme _textTheme(TextTheme base, Color textPrimary) {

    final body = GoogleFonts.interTextTheme(base).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    TextStyle heading(TextStyle? s, FontWeight w) =>
        GoogleFonts.inter(textStyle: s, fontWeight: w, color: textPrimary);
    return body.copyWith(
      displayLarge: heading(body.displayLarge, FontWeight.w700),
      displayMedium: heading(body.displayMedium, FontWeight.w700),
      displaySmall: heading(body.displaySmall, FontWeight.w700),
      headlineLarge: heading(body.headlineLarge, FontWeight.w700),
      headlineMedium: heading(body.headlineMedium, FontWeight.w700),
      headlineSmall: heading(body.headlineSmall, FontWeight.w700),
      titleLarge: heading(body.titleLarge, FontWeight.w700),
      titleMedium: heading(body.titleMedium, FontWeight.w600),
    );
  }

  static ThemeData _build({
    required AppAccent accent,
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, textPrimary);
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent.primary,
      brightness: brightness,
    ).copyWith(
      primary: accent.primary,
      onPrimary: _onPrimary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.expense,
      onError: Colors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        BrandTheme(dark: accent.dark, gradient: accent.gradient),
      ],
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.12),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,

        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.07 : 0.4),
        surfaceTintColor: Colors.transparent,


        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isLight ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.primary,
          foregroundColor: _onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent.primary,
          foregroundColor: _onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: textSecondary.withValues(alpha: 0.25)),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent.dark,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent.primary,
        foregroundColor: _onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? accent.primary.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF0F1F7) : Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 66,
        indicatorColor: accent.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: textPrimary),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent.primary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
