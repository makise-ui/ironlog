import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/database/database.dart';
import '../../data/repositories/exercise_repository.dart';
import 'exercise_image_search_service.dart';

/// Fast background service to fetch, cache, and immediately display exercise demonstration images
class ExerciseAutoImageService {
  /// Notifier for real-time reactive updates to thumbnail icons
  static final ValueNotifier<Map<String, String>> resolvedImagesNotifier =
      ValueNotifier<Map<String, String>>({});

  static final Set<String> _pendingFetches = {};

  /// Retrieves currently known resolved image path or network URL
  static String? getResolvedPath(String? exerciseName) {
    if (exerciseName == null) return null;
    final key = exerciseName.toLowerCase().trim();
    return resolvedImagesNotifier.value[key];
  }

  /// Triggers a non-blocking background fetch for an exercise image
  static void prefetch({
    required String exerciseName,
    String? exerciseId,
    AppDatabase? db,
  }) {
    final clean = exerciseName.toLowerCase().trim();
    if (clean.isEmpty) return;

    // Already resolved or fetch already in progress
    if (resolvedImagesNotifier.value.containsKey(clean) || _pendingFetches.contains(clean)) {
      return;
    }

    _pendingFetches.add(clean);

    Future(() async {
      try {
        // 1. Query online candidates
        final candidates = await ExerciseImageSearchService.searchWebExerciseImages(exerciseName);
        if (candidates.isEmpty) return;

        final firstCandidate = candidates.first;
        final thumbUrl = firstCandidate.thumbnailUrl;

        // 2. Immediately notify listeners with the network URL for sub-second UI updates
        final updatedMap = Map<String, String>.from(resolvedImagesNotifier.value);
        updatedMap[clean] = thumbUrl;
        resolvedImagesNotifier.value = updatedMap;

        // 3. Concurrently download & persist locally for 100% offline access
        final localPath = await ExerciseImageSearchService.downloadAndCacheImage(
          exerciseId: exerciseId ?? clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'),
          imageUrl: thumbUrl,
        );

        if (localPath != null && File(localPath).existsSync()) {
          final persistedMap = Map<String, String>.from(resolvedImagesNotifier.value);
          persistedMap[clean] = localPath;
          resolvedImagesNotifier.value = persistedMap;

          // 4. Update SQLite database row if exerciseId & db are available
          if (exerciseId != null && db != null) {
            try {
              final repo = ExerciseRepository(db);
              await repo.updateExerciseImage(exerciseId, localPath);
            } catch (_) {}
          }
        }
      } catch (_) {
        // Silently swallow network / parsing errors to never interrupt user interaction
      } finally {
        _pendingFetches.remove(clean);
      }
    });
  }

  /// Prefetches a batch of exercises in the background (e.g. when opening a routine preview)
  static void prefetchBatch(
    List<({String name, String? id})> exercises,
    AppDatabase? db,
  ) {
    for (final ex in exercises) {
      prefetch(exerciseName: ex.name, exerciseId: ex.id, db: db);
    }
  }
}
