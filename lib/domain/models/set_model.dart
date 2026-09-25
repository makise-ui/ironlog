import '../../core/utils/unit_converter.dart';
import '../services/e1rm_calculator.dart';
import 'exercise_model.dart';

enum SetType {
  warmup,
  working,
  drop,
  failure;

  static SetType fromString(String val) {
    return SetType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => SetType.working,
    );
  }

  String get displayName {
    switch (this) {
      case SetType.warmup:
        return 'Warmup';
      case SetType.working:
        return 'Working';
      case SetType.drop:
        return 'Drop Set';
      case SetType.failure:
        return 'To Failure';
    }
  }

  String get label => displayName;

  String get shortCode {
    switch (this) {
      case SetType.warmup:
        return 'W';
      case SetType.working:
        return '';
      case SetType.drop:
        return 'D';
      case SetType.failure:
        return 'F';
    }
  }
}

class SetModel {
  final String id;
  final String workoutExerciseId;
  final String exerciseId;
  final String muscleGroupId;
  final DateTime date;
  final int setIndex;
  final double weight;
  final int reps;
  final SetType setType;
  final double? rpe;
  final DateTime completedAt;
  final bool archived;

  const SetModel({
    required this.id,
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.muscleGroupId,
    required this.date,
    required this.setIndex,
    required this.weight,
    required this.reps,
    required this.setType,
    this.rpe,
    required this.completedAt,
    this.archived = false,
  });

  bool get isWarmup => setType == SetType.warmup;
  bool get isWorking => setType == SetType.working;
  bool get isDrop => setType == SetType.drop;
  bool get isFailure => setType == SetType.failure;

  double get e1rm => E1rmCalculator.calculateEpley(weight, reps);
  double get volume => weight * reps;

  /// Formats seconds into human-readable duration like '45s' or '1:15'
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final mins = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '$mins:${remSecs.toString().padLeft(2, '0')}';
  }

  /// Formatted duration string for hold-based or timed sets
  String get formattedDuration => formatDuration(reps);

  /// Formats performance representation based on the exercise's tracking type
  String formatPerformance(ExerciseTrackingType trackingType, {WeightUnit unit = WeightUnit.kg}) {
    switch (trackingType) {
      case ExerciseTrackingType.duration:
        final durStr = formatDuration(reps);
        if (weight > 0) {
          return '$durStr (+${UnitConverter.formatWeight(weight, unit: unit)})';
        }
        return durStr;
      case ExerciseTrackingType.cardioTime:
        return '$reps min';
      case ExerciseTrackingType.bodyweightReps:
        if (weight > 0) {
          return '$reps reps (+${UnitConverter.formatWeight(weight, unit: unit)})';
        }
        return '$reps reps';
      case ExerciseTrackingType.weightAndReps:
        return '${UnitConverter.formatWeight(weight, unit: unit, includeUnit: false)} × $reps';
    }
  }

  SetModel copyWith({
    String? id,
    String? workoutExerciseId,
    String? exerciseId,
    String? muscleGroupId,
    DateTime? date,
    int? setIndex,
    double? weight,
    int? reps,
    SetType? setType,
    double? rpe,
    DateTime? completedAt,
    bool? archived,
  }) {
    return SetModel(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      exerciseId: exerciseId ?? this.exerciseId,
      muscleGroupId: muscleGroupId ?? this.muscleGroupId,
      date: date ?? this.date,
      setIndex: setIndex ?? this.setIndex,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      setType: setType ?? this.setType,
      rpe: rpe ?? this.rpe,
      completedAt: completedAt ?? this.completedAt,
      archived: archived ?? this.archived,
    );
  }
}
