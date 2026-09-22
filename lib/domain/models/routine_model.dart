import 'exercise_model.dart';

class RoutineItemModel {
  final String id;
  final String routineId;
  final ExerciseModel exercise;
  final int position;
  final int targetSets;
  final int repMin;
  final int repMax;
  final int restSeconds;

  const RoutineItemModel({
    required this.id,
    required this.routineId,
    required this.exercise,
    required this.position,
    this.targetSets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.restSeconds = 90,
  });
}

class RoutineModel {
  final String id;
  final String name;
  final String description;
  final List<RoutineItemModel> items;
  final bool archived;

  const RoutineModel({
    required this.id,
    required this.name,
    this.description = '',
    this.items = const [],
    this.archived = false,
  });
}
