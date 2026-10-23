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
  static final Set<String> _failedFetches = {};

  /// Shared database reference for persisting resolved image paths
  static AppDatabase? database;

  /// Initializes the service and pre-populates in-memory cache with all saved images from SQLite
  static Future<void> init(AppDatabase db) async {
    database = db;
    try {
      final exercisesWithImages = await (db.select(db.exercises)
            ..where((t) => t.imagePath.isNotNull()))
          .get();

      if (exercisesWithImages.isNotEmpty) {
        final updatedMap = Map<String, String>.from(resolvedImagesNotifier.value);
        for (final ex in exercisesWithImages) {
          if (ex.imagePath != null && ex.imagePath!.isNotEmpty) {
            final key = ex.name.toLowerCase().trim();
            final norm = _normalizeKey(ex.name);
            updatedMap[key] = ex.imagePath!;
            if (norm.isNotEmpty) updatedMap[norm] = ex.imagePath!;
          }
        }
        resolvedImagesNotifier.value = updatedMap;
      }
    } catch (_) {}
  }

  static String _normalizeKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Retrieves currently known resolved image path or network URL
  static String? getResolvedPath(String? exerciseName) {
    if (exerciseName == null) return null;
    final key = exerciseName.toLowerCase().trim();
    final norm = _normalizeKey(exerciseName);
    return resolvedImagesNotifier.value[key] ?? (norm.isNotEmpty ? resolvedImagesNotifier.value[norm] : null);
  }

  /// Forces a re-fetch of an exercise image (e.g. when an image fails to load or 403s)
  static void retryFetch({
    required String exerciseName,
    String? exerciseId,
    AppDatabase? db,
  }) {
    final clean = exerciseName.toLowerCase().trim();
    final norm = _normalizeKey(exerciseName);
    _pendingFetches.remove(clean);
    _failedFetches.remove(clean);
    if (norm.isNotEmpty) {
      _pendingFetches.remove(norm);
      _failedFetches.remove(norm);
    }
    final updated = Map<String, String>.from(resolvedImagesNotifier.value);
    updated.remove(clean);
    if (norm.isNotEmpty) updated.remove(norm);
    resolvedImagesNotifier.value = updated;

    prefetch(
      exerciseName: exerciseName,
      exerciseId: exerciseId,
      db: db,
      force: true,
    );
  }

  /// Triggers a non-blocking background fetch for an exercise image
  static void prefetch({
    required String exerciseName,
    String? exerciseId,
    AppDatabase? db,
    bool force = false,
  }) {
    final clean = exerciseName.toLowerCase().trim();
    if (clean.isEmpty) return;

    final norm = _normalizeKey(exerciseName);

    if (!force) {
      // Already resolved or fetch already in progress or previously failed
      if (resolvedImagesNotifier.value.containsKey(clean) ||
          (norm.isNotEmpty && resolvedImagesNotifier.value.containsKey(norm)) ||
          _pendingFetches.contains(clean) ||
          _failedFetches.contains(clean)) {
        return;
      }
    }

    _pendingFetches.add(clean);

    Future(() async {
      try {
        // 1. Query online candidates using fast Bing CDN thumbnails
        final candidates = await ExerciseImageSearchService.searchWebExerciseImages(exerciseName);
        if (candidates.isEmpty) {
          _failedFetches.add(clean);
          return;
        }

        final firstCandidate = candidates.first;
        final thumbUrl = firstCandidate.thumbnailUrl;
        if (thumbUrl.isEmpty) {
          _failedFetches.add(clean);
          return;
        }

        // 2. Immediately notify listeners with the CDN thumbnail URL for instant UI display
        final updatedMap = Map<String, String>.from(resolvedImagesNotifier.value);
        updatedMap[clean] = thumbUrl;
        if (norm.isNotEmpty) updatedMap[norm] = thumbUrl;
        resolvedImagesNotifier.value = updatedMap;

        // 3. Concurrently download & persist locally for 100% offline access
        final localPath = await ExerciseImageSearchService.downloadAndCacheImage(
          exerciseId: exerciseId ?? clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'),
          imageUrl: thumbUrl,
        );

        if (localPath != null && File(localPath).existsSync()) {
          final persistedMap = Map<String, String>.from(resolvedImagesNotifier.value);
          persistedMap[clean] = localPath;
          if (norm.isNotEmpty) persistedMap[norm] = localPath;
          resolvedImagesNotifier.value = persistedMap;

          // 4. Update SQLite database row so the image is permanently available offline
          final effectiveDb = db ?? database;
          if (effectiveDb != null) {
            try {
              final repo = ExerciseRepository(effectiveDb);
              if (exerciseId != null) {
                await repo.updateExerciseImage(exerciseId, localPath);
              } else {
                await repo.updateExerciseImageByName(exerciseName, localPath);
              }
            } catch (_) {}
          }
        }
      } catch (_) {
        _failedFetches.add(clean);
      } finally {
        _pendingFetches.remove(clean);
      }
    });
  }

  /// Prefetches a batch of exercises in the background with small delays
  static void prefetchBatch(
    List<({String name, String? id})> exercises,
    AppDatabase? db,
  ) {
    int delayMs = 0;
    for (final ex in exercises) {
      final delay = delayMs;
      delayMs += 100;
      Future.delayed(Duration(milliseconds: delay), () {
        prefetch(exerciseName: ex.name, exerciseId: ex.id, db: db);
      });
    }
  }
}
