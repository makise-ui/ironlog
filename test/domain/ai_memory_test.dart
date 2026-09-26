import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/settings_repository.dart';
import 'package:ironlog/domain/services/ai_memory_service.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settingsRepo;
  late AiMemoryService memoryService;

  setUp(() {
    db = AppDatabase.memory();
    settingsRepo = SettingsRepository(db);
    memoryService = AiMemoryService(settingsRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('AiMemoryService Tests', () {
    test('starts with empty memories', () async {
      final memories = await memoryService.getMemories();
      expect(memories, isEmpty);

      final prompt = await memoryService.formatMemoriesPrompt();
      expect(prompt, contains('(No persistent memories stored yet)'));
    });

    test('saves and categorizes user memories', () async {
      final mem1 = await memoryService.saveMemory(
        fact: 'Left rotator cuff impingement. Needs warm-up before bench.',
      );
      expect(mem1.category, 'injury');

      final mem2 = await memoryService.saveMemory(
        fact: 'Home gym with adjustable dumbbells up to 32kg',
      );
      expect(mem2.category, 'equipment');

      final mem3 = await memoryService.saveMemory(
        fact: 'Targeting 100kg Bench Press 1RM by December',
      );
      expect(mem3.category, 'goal');

      final all = await memoryService.getMemories();
      expect(all.length, 3);

      final prompt = await memoryService.formatMemoriesPrompt();
      expect(prompt, contains('rotator cuff impingement'));
      expect(prompt, contains('32kg'));
      expect(prompt, contains('100kg Bench Press'));
    });

    test('updates existing memory on duplicate fact instead of duplicating', () async {
      await memoryService.saveMemory(
        fact: 'User prefers 4-day Upper/Lower split',
      );
      await memoryService.saveMemory(
        fact: 'User prefers 4-day Upper/Lower split.',
      );

      final all = await memoryService.getMemories();
      expect(all.length, 1);
    });

    test('deletes memory by ID', () async {
      final mem = await memoryService.saveMemory(
        fact: 'Trained early in the morning',
      );
      expect(await memoryService.getMemories(), hasLength(1));

      final deleted = await memoryService.deleteMemory(mem.id);
      expect(deleted, isTrue);
      expect(await memoryService.getMemories(), isEmpty);
    });

    test('deletes memory by matching query', () async {
      await memoryService.saveMemory(fact: 'Lower back stiffness on heavy deadlifts');
      await memoryService.saveMemory(fact: 'Prefers incline dumbbell bench');

      final removed = await memoryService.deleteMatching('deadlift');
      expect(removed, 1);

      final remaining = await memoryService.getMemories();
      expect(remaining.length, 1);
      expect(remaining.first.fact, contains('incline dumbbell'));
    });

    test('clears all memories', () async {
      await memoryService.saveMemory(fact: 'Fact 1');
      await memoryService.saveMemory(fact: 'Fact 2');
      expect(await memoryService.getMemories(), hasLength(2));

      await memoryService.clearAllMemories();
      expect(await memoryService.getMemories(), isEmpty);
    });
  });
}
