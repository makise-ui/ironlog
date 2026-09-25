import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/database/database.dart';

class BackupFileInfo {
  final String path;
  final DateTime modifiedAt;
  final DateTime exportedAt;
  final int workoutCount;
  final int setCount;
  final String? athleteName;
  final double? athleteWeight;
  final String? weightUnit;
  final String displayDirectory;

  BackupFileInfo({
    required this.path,
    required this.modifiedAt,
    DateTime? exportedAt,
    required this.workoutCount,
    required this.setCount,
    this.athleteName,
    this.athleteWeight,
    this.weightUnit,
    String? displayDirectory,
  })  : exportedAt = exportedAt ?? modifiedAt,
        displayDirectory = displayDirectory ??
            (path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : path);
}

class BackupService {
  BackupService._();

  static const String backupFileName = 'ironlog_backup.json';
  static const String autoBackupFileName = 'ironlog_autobackup.json';

  static Timer? _debounceTimer;

  /// Standard persistent directories on Android & Desktop that survive app uninstall
  static Future<List<Directory>> getPersistentDirectories() async {
    final dirs = <Directory>[];

    // 1. Android public Documents/IronLog folder (survives app uninstall)
    try {
      final docDir = Directory('/storage/emulated/0/Documents/IronLog');
      if (!await docDir.exists()) {
        await docDir.create(recursive: true);
      }
      dirs.add(docDir);
    } catch (_) {}

    // 2. Android public Download/IronLog folder (survives app uninstall)
    try {
      final downloadDir = Directory('/storage/emulated/0/Download/IronLog');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      dirs.add(downloadDir);
    } catch (_) {}

    // 3. Android /sdcard symlink fallbacks
    try {
      final sdDoc = Directory('/sdcard/Documents/IronLog');
      if (!await sdDoc.exists()) {
        await sdDoc.create(recursive: true);
      }
      if (!dirs.any((d) => d.path == sdDoc.path)) dirs.add(sdDoc);
    } catch (_) {}

    try {
      final sdDownload = Directory('/sdcard/Download/IronLog');
      if (!await sdDownload.exists()) {
        await sdDownload.create(recursive: true);
      }
      if (!dirs.any((d) => d.path == sdDownload.path)) dirs.add(sdDownload);
    } catch (_) {}

    // 4. Desktop (Linux, macOS, Windows) user Documents folder
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          final docDir = Directory('$home/Documents/IronLog');
          if (!await docDir.exists()) {
            await docDir.create(recursive: true);
          }
          if (!dirs.any((d) => d.path == docDir.path)) dirs.add(docDir);
        }
      } catch (_) {}
    }

    // 5. System Downloads directory via path_provider
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final ironDir = Directory('${downloads.path}/IronLog');
        if (!await ironDir.exists()) {
          await ironDir.create(recursive: true);
        }
        if (!dirs.any((d) => d.path == ironDir.path)) dirs.add(ironDir);
      }
    } catch (_) {}

    // 6. External storage directory
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final ironDir = Directory('${extDir.path}/IronLog');
        if (!await ironDir.exists()) {
          await ironDir.create(recursive: true);
        }
        if (!dirs.any((d) => d.path == ironDir.path)) dirs.add(ironDir);
      }
    } catch (_) {}

    // 7. Application documents directory fallback
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final ironDir = Directory('${appDocDir.path}/IronLog');
      if (!await ironDir.exists()) {
        await ironDir.create(recursive: true);
      }
      if (!dirs.any((d) => d.path == ironDir.path)) dirs.add(ironDir);
    } catch (_) {}

    return dirs;
  }

  /// Get primary user-visible persistent backup directory path for display in UI
  static Future<String> getPrimaryBackupDirectoryPath() async {
    final existing = await findExistingBackup();
    if (existing != null) return existing.displayDirectory;
    final dirs = await getPersistentDirectories();
    for (final dir in dirs) {
      if (dir.path.contains('/Documents/IronLog') || dir.path.contains('/Download/IronLog')) {
        return dir.path;
      }
    }
    return dirs.isNotEmpty ? dirs.first.path : 'Documents/IronLog';
  }

  /// Exports the entire database & user preferences to a JSON structure
  static Future<Map<String, dynamic>> createBackupJson(
    AppDatabase db, {
    bool stripSecrets = false,
  }) async {
    final workouts = await db.select(db.workouts).get();
    final workoutExercises = await db.select(db.workoutExercises).get();
    final sets = await db.select(db.sets).get();
    final prs = await db.select(db.prs).get();
    final routines = await db.select(db.routines).get();
    final routineItems = await db.select(db.routineItems).get();
    final settingsRows = await db.select(db.settings).get();
    final customExercises = await (db.select(db.exercises)..where((e) => e.isCustom.equals(true))).get();
    final bodyMetrics = await db.select(db.bodyMetrics).get();
    final achievements = await db.select(db.achievements).get();
    final photos = await db.select(db.photos).get();

    final settingsMap = <String, String>{};
    for (final s in settingsRows) {
      if (stripSecrets) {
        // Redact live API keys and tokens if requested for anonymous sharing
        if (s.k == 'ai_profiles_json') {
          try {
            final decoded = jsonDecode(s.v);
            if (decoded is List) {
              final sanitizedList = decoded.map((item) {
                if (item is Map<String, dynamic>) {
                  final copy = Map<String, dynamic>.from(item);
                  copy['apiKey'] = '';
                  return copy;
                }
                return item;
              }).toList();
              settingsMap[s.k] = jsonEncode(sanitizedList);
              continue;
            }
          } catch (_) {}
        } else if (s.k == 'ai_config_json') {
          try {
            final decoded = jsonDecode(s.v);
            if (decoded is Map<String, dynamic>) {
              final copy = Map<String, dynamic>.from(decoded);
              copy['apiKey'] = '';
              settingsMap[s.k] = jsonEncode(copy);
              continue;
            }
          } catch (_) {}
        } else if (s.k.toLowerCase().contains('key') ||
            s.k.toLowerCase().contains('secret') ||
            s.k.toLowerCase().contains('token')) {
          continue;
        }
      }
      settingsMap[s.k] = s.v;
    }

    final prefs = await SharedPreferences.getInstance();

    // Export nutrition logs so nutrition data survives backups
    final nutritionLogs = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('nutrition_log_')) {
        final val = prefs.getString(key);
        if (val != null) {
          try {
            nutritionLogs[key] = jsonDecode(val);
          } catch (_) {
            nutritionLogs[key] = val;
          }
        }
      }
    }

    final profile = <String, dynamic>{
      'user_name': settingsMap['user_name'] ?? prefs.getString('user_name') ?? 'Athlete',
      'user_weight_kg': double.tryParse(settingsMap['user_weight'] ?? '') ?? prefs.getDouble('user_weight_kg'),
      'user_age': int.tryParse(settingsMap['user_age'] ?? '') ?? prefs.getInt('user_age'),
      'user_height_cm': double.tryParse(settingsMap['user_height'] ?? '') ?? prefs.getDouble('user_height_cm'),
      'user_gender': settingsMap['user_gender'] ?? prefs.getString('user_gender'),
      'user_fitness_goal': settingsMap['user_goal'] ?? prefs.getString('user_fitness_goal'),
      'user_experience_level': settingsMap['user_level'] ?? prefs.getString('user_experience_level'),
      'weight_unit': settingsMap['weight_unit'] ?? prefs.getString('weight_unit') ?? 'kg',
      'theme_mode': settingsMap['theme_mode'] ?? prefs.getString('theme_mode') ?? 'dark',
      'accent_preset': settingsMap['accent_preset'] ?? 'cobalt',
      'include_warmup': settingsMap['include_warmup_volume'] == 'true',
    };

    return {
      'app': 'IronLog',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': profile,
      'settings': settingsMap,
      'nutrition_logs': nutritionLogs,
      'custom_exercises': customExercises.map((e) => {
        'id': e.id,
        'name': e.name,
        'muscle_group_id': e.muscleGroupId,
        'equipment': e.equipment,
        'is_custom': e.isCustom,
      }).toList(),
      'workouts': workouts.map((w) => {
        'id': w.id,
        'title': w.title,
        'date': w.date.toIso8601String(),
        'started_at': w.startedAt?.toIso8601String(),
        'ended_at': w.endedAt?.toIso8601String(),
        'feel': w.feel,
        'note': w.note,
        'routine_id': w.routineId,
        'archived': w.archived,
      }).toList(),
      'workout_exercises': workoutExercises.map((we) => {
        'id': we.id,
        'workout_id': we.workoutId,
        'exercise_id': we.exerciseId,
        'position': we.position,
        'note': we.note,
        'superset_group': we.supersetGroup,
        'archived': we.archived,
      }).toList(),
      'sets': sets.map((s) => {
        'id': s.id,
        'workout_exercise_id': s.workoutExerciseId,
        'exercise_id': s.exerciseId,
        'muscle_group_id': s.muscleGroupId,
        'date': s.date.toIso8601String(),
        'set_index': s.setIndex,
        'weight': s.weight,
        'reps': s.reps,
        'set_type': s.setType,
        'rpe': s.rpe,
        'completed_at': s.completedAt.toIso8601String(),
        'archived': s.archived,
      }).toList(),
      'prs': prs.map((p) => {
        'id': p.id,
        'exercise_id': p.exerciseId,
        'kind': p.kind,
        'value': p.value,
        'set_id': p.setId,
        'achieved_at': p.achievedAt.toIso8601String(),
      }).toList(),
      'routines': routines.map((r) => {
        'id': r.id,
        'name': r.name,
        'description': r.description,
        'archived': r.archived,
      }).toList(),
      'routine_items': routineItems.map((ri) => {
        'id': ri.id,
        'routine_id': ri.routineId,
        'exercise_id': ri.exerciseId,
        'position': ri.position,
        'target_sets': ri.targetSets,
        'rep_min': ri.repMin,
        'rep_max': ri.repMax,
        'rest_seconds': ri.restSeconds,
      }).toList(),
      'body_metrics': bodyMetrics.map((b) => {
        'id': b.id,
        'date': b.date.toIso8601String(),
        'metric_type': b.metricType,
        'value': b.value,
        'unit': b.unit,
      }).toList(),
      'achievements': achievements.map((a) => {
        'id': a.id,
        'code': a.code,
        'title': a.title,
        'description': a.description,
        'unlocked_at': a.unlockedAt?.toIso8601String(),
        'badge_icon': a.badgeIcon,
      }).toList(),
      'photos': photos.map((p) => {
        'id': p.id,
        'date': p.date.toIso8601String(),
        'file_path': p.filePath,
        'thumbnail_path': p.thumbnailPath,
        'pose': p.pose,
        'note': p.note,
      }).toList(),
    };
  }

  /// Schedules a debounced auto-backup to persistent storage
  static void scheduleAutoBackup(AppDatabase db, {Duration delay = const Duration(seconds: 2)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      try {
        await autoBackup(db);
      } catch (e) {
        debugPrint('Scheduled auto-backup error: $e');
      }
    });
  }

  /// Cancels any pending scheduled debounced auto-backup
  static void cancelPendingAutoBackup() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Automatically backs up progress into phone storage (survives app uninstall)
  static Future<String?> autoBackup(AppDatabase db) async {
    try {
      final jsonMap = await createBackupJson(db);
      final jsonStr = jsonEncode(jsonMap);
      final dirs = await getPersistentDirectories();

      String? primarySavedPath;
      for (final dir in dirs) {
        try {
          final file = File('${dir.path}/$backupFileName');
          await file.writeAsString(jsonStr, flush: true);
          primarySavedPath ??= file.path;

          // Also duplicate to autobackup file for extra resilience
          final autoFile = File('${dir.path}/$autoBackupFileName');
          await autoFile.writeAsString(jsonStr, flush: true);

          debugPrint('IronLog auto-backed up to: ${file.path}');
        } catch (e) {
          debugPrint('Error writing backup to ${dir.path}: $e');
        }
      }
      return primarySavedPath;
    } catch (e) {
      debugPrint('Auto-backup error: $e');
      return null;
    }
  }

  /// Check if a previous backup exists in persistent device storage (surviving reinstall)
  static Future<BackupFileInfo?> findExistingBackup() async {
    final dirs = await getPersistentDirectories();
    BackupFileInfo? bestCandidate;

    for (final dir in dirs) {
      for (final fname in [backupFileName, autoBackupFileName]) {
        final file = File('${dir.path}/$fname');
        if (await file.exists()) {
          try {
            final content = await file.readAsString();
            if (content.trim().isEmpty) continue;
            final data = jsonDecode(content) as Map<String, dynamic>;
            final workouts = (data['workouts'] as List?)?.length ?? 0;
            final sets = (data['sets'] as List?)?.length ?? 0;
            final stat = await file.stat();

            final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
            final settings = (data['settings'] as Map<String, dynamic>?) ?? {};

            final athleteName = profile['user_name'] ?? settings['user_name'];
            final athleteWeight = (profile['user_weight_kg'] as num?)?.toDouble() ??
                double.tryParse(settings['user_weight']?.toString() ?? '');
            final weightUnit = profile['weight_unit'] ?? settings['weight_unit'] ?? 'kg';

            final exportedAt = DateTime.tryParse(data['exported_at']?.toString() ?? '') ?? stat.modified;

            final info = BackupFileInfo(
              path: file.path,
              modifiedAt: stat.modified,
              exportedAt: exportedAt,
              workoutCount: workouts,
              setCount: sets,
              athleteName: athleteName?.toString(),
              athleteWeight: athleteWeight,
              weightUnit: weightUnit?.toString(),
              displayDirectory: dir.path,
            );

            if (bestCandidate == null) {
              bestCandidate = info;
            } else if (info.exportedAt.isAfter(bestCandidate.exportedAt)) {
              bestCandidate = info;
            } else if (info.exportedAt.isAtSameMomentAs(bestCandidate.exportedAt) &&
                info.workoutCount > bestCandidate.workoutCount) {
              bestCandidate = info;
            }
          } catch (e) {
            debugPrint('Error parsing found backup at ${file.path}: $e');
          }
        }
      }
    }
    return bestCandidate;
  }

  /// Restores progress directly from a file path
  static Future<int> restoreFromPath(AppDatabase db, String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    return await restoreFromJson(db, data);
  }

  /// Restores all progress from a JSON map into the local SQLite database
  static Future<int> restoreFromJson(AppDatabase db, Map<String, dynamic> data) async {
    final workoutsList = (data['workouts'] as List? ?? []);
    final weList = (data['workout_exercises'] as List? ?? []);
    final setsList = (data['sets'] as List? ?? []);
    final prsList = (data['prs'] as List? ?? []);
    final routinesList = (data['routines'] as List? ?? []);
    final routineItemsList = (data['routine_items'] as List? ?? []);
    final customExList = (data['custom_exercises'] as List? ?? []);
    final settingsMap = (data['settings'] as Map<String, dynamic>? ?? {});
    final profile = (data['profile'] as Map<String, dynamic>? ?? {});

    // Restore SharedPreferences profile for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    if (profile['user_name'] != null) await prefs.setString('user_name', profile['user_name'].toString());
    if (profile['user_weight_kg'] != null) {
      await prefs.setDouble('user_weight_kg', (profile['user_weight_kg'] as num).toDouble());
    }
    if (profile['user_age'] != null) {
      await prefs.setInt('user_age', (profile['user_age'] as num).toInt());
    }
    if (profile['user_height_cm'] != null) {
      await prefs.setDouble('user_height_cm', (profile['user_height_cm'] as num).toDouble());
    }
    if (profile['user_gender'] != null) {
      await prefs.setString('user_gender', profile['user_gender'].toString());
    }
    if (profile['user_fitness_goal'] != null) {
      await prefs.setString('user_fitness_goal', profile['user_fitness_goal'].toString());
    }
    if (profile['user_experience_level'] != null) {
      await prefs.setString('user_experience_level', profile['user_experience_level'].toString());
    }
    if (profile['weight_unit'] != null) {
      await prefs.setString('weight_unit', profile['weight_unit'].toString());
    }
    await prefs.setBool('user_onboarded', true);

    // Restore nutrition logs if present in backup
    final nutritionLogs = (data['nutrition_logs'] as Map<String, dynamic>? ?? {});
    for (final entry in nutritionLogs.entries) {
      final val = entry.value;
      if (val is String) {
        await prefs.setString(entry.key, val);
      } else {
        await prefs.setString(entry.key, jsonEncode(val));
      }
    }

    // Insert into DB inside a transaction
    await db.transaction(() async {
      // Clear existing log tables (leave exercises catalog)
      await db.delete(db.sets).go();
      await db.delete(db.workoutExercises).go();
      await db.delete(db.workouts).go();
      await db.delete(db.prs).go();
      await db.delete(db.bodyMetrics).go();
      await db.delete(db.achievements).go();
      await db.delete(db.photos).go();

      // 0. Custom Exercises if present
      for (final ex in customExList) {
        await db.into(db.exercises).insertOnConflictUpdate(
          ExercisesCompanion.insert(
            id: ex['id'] as String,
            name: (ex['name'] ?? 'Custom Exercise') as String,
            muscleGroupId: (ex['muscle_group_id'] ?? 'chest') as String,
            equipment: (ex['equipment'] as String?) ?? 'other',
            isCustom: const Value(true),
          ),
        );
      }

      // 1. Workouts
      for (final w in workoutsList) {
        await db.into(db.workouts).insertOnConflictUpdate(
          WorkoutsCompanion.insert(
            id: w['id'],
            title: w['title'] ?? 'Workout',
            date: DateTime.parse(w['date']),
            startedAt: Value(w['started_at'] != null ? DateTime.parse(w['started_at']) : null),
            endedAt: Value(w['ended_at'] != null ? DateTime.parse(w['ended_at']) : null),
            feel: Value(w['feel']),
            note: Value(w['note'] ?? w['notes']),
            routineId: Value(w['routine_id']),
            archived: Value(w['archived'] ?? false),
          ),
        );
      }

      // 2. Workout Exercises
      for (final we in weList) {
        await db.into(db.workoutExercises).insertOnConflictUpdate(
          WorkoutExercisesCompanion.insert(
            id: we['id'],
            workoutId: we['workout_id'],
            exerciseId: we['exercise_id'],
            position: we['position'] ?? 0,
            note: Value(we['note'] ?? we['notes']),
            supersetGroup: Value(we['superset_group']),
            archived: Value(we['archived'] ?? false),
          ),
        );
      }

      // 3. Sets
      for (final s in setsList) {
        await db.into(db.sets).insertOnConflictUpdate(
          SetsCompanion.insert(
            id: s['id'],
            workoutExerciseId: s['workout_exercise_id'],
            exerciseId: s['exercise_id'],
            muscleGroupId: s['muscle_group_id'],
            date: DateTime.parse(s['date']),
            setIndex: s['set_index'] ?? 0,
            weight: (s['weight'] as num).toDouble(),
            reps: s['reps'] ?? 0,
            setType: s['set_type'] ?? 'working',
            rpe: Value(s['rpe'] != null ? (s['rpe'] as num).toDouble() : null),
            completedAt: DateTime.parse(s['completed_at']),
            archived: Value(s['archived'] ?? false),
          ),
        );
      }

      // 4. PRs
      for (final p in prsList) {
        await db.into(db.prs).insertOnConflictUpdate(
          PrsCompanion.insert(
            id: p['id'],
            exerciseId: p['exercise_id'],
            kind: p['kind'] ?? 'heaviest',
            value: (p['value'] ?? p['weight'] ?? p['e1rm'] as num).toDouble(),
            setId: Value(p['set_id']),
            achievedAt: DateTime.parse(p['achieved_at']),
          ),
        );
      }

      // 5. Custom routines if present
      for (final r in routinesList) {
        await db.into(db.routines).insertOnConflictUpdate(
          RoutinesCompanion.insert(
            id: r['id'],
            name: r['name'],
            description: Value(r['description']),
            archived: Value(r['archived'] ?? false),
          ),
        );
      }
      for (final ri in routineItemsList) {
        await db.into(db.routineItems).insertOnConflictUpdate(
          RoutineItemsCompanion.insert(
            id: ri['id'],
            routineId: ri['routine_id'],
            exerciseId: ri['exercise_id'],
            position: ri['position'] ?? 0,
            targetSets: Value(ri['target_sets'] ?? 3),
            repMin: Value(ri['rep_min'] ?? 8),
            repMax: Value(ri['rep_max'] ?? 12),
            restSeconds: Value(ri['rest_seconds'] ?? 90),
          ),
        );
      }

      // 6. Settings Table
      // Retrieve current existing settings so we don't wipe active secrets with empty values
      final currentSettings = await db.select(db.settings).get();
      final existingMap = {for (final s in currentSettings) s.k: s.v};

      for (final entry in settingsMap.entries) {
        String val = entry.value.toString();
        // If restoring ai_profiles_json, merge existing API keys if the backup had redacted them
        if (entry.key == 'ai_profiles_json' && existingMap.containsKey('ai_profiles_json')) {
          try {
            final incomingList = jsonDecode(val) as List;
            final currentList = jsonDecode(existingMap['ai_profiles_json']!) as List;
            final currentKeyMap = <String, String>{};
            for (final c in currentList) {
              if (c is Map && c['id'] != null && c['apiKey'] != null && (c['apiKey'] as String).isNotEmpty) {
                currentKeyMap[c['id'].toString()] = c['apiKey'].toString();
              }
            }
            final mergedList = incomingList.map((item) {
              if (item is Map<String, dynamic>) {
                final copy = Map<String, dynamic>.from(item);
                if ((copy['apiKey'] == null || copy['apiKey'].toString().isEmpty) && currentKeyMap.containsKey(copy['id'])) {
                  copy['apiKey'] = currentKeyMap[copy['id']];
                }
                return copy;
              }
              return item;
            }).toList();
            val = jsonEncode(mergedList);
          } catch (_) {}
        }
        await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(k: entry.key, v: val),
        );
      }
      // 7. Body Metrics if present
      final bodyMetricsList = (data['body_metrics'] as List? ?? []);
      for (final b in bodyMetricsList) {
        await db.into(db.bodyMetrics).insertOnConflictUpdate(
          BodyMetricsCompanion.insert(
            id: b['id'],
            date: DateTime.parse(b['date']),
            metricType: b['metric_type'],
            value: (b['value'] as num).toDouble(),
            unit: b['unit'] ?? 'kg',
          ),
        );
      }

      // 8. Achievements if present
      final achievementsList = (data['achievements'] as List? ?? []);
      for (final a in achievementsList) {
        await db.into(db.achievements).insertOnConflictUpdate(
          AchievementsCompanion.insert(
            id: a['id'],
            code: a['code'],
            title: a['title'] ?? 'Achievement',
            description: a['description'] ?? '',
            unlockedAt: Value(a['unlocked_at'] != null ? DateTime.parse(a['unlocked_at']) : null),
            badgeIcon: a['badge_icon'] ?? 'emoji_events',
          ),
        );
      }

      // 9. Photos if present
      final photosList = (data['photos'] as List? ?? []);
      for (final p in photosList) {
        await db.into(db.photos).insertOnConflictUpdate(
          PhotosCompanion.insert(
            id: p['id'],
            date: DateTime.parse(p['date']),
            filePath: p['file_path'],
            thumbnailPath: Value(p['thumbnail_path']),
            pose: p['pose'] ?? 'front',
            note: Value(p['note']),
          ),
        );
      }

      // Ensure user is marked onboarded and initial restore checked
      await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(k: 'user_onboarded', v: 'true'),
      );
      await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(k: 'initial_backup_restore_checked', v: 'true'),
      );
    });

    return workoutsList.length;
  }

  /// Export backup file using SharePlus sheet (save to Files, Google Drive, WhatsApp, etc.)
  static Future<void> exportBackupFile(AppDatabase db) async {
    final jsonMap = await createBackupJson(db, stripSecrets: false);
    final jsonStr = jsonEncode(jsonMap);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ironlog_backup.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'IronLog Backup (${DateTime.now().toString().substring(0, 10)})',
      text: 'IronLog progress backup file. Keep this to restore your workout history anytime.',
    );
  }

  /// Pick any backup JSON file from phone storage and restore it
  static Future<int?> importBackupFile(AppDatabase db) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return await restoreFromJson(db, data);
    }
    return null;
  }
}
