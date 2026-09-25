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

enum ExerciseTrackingType {
  weightAndReps,
  bodyweightReps,
  duration,     // Isometric holds (Plank, Wall Sit, Dead Hang, L-Sit) - measured in seconds
  cardioTime,   // Sports & Cardio (Football, Basketball, Running, Boxing) - measured in minutes
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

  /// Automatically categorizes the exercise into one of the 4 adaptive tracking modes
  ExerciseTrackingType get trackingType {
    final nameLower = name.toLowerCase();
    final muscleLower = muscleGroupId.toLowerCase();

    // 1. Isometric Holds (measured in seconds duration)
    // Checked first to ensure core/bodyweight holds like Plank get timed hold mode
    const durationKeywords = [
      'plank',
      'dead hang',
      'wall sit',
      'hollow body',
      'hollow hold',
      'l-sit',
      'handstand hold',
      'arch hold',
      'isometric hold',
      'bridge hold',
      'side plank',
      'static hold',
    ];
    for (final kw in durationKeywords) {
      if (nameLower.contains(kw)) {
        return ExerciseTrackingType.duration;
      }
    }

    // 2. Cardio & Sports/Games (measured in session duration in minutes)
    const cardioKeywords = [
      'football',
      'soccer',
      'basketball',
      'boxing',
      'sparring',
      'running',
      'jogging',
      'sprint',
      'treadmill',
      'cycling',
      'bicycle',
      'swimming',
      'rowing machine',
      'elliptical',
      'jump rope',
      'skipping rope',
      'badminton',
      'tennis',
      'volleyball',
      'cricket',
      'rugby',
      'baseball',
      'mma',
      'cardio',
    ];
    if (muscleLower == 'cardio') {
      return ExerciseTrackingType.cardioTime;
    }
    for (final kw in cardioKeywords) {
      if (nameLower.contains(kw)) {
        return ExerciseTrackingType.cardioTime;
      }
    }

    // 3. Bodyweight Exercises (measured in reps, 0 default weight with optional added weight)
    const bodyweightKeywords = [
      'push-up',
      'push up',
      'pushup',
      'pull-up',
      'pull up',
      'pullup',
      'chin-up',
      'chin up',
      'chinup',
      'dip',
      'crunch',
      'sit-up',
      'sit up',
      'situp',
      'leg raise',
      'knee raise',
      'burpee',
      'mountain climber',
      'bodyweight squat',
      'air squat',
      'jumping jack',
      'calisthenics',
    ];
    if (equipment == EquipmentType.bodyweight || loadMode == LoadMode.bodyweight) {
      return ExerciseTrackingType.bodyweightReps;
    }
    for (final kw in bodyweightKeywords) {
      if (nameLower.contains(kw)) {
        return ExerciseTrackingType.bodyweightReps;
      }
    }

    // 4. Default: Standard Weight & Reps (Barbell, Dumbbell, Cable, Machine)
    return ExerciseTrackingType.weightAndReps;
  }

  bool get isHoldDuration => trackingType == ExerciseTrackingType.duration;
  bool get isCardioTime => trackingType == ExerciseTrackingType.cardioTime;
  bool get isBodyweight => trackingType == ExerciseTrackingType.bodyweightReps;
  bool get isStandardWeightAndReps => trackingType == ExerciseTrackingType.weightAndReps;

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
