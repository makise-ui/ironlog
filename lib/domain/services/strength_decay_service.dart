import 'dart:math' as math;

class RetainedStrengthAnalysis {
  final double peak1Rm;
  final DateTime lastTrainedDate;
  final int daysElapsed;
  final double decayFactor; // 1.0 (100%) down to 0.5 (50% floor)
  final double currentExpected1Rm;
  final bool isDetrained;
  final String statusLabel;
  final double suggestedReentryWeight;

  const RetainedStrengthAnalysis({
    required this.peak1Rm,
    required this.lastTrainedDate,
    required this.daysElapsed,
    required this.decayFactor,
    required this.currentExpected1Rm,
    required this.isDetrained,
    required this.statusLabel,
    required this.suggestedReentryWeight,
  });
}

class StrengthDecayService {
  // Scientific parameters matching exercise physiology:
  // - 14-day neuromuscular plateau: No measurable strength loss for first 2 weeks.
  // - 28-day half-life decay: Retained strength decays gradually over the subsequent 4 weeks.
  // - 50% strength floor: An experienced lifter never resets below 50% of peak due to muscle memory.
  static const int plateauDays = 14;
  static const double halfLifeDays = 28.0;
  static const double strengthFloor = 0.50;

  /// Calculates the retained neuromuscular strength capacity based on time elapsed since last session
  static RetainedStrengthAnalysis evaluate({
    required double peak1Rm,
    required DateTime lastTrainedDate,
    DateTime? now,
    double weightStep = 2.5,
  }) {
    final currentDate = now ?? DateTime.now();
    final difference = currentDate.difference(lastTrainedDate);
    final daysElapsed = math.max(0, difference.inDays);

    double decay = 1.0;
    if (daysElapsed > plateauDays) {
      final daysBeyondPlateau = (daysElapsed - plateauDays).toDouble();
      // Decay formula: 2^(-t / halfLife)
      final exponentialDecay = math.pow(2.0, -daysBeyondPlateau / halfLifeDays).toDouble();
      decay = math.max(strengthFloor, exponentialDecay);
    }

    final currentExpected = double.parse((peak1Rm * decay).toStringAsFixed(1));
    final isDetrained = daysElapsed > plateauDays;

    String status;
    if (daysElapsed <= 7) {
      status = 'Fresh & Primed (100%)';
    } else if (daysElapsed <= plateauDays) {
      status = 'Peak Capacity Retained (100%)';
    } else if (decay >= 0.90) {
      final pct = ((1.0 - decay) * 100).round();
      status = 'Mild Detraining (-$pct%)';
    } else if (decay >= 0.75) {
      final pct = ((1.0 - decay) * 100).round();
      status = 'Moderate Detraining (-$pct%)';
    } else {
      final pct = ((1.0 - decay) * 100).round();
      status = 'Detrained (-$pct%) — Re-entry Protocol';
    }

    // Propose a 8-rep re-entry target (approx 75% of current capacity)
    final rawReentry = currentExpected * 0.75;
    final quotient = (rawReentry / weightStep).round();
    final reentryWeight = double.parse((quotient * weightStep).toStringAsFixed(1));

    return RetainedStrengthAnalysis(
      peak1Rm: peak1Rm,
      lastTrainedDate: lastTrainedDate,
      daysElapsed: daysElapsed,
      decayFactor: double.parse(decay.toStringAsFixed(3)),
      currentExpected1Rm: currentExpected,
      isDetrained: isDetrained,
      statusLabel: status,
      suggestedReentryWeight: reentryWeight,
    );
  }
}
