import '../models/set_model.dart';

class SetEffortRating {
  final double? rpe;
  final int? rir;
  final bool isStimulating; // Hard set (RIR <= 3 or RPE >= 7)
  final int effectiveReps;
  final bool isJunkVolume; // Working set with RIR >= 4

  const SetEffortRating({
    this.rpe,
    this.rir,
    required this.isStimulating,
    required this.effectiveReps,
    required this.isJunkVolume,
  });
}

class WorkoutEffortSummary {
  final int totalSets;
  final int stimulatingSets;
  final int junkVolumeSets;
  final int totalEffectiveReps;
  final double averageRpe;
  final double averageRir;
  final double stimulatingRatio; // e.g. 0.85 (85%)
  final String fatigueWarning;

  const WorkoutEffortSummary({
    required this.totalSets,
    required this.stimulatingSets,
    required this.junkVolumeSets,
    required this.totalEffectiveReps,
    required this.averageRpe,
    required this.averageRir,
    required this.stimulatingRatio,
    required this.fatigueWarning,
  });
}

class EffortAnalyticsService {
  /// Converts RPE (Rate of Perceived Exertion 6-10) to RIR (Reps in Reserve 0-4)
  static int rpeToRir(double rpe) {
    final clamped = rpe.clamp(6.0, 10.0);
    return (10.0 - clamped).round();
  }

  /// Converts RIR to equivalent RPE
  static double rirToRpe(int rir) {
    final clamped = rir.clamp(0, 4);
    return 10.0 - clamped;
  }

  /// Analyzes a single set for stimulating reps vs junk volume
  static SetEffortRating evaluateSet(SetModel set) {
    if (set.setType == SetType.warmup) {
      return const SetEffortRating(
        rpe: null,
        rir: null,
        isStimulating: false,
        effectiveReps: 0,
        isJunkVolume: false,
      );
    }

    // Default to RPE 8 (RIR 2) if athlete did not explicitly log RPE
    final double rpe = set.rpe ?? 8.0;
    final int rir = rpeToRir(rpe);

    // Sports science standard: Sets within 3 reps of failure (RIR <= 3 / RPE >= 7) drive adaptation
    final bool isStimulating = rir <= 3;
    final bool isJunk = !isStimulating && set.setType == SetType.working;

    // Last 5 reps of a set approaching failure have full motor unit recruitment
    // Effective reps = max(0, min(reps, 5 - rir))
    final int effectiveReps = isStimulating ? (set.reps >= (5 - rir) ? (5 - rir) : set.reps) : 0;

    return SetEffortRating(
      rpe: rpe,
      rir: rir,
      isStimulating: isStimulating,
      effectiveReps: effectiveReps,
      isJunkVolume: isJunk,
    );
  }

  /// Evaluates an entire collection of sets (workout session or weekly training block)
  static WorkoutEffortSummary evaluateCollection(List<SetModel> sets) {
    final workingSets = sets.where((s) => s.setType != SetType.warmup).toList();
    if (workingSets.isEmpty) {
      return const WorkoutEffortSummary(
        totalSets: 0,
        stimulatingSets: 0,
        junkVolumeSets: 0,
        totalEffectiveReps: 0,
        averageRpe: 0.0,
        averageRir: 0.0,
        stimulatingRatio: 0.0,
        fatigueWarning: 'No working sets logged',
      );
    }

    int stimulatingCount = 0;
    int junkCount = 0;
    int totalEffectiveReps = 0;
    double rpeSum = 0.0;
    int maxFailureSets = 0;

    for (final s in workingSets) {
      final rating = evaluateSet(s);
      if (rating.isStimulating) stimulatingCount++;
      if (rating.isJunkVolume) junkCount++;
      totalEffectiveReps += rating.effectiveReps;
      final rpe = rating.rpe ?? 8.0;
      rpeSum += rpe;
      if (rpe >= 9.5) maxFailureSets++;
    }

    final avgRpe = double.parse((rpeSum / workingSets.length).toStringAsFixed(1));
    final avgRir = double.parse((10.0 - avgRpe).toStringAsFixed(1));
    final ratio = double.parse((stimulatingCount / workingSets.length).toStringAsFixed(2));

    String warning;
    if (maxFailureSets >= 6) {
      warning = 'High Systemic Fatigue: $maxFailureSets sets taken to absolute failure (RPE 9.5+). Consider adding rest.';
    } else if (ratio < 0.60 && workingSets.length >= 8) {
      warning = 'Junk Volume Alert: $junkCount sets were stopped >3 reps from failure. Increase load or intensity.';
    } else {
      warning = 'Optimal Stimulus: $stimulatingCount/${workingSets.length} sets in hypertrophy zone.';
    }

    return WorkoutEffortSummary(
      totalSets: workingSets.length,
      stimulatingSets: stimulatingCount,
      junkVolumeSets: junkCount,
      totalEffectiveReps: totalEffectiveReps,
      averageRpe: avgRpe,
      averageRir: avgRir,
      stimulatingRatio: ratio,
      fatigueWarning: warning,
    );
  }
}
