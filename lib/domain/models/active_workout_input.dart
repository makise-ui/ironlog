import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/unit_converter.dart';
import '../services/weight_step_learner.dart';
import 'set_model.dart';

enum WorkoutInputField { weight, reps }

class ActiveWorkoutInput {
  final String workoutExerciseId;
  final String exerciseId;
  final String exerciseName;
  final EquipmentType equipment;
  final int setIndex; // 1-indexed (1, 2, 3...)
  final String? existingSetId; // null if this is an unlogged/planned ghost set
  final SetType setType;
  final WorkoutInputField activeField;
  final String weightInput;
  final String repsInput;
  final WeightUnit unit;
  final bool isCompleted;
  final bool replaceOnNextInput;

  const ActiveWorkoutInput({
    required this.workoutExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.equipment,
    required this.setIndex,
    this.existingSetId,
    required this.setType,
    required this.activeField,
    required this.weightInput,
    required this.repsInput,
    required this.unit,
    required this.isCompleted,
    this.replaceOnNextInput = true,
  });

  double get effectiveWeight => double.tryParse(weightInput) ?? 0.0;
  int get effectiveReps => int.tryParse(repsInput) ?? 0;

  /// Formatted breakdown of plates per side for barbell / plate loaded exercises
  String? get plateBreakdownSummary {
    if (equipment != EquipmentType.barbell) return null;
    final w = effectiveWeight;
    final isKg = unit == WeightUnit.kg;
    final barWeight = isKg ? 20.0 : 45.0;

    if (w <= barWeight) return null;

    final perSide = (w - barWeight) / 2.0;
    if (perSide <= 0) return null;

    final plates = isKg
        ? const [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
        : const [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

    final counts = <double, int>{};
    double rem = perSide;
    const eps = 0.001;

    for (final p in plates) {
      if (rem + eps >= p) {
        final c = (rem / p).floor();
        if (c > 0) {
          counts[p] = c;
          rem -= c * p;
        }
      }
    }

    if (counts.isEmpty) return null;

    final parts = counts.entries.map((e) {
      final pStr = e.key == e.key.roundToDouble()
          ? '${e.key.toInt()}'
          : '${e.key}';
      return e.value > 1 ? '${e.value}×$pStr' : pStr;
    }).toList();

    return parts.join(' + ');
  }

  ActiveWorkoutInput copyWith({
    String? workoutExerciseId,
    String? exerciseId,
    String? exerciseName,
    EquipmentType? equipment,
    int? setIndex,
    String? existingSetId,
    SetType? setType,
    WorkoutInputField? activeField,
    String? weightInput,
    String? repsInput,
    WeightUnit? unit,
    bool? isCompleted,
    bool? replaceOnNextInput,
  }) {
    return ActiveWorkoutInput(
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      equipment: equipment ?? this.equipment,
      setIndex: setIndex ?? this.setIndex,
      existingSetId: existingSetId ?? this.existingSetId,
      setType: setType ?? this.setType,
      activeField: activeField ?? this.activeField,
      weightInput: weightInput ?? this.weightInput,
      repsInput: repsInput ?? this.repsInput,
      unit: unit ?? this.unit,
      isCompleted: isCompleted ?? this.isCompleted,
      replaceOnNextInput: replaceOnNextInput ?? this.replaceOnNextInput,
    );
  }
}

class ActiveWorkoutInputNotifier extends StateNotifier<ActiveWorkoutInput?> {
  ActiveWorkoutInputNotifier() : super(null);

  void startEditing({
    required String workoutExerciseId,
    required String exerciseId,
    required String exerciseName,
    required EquipmentType equipment,
    required int setIndex,
    String? existingSetId,
    required SetType setType,
    required WorkoutInputField field,
    required double initialWeight,
    required int initialReps,
    required WeightUnit unit,
    required bool isCompleted,
  }) {
    state = ActiveWorkoutInput(
      workoutExerciseId: workoutExerciseId,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      equipment: equipment,
      setIndex: setIndex,
      existingSetId: existingSetId,
      setType: setType,
      activeField: field,
      weightInput: UnitConverter.formatWeight(initialWeight, unit: unit, includeUnit: false),
      repsInput: '$initialReps',
      unit: unit,
      isCompleted: isCompleted,
      replaceOnNextInput: true,
    );
  }

  void switchField(WorkoutInputField field) {
    if (state == null) return;
    state = state!.copyWith(
      activeField: field,
      replaceOnNextInput: true,
    );
  }

  void toggleField() {
    if (state == null) return;
    state = state!.copyWith(
      activeField: state!.activeField == WorkoutInputField.weight
          ? WorkoutInputField.reps
          : WorkoutInputField.weight,
      replaceOnNextInput: true,
    );
  }

  void onDigit(String char) {
    if (state == null) return;
    final currentField = state!.activeField;
    final replace = state!.replaceOnNextInput;

    if (currentField == WorkoutInputField.weight) {
      if (char == '.' && !replace && state!.weightInput.contains('.')) return;

      String next;
      if (replace) {
        next = (char == '.') ? '0.' : char;
      } else {
        if (state!.weightInput.length >= 6) return;
        next = state!.weightInput + char;
      }
      state = state!.copyWith(
        weightInput: next,
        replaceOnNextInput: false,
      );
    } else {
      if (char == '.') return; // No decimals in reps

      String next;
      if (replace) {
        next = char;
      } else {
        if (state!.repsInput.length >= 3) return;
        next = state!.repsInput + char;
      }
      state = state!.copyWith(
        repsInput: next,
        replaceOnNextInput: false,
      );
    }
  }

  void onBackspace() {
    if (state == null) return;
    final currentField = state!.activeField;
    final replace = state!.replaceOnNextInput;

    if (replace) {
      // First backspace clears the whole field so user starts with a clean slate
      if (currentField == WorkoutInputField.weight) {
        state = state!.copyWith(weightInput: '', replaceOnNextInput: false);
      } else {
        state = state!.copyWith(repsInput: '', replaceOnNextInput: false);
      }
      return;
    }

    if (currentField == WorkoutInputField.weight) {
      if (state!.weightInput.isNotEmpty) {
        state = state!.copyWith(
          weightInput: state!.weightInput.substring(0, state!.weightInput.length - 1),
        );
      }
    } else {
      if (state!.repsInput.isNotEmpty) {
        state = state!.copyWith(
          repsInput: state!.repsInput.substring(0, state!.repsInput.length - 1),
        );
      }
    }
  }

  void onClear() {
    if (state == null) return;
    if (state!.activeField == WorkoutInputField.weight) {
      state = state!.copyWith(weightInput: '', replaceOnNextInput: false);
    } else {
      state = state!.copyWith(repsInput: '', replaceOnNextInput: false);
    }
  }

  void stepWeight(double delta) {
    if (state == null) return;
    final current = state!.effectiveWeight;
    final next = (current + delta).clamp(0.0, 999.0);
    state = state!.copyWith(
      weightInput: UnitConverter.formatWeight(next, unit: state!.unit, includeUnit: false),
      replaceOnNextInput: false,
    );
  }

  void stepReps(int delta) {
    if (state == null) return;
    final current = state!.effectiveReps;
    final next = (current + delta).clamp(1, 999);
    state = state!.copyWith(
      repsInput: '$next',
      replaceOnNextInput: false,
    );
  }

  void cycleSetType() {
    if (state == null) return;
    final current = state!.setType;
    final next = switch (current) {
      SetType.working => SetType.warmup,
      SetType.warmup => SetType.drop,
      SetType.drop => SetType.failure,
      SetType.failure => SetType.working,
    };
    state = state!.copyWith(setType: next);
  }

  void setSetType(SetType type) {
    if (state == null) return;
    state = state!.copyWith(setType: type);
  }

  void close() {
    state = null;
  }
}

final activeWorkoutInputProvider =
    StateNotifierProvider<ActiveWorkoutInputNotifier, ActiveWorkoutInput?>((ref) {
  return ActiveWorkoutInputNotifier();
});
