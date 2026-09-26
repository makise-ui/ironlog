import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../models/ai_memory_model.dart';

final aiMemoryServiceProvider = Provider<AiMemoryService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return AiMemoryService(settingsRepo);
});

class AiMemoryService {
  final SettingsRepository _settingsRepo;
  static const String _storageKey = 'ai_user_memories';

  AiMemoryService(this._settingsRepo);

  /// Load all long-term memories from persistent storage
  Future<List<AiUserMemory>> getMemories() async {
    try {
      final raw = await _settingsRepo.getSetting(_storageKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => AiUserMemory.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback on corrupt or empty storage
    }
    return [];
  }

  /// Save or update a memory fact
  Future<AiUserMemory> saveMemory({
    required String fact,
    String? category,
  }) async {
    final cleanFact = fact.trim();
    if (cleanFact.isEmpty) {
      throw ArgumentError('Memory fact cannot be empty');
    }

    final cat = (category != null && category.trim().isNotEmpty)
        ? category.trim().toLowerCase()
        : _inferCategory(cleanFact);

    final memories = await getMemories();
    final now = DateTime.now();

    // Check for existing similar memory to update instead of duplicate
    final existingIdx = memories.indexWhere(
      (m) => m.fact.toLowerCase() == cleanFact.toLowerCase() ||
          _isDuplicate(m.fact, cleanFact),
    );

    final AiUserMemory savedMemory;
    if (existingIdx != -1) {
      final existing = memories[existingIdx];
      savedMemory = existing.copyWith(
        fact: cleanFact,
        category: cat,
        updatedAt: now,
      );
      memories[existingIdx] = savedMemory;
    } else {
      savedMemory = AiUserMemory(
        id: 'mem_${now.millisecondsSinceEpoch}',
        fact: cleanFact,
        category: cat,
        createdAt: now,
        updatedAt: now,
      );
      memories.add(savedMemory);
    }

    // Persist to SQLite settings
    final serialized = jsonEncode(memories.map((m) => m.toMap()).toList());
    await _settingsRepo.setSetting(_storageKey, serialized);

    return savedMemory;
  }

  /// Delete a memory by its ID
  Future<bool> deleteMemory(String id) async {
    final memories = await getMemories();
    final initialLen = memories.length;
    memories.removeWhere((m) => m.id == id);

    if (memories.length != initialLen) {
      final serialized = jsonEncode(memories.map((m) => m.toMap()).toList());
      await _settingsRepo.setSetting(_storageKey, serialized);
      return true;
    }
    return false;
  }

  /// Delete memory matching a query or phrase
  Future<int> deleteMatching(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return 0;

    final memories = await getMemories();
    final initialLen = memories.length;
    memories.removeWhere((m) =>
        m.fact.toLowerCase().contains(clean) || m.id.toLowerCase() == clean);

    final removedCount = initialLen - memories.length;
    if (removedCount > 0) {
      final serialized = jsonEncode(memories.map((m) => m.toMap()).toList());
      await _settingsRepo.setSetting(_storageKey, serialized);
    }
    return removedCount;
  }

  /// Clear all stored memories
  Future<void> clearAllMemories() async {
    await _settingsRepo.setSetting(_storageKey, '[]');
  }

  /// Formats all memories into a concise prompt block for the AI system message
  Future<String> formatMemoriesPrompt() async {
    final memories = await getMemories();
    if (memories.isEmpty) {
      return '(No persistent memories stored yet)';
    }

    final buffer = StringBuffer();
    for (final mem in memories) {
      buffer.writeln('- [ID: ${mem.id}] ${mem.fact} (Category: ${mem.category})');
    }
    return buffer.toString().trimRight();
  }

  String _inferCategory(String fact) {
    final lower = fact.toLowerCase();
    if (lower.contains('pain') ||
        lower.contains('injur') ||
        lower.contains('hurts') ||
        lower.contains('impingement') ||
        lower.contains('tear') ||
        lower.contains('rehab') ||
        lower.contains('sprain') ||
        lower.contains('hernia') ||
        lower.contains('surgery')) {
      return 'injury';
    }
    if (lower.contains('goal') ||
        lower.contains('aim') ||
        lower.contains('target') ||
        lower.contains('pr ') ||
        lower.contains('cut') ||
        lower.contains('bulk') ||
        lower.contains('hypertrophy')) {
      return 'goal';
    }
    if (lower.contains('dumbbell') ||
        lower.contains('barbell') ||
        lower.contains('home gym') ||
        lower.contains('bench') ||
        lower.contains('cable') ||
        lower.contains('rack') ||
        lower.contains('bands') ||
        lower.contains('machine')) {
      return 'equipment';
    }
    if (lower.contains('prefer') ||
        lower.contains('favorite') ||
        lower.contains('like ') ||
        lower.contains('love ') ||
        lower.contains('hate ') ||
        lower.contains('avoid ')) {
      return 'preference';
    }
    if (lower.contains('morning') ||
        lower.contains('evening') ||
        lower.contains('day split') ||
        lower.contains('days a week') ||
        lower.contains('minute')) {
      return 'schedule';
    }
    return 'general';
  }

  bool _isDuplicate(String a, String b) {
    final cleanA = a.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final cleanB = b.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanA == cleanB) return true;
    if (cleanA.contains(cleanB) || cleanB.contains(cleanA)) {
      final diff = (cleanA.length - cleanB.length).abs();
      return diff < 6;
    }
    return false;
  }
}
