import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/providers.dart';
import 'package:ironlog/domain/models/ai_chat_message.dart';
import 'package:ironlog/domain/services/ai_chat_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AiChatNotifier & AiChatState tests', () {
    test('Initial state has expected defaults', () {
      const state = AiChatState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
      expect(state.activeThought, isNull);
      expect(state.latestAssistantSnippet, isNull);
      expect(state.showFloatingCloud, false);
      expect(state.isInitialized, false);
    });

    test('dismissCloud and onOpenChat toggle floating cloud visibility', () async {
      final db = AppDatabase.memory();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final notifier = container.read(aiChatNotifierProvider.notifier);

      // Manually set showFloatingCloud to true
      notifier.state = notifier.state.copyWith(
        showFloatingCloud: true,
        latestAssistantSnippet: 'Test preview',
      );
      expect(container.read(aiChatNotifierProvider).showFloatingCloud, true);

      notifier.dismissCloud();
      expect(container.read(aiChatNotifierProvider).showFloatingCloud, false);

      notifier.state = notifier.state.copyWith(showFloatingCloud: true);
      expect(container.read(aiChatNotifierProvider).showFloatingCloud, true);

      notifier.onOpenChat();
      expect(container.read(aiChatNotifierProvider).showFloatingCloud, false);
    });

    test('copyWith updates state properties correctly', () {
      const state = AiChatState();
      final updated = state.copyWith(
        isLoading: true,
        activeThought: 'Thinking...',
        latestAssistantSnippet: 'Done',
        showFloatingCloud: true,
        messages: [
          AiChatMessage(
            id: '1',
            role: 'user',
            content: 'Hello',
            timestamp: DateTime(2026, 9, 23),
          ),
        ],
      );

      expect(updated.isLoading, true);
      expect(updated.activeThought, 'Thinking...');
      expect(updated.latestAssistantSnippet, 'Done');
      expect(updated.showFloatingCloud, true);
      expect(updated.messages.length, 1);

      final cleared = updated.copyWith(
        clearActiveThought: true,
        clearSnippet: true,
      );
      expect(cleared.activeThought, isNull);
      expect(cleared.latestAssistantSnippet, isNull);
    });
  });
}
