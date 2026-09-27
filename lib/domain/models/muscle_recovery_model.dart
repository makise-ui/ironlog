import 'package:flutter/material.dart';

enum MuscleRecoveryState {
  fatigued, // 0 - 45% (Red)
  recovering, // 46 - 79% (Amber)
  ready, // 80 - 100% (Green)
}

class MuscleRecoveryData {
  final String id;
  final String name;
  final double recoveryPercent; // 0.0 to 1.0
  final double? hoursSinceLastTrained;
  final DateTime? lastTrainedDate;
  final int weeklySetsCount;
  final String status;
  final String tip;

  const MuscleRecoveryData({
    required this.id,
    required this.name,
    required this.recoveryPercent,
    this.hoursSinceLastTrained,
    this.lastTrainedDate,
    required this.weeklySetsCount,
    required this.status,
    required this.tip,
  });

  MuscleRecoveryState get state {
    if (recoveryPercent < 0.45) return MuscleRecoveryState.fatigued;
    if (recoveryPercent < 0.80) return MuscleRecoveryState.recovering;
    return MuscleRecoveryState.ready;
  }

  Color get color {
    switch (state) {
      case MuscleRecoveryState.fatigued:
        return const Color(0xFFEF4444); // Vibrant Athletic Red
      case MuscleRecoveryState.recovering:
        return const Color(0xFFF59E0B); // Warm Amber
      case MuscleRecoveryState.ready:
        return const Color(0xFF10B981); // Fresh Emerald Green
    }
  }

  String get recoveryDescription {
    final pct = (recoveryPercent * 100).round();
    if (hoursSinceLastTrained == null) {
      return '100% • Fully recovered & primed';
    }
    final hrs = hoursSinceLastTrained!.round();
    if (hrs < 24) {
      return '$pct% • Hit $hrs h ago ($weeklySetsCount sets recently)';
    } else {
      final days = (hrs / 24).floor();
      return '$pct% • Hit ${days}d ago ($weeklySetsCount sets recently)';
    }
  }
}
