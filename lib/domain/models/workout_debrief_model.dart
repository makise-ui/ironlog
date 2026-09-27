import 'analytics_model.dart';
import 'workout_model.dart';

/// Data class representing an AI-driven post-workout debriefing.
/// Summarizes broken PRs, volume vs historical baseline, fatigued muscle groups,
/// and actionable recovery & fueling recommendations.
class WorkoutDebriefData {
  final WorkoutModel workout;
  final Duration duration;
  final List<PrItemData> brokenPrs;
  final double currentVolume;
  final double baselineVolume;
  final double volumeDeltaPercent; // e.g. +14.5%
  final Map<String, int> muscleSets;
  final List<String> primaryFatiguedMuscles;
  final String headline;
  final String volumeInsight;
  final String recoveryAdvice;
  final String nutritionTip;

  const WorkoutDebriefData({
    required this.workout,
    required this.duration,
    required this.brokenPrs,
    required this.currentVolume,
    required this.baselineVolume,
    required this.volumeDeltaPercent,
    required this.muscleSets,
    required this.primaryFatiguedMuscles,
    required this.headline,
    required this.volumeInsight,
    required this.recoveryAdvice,
    required this.nutritionTip,
  });

  bool get hasPrs => brokenPrs.isNotEmpty;

  bool get isVolumeSurge => volumeDeltaPercent >= 10.0;
  bool get isVolumeDeload => volumeDeltaPercent <= -15.0;
}
