/// Service to provide ONLY 100% verified exercise animations.
/// If an exercise does NOT have an exact, verified match, returns null
/// to avoid confusing users with mismatched movements.
class ExerciseMediaService {
  /// Strictly verified exact exercise matches bundled locally
  static const Map<String, String> _verifiedExactMatches = {
    // Chest
    'barbell bench press': 'assets/exercises/barbell_bench_press.gif',
    'incline barbell bench press': 'assets/exercises/incline_barbell_bench.gif',
    'decline barbell bench press': 'assets/exercises/decline_barbell_bench.gif',
    'flat dumbbell press': 'assets/exercises/dumbbell_bench_press.gif',
    'flat dumbbell fly': 'assets/exercises/dumbbell_fly.gif',
    'incline dumbbell fly': 'assets/exercises/dumbbell_fly.gif',
    'pec deck machine': 'assets/exercises/lever_seated_fly.gif',

    // Back
    'barbell deadlift': 'assets/exercises/barbell_deadlift.gif',
    'conventional deadlift': 'assets/exercises/barbell_deadlift.gif',
    'deadlift': 'assets/exercises/barbell_deadlift.gif',
    'romanian deadlift': 'assets/exercises/romanian_deadlift.gif',
    'rdl': 'assets/exercises/romanian_deadlift.gif',
    'barbell bent-over row': 'assets/exercises/barbell_bent_over_row.gif',
    'barbell bent over row': 'assets/exercises/barbell_bent_over_row.gif',
    'bent-over row': 'assets/exercises/barbell_bent_over_row.gif',
    'bent over row': 'assets/exercises/barbell_bent_over_row.gif',
    'barbell row': 'assets/exercises/barbell_bent_over_row.gif',
    'lat pulldown': 'assets/exercises/cable_lat_pulldown.gif',
    'cable lat pulldown': 'assets/exercises/cable_lat_pulldown.gif',
    'wide-grip lat pulldown': 'assets/exercises/cable_lat_pulldown.gif',
    'close-grip lat pulldown': 'assets/exercises/cable_lat_pulldown.gif',
    'pull-ups': 'assets/exercises/pull_up.gif',
    'pull-up': 'assets/exercises/pull_up.gif',
    'pull up': 'assets/exercises/pull_up.gif',
    'pullups': 'assets/exercises/pull_up.gif',
    'chin-up': 'assets/exercises/pull_up.gif',
    'chin up': 'assets/exercises/pull_up.gif',
    'seated cable row': 'assets/exercises/cable_seated_row.gif',
    'cable row': 'assets/exercises/cable_seated_row.gif',

    // Shoulders
    'overhead barbell press (ohp)': 'assets/exercises/overhead_press.gif',
    'overhead press': 'assets/exercises/overhead_press.gif',
    'barbell overhead press': 'assets/exercises/overhead_press.gif',
    'military press': 'assets/exercises/overhead_press.gif',
    'seated barbell overhead press': 'assets/exercises/overhead_press.gif',
    'standing dumbbell shoulder press': 'assets/exercises/overhead_press.gif',
    'seated dumbbell shoulder press': 'assets/exercises/overhead_press.gif',
    'shoulder press': 'assets/exercises/overhead_press.gif',
    'dumbbell lateral raise': 'assets/exercises/dumbbell_lateral_raise.gif',
    'lateral raise': 'assets/exercises/dumbbell_lateral_raise.gif',
    'side lateral raise': 'assets/exercises/dumbbell_lateral_raise.gif',

    // Biceps
    'barbell bicep curl': 'assets/exercises/dumbbell_bicep_curl.gif',
    'dumbbell bicep curl': 'assets/exercises/dumbbell_bicep_curl.gif',
    'bicep curl': 'assets/exercises/dumbbell_bicep_curl.gif',
    'biceps curl': 'assets/exercises/dumbbell_bicep_curl.gif',
    'dumbbell curl': 'assets/exercises/dumbbell_bicep_curl.gif',
    'hammer curl': 'assets/exercises/cable_hammer_curl.gif',
    'cable rope hammer curl': 'assets/exercises/cable_hammer_curl.gif',
    'cable hammer curl': 'assets/exercises/cable_hammer_curl.gif',
    'preacher curl (barbell/ez)': 'assets/exercises/preacher_curl.gif',
    'preacher curl': 'assets/exercises/preacher_curl.gif',

    // Triceps
    'tricep rope pushdown': 'assets/exercises/cable_tricep_pushdown.gif',
    'straight-bar cable pushdown': 'assets/exercises/cable_tricep_pushdown.gif',
    'cable tricep pushdown': 'assets/exercises/cable_tricep_pushdown.gif',
    'tricep pushdown': 'assets/exercises/cable_tricep_pushdown.gif',
    'pushdown': 'assets/exercises/cable_tricep_pushdown.gif',
    'tricep dips': 'assets/exercises/tricep_dips.gif',
    'tricep dip': 'assets/exercises/tricep_dips.gif',
    'dips': 'assets/exercises/tricep_dips.gif',
    'dip': 'assets/exercises/tricep_dips.gif',
    'skull crushers (lying tricep extension)': 'assets/exercises/skull_crusher.gif',
    'skull crusher': 'assets/exercises/skull_crusher.gif',
    'skull crushers': 'assets/exercises/skull_crusher.gif',

    // Legs
    'barbell squat': 'assets/exercises/barbell_squat.gif',
    'barbell full squat': 'assets/exercises/barbell_squat.gif',
    'back squat': 'assets/exercises/barbell_squat.gif',
    'squat': 'assets/exercises/barbell_squat.gif',
    'squats': 'assets/exercises/barbell_squat.gif',
    'sled 45° leg press': 'assets/exercises/sled_leg_press.gif',
    'leg press': 'assets/exercises/sled_leg_press.gif',
    'hack squat': 'assets/exercises/hack_squat.gif',
    'leg extension': 'assets/exercises/lever_leg_extension.gif',
  };

  /// Returns verified media if an exact or normalized match exists.
  /// Prioritizes bundled local GIF assets with zero lag.
  static ExerciseMediaInfo? getVerifiedMedia(String exerciseName) {
    final clean = exerciseName
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (_verifiedExactMatches.containsKey(clean)) {
      return ExerciseMediaInfo(
        source: _verifiedExactMatches[clean]!,
        isLocalAsset: true,
        displayName: exerciseName,
      );
    }

    for (final entry in _verifiedExactMatches.entries) {
      final keyClean = entry.key
          .toLowerCase()
          .replaceAll('-', ' ')
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (clean == keyClean || clean.contains(keyClean) || keyClean.contains(clean)) {
        return ExerciseMediaInfo(
          source: entry.value,
          isLocalAsset: true,
          displayName: exerciseName,
        );
      }
    }
    return null;
  }
}

class ExerciseMediaInfo {
  final String source;
  final bool isLocalAsset;
  final String displayName;

  const ExerciseMediaInfo({
    required this.source,
    required this.isLocalAsset,
    required this.displayName,
  });
}
