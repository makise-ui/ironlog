class SeedMuscleGroup {
  final String id;
  final String name;
  final String color;
  final String icon;
  final int sort;

  const SeedMuscleGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.sort,
  });
}

class SeedExercise {
  final String id;
  final String name;
  final String muscleGroupId;
  final String secondaryGroups;
  final String equipment;
  final String loadMode;
  final bool isUnilateral;
  final double weightStep;
  final int repMin;
  final int repMax;
  final int restSeconds;

  const SeedExercise({
    required this.id,
    required this.name,
    required this.muscleGroupId,
    this.secondaryGroups = '',
    required this.equipment,
    this.loadMode = 'total',
    this.isUnilateral = false,
    this.weightStep = 2.5,
    this.repMin = 8,
    this.repMax = 12,
    this.restSeconds = 90,
  });
}

class SeedData {
  SeedData._();

  static const List<SeedMuscleGroup> muscleGroups = [
    SeedMuscleGroup(id: 'chest', name: 'Chest', color: '#FF5376', icon: 'fitness_center', sort: 1),
    SeedMuscleGroup(id: 'back', name: 'Back', color: '#3B82F6', icon: 'accessibility_new', sort: 2),
    SeedMuscleGroup(id: 'shoulders', name: 'Shoulders', color: '#F59E0B', icon: 'military_tech', sort: 3),
    SeedMuscleGroup(id: 'biceps', name: 'Biceps', color: '#10B981', icon: 'sports_handball', sort: 4),
    SeedMuscleGroup(id: 'triceps', name: 'Triceps', color: '#06B6D4', icon: 'hardware', sort: 5),
    SeedMuscleGroup(id: 'legs', name: 'Legs', color: '#8B5CF6', icon: 'directions_run', sort: 6),
    SeedMuscleGroup(id: 'glutes', name: 'Glutes', color: '#EC4899', icon: 'airline_seat_legroom_extra', sort: 7),
    SeedMuscleGroup(id: 'core', name: 'Core', color: '#F43F5E', icon: 'shield', sort: 8),
    SeedMuscleGroup(id: 'forearms', name: 'Forearms', color: '#84CC16', icon: 'front_hand', sort: 9),
    SeedMuscleGroup(id: 'cardio', name: 'Cardio', color: '#0EA5E9', icon: 'favorite', sort: 10),
  ];

