import '../services/weight_step_learner.dart';

enum LoadMode {
  total,
  perHand,
  bodyweight,
  assisted;

  static LoadMode fromString(String val) {
    switch (val.toLowerCase()) {
      case 'per_hand':
      case 'perhand':
        return LoadMode.perHand;
      case 'bodyweight':
        return LoadMode.bodyweight;
      case 'assisted':
        return LoadMode.assisted;
      default:
        return LoadMode.total;
    }
  }

  String get dbValue {
    switch (this) {
      case LoadMode.perHand:
        return 'per_hand';
      case LoadMode.bodyweight:
        return 'bodyweight';
      case LoadMode.assisted:
        return 'assisted';
      case LoadMode.total:
        return 'total';
    }
  }
}

class ExerciseModel {
  final String id;
  final String name;
  final String muscleGroupId;
  final List<String> secondaryGroups;
  final EquipmentType equipment;
  final LoadMode loadMode;
  final bool isUnilateral;
  final double weightStep;
  final int repMin;
  final int repMax;
  final int restSeconds;
  final bool isCustom;
  final bool archived;

  const ExerciseModel({
    required this.id,
    required this.name,
    required this.muscleGroupId,
    this.secondaryGroups = const [],
    this.equipment = EquipmentType.barbell,
    this.loadMode = LoadMode.total,
    this.isUnilateral = false,
    this.weightStep = 2.5,
    this.repMin = 8,
    this.repMax = 12,
    this.restSeconds = 90,
    this.isCustom = false,
    this.archived = false,
  });

  ExerciseModel copyWith({
    String? id,
    String? name,
    String? muscleGroupId,
    List<String>? secondaryGroups,
    EquipmentType? equipment,
    LoadMode? loadMode,
    bool? isUnilateral,
    double? weightStep,
    int? repMin,
    int? repMax,
    int? restSeconds,
    bool? isCustom,
    bool? archived,
  }) {
    return ExerciseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroupId: muscleGroupId ?? this.muscleGroupId,
      secondaryGroups: secondaryGroups ?? this.secondaryGroups,
      equipment: equipment ?? this.equipment,
      loadMode: loadMode ?? this.loadMode,
      isUnilateral: isUnilateral ?? this.isUnilateral,
      weightStep: weightStep ?? this.weightStep,
      repMin: repMin ?? this.repMin,
      repMax: repMax ?? this.repMax,
      restSeconds: restSeconds ?? this.restSeconds,
      isCustom: isCustom ?? this.isCustom,
      archived: archived ?? this.archived,
    );
  }
}

class MuscleGroupModel {
  final String id;
  final String name;
  final String color;
  final String icon;
  final int sort;

  const MuscleGroupModel({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.sort = 0,
  });
}
