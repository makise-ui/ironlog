import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  static void step() {
    HapticFeedback.selectionClick();
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void tap() {
    HapticFeedback.lightImpact();
  }

  static void save() {
    HapticFeedback.mediumImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  static void pr() {
    HapticFeedback.heavyImpact();
  }

  static void prCelebration() {
    HapticFeedback.heavyImpact();
  }

  static void warning() {
    HapticFeedback.vibrate();
  }

  static Future<void> timerWarning() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 140));
    HapticFeedback.mediumImpact();
  }

  static Future<void> timerFinished() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 160));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 160));
    HapticFeedback.heavyImpact();
  }
}

