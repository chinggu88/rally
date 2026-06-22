import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // View 공용 상수 (ColorScheme으로 매핑하기 애매하거나 자주 반복되는 톤)
  static const Color bg = Color(0xFF0A0A0A);
  static const Color accent = Color(0xFFC3F400);
  static const Color accentDark = Color(0xFF283500);
  static const Color accentLime = Color(0xFFD7FF00);
  static const Color accentNeon = Color(0xFFE0EC30);
  static const Color subtleText = Color(0xFF9CA3A1);
  static const Color divider = Color(0xFF1F2421);
  static const Color cardBg = Color(0xFF1C1B1B);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color chipBg = Color(0xFF201F1F);
  static const Color surfaceAlt = Color(0xFF222121);
  static const Color surfaceAlt2 = Color(0xFF252423);
  static const Color gradientStart = Color(0xFF1B1F1C);
  static const Color gradientStartAlt = Color(0xFF202521);
  static const Color liveRed = Color(0xFFFF3B30);
  static const Color liveRedAlt = Color(0xFFFF4D4F);
  static const Color inactive = Color(0xFF3A3A3A);
  static const Color muted = Color(0xFF6B6B6B);
  static const Color upGreen = Color(0xFF4ADE80);
  static const Color downRed = Color(0xFFFF6B6B);
  static const Color hint = Color(0xFF5C5F5D);
  static const Color surfaceDeep = Color(0xFF14181A);
  static const Color surfaceDeepest = Color(0xFF0E0E0E);

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF283500),
    primaryContainer: Color(0xFFC3F400),
    onPrimaryContainer: Color(0xFF556D00),
    secondary: Color(0xFFE0EC30),
    onSecondary: Color(0xFF303300),
    secondaryContainer: Color(0xFFC4D000),
    onSecondaryContainer: Color(0xFF515700),
    tertiary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFF303030),
    tertiaryContainer: Color(0xFFE5E2E1),
    onTertiaryContainer: Color(0xFF656464),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131313),
    onSurface: Color(0xFFE5E2E1),
    surfaceContainerLowest: Color(0xFF0E0E0E),
    surfaceContainerLow: Color(0xFF1C1B1B),
    surfaceContainer: Color(0xFF201F1F),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainerHighest: Color(0xFF353534),
    surfaceDim: Color(0xFF131313),
    surfaceBright: Color(0xFF393939),
    onSurfaceVariant: Color(0xFFC4C9AC),
    outline: Color(0xFF8E9379),
    outlineVariant: Color(0xFF444933),
    inverseSurface: Color(0xFFE5E2E1),
    onInverseSurface: Color(0xFF313030),
    inversePrimary: Color(0xFF506600),
    surfaceTint: Color(0xFFABD600),
    primaryFixed: Color(0xFFC3F400),
    primaryFixedDim: Color(0xFFABD600),
    onPrimaryFixed: Color(0xFF161E00),
    onPrimaryFixedVariant: Color(0xFF3C4D00),
    secondaryFixed: Color(0xFFE0EC30),
    secondaryFixedDim: Color(0xFFC4D000),
    onSecondaryFixed: Color(0xFF1B1D00),
    onSecondaryFixedVariant: Color(0xFF464A00),
    tertiaryFixed: Color(0xFFE5E2E1),
    tertiaryFixedDim: Color(0xFFC8C6C5),
    onTertiaryFixed: Color(0xFF1B1B1C),
    onTertiaryFixedVariant: Color(0xFF474746),
  );

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF131313),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFC3F400),
    onPrimaryContainer: Color(0xFF283500),
    secondary: Color(0xFF556D00),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0EC30),
    onSecondaryContainer: Color(0xFF1B1D00),
    tertiary: Color(0xFF313030),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE5E2E1),
    onTertiaryContainer: Color(0xFF313030),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF131313),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F7F6),
    surfaceContainer: Color(0xFFF1F1F0),
    surfaceContainerHigh: Color(0xFFEBEBEA),
    surfaceContainerHighest: Color(0xFFE5E5E4),
    surfaceDim: Color(0xFFDCDCDB),
    surfaceBright: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF464A39),
    outline: Color(0xFF767A66),
    outlineVariant: Color(0xFFC6CAB2),
    inverseSurface: Color(0xFF2F2F2F),
    onInverseSurface: Color(0xFFF0F0EF),
    inversePrimary: Color(0xFFABD600),
    surfaceTint: Color(0xFF506600),
    primaryFixed: Color(0xFFC3F400),
    primaryFixedDim: Color(0xFFABD600),
    onPrimaryFixed: Color(0xFF161E00),
    onPrimaryFixedVariant: Color(0xFF3C4D00),
    secondaryFixed: Color(0xFFE0EC30),
    secondaryFixedDim: Color(0xFFC4D000),
    onSecondaryFixed: Color(0xFF1B1D00),
    onSecondaryFixedVariant: Color(0xFF464A00),
    tertiaryFixed: Color(0xFFE5E2E1),
    tertiaryFixedDim: Color(0xFFC8C6C5),
    onTertiaryFixed: Color(0xFF1B1B1C),
    onTertiaryFixedVariant: Color(0xFF474746),
  );
}
