import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  static void step() {
    HapticFeedback.selectionClick();
  }

  static void tap() {
    HapticFeedback.lightImpact();
  }

  static void save() {
    HapticFeedback.mediumImpact();
  }

  static void prCelebration() {
    HapticFeedback.heavyImpact();
  }

  static void warning() {
    HapticFeedback.vibrate();
  }
}
