import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String chivo = 'Chivo';
  static const String sourceSans = 'Source Sans 3';

  static const TextStyle displayLg = TextStyle(
    fontFamily: chivo,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 48 / 40,
    letterSpacing: -0.02 * 40,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: chivo,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 38 / 32,
  );

  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: chivo,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: chivo,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sourceSans,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: sourceSans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle labelLg = TextStyle(
    fontFamily: chivo,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: 0.05 * 14,
  );

  static const TextStyle statsNumber = TextStyle(
    fontFamily: chivo,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 24 / 22,
  );

  static TextTheme textTheme(Color onSurface) {
    return TextTheme(
      displayLarge: displayLg.copyWith(color: onSurface),
      headlineLarge: headlineLg.copyWith(color: onSurface),
      headlineMedium: headlineMd.copyWith(color: onSurface),
      titleLarge: headlineMd.copyWith(color: onSurface),
      bodyLarge: bodyLg.copyWith(color: onSurface),
      bodyMedium: bodyMd.copyWith(color: onSurface),
      labelLarge: labelLg.copyWith(color: onSurface),
    );
  }
}
