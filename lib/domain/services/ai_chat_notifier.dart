import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_chat_message.dart';
import 'ai_assistant_service.dart';
import 'app_notification_service.dart';
import '../../data/providers.dart';

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? activeThought;
  final String? latestAssistantSnippet;
  final bool showFloatingCloud;
  final bool isInitialized;
  final String? currentSessionId;
  final List<AiChatSession> sessions;
  final bool isLoadingSessions;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.activeThought,
    this.latestAssistantSnippet,
    this.showFloatingCloud = false,
    this.isInitialized = false,
    this.currentSessionId,
    this.sessions = const [],
    this.isLoadingSessions = false,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? activeThought,
    bool clearActiveThought = false,
    String? latestAssistantSnippet,
    bool clearSnippet = false,
    bool? showFloatingCloud,
    bool? isInitialized,
    String? currentSessionId,
    List<AiChatSession>? sessions,
    bool? isLoadingSessions,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      activeThought: clearActiveThought ? null : (activeThought ?? this.activeThought),
      latestAssistantSnippet: clearSnippet ? null : (latestAssistantSnippet ?? this.latestAssistantSnippet),
      showFloatingCloud: showFloatingCloud ?? this.showFloatingCloud,
      isInitialized: isInitialized ?? this.isInitialized,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      sessions: sessions ?? this.sessions,
      isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
    );
  }
}

final aiChatNotifierProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final notifier = AiChatNotifier(ref);
  notifier.init();
  return notifier;
});

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(const AiChatState());

  Future<void> init() async {
    if (state.isInitialized) return;
    try {
      final aiService = _ref.read(aiAssistantServiceProvider);

      // Load sessions index
      final sessions = await aiService.loadAllSessions();
      if (!mounted) return;

      // Try the legacy single-session history first (migrate it)
      final legacyHistory = await aiService.loadChatHistory();
      if (!mounted) return;

      if (legacyHistory.isNotEmpty) {
        // Migrate legacy history into a session
        final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        await aiService.saveSession(sessionId, legacyHistory);
        if (!mounted) return;
        await aiService.clearChatHistory(); // remove legacy key
        if (!mounted) return;
        final updatedSessions = await aiService.loadAllSessions();
        if (!mounted) return;
        final lastAsst = legacyHistory.reversed.where((m) => m.role == 'assistant' && !m.isError).firstOrNull;
        state = state.copyWith(
          messages: legacyHistory,
          latestAssistantSnippet: lastAsst != null ? _extractSnippet(lastAsst.content) : null,
          isInitialized: true,
          currentSessionId: sessionId,
          sessions: updatedSessions,
        );
      } else if (sessions.isNotEmpty) {
        // Load most recent session
        final latest = sessions.first;
        final msgs = await aiService.loadSession(latest.id);
        if (!mounted) return;
        final lastAsst = msgs.reversed.where((m) => m.role == 'assistant' && !m.isError).firstOrNull;
        state = state.copyWith(
          messages: msgs.isNotEmpty ? msgs : state.messages,
          latestAssistantSnippet: lastAsst != null ? _extractSnippet(lastAsst.content) : null,
          isInitialized: true,
          currentSessionId: latest.id,
          sessions: sessions,
        );
      } else {
        // Brand new — create first session
        final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        final proactiveGreeting = await aiService.generateProactiveCoachGreeting();
        if (!mounted) return;
        final initialMsg = AiChatMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: proactiveGreeting,
          timestamp: DateTime.now(),
        );
        await aiService.saveSession(sessionId, [initialMsg]);
        if (!mounted) return;
        final updatedSessions = await aiService.loadAllSessions();
        if (!mounted) return;
        state = state.copyWith(
          messages: [initialMsg],
          latestAssistantSnippet: _extractSnippet(proactiveGreeting),
          isInitialized: true,
          currentSessionId: sessionId,
          sessions: updatedSessions,
        );
      }
    } catch (e) {
      debugPrint('Error initializing AiChatNotifier: $e');
      if (mounted) {
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  void dismissCloud() {
    state = state.copyWith(showFloatingCloud: false);
  }

  void onOpenChat() {
    state = state.copyWith(showFloatingCloud: false);
  }

  /// Save current session then start a brand-new empty one
  Future<void> startNewSession() async {
    final aiService = _ref.read(aiAssistantServiceProvider);
    // Save current session first
    if (state.currentSessionId != null && state.messages.isNotEmpty) {
      await aiService.saveSession(state.currentSessionId!, state.messages);
    }
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final proactiveGreeting = await aiService.generateProactiveCoachGreeting();
    final initialMsg = AiChatMessage(
      id: 'init_${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      content: proactiveGreeting,
      timestamp: DateTime.now(),
    );
    await aiService.saveSession(sessionId, [initialMsg]);
    final updatedSessions = await aiService.loadAllSessions();
    state = state.copyWith(
      messages: [initialMsg],
      currentSessionId: sessionId,
      sessions: updatedSessions,
      isLoading: false,
      clearActiveThought: true,
      clearSnippet: true,
      showFloatingCloud: false,
    );
  }

  /// Switch to a previously saved session
  Future<void> switchToSession(String sessionId) async {
    if (sessionId == state.currentSessionId) return;
    final aiService = _ref.read(aiAssistantServiceProvider);
    // Save current session
    if (state.currentSessionId != null && state.messages.isNotEmpty) {
      await aiService.saveSession(state.currentSessionId!, state.messages);
    }
    final msgs = await aiService.loadSession(sessionId);
    final lastAsst = msgs.reversed.where((m) => m.role == 'assistant' && !m.isError).firstOrNull;
    state = state.copyWith(
      messages: msgs,
      currentSessionId: sessionId,
      latestAssistantSnippet: lastAsst != null ? _extractSnippet(lastAsst.content) : null,
      isLoading: false,
      clearActiveThought: true,
      showFloatingCloud: false,
    );
  }

  /// Delete a session; if it was the current one, start fresh
  Future<void> deleteSession(String sessionId) async {
    // Immediately remove from state.sessions so Dismissible doesn't crash on rebuild
    state = state.copyWith(
      sessions: state.sessions.where((s) => s.id != sessionId).toList(),
    );
    final aiService = _ref.read(aiAssistantServiceProvider);
    await aiService.deleteSession(sessionId);
    final updatedSessions = await aiService.loadAllSessions();
    if (sessionId == state.currentSessionId) {
      // Switch to the next available session or create new
      if (updatedSessions.isNotEmpty) {
        final msgs = await aiService.loadSession(updatedSessions.first.id);
        state = state.copyWith(
          messages: msgs,
          currentSessionId: updatedSessions.first.id,
          sessions: updatedSessions,
          clearActiveThought: true,
          showFloatingCloud: false,
        );
      } else {
        state = state.copyWith(sessions: updatedSessions);
        await startNewSession();
      }
    } else {
      state = state.copyWith(sessions: updatedSessions);
    }
  }

  /// Refresh the sessions list (called when sidebar opens)
  Future<void> loadAllSessions() async {
    state = state.copyWith(isLoadingSessions: true);
    try {
      final aiService = _ref.read(aiAssistantServiceProvider);
      // Save current session first to make sure index is up to date
      if (state.currentSessionId != null && state.messages.isNotEmpty) {
        await aiService.saveSession(state.currentSessionId!, state.messages);
      }
      final sessions = await aiService.loadAllSessions();
      state = state.copyWith(sessions: sessions, isLoadingSessions: false);
    } catch (e) {
      state = state.copyWith(isLoadingSessions: false);
    }
  }

  Future<void> clearHistory() async {
    // clearHistory now just starts a new session (legacy compat)
    await startNewSession();
  }

  Future<void> handleConfirmDeleteWorkout(AiChatMessage msg, AiToolExecutionResult tr) async {
    final workoutId = tr.data?['workoutId']?.toString();
    if (workoutId == null) return;

    final toolService = _ref.read(aiAssistantServiceProvider).toolService;
    final confirmResult = await toolService.executeTool(
      AiToolCall(
        id: 'confirm_del_${DateTime.now().millisecondsSinceEpoch}',
        name: 'delete_workout',
        arguments: {'workoutId': workoutId, 'confirmed': true},
      ),
    );

    final msgs = List<AiChatMessage>.from(state.messages);
    final msgIdx = msgs.indexWhere((m) => m.id == msg.id);
    if (msgIdx != -1) {
      final list = List<AiToolExecutionResult>.from(msgs[msgIdx].toolResults ?? []);
      final trIdx = list.indexWhere((r) => r.toolName == tr.toolName && r.durationMs == tr.durationMs);
      if (trIdx != -1) {
        list[trIdx] = confirmResult;
      } else {
        list.add(confirmResult);
      }
      msgs[msgIdx] = msgs[msgIdx].copyWith(toolResults: list);
      state = state.copyWith(messages: msgs);
      _ref.invalidate(streakAndWeekProvider);
      _ref.read(isWorkoutActiveProvider.notifier).state = false;
      await _ref.read(aiAssistantServiceProvider).saveSession(state.currentSessionId ?? 'session_default', msgs);
    }
  }

  void handleCancelDeleteWorkout(AiChatMessage msg, AiToolExecutionResult tr) {
    final msgs = List<AiChatMessage>.from(state.messages);
    final msgIdx = msgs.indexWhere((m) => m.id == msg.id);
    if (msgIdx != -1) {
      final list = List<AiToolExecutionResult>.from(msgs[msgIdx].toolResults ?? []);
      final trIdx = list.indexWhere((r) => r.toolName == tr.toolName && r.durationMs == tr.durationMs);
      final cancelResult = AiToolExecutionResult(
        toolName: 'delete_workout',
        success: false,
        summary: 'Workout deletion cancelled.',
        data: {'status': 'cancelled'},
      );
      if (trIdx != -1) {
        list[trIdx] = cancelResult;
      } else {
        list.add(cancelResult);
      }
      msgs[msgIdx] = msgs[msgIdx].copyWith(toolResults: list);
      state = state.copyWith(messages: msgs);
      _ref.read(aiAssistantServiceProvider).saveSession(state.currentSessionId ?? 'session_default', msgs);
    }
  }

  Future<void> handleAnswerQuestion(AiChatMessage msg, AiToolExecutionResult tr, String chosenOption) async {
    final msgs = List<AiChatMessage>.from(state.messages);
    final msgIdx = msgs.indexWhere((m) => m.id == msg.id);
    if (msgIdx != -1) {
      final list = List<AiToolExecutionResult>.from(msgs[msgIdx].toolResults ?? []);
      final trIdx = list.indexWhere((r) => r.toolName == tr.toolName && r.durationMs == tr.durationMs);
      final oldData = Map<String, dynamic>.from(tr.data is Map ? tr.data as Map : {});
      oldData['selectedOption'] = chosenOption;
      oldData['status'] = 'answered';
      final updatedTr = AiToolExecutionResult(
        toolName: tr.toolName,
        success: true,
        summary: 'Answered: $chosenOption',
        data: oldData,
        durationMs: tr.durationMs,
      );
      if (trIdx != -1) {
        list[trIdx] = updatedTr;
      } else {
        list.add(updatedTr);
      }
      msgs[msgIdx] = msgs[msgIdx].copyWith(toolResults: list);
      state = state.copyWith(messages: msgs);
      await _ref.read(aiAssistantServiceProvider).saveSession(state.currentSessionId ?? 'session_default', msgs);
    }
    // Automatically submit reply
    await sendMessage(chosenOption);
  }

  Future<void> sendMessage(String text, {String? imagePath}) async {
    final promptText = text.trim().isEmpty ? 'Analyze this workout / physique photo' : text.trim();

    final userMsg = AiChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: promptText,
      timestamp: DateTime.now(),
      imageAttachmentPath: imagePath,
    );

    final assistantMsgId = 'asst_${DateTime.now().millisecondsSinceEpoch}';
    final initialAssistantMsg = AiChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      liveThinking: 'Analyzing request...',
    );

    final updatedMessages = List<AiChatMessage>.from(state.messages)
      ..add(userMsg)
      ..add(initialAssistantMsg);

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      activeThought: 'Analyzing request...',
      latestAssistantSnippet: 'Analyzing request...',
      showFloatingCloud: true,
    );

    try {
      AppNotificationService.instance.showAiRunningNotification(prompt: promptText);
      final aiService = _ref.read(aiAssistantServiceProvider);
      final stream = aiService.sendMessageStream(
        history: updatedMessages.where((m) => m.id != assistantMsgId).toList(),
        userPrompt: promptText,
        imagePath: imagePath,
      );

      final currentToolResults = <AiToolExecutionResult>[];
      final currentToolCalls = <AiToolCall>[];
      final currentThoughtSteps = <String>[];

      await for (final event in stream) {
        if (event is AiThinkingEvent) {
          final thought = event.status;
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          if (idx != -1) {
            final msgs = List<AiChatMessage>.from(state.messages);
            msgs[idx] = msgs[idx].copyWith(liveThinking: thought);
            state = state.copyWith(
              messages: msgs,
              activeThought: thought,
              latestAssistantSnippet: thought,
            );
          }
        } else if (event is AiToolExecutingEvent) {
          final call = AiToolCall(
            id: 'call_${DateTime.now().millisecondsSinceEpoch}',
            name: event.toolName,
            arguments: event.arguments,
          );
          currentToolCalls.add(call);
          final activeThought = _formatToolThought(event.toolName, event.arguments, isExecuting: true);
          currentThoughtSteps.add(activeThought);
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          if (idx != -1) {
            final msgs = List<AiChatMessage>.from(state.messages);
            msgs[idx] = msgs[idx].copyWith(
              liveToolStatus: activeThought,
              toolCalls: List.from(currentToolCalls),
              thoughtSteps: List.from(currentThoughtSteps),
            );
            state = state.copyWith(
              messages: msgs,
              activeThought: activeThought,
              latestAssistantSnippet: activeThought,
            );
          }
        } else if (event is AiToolCompletedEvent) {
          currentToolResults.add(event.result);
          final completedThought = _formatToolThought(
            event.result.toolName,
            (event.result.data is Map ? Map<String, dynamic>.from(event.result.data as Map) : {}),
            isExecuting: false,
          );
          if (currentThoughtSteps.isNotEmpty) {
            currentThoughtSteps[currentThoughtSteps.length - 1] = completedThought;
          } else {
            currentThoughtSteps.add(completedThought);
          }
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          if (idx != -1) {
            final msgs = List<AiChatMessage>.from(state.messages);
            msgs[idx] = msgs[idx].copyWith(
              toolResults: List.from(currentToolResults),
              thoughtSteps: List.from(currentThoughtSteps),
              liveToolStatus: null,
            );
            state = state.copyWith(
              messages: msgs,
              activeThought: completedThought,
              latestAssistantSnippet: completedThought,
            );
          }
        } else if (event is AiStreamChunkEvent) {
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          if (idx != -1) {
            final msgs = List<AiChatMessage>.from(state.messages);
            msgs[idx] = msgs[idx].copyWith(
              content: event.accumulatedText,
              isStreaming: true,
            );
            state = state.copyWith(
              messages: msgs,
              latestAssistantSnippet: _extractSnippet(event.accumulatedText),
            );
          }
        } else if (event is AiCompleteEvent) {
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          final msgs = List<AiChatMessage>.from(state.messages);
          if (idx != -1) {
            msgs[idx] = event.message.copyWith(
              isStreaming: false,
              liveThinking: null,
              liveToolStatus: null,
              thoughtSteps: List.from(currentThoughtSteps),
            );
          }
          final snippet = _extractSnippet(event.message.content);
          state = state.copyWith(
            messages: msgs,
            isLoading: false,
            clearActiveThought: true,
            latestAssistantSnippet: snippet,
            showFloatingCloud: true,
          );
          await aiService.saveSession(state.currentSessionId ?? 'session_default', msgs);
          AppNotificationService.instance.showAiCompletedNotification(
            prompt: promptText,
            snippet: snippet,
          );
        } else if (event is AiErrorEvent) {
          final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
          final msgs = List<AiChatMessage>.from(state.messages);
          if (idx != -1) {
            msgs[idx] = AiChatMessage(
              id: assistantMsgId,
              role: 'assistant',
              content: 'Issue encountered: ${event.error}',
              timestamp: DateTime.now(),
              isError: true,
              isStreaming: false,
            );
          }
          state = state.copyWith(
            messages: msgs,
            isLoading: false,
            clearActiveThought: true,
            latestAssistantSnippet: 'Issue encountered. Tap to view.',
            showFloatingCloud: true,
          );
          await aiService.saveSession(state.currentSessionId ?? 'session_default', msgs);
          AppNotificationService.instance.showAiCompletedNotification(
            prompt: promptText,
            snippet: 'Issue encountered: ${event.error}',
          );
        }
      }
    } catch (e) {
      final idx = state.messages.indexWhere((m) => m.id == assistantMsgId);
      final msgs = List<AiChatMessage>.from(state.messages);
      if (idx != -1) {
        msgs[idx] = AiChatMessage(
          id: assistantMsgId,
          role: 'assistant',
          content: 'Sorry, I encountered an issue: $e',
          timestamp: DateTime.now(),
          isError: true,
          isStreaming: false,
        );
      }
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        clearActiveThought: true,
        latestAssistantSnippet: 'Issue encountered. Tap to view.',
        showFloatingCloud: true,
      );
      await _ref.read(aiAssistantServiceProvider).saveSession(state.currentSessionId ?? 'session_default', msgs);
      AppNotificationService.instance.showAiCompletedNotification(
        prompt: promptText,
        snippet: 'Issue encountered: $e',
      );
    }
  }

  static String _extractSnippet(String text) {
    if (text.trim().isEmpty) return '';
    // Strip markdown formatting, headers, bullets, asterisks
    var clean = text
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*|\*|__|_|`'), '')
        .replaceAll(RegExp(r'^[•\-\*]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    if (clean.length > 70) {
      return '${clean.substring(0, 67)}...';
    }
    return clean;
  }

  static String _formatToolThought(String toolName, Map<String, dynamic> arguments, {bool isExecuting = true}) {
    final exName = arguments['exerciseName']?.toString();
    final weight = arguments['weight'];
    final reps = arguments['reps'];
    final title = arguments['title']?.toString();
    final routineName = arguments['routineName']?.toString();
    final query = arguments['query']?.toString();
    final seconds = arguments['seconds'];
    final date = arguments['date']?.toString();

    if (isExecuting) {
      switch (toolName) {
        case 'query_prs_and_history':
          return exName != null && exName.isNotEmpty
              ? 'Getting PRs & history for $exName...'
              : 'Getting exercise records & PRs...';
        case 'log_set':
          if (exName != null && weight != null && reps != null) {
            return 'Logging $exName ${weight}kg × $reps${date != null ? " ($date)" : ""}...';
          }
          return 'Logging set...';
        case 'create_custom_exercise':
          final name = arguments['name']?.toString() ?? 'exercise';
          return 'Creating custom exercise: $name...';
        case 'set_rest_day':
          return 'Setting rest day${date != null ? " for $date" : ""}...';
        case 'start_workout':
          return title != null && title.isNotEmpty
              ? 'Starting $title session...'
              : 'Starting workout session...';
        case 'finish_workout':
          return 'Saving workout...';
        case 'add_exercise':
          return exName != null ? 'Adding $exName to session...' : 'Adding exercise...';
        case 'edit_set':
          return exName != null ? 'Updating set for $exName...' : 'Updating set...';
        case 'delete_set':
          return 'Removing set...';
        case 'remove_exercise':
          return exName != null ? 'Removing $exName from session...' : 'Removing exercise...';
        case 'edit_workout':
          return 'Updating workout details...';
        case 'delete_workout':
          return 'Deleting workout...';
        case 'create_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Creating routine: $routineName...'
              : 'Creating routine preset...';
        case 'edit_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Updating routine: $routineName...'
              : 'Updating routine...';
        case 'delete_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Deleting routine: $routineName...'
              : 'Deleting routine...';
        case 'edit_exercise':
          return exName != null ? 'Updating catalog exercise $exName...' : 'Updating exercise...';
        case 'edit_setting':
          return 'Updating preference...';
        case 'start_rest_timer':
          return seconds != null ? 'Starting ${seconds}s rest timer...' : 'Starting rest timer...';
        case 'recommend_weights':
          return exName != null ? 'Calculating weights for $exName...' : 'Calculating weights...';
        case 'search_web':
          return query != null && query.isNotEmpty ? 'Searching "$query"...' : 'Searching exercise science...';
        case 'ask_user_question':
          return 'Asking question...';
        default:
          return 'Running $toolName...';
      }
    } else {
      switch (toolName) {
        case 'query_prs_and_history':
          return exName != null && exName.isNotEmpty
              ? 'Loaded records for $exName'
              : 'Loaded records & PR history';
        case 'log_set':
          if (exName != null && weight != null && reps != null) {
            return 'Logged $exName ${weight}kg × $reps';
          }
          return 'Set logged';
        case 'create_custom_exercise':
          final name = arguments['name']?.toString() ?? 'exercise';
          return 'Created custom exercise $name';
        case 'set_rest_day':
          return 'Rest day saved';
        case 'start_workout':
          return title != null && title.isNotEmpty ? 'Started $title' : 'Workout started';
        case 'finish_workout':
          return 'Workout saved & celebrated';
        case 'add_exercise':
          return exName != null ? 'Added $exName to workout' : 'Exercise added';
        case 'edit_set':
          return 'Set updated';
        case 'delete_set':
          return 'Set removed';
        case 'remove_exercise':
          return exName != null ? '$exName removed' : 'Exercise removed';
        case 'edit_workout':
          return 'Workout updated';
        case 'delete_workout':
          return 'Workout deleted';
        case 'create_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Routine "$routineName" saved'
              : 'Routine saved';
        case 'edit_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Routine "$routineName" updated'
              : 'Routine updated';
        case 'delete_routine':
          return routineName != null && routineName.isNotEmpty
              ? 'Routine "$routineName" deleted'
              : 'Routine deleted';
        case 'edit_exercise':
          return 'Exercise updated in catalog';
        case 'edit_setting':
          return 'Setting saved';
        case 'start_rest_timer':
          return seconds != null ? 'Started ${seconds}s timer' : 'Timer started';
        case 'recommend_weights':
          return 'Weight recommendations computed';
        case 'search_web':
          return 'Web research complete';
        case 'ask_user_question':
          return 'Question presented';
        default:
          return '$toolName finished';
      }
    }
  }
}
