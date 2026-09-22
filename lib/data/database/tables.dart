import 'package:drift/drift.dart';

@DataClassName('MuscleGroupData')
class MuscleGroups extends Table {
  TextColumn get id => text()(); // e.g. 'chest', 'back'
  TextColumn get name => text()();
  TextColumn get color => text()(); // hex string #RRGGBB
  TextColumn get icon => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseData')
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get muscleGroupId => text().references(MuscleGroups, #id)();
  TextColumn get secondaryGroups => text().withDefault(const Constant(''))();
  TextColumn get equipment => text()(); // barbell, dumbbell, machine, cable, bodyweight, assisted, other
  TextColumn get loadMode => text().withDefault(const Constant('total'))(); // total, per_hand, bodyweight, assisted
  BoolColumn get isUnilateral => boolean().withDefault(const Constant(false))();
  RealColumn get weightStep => real().withDefault(const Constant(2.5))();
  IntColumn get repMin => integer().withDefault(const Constant(8))();
  IntColumn get repMax => integer().withDefault(const Constant(12))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WorkoutData')
class Workouts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  IntColumn get feel => integer().nullable()(); // 1-5
  TextColumn get routineId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WorkoutExerciseData')
class WorkoutExercises extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get supersetGroup => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GymSetData')
class Sets extends Table {
  TextColumn get id => text()();
  TextColumn get workoutExerciseId => text()();
  TextColumn get exerciseId => text()();
  TextColumn get muscleGroupId => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get setIndex => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  TextColumn get setType => text()(); // warmup, working, drop, failure
  RealColumn get rpe => real().nullable()();
  DateTimeColumn get completedAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoutineData')
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoutineItemData')
class RoutineItems extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().references(Routines, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get repMin => integer().withDefault(const Constant(8))();
  IntColumn get repMax => integer().withDefault(const Constant(12))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrData')
class Prs extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId => text()();
  TextColumn get kind => text()(); // heaviest, reps_at_weight, e1rm, session_volume
  RealColumn get value => real()();
  TextColumn get setId => text().nullable()();
  DateTimeColumn get achievedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AchievementData')
class Achievements extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
  TextColumn get badgeIcon => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingData')
class Settings extends Table {
  TextColumn get k => text()();
  TextColumn get v => text()();

  @override
  Set<Column> get primaryKey => {k};
}

@DataClassName('BodyMetricData')
class BodyMetrics extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get metricType => text()(); // weight, body_fat, waist, arm, etc.
  RealColumn get value => real()();
  TextColumn get unit => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhotoData')
class Photos extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get pose => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
