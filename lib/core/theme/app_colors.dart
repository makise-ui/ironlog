import 'package:flutter/material.dart';

/// Supported premium accent themes
enum AccentPreset {
  cobalt,
  emerald,
  crimson,
  amethyst,
  amber,
  titanium,
}

class AccentThemeData {
  final AccentPreset preset;
  final String name;
  final Color darkColor;
  final Color lightColor;
  final Color onDark;
  final Color onLight;

  const AccentThemeData({
    required this.preset,
    required this.name,
    required this.darkColor,
    required this.lightColor,
    this.onDark = Colors.white,
    this.onLight = Colors.white,
  });
}

class AppColors {
  AppColors._();

  static const Map<AccentPreset, AccentThemeData> accentPresets = {
    AccentPreset.cobalt: AccentThemeData(
      preset: AccentPreset.cobalt,
      name: 'Cobalt Sapphire',
      darkColor: Color(0xFF3B82F6), // Vibrant Electric Cobalt
      lightColor: Color(0xFF2563EB), // Rich Royal Cobalt
    ),
    AccentPreset.emerald: AccentThemeData(
      preset: AccentPreset.emerald,
      name: 'Athletic Emerald',
      darkColor: Color(0xFF10B981), // Crisp Emerald
      lightColor: Color(0xFF059669), // Deep Jade
    ),
    AccentPreset.crimson: AccentThemeData(
      preset: AccentPreset.crimson,
      name: 'Crimson Titan',
      darkColor: Color(0xFFF43F5E), // Athletic Crimson
      lightColor: Color(0xFFE11D48), // Bold Athletic Red
    ),
    AccentPreset.amethyst: AccentThemeData(
      preset: AccentPreset.amethyst,
      name: 'Amethyst Pro',
      darkColor: Color(0xFFA855F7), // Luxury Violet
      lightColor: Color(0xFF7C3AED), // Deep Royal Purple
    ),
    AccentPreset.amber: AccentThemeData(
      preset: AccentPreset.amber,
      name: 'Sunset Amber',
      darkColor: Color(0xFFF59E0B), // Warm Amber
      lightColor: Color(0xFFD97706), // Athletic Amber
    ),
    AccentPreset.titanium: AccentThemeData(
      preset: AccentPreset.titanium,
      name: 'Titanium Slate',
      darkColor: Color(0xFFE2E8F0), // Clean Silver
      lightColor: Color(0xFF1E293B), // Deep Charcoal
      onDark: Color(0xFF0F172A),
      onLight: Colors.white,
    ),
  };

  // Currently selected preset (defaults to flagship Cobalt Sapphire)
  static AccentPreset currentPreset = AccentPreset.cobalt;

  static Color get activeAccentDark =>
      accentPresets[currentPreset]?.darkColor ?? const Color(0xFF3B82F6);
  static Color get activeAccentLight =>
      accentPresets[currentPreset]?.lightColor ?? const Color(0xFF2563EB);

  // Backward compatibility aliases
  static Color get activeAccent => activeAccentDark;
  static Color get accent => activeAccentDark;
  static Color get accentPrimary => activeAccentDark;

  static Color currentOnAccent(bool isDark) {
    final theme = accentPresets[currentPreset] ?? accentPresets[AccentPreset.cobalt]!;
    return isDark ? theme.onDark : theme.onLight;
  }

  // ── Backgrounds (Dark Mode — Modern Obsidian Surface Ladder) ──
  static const Color background = Color(0xFF090A0E); // Deep Obsidian Canvas
  static const Color backgroundCard = Color(0xFF12141A); // Surface L1: Cards
  static const Color surfaceElevated = Color(0xFF181B24); // Surface L2: Elevated / Inner panels
  static const Color surfaceElevatedHigh = Color(0xFF20232E); // Surface L3: Modals / Dialogs

