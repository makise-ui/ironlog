import 'dart:convert';
import 'package:flutter/services.dart';

class ExerciseInstructionsService {
  ExerciseInstructionsService._();

  static Map<String, List<String>>? _cache;
  static bool _isLoading = false;

  /// Loads instruction steps mapping from assets
  static Future<void> init() async {
    if (_cache != null || _isLoading) return;
    _isLoading = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/exercises/exercise_instructions.json');
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        _cache = decoded.map((k, v) => MapEntry(k.toLowerCase(), List<String>.from(v ?? [])));
      }
    } catch (_) {
      _cache = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Looks up step-by-step form execution instructions for an exercise
  static List<String>? getInstructions(String exerciseName) {
    if (_cache == null || _cache!.isEmpty) return null;

    final lower = exerciseName.toLowerCase().trim();

    // 1. Direct match
    if (_cache!.containsKey(lower) && _cache![lower]!.isNotEmpty) {
      return _cache![lower];
    }

    // 2. Normalized match (strip equipment brackets)
    final clean = lower
        .replaceAll(RegExp(r'\s*\((?:barbell|dumbbell|cable|machine|smith machine|bodyweight|pulley)\)', caseSensitive: false), '')
        .trim();
    if (_cache!.containsKey(clean) && _cache![clean]!.isNotEmpty) {
      return _cache![clean];
    }

    // 3. Substring match
    for (final entry in _cache!.entries) {
      if (entry.key.contains(clean) || clean.contains(entry.key)) {
        if (entry.value.isNotEmpty) return entry.value;
      }
    }

    return null;
  }
}
