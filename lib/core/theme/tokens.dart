import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class C {
  static bool isDark = true;

  static Color get bg => isDark ? const Color(0xFF090A0E) : const Color(0xFFF8FAFC);
  static Color get surface => isDark ? const Color(0xFF12141A) : Colors.white;
  static Color get surfaceHi => isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9);
  static Color get surfaceModal => isDark ? const Color(0xFF20232E) : Colors.white;
  static Color get hairline => isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
  static Color get hairlineSubtle => isDark ? const Color(0x0AFFFFFF) : const Color(0xFFEEF1F6);

  // Dynamic accent linked with AppColors current preset
  static Color get accent => isDark ? AppColors.activeAccentDark : AppColors.activeAccentLight;
  static Color get onAccent => AppColors.currentOnAccent(isDark);

  static Color get text1 => isDark ? const Color(0xFFF4F5F7) : const Color(0xFF0F172A);
  static Color get text2 => isDark ? const Color(0xFF9AA0AA) : const Color(0xFF475569);
  static Color get text3 => isDark ? const Color(0xFF636A78) : const Color(0xFF94A3B8);
  static const positive = Color(0xFF10B981);
}

abstract final class R {
  static const card = 22.0;
  static const button = 16.0;
}

abstract final class S {
  // Strict 4pt grid
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

abstract final class T {
  static TextStyle get display => TextStyle(
        fontFamily: 'Inter',
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: C.text1,
      );

  static TextStyle get title => TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: C.text1,
      );

  static TextStyle get stat => TextStyle(
        fontFamily: 'Inter',
        fontSize: 34,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: C.text1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get body => TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: C.text2,
      );

  static TextStyle get label => TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: C.text3,
      );
}
