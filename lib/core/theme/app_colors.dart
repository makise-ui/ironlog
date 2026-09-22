import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF07080C);
  static const Color backgroundCard = Color(0xFF0D0F18);
  static const Color surfaceElevated = Color(0xFF131722);

  // Glass tokens
  static const Color glassFill = Color(0x12FFFFFF); // ~7% white fill
  static const Color glassFillActive = Color(0x1AFFFFFF); // ~10% white fill
  static const Color glassTileFill = Color(0x0EFFFFFF); // ~5.5% for list tiles
  static const Color glassBorderLight = Color(0x28FFFFFF); // ~16% white top-left
  static const Color glassBorderDim = Color(0x10FFFFFF); // ~6% white bottom-right
  static const Color glassBorderHighlight = Color(0x40FFFFFF); // ~25% white specular

  // Accent Gradient (#7C5CFF -> #22D3EE)
  static const Color accentViolet = Color(0xFF7C5CFF);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentViolet, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradientHorizontal = LinearGradient(
    colors: [accentViolet, accentCyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Status Colors
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  // Text Colors
  static const Color textPrimary = Color(0xFFF4F6FA);
  static const Color textSecondary = Color(0x99FFFFFF); // 60% white
  static const Color textTertiary = Color(0x55FFFFFF); // 33% white
  static const Color textDisabled = Color(0x33FFFFFF); // 20% white

  // Set type colors
  static const Color warmupSet = Color(0xFFFBBF24); // Amber
  static const Color workingSet = Color(0xFF22D3EE); // Cyan
  static const Color dropSet = Color(0xFFC084FC); // Purple
  static const Color failureSet = Color(0xFFF87171); // Red

  // Muscle group colors
  static const Map<String, Color> muscleGroupColors = {
    'Chest': Color(0xFFFF5376),
    'Back': Color(0xFF3B82F6),
    'Shoulders': Color(0xFFF59E0B),
    'Biceps': Color(0xFF10B981),
    'Triceps': Color(0xFF06B6D4),
    'Legs': Color(0xFF8B5CF6),
    'Glutes': Color(0xFFEC4899),
    'Core': Color(0xFFF43F5E),
    'Forearms': Color(0xFF84CC16),
    'Cardio': Color(0xFF0EA5E9),
  };
}