  static const List<SeedExercise> exercises = [
    // --- CHEST (20) ---
    SeedExercise(id: 'ex_c_01', name: 'Barbell Bench Press', muscleGroupId: 'chest', secondaryGroups: 'triceps,shoulders', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 10, restSeconds: 120),
    SeedExercise(id: 'ex_c_02', name: 'Incline Barbell Bench Press', muscleGroupId: 'chest', secondaryGroups: 'shoulders,triceps', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_03', name: 'Decline Barbell Bench Press', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_04', name: 'Flat Dumbbell Press', muscleGroupId: 'chest', secondaryGroups: 'triceps,shoulders', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_05', name: 'Incline Dumbbell Press', muscleGroupId: 'chest', secondaryGroups: 'shoulders,triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_06', name: 'Decline Dumbbell Press', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_07', name: 'Flat Dumbbell Fly', muscleGroupId: 'chest', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_c_08', name: 'Incline Dumbbell Fly', muscleGroupId: 'chest', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_c_09', name: 'Cable Crossover', muscleGroupId: 'chest', equipment: 'cable', loadMode: 'per_hand', weightStep: 2.5, repMin: 12, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_c_10', name: 'Low-to-High Cable Fly', muscleGroupId: 'chest', equipment: 'cable', loadMode: 'per_hand', weightStep: 2.5, repMin: 12, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_c_11', name: 'High-to-Low Cable Fly', muscleGroupId: 'chest', equipment: 'cable', loadMode: 'per_hand', weightStep: 2.5, repMin: 12, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_c_12', name: 'Pec Deck Machine', muscleGroupId: 'chest', equipment: 'machine', weightStep: 5.0, repMin: 10, repMax: 15, restSeconds: 75),
    SeedExercise(id: 'ex_c_13', name: 'Chest Press Machine', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_14', name: 'Incline Chest Press Machine', muscleGroupId: 'chest', secondaryGroups: 'shoulders,triceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_15', name: 'Push-Ups', muscleGroupId: 'chest', secondaryGroups: 'triceps,core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 12, repMax: 25, restSeconds: 60),
    SeedExercise(id: 'ex_c_16', name: 'Diamond Push-Ups', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 10, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_c_17', name: 'Weighted Push-Ups', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'other', weightStep: 2.5, repMin: 8, repMax: 15, restSeconds: 90),
    SeedExercise(id: 'ex_c_18', name: 'Chest Dips', muscleGroupId: 'chest', secondaryGroups: 'triceps,shoulders', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 2.5, repMin: 6, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_c_19', name: 'Assisted Chest Dips', muscleGroupId: 'chest', secondaryGroups: 'triceps', equipment: 'assisted', loadMode: 'assisted', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_c_20', name: 'Svend Press', muscleGroupId: 'chest', equipment: 'dumbbell', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 60),

    // --- BACK (22) ---
    SeedExercise(id: 'ex_b_01', name: 'Conventional Deadlift', muscleGroupId: 'back', secondaryGroups: 'legs,glutes,core', equipment: 'barbell', weightStep: 5.0, repMin: 4, repMax: 8, restSeconds: 180),
    SeedExercise(id: 'ex_b_02', name: 'Barbell Bent-Over Row', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 10, restSeconds: 90),
    SeedExercise(id: 'ex_b_03', name: 'Pendlay Row', muscleGroupId: 'back', secondaryGroups: 'biceps,core', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 8, restSeconds: 90),
    SeedExercise(id: 'ex_b_04', name: 'Lat Pulldown', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'cable', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_05', name: 'Wide-Grip Lat Pulldown', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'cable', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_06', name: 'Close-Grip Lat Pulldown', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'cable', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_07', name: 'Seated Cable Row', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'cable', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_08', name: 'Single-Arm Dumbbell Row', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_b_09', name: 'T-Bar Row', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'barbell', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_b_10', name: 'Chest-Supported Row Machine', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_11', name: 'Pull-Ups', muscleGroupId: 'back', secondaryGroups: 'biceps,core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 5, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_b_12', name: 'Chin-Ups', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 6, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_b_13', name: 'Neutral-Grip Pull-Ups', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 6, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_b_14', name: 'Assisted Pull-Ups', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'assisted', loadMode: 'assisted', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_b_15', name: 'Straight-Arm Cable Pulldown', muscleGroupId: 'back', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_b_16', name: 'Dumbbell Pullover', muscleGroupId: 'back', secondaryGroups: 'chest', equipment: 'dumbbell', weightStep: 2.5, repMin: 10, repMax: 14, restSeconds: 75),
    SeedExercise(id: 'ex_b_17', name: 'Rack Pulls', muscleGroupId: 'back', secondaryGroups: 'glutes,forearms', equipment: 'barbell', weightStep: 5.0, repMin: 5, repMax: 8, restSeconds: 120),
    SeedExercise(id: 'ex_b_18', name: 'Back Extension (Hyperextension)', muscleGroupId: 'back', secondaryGroups: 'glutes', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_b_19', name: 'Face Pull', muscleGroupId: 'back', secondaryGroups: 'shoulders', equipment: 'cable', weightStep: 2.5, repMin: 12, repMax: 16, restSeconds: 60),
    SeedExercise(id: 'ex_b_20', name: 'Barbell Shrugs', muscleGroupId: 'back', secondaryGroups: 'forearms', equipment: 'barbell', weightStep: 5.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_b_21', name: 'Dumbbell Shrugs', muscleGroupId: 'back', secondaryGroups: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_b_22', name: 'Incline Dumbbell Row', muscleGroupId: 'back', secondaryGroups: 'biceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),

    // --- SHOULDERS (18) ---
    SeedExercise(id: 'ex_s_01', name: 'Overhead Barbell Press (OHP)', muscleGroupId: 'shoulders', secondaryGroups: 'triceps,core', equipment: 'barbell', weightStep: 2.5, repMin: 5, repMax: 8, restSeconds: 120),
    SeedExercise(id: 'ex_s_02', name: 'Seated Barbell Overhead Press', muscleGroupId: 'shoulders', secondaryGroups: 'triceps', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 10, restSeconds: 90),
    SeedExercise(id: 'ex_s_03', name: 'Standing Dumbbell Shoulder Press', muscleGroupId: 'shoulders', secondaryGroups: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_s_04', name: 'Seated Dumbbell Shoulder Press', muscleGroupId: 'shoulders', secondaryGroups: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_s_05', name: 'Arnold Press', muscleGroupId: 'shoulders', secondaryGroups: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_s_06', name: 'Dumbbell Lateral Raise', muscleGroupId: 'shoulders', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 1.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_s_07', name: 'Cable Lateral Raise', muscleGroupId: 'shoulders', equipment: 'cable', isUnilateral: true, weightStep: 1.25, repMin: 12, repMax: 16, restSeconds: 45),
    SeedExercise(id: 'ex_s_08', name: 'Machine Lateral Raise', muscleGroupId: 'shoulders', equipment: 'machine', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_s_09', name: 'Barbell Front Raise', muscleGroupId: 'shoulders', equipment: 'barbell', weightStep: 2.5, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_s_10', name: 'Dumbbell Front Raise', muscleGroupId: 'shoulders', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_s_11', name: 'Cable Front Raise', muscleGroupId: 'shoulders', equipment: 'cable', weightStep: 2.5, repMin: 12, repMax: 15, restSeconds: 45),
    SeedExercise(id: 'ex_s_12', name: 'Rear Delt Dumbbell Fly', muscleGroupId: 'shoulders', secondaryGroups: 'back', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 12, repMax: 18, restSeconds: 60),
    SeedExercise(id: 'ex_s_13', name: 'Rear Delt Cable Fly', muscleGroupId: 'shoulders', secondaryGroups: 'back', equipment: 'cable', weightStep: 1.25, repMin: 12, repMax: 18, restSeconds: 45),
    SeedExercise(id: 'ex_s_14', name: 'Reverse Pec Deck (Machine Rear Delt)', muscleGroupId: 'shoulders', secondaryGroups: 'back', equipment: 'machine', weightStep: 5.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_s_15', name: 'Barbell Upright Row', muscleGroupId: 'shoulders', secondaryGroups: 'back', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_s_16', name: 'Dumbbell Upright Row', muscleGroupId: 'shoulders', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_s_17', name: 'Landmine Press', muscleGroupId: 'shoulders', secondaryGroups: 'triceps,chest', equipment: 'barbell', isUnilateral: true, weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_s_18', name: 'Shoulder Press Machine', muscleGroupId: 'shoulders', secondaryGroups: 'triceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),

    // --- BICEPS (14) ---
    SeedExercise(id: 'ex_bi_01', name: 'Barbell Bicep Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_bi_02', name: 'EZ-Bar Bicep Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_bi_03', name: 'Dumbbell Bicep Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_bi_04', name: 'Incline Dumbbell Curl', muscleGroupId: 'biceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_bi_05', name: 'Hammer Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_bi_06', name: 'Cable Rope Hammer Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_bi_07', name: 'Cable Bicep Curl', muscleGroupId: 'biceps', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_bi_08', name: 'Preacher Curl (Barbell/EZ)', muscleGroupId: 'biceps', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_bi_09', name: 'Dumbbell Concentration Curl', muscleGroupId: 'biceps', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.0, repMin: 10, repMax: 14, restSeconds: 45),
    SeedExercise(id: 'ex_bi_10', name: 'Spider Curl', muscleGroupId: 'biceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_bi_11', name: 'Waiter Curl', muscleGroupId: 'biceps', equipment: 'dumbbell', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_bi_12', name: 'Reverse Barbell Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_bi_13', name: 'Machine Bicep Curl', muscleGroupId: 'biceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_bi_14', name: 'Cross-Body Hammer Curl', muscleGroupId: 'biceps', secondaryGroups: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.0, repMin: 8, repMax: 12, restSeconds: 45),

    // --- TRICEPS (16) ---
    SeedExercise(id: 'ex_tr_01', name: 'Close-Grip Bench Press', muscleGroupId: 'triceps', secondaryGroups: 'chest,shoulders', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 10, restSeconds: 90),
    SeedExercise(id: 'ex_tr_02', name: 'Tricep Dips', muscleGroupId: 'triceps', secondaryGroups: 'chest', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_tr_03', name: 'Assisted Tricep Dips', muscleGroupId: 'triceps', secondaryGroups: 'chest', equipment: 'assisted', loadMode: 'assisted', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_tr_04', name: 'Skull Crushers (Lying Tricep Extension)', muscleGroupId: 'triceps', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_tr_05', name: 'Overhead Dumbbell Tricep Extension', muscleGroupId: 'triceps', equipment: 'dumbbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_tr_06', name: 'Overhead Cable Tricep Extension', muscleGroupId: 'triceps', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_tr_07', name: 'Tricep Rope Pushdown', muscleGroupId: 'triceps', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_tr_08', name: 'Straight-Bar Cable Pushdown', muscleGroupId: 'triceps', equipment: 'cable', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_tr_09', name: 'Single-Arm Cable Pushdown', muscleGroupId: 'triceps', equipment: 'cable', isUnilateral: true, weightStep: 1.25, repMin: 10, repMax: 15, restSeconds: 45),
    SeedExercise(id: 'ex_tr_10', name: 'Dumbbell Kickbacks', muscleGroupId: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 1.0, repMin: 12, repMax: 16, restSeconds: 45),
    SeedExercise(id: 'ex_tr_11', name: 'Cable Kickbacks', muscleGroupId: 'triceps', equipment: 'cable', isUnilateral: true, weightStep: 1.25, repMin: 12, repMax: 16, restSeconds: 45),
    SeedExercise(id: 'ex_tr_12', name: 'Bench Dips', muscleGroupId: 'triceps', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 12, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_tr_13', name: 'JM Press', muscleGroupId: 'triceps', equipment: 'barbell', weightStep: 2.5, repMin: 6, repMax: 10, restSeconds: 90),
    SeedExercise(id: 'ex_tr_14', name: 'Tate Press', muscleGroupId: 'triceps', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.0, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_tr_15', name: 'Machine Tricep Extension', muscleGroupId: 'triceps', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_tr_16', name: 'Diamond Push-Up (Triceps)', muscleGroupId: 'triceps', secondaryGroups: 'chest', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 10, repMax: 20, restSeconds: 60),

    // --- LEGS (22) ---
    SeedExercise(id: 'ex_l_01', name: 'Barbell Back Squat', muscleGroupId: 'legs', secondaryGroups: 'glutes,core', equipment: 'barbell', weightStep: 5.0, repMin: 5, repMax: 8, restSeconds: 150),
    SeedExercise(id: 'ex_l_02', name: 'Barbell Front Squat', muscleGroupId: 'legs', secondaryGroups: 'core,glutes', equipment: 'barbell', weightStep: 5.0, repMin: 5, repMax: 8, restSeconds: 120),
    SeedExercise(id: 'ex_l_03', name: 'Leg Press', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'machine', weightStep: 10.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_l_04', name: 'Hack Squat Machine', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_l_05', name: 'Goblet Squat', muscleGroupId: 'legs', secondaryGroups: 'core', equipment: 'dumbbell', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 75),
    SeedExercise(id: 'ex_l_06', name: 'Bulgarian Split Squat', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_l_07', name: 'Barbell Walking Lunge', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'barbell', weightStep: 2.5, repMin: 10, repMax: 16, restSeconds: 90),
    SeedExercise(id: 'ex_l_08', name: 'Dumbbell Walking Lunge', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 10, repMax: 16, restSeconds: 75),
    SeedExercise(id: 'ex_l_09', name: 'Dumbbell Reverse Lunge', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_l_10', name: 'Leg Extension Machine', muscleGroupId: 'legs', equipment: 'machine', weightStep: 5.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_l_11', name: 'Lying Leg Curl Machine', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_l_12', name: 'Seated Leg Curl Machine', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'machine', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_l_13', name: 'Romanian Deadlift (RDL)', muscleGroupId: 'legs', secondaryGroups: 'glutes,back', equipment: 'barbell', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_l_14', name: 'Dumbbell Romanian Deadlift', muscleGroupId: 'legs', secondaryGroups: 'glutes,back', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_l_15', name: 'Good Mornings', muscleGroupId: 'legs', secondaryGroups: 'back,glutes', equipment: 'barbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 90),
    SeedExercise(id: 'ex_l_16', name: 'Standing Calf Raise', muscleGroupId: 'legs', equipment: 'machine', weightStep: 5.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_l_17', name: 'Seated Calf Raise', muscleGroupId: 'legs', equipment: 'machine', weightStep: 5.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_l_18', name: 'Leg Press Calf Raise', muscleGroupId: 'legs', equipment: 'machine', weightStep: 10.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_l_19', name: 'Sissy Squat', muscleGroupId: 'legs', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_l_20', name: 'Step-Ups', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.5, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_l_21', name: 'Box Squat', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'barbell', weightStep: 5.0, repMin: 6, repMax: 10, restSeconds: 120),
    SeedExercise(id: 'ex_l_22', name: 'Nordic Hamstring Curl', muscleGroupId: 'legs', secondaryGroups: 'glutes', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 4, repMax: 8, restSeconds: 90),

    // --- GLUTES (14) ---
    SeedExercise(id: 'ex_g_01', name: 'Barbell Hip Thrust', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'barbell', weightStep: 5.0, repMin: 8, repMax: 12, restSeconds: 120),
    SeedExercise(id: 'ex_g_02', name: 'Single-Leg Hip Thrust', muscleGroupId: 'glutes', equipment: 'dumbbell', isUnilateral: true, weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_g_03', name: 'Barbell Glute Bridge', muscleGroupId: 'glutes', equipment: 'barbell', weightStep: 5.0, repMin: 10, repMax: 15, restSeconds: 90),
    SeedExercise(id: 'ex_g_04', name: 'Dumbbell Glute Bridge', muscleGroupId: 'glutes', equipment: 'dumbbell', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_g_05', name: 'Cable Glute Kickbacks', muscleGroupId: 'glutes', equipment: 'cable', isUnilateral: true, weightStep: 1.25, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_g_06', name: 'Machine Hip Abduction', muscleGroupId: 'glutes', equipment: 'machine', weightStep: 5.0, repMin: 12, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_g_07', name: 'Machine Hip Adduction', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'machine', weightStep: 5.0, repMin: 12, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_g_08', name: 'Sumo Deadlift', muscleGroupId: 'glutes', secondaryGroups: 'legs,back', equipment: 'barbell', weightStep: 5.0, repMin: 5, repMax: 8, restSeconds: 150),
    SeedExercise(id: 'ex_g_09', name: 'Sumo Squat', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'dumbbell', weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 75),
    SeedExercise(id: 'ex_g_10', name: 'Cable Pull-Through', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_g_11', name: 'Curtsy Lunge', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.0, repMin: 10, repMax: 14, restSeconds: 60),
    SeedExercise(id: 'ex_g_12', name: 'Frog Pumps', muscleGroupId: 'glutes', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 20, repMax: 30, restSeconds: 45),
    SeedExercise(id: 'ex_g_13', name: 'Deficit Reverse Lunge', muscleGroupId: 'glutes', secondaryGroups: 'legs', equipment: 'dumbbell', loadMode: 'per_hand', isUnilateral: true, weightStep: 2.5, repMin: 8, repMax: 12, restSeconds: 60),
    SeedExercise(id: 'ex_g_14', name: 'Hyperextension (Glute Bias)', muscleGroupId: 'glutes', secondaryGroups: 'back', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 60),

    // --- CORE (16) ---
    SeedExercise(id: 'ex_cr_01', name: 'Hanging Leg Raise', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 10, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_cr_02', name: 'Hanging Knee Raise', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_cr_03', name: 'Cable Crunch', muscleGroupId: 'core', equipment: 'cable', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_cr_04', name: 'Ab Wheel Rollout', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 8, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_cr_05', name: 'Plank', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 30, repMax: 60, restSeconds: 45),
    SeedExercise(id: 'ex_cr_06', name: 'Side Plank', muscleGroupId: 'core', isUnilateral: true, equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 30, repMax: 45, restSeconds: 30),
    SeedExercise(id: 'ex_cr_07', name: 'Russian Twist', muscleGroupId: 'core', equipment: 'other', weightStep: 2.5, repMin: 15, repMax: 25, restSeconds: 45),
    SeedExercise(id: 'ex_cr_08', name: 'Decline Crunch', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 2.5, repMin: 15, repMax: 25, restSeconds: 45),
    SeedExercise(id: 'ex_cr_09', name: 'Bicycle Crunch', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 20, repMax: 30, restSeconds: 45),
    SeedExercise(id: 'ex_cr_10', name: 'Dragon Flag', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 5, repMax: 10, restSeconds: 90),
    SeedExercise(id: 'ex_cr_11', name: 'Toes to Bar', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 8, repMax: 15, restSeconds: 60),
    SeedExercise(id: 'ex_cr_12', name: 'Pallof Press', muscleGroupId: 'core', isUnilateral: true, equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 45),
    SeedExercise(id: 'ex_cr_13', name: 'Cable Woodchopper', muscleGroupId: 'core', isUnilateral: true, equipment: 'cable', weightStep: 2.5, repMin: 10, repMax: 15, restSeconds: 45),
    SeedExercise(id: 'ex_cr_14', name: 'Captain\'s Chair Knee Raise', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_cr_15', name: 'Mountain Climbers', muscleGroupId: 'core', secondaryGroups: 'cardio', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 20, repMax: 40, restSeconds: 30),
    SeedExercise(id: 'ex_cr_16', name: 'L-Sit', muscleGroupId: 'core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 15, repMax: 30, restSeconds: 60),

    // --- FOREARMS (10) ---
    SeedExercise(id: 'ex_fa_01', name: 'Barbell Wrist Curl', muscleGroupId: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_fa_02', name: 'Barbell Reverse Wrist Curl', muscleGroupId: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_fa_03', name: 'Dumbbell Wrist Curl', muscleGroupId: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 1.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_fa_04', name: 'Dumbbell Reverse Wrist Curl', muscleGroupId: 'forearms', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 1.0, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_fa_05', name: 'Farmer\'s Walk', muscleGroupId: 'forearms', secondaryGroups: 'core,back', equipment: 'dumbbell', loadMode: 'per_hand', weightStep: 5.0, repMin: 30, repMax: 60, restSeconds: 90),
    SeedExercise(id: 'ex_fa_06', name: 'Plate Pinch Hold', muscleGroupId: 'forearms', equipment: 'other', weightStep: 2.5, repMin: 20, repMax: 45, restSeconds: 60),
    SeedExercise(id: 'ex_fa_07', name: 'Behind-the-Back Barbell Wrist Curl', muscleGroupId: 'forearms', equipment: 'barbell', weightStep: 2.5, repMin: 12, repMax: 20, restSeconds: 45),
    SeedExercise(id: 'ex_fa_08', name: 'Dead Hang', muscleGroupId: 'forearms', secondaryGroups: 'back', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 30, repMax: 60, restSeconds: 60),
    SeedExercise(id: 'ex_fa_09', name: 'Wrist Roller', muscleGroupId: 'forearms', equipment: 'other', weightStep: 1.25, repMin: 3, repMax: 6, restSeconds: 60),
    SeedExercise(id: 'ex_fa_10', name: 'Towel Pull-Up Hang', muscleGroupId: 'forearms', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 15, repMax: 40, restSeconds: 60),

    // --- CARDIO (10) ---
    SeedExercise(id: 'ex_cd_01', name: 'Treadmill Running', muscleGroupId: 'cardio', secondaryGroups: 'legs', equipment: 'machine', weightStep: 0.0, repMin: 15, repMax: 30, restSeconds: 0),
    SeedExercise(id: 'ex_cd_02', name: 'Treadmill Incline Walk', muscleGroupId: 'cardio', secondaryGroups: 'legs', equipment: 'machine', weightStep: 0.0, repMin: 20, repMax: 45, restSeconds: 0),
    SeedExercise(id: 'ex_cd_03', name: 'Stationary Bike', muscleGroupId: 'cardio', secondaryGroups: 'legs', equipment: 'machine', weightStep: 0.0, repMin: 20, repMax: 40, restSeconds: 0),
    SeedExercise(id: 'ex_cd_04', name: 'Rowing Machine', muscleGroupId: 'cardio', secondaryGroups: 'back,legs', equipment: 'machine', weightStep: 0.0, repMin: 10, repMax: 25, restSeconds: 60),
    SeedExercise(id: 'ex_cd_05', name: 'Stair Climber', muscleGroupId: 'cardio', secondaryGroups: 'legs,glutes', equipment: 'machine', weightStep: 0.0, repMin: 15, repMax: 30, restSeconds: 0),
    SeedExercise(id: 'ex_cd_06', name: 'Elliptical', muscleGroupId: 'cardio', equipment: 'machine', weightStep: 0.0, repMin: 20, repMax: 40, restSeconds: 0),
    SeedExercise(id: 'ex_cd_07', name: 'Jump Rope', muscleGroupId: 'cardio', secondaryGroups: 'forearms,legs', equipment: 'other', weightStep: 0.0, repMin: 50, repMax: 200, restSeconds: 45),
    SeedExercise(id: 'ex_cd_08', name: 'Battle Ropes', muscleGroupId: 'cardio', secondaryGroups: 'shoulders,core', equipment: 'other', weightStep: 0.0, repMin: 30, repMax: 60, restSeconds: 45),
    SeedExercise(id: 'ex_cd_09', name: 'Assault AirBike', muscleGroupId: 'cardio', secondaryGroups: 'legs', equipment: 'machine', weightStep: 0.0, repMin: 10, repMax: 20, restSeconds: 60),
    SeedExercise(id: 'ex_cd_10', name: 'Burpees', muscleGroupId: 'cardio', secondaryGroups: 'chest,legs,core', equipment: 'bodyweight', loadMode: 'bodyweight', weightStep: 0.0, repMin: 10, repMax: 25, restSeconds: 45),
  ];

  static const List<Map<String, dynamic>> defaultRoutines = [
    {
      'id': 'routine_push',
      'name': 'Push Day (Chest, Shoulders, Triceps)',
      'description': 'Target chest, anterior delts, and triceps with compound pressing and accessory isolation.',
      'exercises': ['ex_c_01', 'ex_c_05', 'ex_s_01', 'ex_s_06', 'ex_tr_07', 'ex_tr_04'],
    },
    {
      'id': 'routine_pull',
      'name': 'Pull Day (Back, Biceps, Rear Delts)',
      'description': 'Heavy pulling movements for lat width, upper back thickness, and bicep peaks.',
      'exercises': ['ex_b_01', 'ex_b_04', 'ex_b_08', 'ex_s_19', 'ex_bi_01', 'ex_bi_05'],
    },
    {
      'id': 'routine_legs',
      'name': 'Legs & Abs (Quads, Hamstrings, Calves)',
      'description': 'Comprehensive lower body development with squats, RDLs, and direct core work.',
      'exercises': ['ex_l_01', 'ex_l_13', 'ex_l_03', 'ex_l_11', 'ex_l_16', 'ex_cr_01'],
    },
  ];
}
