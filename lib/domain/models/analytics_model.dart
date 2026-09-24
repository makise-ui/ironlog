class DailyVolumeStat {
  final DateTime date;
  final double volume;
  final int setsCount;

  const DailyVolumeStat({
    required this.date,
    required this.volume,
    required this.setsCount,
  });
}

class AnalyticsOverviewData {
  final double totalVolume;
  final int totalWorkouts;
  final int totalSets;
  final int totalReps;
  final int currentStreakDays;

  const AnalyticsOverviewData({
    required this.totalVolume,
    required this.totalWorkouts,
    required this.totalSets,
    required this.totalReps,
    required this.currentStreakDays,
  });
}

class PrItemData {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String muscleGroupId;
  final String kind;
  final double value;
  final DateTime achievedAt;

  const PrItemData({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroupId,
    required this.kind,
    required this.value,
    required this.achievedAt,
  });

  String get formattedKind {
    switch (kind) {
      case 'heaviest':
        return 'Max Weight';
      case 'e1rm':
        return 'Est. 1RM';
      case 'session_volume':
        return 'Session Volume';
      case 'reps_at_weight':
        return 'Reps PR';
      default:
        return 'Personal Record';
    }
  }
}

class WeeklyFrequencyStat {
  final DateTime weekStart;
  final int workoutCount;
  const WeeklyFrequencyStat({required this.weekStart, required this.workoutCount});
}

class ExerciseVolumeStat {
  final String exerciseName;
  final double totalVolume;
  final int setsCount;
  const ExerciseVolumeStat({required this.exerciseName, required this.totalVolume, required this.setsCount});
}

class BestSetStat {
  final String exerciseName;
  final double weight;
  final int reps;
  final double e1rm;
  final DateTime date;
  const BestSetStat({required this.exerciseName, required this.weight, required this.reps, required this.e1rm, required this.date});
}

class SetData {
  final double weight;
  final int reps;
  final double e1rm;
  final DateTime date;
  const SetData({required this.weight, required this.reps, required this.e1rm, required this.date});
}

class RepRangeStat {
  final String label;
  final String rangeDescription;
  final int count;
  final double percentage;
  const RepRangeStat({
    required this.label,
    required this.rangeDescription,
    required this.count,
    required this.percentage,
  });
}