  // ── Backgrounds (Light Mode — Crisp studio porcelain) ──
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundCardLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF1F5F9);

  // ── Border tokens (Dark Mode — Pure Hairlines) ──
  static const Color glassFill = Color(0x0CFFFFFF);
  static const Color glassFillActive = Color(0x18FFFFFF);
  static const Color glassTileFill = Color(0x08FFFFFF);
  static const Color glassBorderLight = Color(0x14FFFFFF); // 8% white hairline
  static const Color glassBorderDim = Color(0x0AFFFFFF); // 4% white subtle hairline
  static const Color glassBorderHighlight = Color(0x24FFFFFF); // 14% white active

  // ── Border tokens (Light Mode) ──
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEEF1F6);
  static const Color lightFill = Colors.white;
  static const Color lightFillSecondary = Color(0xFFF1F5F9);

  // ── Secondary Accents & Accoutrements ──
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentCyanLight = Color(0xFF38BDF8);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color prGold = Color(0xFFF59E0B);

  // High performance gradients
  static LinearGradient get accentGradient => LinearGradient(
        colors: [activeAccentDark, activeAccentDark.withValues(alpha: 0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF151822), Color(0xFF101218)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Status Colors ──
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Text Colors (Dark) ──
  static const Color textPrimary = Color(0xFFF4F5F7);
  static const Color textSecondary = Color(0xFF9AA0AA);
  static const Color textTertiary = Color(0xFF636A78);
  static const Color textDisabled = Color(0xFF424754);

  // ── Text Colors (Light) ──
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ── Set type colors (Athletic standard color-coded) ──
  static const Color warmupSet = Color(0xFFF59E0B);
  static const Color workingSet = Color(0xFF10B981);
  static const Color dropSet = Color(0xFF06B6D4);
  static const Color failureSet = Color(0xFFEF4444);

  // ── Muscle group colors ──
  static const Map<String, Color> muscleGroupColors = {
    'Chest': Color(0xFFEF4444),
    'Back': Color(0xFF3B82F6),
    'Shoulders': Color(0xFFF59E0B),
    'Biceps': Color(0xFF10B981),
    'Triceps': Color(0xFF06B6D4),
    'Legs': Color(0xFF8B5CF6),
    'Glutes': Color(0xFFEC4899),
    'Core': Color(0xFFF97316),
    'Forearms': Color(0xFF84CC16),
    'Cardio': Color(0xFF0EA5E9),
  };
}

/// Theme helper extension
extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Adaptive accent: Clean high-contrast colors for both dark and light modes
  Color get accent => isDark ? AppColors.activeAccentDark : AppColors.activeAccentLight;
  Color get onAccent => AppColors.currentOnAccent(isDark);
  Color get accentMuted => accent.withValues(alpha: 0.70);

  Color get textPrimary => isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
  Color get textSecondary => isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
  Color get textTertiary => isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;
  Color get textDisabled => isDark ? AppColors.textDisabled : const Color(0xFFCBD5E1);

  Color get scaffoldBg => isDark ? AppColors.background : AppColors.backgroundLight;
  Color get cardBg => isDark ? AppColors.backgroundCard : AppColors.backgroundCardLight;
  Color get cardBorder => isDark ? AppColors.glassBorderLight : AppColors.lightBorder;
  Color get cardElevated => isDark ? AppColors.surfaceElevated : AppColors.surfaceElevatedLight;

  Color get chipBg => isDark ? AppColors.surfaceElevated : const Color(0xFFF1F5F9);
  Color get chipSelectedBg => accent;
  Color get chipBorder => isDark ? AppColors.glassBorderLight : AppColors.lightBorder;

  Color get sheetBg => isDark ? AppColors.backgroundCard : Colors.white;
  Color get sheetBorder => isDark ? AppColors.glassBorderLight : AppColors.lightBorder;
  Color get handleBar => isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1);

  Color get keypadBg => isDark ? AppColors.surfaceElevated : const Color(0xFFF1F5F9);
  Color get keypadBorder => isDark ? AppColors.glassBorderLight : AppColors.lightBorder;
  Color get inputBg => isDark ? AppColors.surfaceElevated : const Color(0xFFF8FAFC);
  Color get inputBorder => isDark ? AppColors.glassBorderLight : AppColors.lightBorder;
}
