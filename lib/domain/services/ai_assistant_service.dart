import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/providers.dart';
import '../models/ai_config_model.dart';
import '../models/ai_chat_message.dart';
import '../models/chibi_avatar_model.dart';
import 'ai_tool_service.dart';

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return AiAssistantService(ref);
});

class AiAssistantService {
  final Ref _ref;
  late final AiToolService _toolService;

  AiAssistantService(this._ref) {
    _toolService = AiToolService(_ref);
  }

  AiToolService get toolService => _toolService;

  /// Load list of all AI profiles
  Future<List<AiConfigModel>> getProfiles() async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final jsonStr = await settingsRepo.getSetting('ai_profiles_json');
    if (jsonStr != null && jsonStr.trim().isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List;
        final profiles = list
            .map((item) => AiConfigModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (profiles.isNotEmpty) {
          // Merge any newly introduced default profiles (e.g. Agnes, Claude 3.7, Groq, DeepSeek)
          final existingIds = profiles.map((p) => p.id).toSet();
          bool updated = false;
          for (final def in AiConfigModel.defaultProfiles) {
            if (!existingIds.contains(def.id)) {
              profiles.add(def);
              updated = true;
            }
          }
          if (updated) {
            await saveProfiles(profiles);
          }
          return profiles;
        }
      } catch (_) {}
    }
    // Default seed profiles
    final defaults = AiConfigModel.defaultProfiles;
    await saveProfiles(defaults, activeProfileId: defaults.first.id);
    return defaults;
  }

  /// Save profiles and optionally update active profile
  Future<void> saveProfiles(List<AiConfigModel> profiles, {String? activeProfileId}) async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final jsonList = profiles.map((p) => p.toMap()).toList();
    await settingsRepo.setSetting('ai_profiles_json', jsonEncode(jsonList));

    if (activeProfileId != null) {
      await settingsRepo.setSetting('ai_active_profile_id', activeProfileId);
      final active = profiles.firstWhere((p) => p.id == activeProfileId, orElse: () => profiles.first);
      await settingsRepo.setSetting('ai_config_json', active.toJson());
    }
  }

  /// Get active profile ID
  Future<String> getActiveProfileId() async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final id = await settingsRepo.getSetting('ai_active_profile_id');
    if (id != null && id.isNotEmpty) return id;
    return 'kilo_free';
  }

  /// Set active profile by ID
  Future<void> setActiveProfile(String profileId) async {
    final profiles = await getProfiles();
    final active = profiles.firstWhere((p) => p.id == profileId, orElse: () => profiles.first);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    await settingsRepo.setSetting('ai_active_profile_id', active.id);
    await settingsRepo.setSetting('ai_config_json', active.toJson());
  }

  /// Delete a profile by ID
  Future<void> deleteProfile(String profileId) async {
    final profiles = await getProfiles();
    if (profiles.length <= 1) return; // Always keep at least 1 profile
    profiles.removeWhere((p) => p.id == profileId);
    final activeId = await getActiveProfileId();
    final newActiveId = (activeId == profileId) ? profiles.first.id : activeId;
    await saveProfiles(profiles, activeProfileId: newActiveId);
  }

  /// Load current active AI configuration
  Future<AiConfigModel> getConfig() async {
    final activeId = await getActiveProfileId();
    final profiles = await getProfiles();
    final active = profiles.firstWhere((p) => p.id == activeId, orElse: () => profiles.first);
    return active;
  }

  /// Save updated AI configuration (syncs active profile)
  Future<void> saveConfig(AiConfigModel config) async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    await settingsRepo.setSetting('ai_config_json', config.toJson());
    await settingsRepo.setSetting('ai_active_profile_id', config.id);

    final profiles = await getProfiles();
    final idx = profiles.indexWhere((p) => p.id == config.id);
    if (idx != -1) {
      profiles[idx] = config;
    } else {
      profiles.add(config);
    }
    await saveProfiles(profiles, activeProfileId: config.id);
  }

  /// Load persisted AI chat history
  Future<List<AiChatMessage>> loadChatHistory() async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      final jsonStr = await settingsRepo.getSetting('ai_chat_history_json');
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        return list
            .map((item) => AiChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
    return [];
  }

  /// Persist AI chat history (stores up to 60 most recent messages)
  Future<void> saveChatHistory(List<AiChatMessage> messages) async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      final recent = messages.length > 60 ? messages.sublist(messages.length - 60) : messages;
      final jsonList = recent.map((m) => m.toMap()).toList();
      await settingsRepo.setSetting('ai_chat_history_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  /// Clear persisted AI chat history
  Future<void> clearChatHistory() async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      await settingsRepo.setSetting('ai_chat_history_json', '');
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  // ─────────────────── Multi-session support ───────────────────

  static const _sessionIndexKey = 'ai_sessions_index_json';
  static const _maxSessions = 50;

  String _sessionKey(String id) => 'ai_session_${id}_json';

  /// Load the list of all saved sessions (metadata only, no messages)
  Future<List<AiChatSession>> loadAllSessions() async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      final raw = await settingsRepo.getSetting(_sessionIndexKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => AiChatSession.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      }
    } catch (e) {
      debugPrint('Error loading sessions index: $e');
    }
    return [];
  }

  /// Load messages for a specific session
  Future<List<AiChatMessage>> loadSession(String sessionId) async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      final raw = await settingsRepo.getSetting(_sessionKey(sessionId));
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => AiChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading session $sessionId: $e');
    }
    return [];
  }

  /// Save messages for a session and update the index metadata
  Future<void> saveSession(String sessionId, List<AiChatMessage> messages) async {
    if (messages.isEmpty) return;
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);

      // Save messages
      final recent = messages.length > 80 ? messages.sublist(messages.length - 80) : messages;
      await settingsRepo.setSetting(_sessionKey(sessionId), jsonEncode(recent.map((m) => m.toMap()).toList()));

      // Build session metadata
      final userMsgs = messages.where((m) => m.role == 'user').toList();
      final title = userMsgs.isNotEmpty
          ? _truncate(userMsgs.first.content, 40)
          : 'New Chat';
      final lastMsg = messages.last;
      final previewText = _truncate(lastMsg.content.replaceAll(RegExp(r'\*+|#+|`+'), ''), 60);

      final newMeta = AiChatSession(
        id: sessionId,
        title: title,
        createdAt: messages.first.timestamp,
        lastMessageAt: lastMsg.timestamp,
        messageCount: messages.length,
        previewText: previewText,
      );

      // Update index
      var sessions = await loadAllSessions();
      final idx = sessions.indexWhere((s) => s.id == sessionId);
      if (idx != -1) {
        sessions[idx] = newMeta;
      } else {
        sessions.insert(0, newMeta);
      }

      // Cap at max sessions (prune oldest)
      if (sessions.length > _maxSessions) {
        final toRemove = sessions.sublist(_maxSessions);
        sessions = sessions.sublist(0, _maxSessions);
        for (final old in toRemove) {
          await settingsRepo.setSetting(_sessionKey(old.id), '');
        }
      }

      await settingsRepo.setSetting(_sessionIndexKey, jsonEncode(sessions.map((s) => s.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving session $sessionId: $e');
    }
  }

  /// Delete a session and remove from index
  Future<void> deleteSession(String sessionId) async {
    try {
      final settingsRepo = _ref.read(settingsRepositoryProvider);
      await settingsRepo.setSetting(_sessionKey(sessionId), '');
      var sessions = await loadAllSessions();
      sessions.removeWhere((s) => s.id == sessionId);
      await settingsRepo.setSetting(_sessionIndexKey, jsonEncode(sessions.map((s) => s.toMap()).toList()));
    } catch (e) {
      debugPrint('Error deleting session $sessionId: $e');
    }
  }

  String _truncate(String text, int maxLen) {
    final trimmed = text.trim();
    return trimmed.length <= maxLen ? trimmed : '${trimmed.substring(0, maxLen)}…';
  }

  /// Generate occasional proactive AI coach message tailored with real user workout data
  Future<String> generateProactiveCoachGreeting() async {
    try {
      final settings = _ref.read(settingsRepositoryProvider);
      final userName = await settings.getSetting('user_name') ?? 'Athlete';
      final workoutRepo = _ref.read(workoutRepositoryProvider);
      final streakData = await workoutRepo.getStreakAndWeekData();
      final todayWorkout = await workoutRepo.getOrCreateTodayWorkout();
      final hasLiftedToday = todayWorkout.exercises.any((e) => e.sets.any((s) => !s.archived && (s.reps > 0 || s.weight > 0)));
      final isRestToday = todayWorkout.title.toLowerCase().contains('rest');

      final streak = streakData.streakDays;
      final weekWorkouts = streakData.workoutsThisWeek;

      if (isRestToday) {
        return "**Rest & Recovery Day, $userName**: Your streak of $streak days is preserved! Muscles grow when you rest and fuel up. Need nutrition advice, stretching tips, or want to preview tomorrow's session?";
      } else if (hasLiftedToday) {
        return "**Workout Complete, $userName**: Incredible job today! You're holding a **$streak-day streak** with $weekWorkouts sessions logged this week. Make sure to hydrate, hit your protein goals, and let me know if you want to analyze your volume!";
      } else if (streak > 0) {
        return "**Keep The Momentum Going, $userName**: You're currently on a **$streak-day streak** ($weekWorkouts workouts this week)! You haven't lifted yet today. Even 3 quick sets will keep your streak alive and push you closer to your goals. Ready to crush today?";
      } else {
        return "**Welcome back, $userName!** Consistency is how champions are built. Jump into today's session, log your sets, or ask me to recommend weights based on your PRs!";
      }
    } catch (e) {
      return "**Welcome to your AI Coach!** Ready to crush your workout today? Ask me to log sets, recommend weights, or search training techniques.";
    }
  }

  /// Builds athlete personal profile prompt to inject into AI system instructions
  Future<String> _getAthleteProfilePrompt() async {
    try {
      final settings = _ref.read(settingsRepositoryProvider);
      final name = await settings.getSetting('user_name') ?? 'Athlete';
      final age = await settings.getSetting('user_age') ?? '25';
      final weight = await settings.getSetting('user_weight') ?? '75';
      final height = await settings.getSetting('user_height') ?? '178';
      final gender = await settings.getSetting('user_gender') ?? 'Male';
      final goal = await settings.getSetting('user_goal') ?? 'Build Muscle';
      final level = await settings.getSetting('user_level') ?? 'Intermediate';
      final unit = await settings.getWeightUnit();

      return '''
ATHLETE PERSONAL PROFILE:
- Name: $name
- Age: $age years old
- Body Weight: $weight ${unit.name}
- Height: $height cm
- Gender: $gender
- Primary Goal: $goal
- Experience Level: $level

COACHING DIRECTIVES:
Address the athlete directly by their name ($name) when greeting or coaching them.
Formulate all exercise selections, progressive overload targets, volume recommendations, and recovery advice tailored specifically to $name's goal ($goal) and experience level ($level).''';
    } catch (_) {
      return '';
    }
  }

  /// Builds today's live workout context prompt to inject into AI system instructions
  Future<String> _getTodayWorkoutContextPrompt() async {
    try {
      final now = DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      final workoutRepo = _ref.read(workoutRepositoryProvider);
      final settings = _ref.read(settingsRepositoryProvider);
      final unit = await settings.getWeightUnit();
      final workout = await workoutRepo.getWorkoutForDate(todayNorm);

      final dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(now);

      if (workout == null || (workout.exercises.isEmpty && !workout.isRestDay)) {
        return '''
TODAY'S WORKOUT LOG ($dateFormatted):
- Status: No exercises or sets logged yet today.
- Today is active/ongoing. If the athlete asks about today's workout or mentions logging an exercise or set, be aware that nothing has been logged yet for today, and use the appropriate tools like `log_set` or `add_exercise` when they want to record their session.''';
      }

      if (workout.isRestDay) {
        return '''
TODAY'S WORKOUT LOG ($dateFormatted):
- Status: Scheduled Rest Day${workout.note != null && workout.note!.isNotEmpty ? ' (${workout.note})' : ''}.
- Advise the athlete on active recovery, nutrition, hydration, and sleep if asked.''';
      }

      final buffer = StringBuffer();
      buffer.writeln("TODAY'S WORKOUT LOG ($dateFormatted):");
      buffer.writeln("- Title: \"${workout.title}\"");
      buffer.writeln("- Completed Volume: ${UnitConverter.formatWeight(workout.totalVolume, unit: unit)} across ${workout.totalSetsCount} total sets.");
      final dur = workout.duration;
      if (dur != null && dur.inMinutes > 0) {
        buffer.writeln("- Duration: ${dur.inMinutes} minutes");
      }
      buffer.writeln("- Logged Exercises and Sets:");

      for (final we in workout.exercises) {
        if (we.archived) continue;
        final activeSets = we.sets.where((s) => !s.archived).toList();
        if (activeSets.isEmpty) {
          buffer.writeln("  • ${we.exercise.name}: Added to session, 0 sets logged yet.");
        } else {
          final setsDetail = activeSets.map((s) {
            final typeTag = s.setType.name != 'working' ? ' [${s.setType.name}]' : '';
            return 'Set ${s.setIndex}: ${s.formatPerformance(we.exercise.trackingType, unit: unit)}$typeTag';
          }).join(' | ');
          buffer.writeln("  • ${we.exercise.name}: $setsDetail");
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error building today workout context prompt: $e');
      return '';
    }
  }

  /// Ping connection to verify API key and endpoint (supports local/no-key mode)
  Future<Map<String, dynamic>> testConnection(AiConfigModel config) async {
    final hasKey = config.apiKey.trim().isNotEmpty;
    final isUniversal = config.provider == AiProvider.universal;

    if (!hasKey && config.requireApiKey && !isUniversal) {
      return {
        'success': false,
        'message': 'API key is required for ${config.provider.displayName}. Please enter your key or switch to Universal / Local.',
      };
    }

    try {
      if (config.provider == AiProvider.gemini) {
        if (!hasKey) {
          return {
            'success': false,
            'message': 'Google Gemini requires an API key.',
          };
        }
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/${config.modelName}:generateContent?key=${config.apiKey.trim()}',
        );
        final resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': 'Ping'}
                ]
              }
            ],
            'generationConfig': {'maxOutputTokens': 5},
          }),
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          return {'success': true, 'message': 'Connected successfully!'};
        } else {
          return {'success': false, 'message': 'API error (${resp.statusCode}): ${resp.body}'};
        }
      } else if (config.provider == AiProvider.anthropic) {
        if (!hasKey) {
          return {
            'success': false,
            'message': 'Anthropic Claude requires an API key.',
          };
        }
        final url = Uri.parse('https://api.anthropic.com/v1/messages');
        final resp = await http.post(
          url,
          headers: {
            'x-api-key': config.apiKey.trim(),
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': config.modelName,
            'max_tokens': 10,
            'messages': [
              {'role': 'user', 'content': 'Ping'}
            ],
          }),
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          return {'success': true, 'message': 'Connected successfully!'};
        } else {
          return {'success': false, 'message': 'API error (${resp.statusCode}): ${resp.body}'};
        }
      } else {
        // Universal / OpenAI-compatible / Local AI (Ollama, LM Studio, etc.)
        var base = config.baseUrl.trim();
        if (base.endsWith('/')) base = base.substring(0, base.length - 1);
        final url = Uri.parse(
          base.endsWith('/chat/completions') ? base : '$base/chat/completions',
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        if (hasKey) {
          headers['Authorization'] = 'Bearer ${config.apiKey.trim()}';
        }

        final resp = await http.post(
          url,
          headers: headers,
          body: jsonEncode({
            'model': config.modelName,
            'messages': [
              {'role': 'user', 'content': 'Ping'}
            ],
            'max_tokens': 5,
          }),
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          final note = hasKey ? 'Connected successfully!' : 'Connected & validated successfully! (No API key needed / Local server)';
          return {'success': true, 'message': note};
        } else {
          return {'success': false, 'message': 'API returned ${resp.statusCode}: ${resp.body}'};
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': hasKey
            ? 'Network/Connection error: $e'
            : 'Connection error: $e. Ensure local server (Ollama/LM Studio) is running at ${config.baseUrl}, or toggle Built-in Offline Engine.',
      };
    }
  }

  /// Send message and execute tool calls in conversation loop
  /// Send message and execute tool calls in conversation loop
  Future<AiChatMessage> sendMessage({
    required List<AiChatMessage> history,
    required String userPrompt,
    String? imagePath,
    Function(String status)? onProgress,
  }) async {
    AiChatMessage? finalMsg;
    await for (final event in sendMessageStream(
      history: history,
      userPrompt: userPrompt,
      imagePath: imagePath,
    )) {
      if (event is AiThinkingEvent) {
        onProgress?.call(event.status);
      } else if (event is AiToolExecutingEvent) {
        onProgress?.call('Executing app tool: ${event.toolName}...');
      } else if (event is AiCompleteEvent) {
        finalMsg = event.message;
      } else if (event is AiErrorEvent) {
        throw Exception(event.error);
      }
    }
    return finalMsg ??
        AiChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: 'No response generated.',
          timestamp: DateTime.now(),
        );
  }

  /// Send message as an active live event stream for thinking state, tool execution, and token streaming
  Stream<AiAssistantEvent> sendMessageStream({
    required List<AiChatMessage> history,
    required String userPrompt,
    String? imagePath,
  }) async* {
    yield const AiThinkingEvent('Thinking...');
    final config = await getConfig();

    final hasKey = config.apiKey.trim().isNotEmpty;
    final canUseUniversalWithoutKey = config.provider == AiProvider.universal && !config.requireApiKey;

    if (!hasKey && !canUseUniversalWithoutKey) {
      yield* _handleOfflineHeuristicStream(userPrompt, imagePath: imagePath);
      return;
    }

    try {
      if (config.provider == AiProvider.gemini) {
        yield* _sendGeminiMessageStream(config, history, userPrompt);
      } else if (config.provider == AiProvider.anthropic) {
        yield* _sendAnthropicMessageStream(config, history, userPrompt);
      } else {
        yield* _sendOpenAiCompatibleMessageStream(config, history, userPrompt, imagePath: imagePath);
      }
    } catch (e) {
      debugPrint('AI Stream error: $e');
      yield AiThinkingEvent('Connection issue encountered. Switching to offline engine...');
      yield* _handleOfflineHeuristicStream(userPrompt, fallbackError: e.toString(), imagePath: imagePath);
    }
  }

  /// Builds pruned message payload to protect against context window limit overflows
  List<Map<String, dynamic>> _buildPrunedContext({
    required List<AiChatMessage> history,
    required String userPrompt,
    String? imagePath,
    String? athleteProfile,
    String? todayWorkoutContext,
    String? companionPersona,
    int maxCharacters = 16000,
  }) {
    final systemPromptText = StringBuffer('''You are the premier Gym AI Coach embedded inside this workout app with direct app control.
You can query PRs/history, log sets, edit sets, delete sets, add/remove exercises, start/finish workouts, edit workouts, delete workouts, create routines, edit routines, delete routines, edit exercises, edit settings, trigger rest timers, and search exercise science.
You can execute multi-step actions in sequence: gather data first (e.g. query_prs_and_history, search_web), use that information to execute subsequent actions (e.g. log_set, edit_set, create_routine, start_rest_timer), and provide a complete, clear response.

CRITICAL RULES FOR LOGGING WORKOUTS:
1. ALWAYS call query_prs_and_history first (with no exerciseName) to discover the exact exercise names available in the app before calling log_set or add_exercise. The tool returns a list of all exercises — use the EXACT names from that list.
2. When log_set fails with "not found", it will give you available exercise names. Re-try with one of those exact names.
3. log_set automatically handles adding the exercise to the session if it is not already there — no need to call add_exercise separately before log_set.
4. Default setType to "working" for all normal work sets. Only use "warmup" when the user explicitly says it is a warmup set.
5. Never log the same exercise twice in one session. If add_exercise says the exercise is already in the session, skip it and proceed.
6. When starting a workout, call start_workout once, then call log_set for each set.
7. You have real-time access to TODAY'S WORKOUT LOG injected below, as well as the `get_today_workout` tool. When the athlete asks what they did today, what is logged, their current volume/sets, or references their current session, inspect the injected TODAY'S WORKOUT LOG or call `get_today_workout`.
8. ADAPTIVE EXERCISE TRACKING (BODYWEIGHT, ISOMETRIC HOLDS, SPORTS/GAMES):
- Bodyweight Calisthenics (Push-Ups, Pull-Ups, Dips, Crunches): Set weight to 0.0 (or specify added load if weighted, e.g. 10.0 for "+10kg weighted dips") and reps to completed repetitions.
- Timed Isometric Holds (Plank, Side Plank, Dead Hang, Wall Sit, L-Sit): Pass durationSeconds (or reps) in exact hold seconds (e.g. 60 for 60 seconds) and weight 0.0 (or added plate load).
- Sports, Games & Cardio (Football, Basketball, Boxing, Running, Cycling, Swimming): Pass durationMinutes (or reps) representing session duration in minutes and weight 0.0. The app automatically creates the activity under CARDIO.
9. HISTORICAL WORKOUTS & MUSCLE GROUP SEARCH: When asked about past workouts, previous sessions, or which sessions included specific muscle groups (e.g., "which sessions did I train Glutes?", "show my leg days", "what was my last back workout"), ALWAYS call query_workout_history(muscleGroup: "...", limit: 10). NEVER say "Let me check..." and pause — execute query_workout_history immediately so you can deliver the complete answer in a single turn.

When asked to delete a logged workout, always inform the athlete that deleting a workout requires their explicit confirmation before it is removed.
When you need clarification, choices, or user preference (e.g. choosing a routine, picking a target weight, confirming an action), call the ask_user_question tool with a summary of the situation/context, the question, and 2 to 4 selectable options. Calling ask_user_question immediately halts execution so the athlete can respond before you take any further steps.
Never use developer jargon like "toolcall", "tool execution", or "JSON" in your messages to the user; use natural coaching phrases like "I logged your set", "I updated your routine", "Would you like me to delete this workout?".
When creating or editing routines, include ALL exercises requested without truncating or omitting any.
Be encouraging, concise, evidence-based, and focused on hypertrophy and progressive overload.''');

    if (athleteProfile != null && athleteProfile.trim().isNotEmpty) {
      systemPromptText.write('\n\n$athleteProfile');
    }

    if (todayWorkoutContext != null && todayWorkoutContext.trim().isNotEmpty) {
      systemPromptText.write('\n\n$todayWorkoutContext');
    }

    if (companionPersona != null && companionPersona.trim().isNotEmpty) {
      systemPromptText.write('\n\n$companionPersona');
    }

    final systemMessage = <String, dynamic>{
      'role': 'system',
      'content': systemPromptText.toString(),
    };

    dynamic userContent;
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = File(imagePath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final base64Str = base64Encode(bytes);
          final ext = imagePath.split('.').last.toLowerCase();
          final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
          userContent = [
            {'type': 'text', 'text': userPrompt.isEmpty ? 'Analyze this workout image / physique' : userPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Str',
              },
            },
          ];
        }
      } catch (e) {
        debugPrint('Error reading attached image: $e');
      }
    }
    userContent ??= userPrompt;

    final userMessage = <String, dynamic>{'role': 'user', 'content': userContent};

    int budget = maxCharacters - (systemMessage['content'] as String).length - userPrompt.length;
    if (budget < 1500) budget = 1500;

    final historyList = <Map<String, dynamic>>[];
    int currentChars = 0;

    // Prune history from newest backwards to keep within budget
    for (int i = history.length - 1; i >= 0; i--) {
      final m = history[i];
      if (m.role != 'user' && m.role != 'assistant') continue;
      final len = m.content.length;
      if (currentChars + len > budget) {
        break;
      }
      currentChars += len;
      historyList.insert(0, {'role': m.role, 'content': m.content});
    }

    return [
      systemMessage,
      ...historyList,
      userMessage,
    ];
  }

  /// Universal / OpenAI-compatible endpoint with function calling, context window handling, and live streaming
  Stream<AiAssistantEvent> _sendOpenAiCompatibleMessageStream(
    AiConfigModel config,
    List<AiChatMessage> history,
    String userPrompt, {
    String? imagePath,
  }) async* {
    yield const AiThinkingEvent('Connecting to AI...');

    var base = config.baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final endpoint = Uri.parse(
      base.endsWith('/chat/completions') ? base : '$base/chat/completions',
    );

    final athleteProfile = await _getAthleteProfilePrompt();
    final todayWorkoutContext = await _getTodayWorkoutContextPrompt();
    final companion = await ChibiAvatar.loadCurrent();
    final messages = _buildPrunedContext(
      history: history,
      userPrompt: userPrompt,
      imagePath: imagePath,
      athleteProfile: athleteProfile,
      todayWorkoutContext: todayWorkoutContext,
      companionPersona: companion.personaPrompt,
      maxCharacters: 16000,
    );

    final allExecutedResults = <AiToolExecutionResult>[];
    final allToolCalls = <AiToolCall>[];
    String finalContent = '';
    const maxSteps = 10;
    int step = 0;
    bool hasAskedQuestion = false;

    // Autonomous Multi-Step Tool Call Loop
    while (step < maxSteps) {
      step++;
      yield AiThinkingEvent(step == 1
          ? 'Thinking...'
          : 'Step $step: Processing...');

      final requestBody = {
        'model': config.modelName,
        'messages': messages,
        'tools': AiToolService.openAiToolDefinitions,
        'tool_choice': 'auto',
        'temperature': config.temperature,
      };

      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
      };
      if (config.apiKey.trim().isNotEmpty) {
        requestHeaders['Authorization'] = 'Bearer ${config.apiKey.trim()}';
      }

      // 45s timeout for AI responses
      var response = await http.post(
        endpoint,
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45));

      // Automatic Context Window Recovery if exceeded
      if (response.statusCode != 200) {
        final errBody = response.body.toLowerCase();
        final isEmptyOutputError = errBody.contains('model output') ||
            errBody.contains('output text or tool calls');

        if (isEmptyOutputError) {
          yield const AiThinkingEvent('Retrying...');
          final nudgedMessages = List<Map<String, dynamic>>.from(messages)
            ..add({'role': 'user', 'content': 'Please respond now.'});
          response = await http.post(
            endpoint,
            headers: requestHeaders,
            body: jsonEncode({...requestBody, 'messages': nudgedMessages}),
          ).timeout(const Duration(seconds: 45));
        } else if ((errBody.contains('context') ||
                errBody.contains('token') ||
                errBody.contains('too long') ||
                errBody.contains('maximum context length') ||
                response.statusCode == 400) &&
            messages.length > 2) {
          yield const AiThinkingEvent('Context window exceeded. Compacting history and retrying...');
          final sys = messages.firstWhere((m) => m['role'] == 'system', orElse: () => messages.first);
          final lastUser = messages.lastWhere((m) => m['role'] == 'user', orElse: () => messages.last);
          messages.clear();
          messages.addAll([sys, lastUser]);

          response = await http.post(
            endpoint,
            headers: requestHeaders,
            body: jsonEncode({
              ...requestBody,
              'messages': messages,
            }),
          ).timeout(const Duration(seconds: 45));
        }

        if (response.statusCode != 200) {
          throw Exception('API error (${response.statusCode}): ${response.body}');
        }
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choice = (data['choices'] as List).firstOrNull as Map<String, dynamic>?;
      final message = choice?['message'] as Map<String, dynamic>?;

      // Handle completely empty model output — treat as done with no content
      if (message == null ||
          (message['content'] == null &&
              (message['tool_calls'] == null || (message['tool_calls'] as List).isEmpty))) {
        debugPrint('AI returned empty message, breaking loop');
        break;
      }

      final toolCallsRaw = message['tool_calls'] as List?;
      if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
        messages.add(message);

        for (final tc in toolCallsRaw) {
          final id = tc['id']?.toString() ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
          final fn = tc['function'] as Map<String, dynamic>;
          final name = fn['name']?.toString() ?? '';
          final argsStr = fn['arguments']?.toString() ?? '{}';
          Map<String, dynamic> args = {};
          try {
            args = jsonDecode(argsStr) as Map<String, dynamic>;
          } catch (_) {}

          final toolCall = AiToolCall(id: id, name: name, arguments: args);
          allToolCalls.add(toolCall);

          yield AiThinkingEvent(_formatActionThinking(name));
          yield AiToolExecutingEvent(name, args);
          final toolStart = DateTime.now();
          final rawResult = await _toolService.executeTool(toolCall);
          final elapsed = DateTime.now().difference(toolStart).inMilliseconds;
          // Attach elapsed time so the UI can display "worked for Xs"
          final result = AiToolExecutionResult(
            toolName: rawResult.toolName,
            success: rawResult.success,
            summary: rawResult.summary,
            data: rawResult.data,
            durationMs: elapsed,
          );
          allExecutedResults.add(result);
          yield AiToolCompletedEvent(result);

          // Feed tool execution result back to messages as role: tool
          messages.add({
            'role': 'tool',
            'tool_call_id': id,
            'name': name,
            'content': jsonEncode(result.toMap()),
          });

          // HALT on ask_user_question: Wait for user to answer!
          if (name == 'ask_user_question') {
            hasAskedQuestion = true;
            break;
          }
        }

        if (hasAskedQuestion) {
          // Immediately stop multi-step loop and await user's response
          break;
        }

        // Continue loop: model can inspect results and decide to call another tool or finish!
        continue;
      }

      // No more tool calls! Model has concluded its actions and generated final text
      finalContent = message['content']?.toString() ?? '';
      break;
    }

    if (finalContent.isEmpty && allExecutedResults.isNotEmpty) {
      if (hasAskedQuestion) {
        final qResult = allExecutedResults.firstWhere(
          (r) => r.toolName == 'ask_user_question',
          orElse: () => allExecutedResults.last,
        );
        final summary = qResult.data?['summary']?.toString();
        final question = qResult.data?['question']?.toString();
        if (summary != null && summary.isNotEmpty) {
          finalContent = summary;
        } else if (question != null && question.isNotEmpty) {
          finalContent = question;
        } else {
          finalContent = 'Please answer the question below:';
        }
      } else {
        // Build a natural summary from what the AI actually did
        final successful = allExecutedResults.where((r) => r.success).toList();
        final failed = allExecutedResults.where((r) => !r.success).toList();
        final parts = <String>[];
        if (successful.isNotEmpty) {
          parts.add(successful.map((r) => r.summary).join('\n'));
        }
        if (failed.isNotEmpty) {
          parts.add('Could not complete: ${failed.map((r) => r.summary).join('; ')}');
        }
        finalContent = parts.join('\n\n');
      }
    }
    if (finalContent.isEmpty) {
      finalContent = "Done! Let me know if you need anything else.";
    }

    // Stream text chunk by chunk
    yield const AiThinkingEvent('Streaming response...');
    final words = finalContent.split(' ');
    String accumulated = '';
    for (int i = 0; i < words.length; i++) {
      final delta = i == 0 ? words[i] : ' ${words[i]}';
      accumulated += delta;
      yield AiStreamChunkEvent(delta, accumulated);
      await Future.delayed(const Duration(milliseconds: 14));
    }

    yield AiCompleteEvent(
      AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: accumulated,
        timestamp: DateTime.now(),
        toolCalls: allToolCalls.isNotEmpty ? allToolCalls : null,
        toolResults: allExecutedResults.isNotEmpty ? allExecutedResults : null,
      ),
    );
  }

  /// Google Gemini execution with stream
  Stream<AiAssistantEvent> _sendGeminiMessageStream(
    AiConfigModel config,
    List<AiChatMessage> history,
    String userPrompt,
  ) async* {
    yield const AiThinkingEvent('Connecting to AI...');
    final athleteProfile = await _getAthleteProfilePrompt();
    final todayWorkoutContext = await _getTodayWorkoutContextPrompt();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${config.modelName}:generateContent?key=${config.apiKey.trim()}',
    );

    final contents = <Map<String, dynamic>>[];
    for (final m in history.take(6)) {
      contents.add({
        'role': m.role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m.content}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userPrompt}
      ],
    });

    yield const AiThinkingEvent('Generating workout insights...');
    final systemPrompt = 'You are a premier strength and hypertrophy AI Coach. You help athletes track workouts, progressive overload, and search exercise science.'
        '${athleteProfile.isNotEmpty ? '\n\n$athleteProfile' : ''}'
        '${todayWorkoutContext.isNotEmpty ? '\n\n$todayWorkoutContext' : ''}';

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'systemInstruction': {
          'parts': [
            {
              'text': systemPrompt
            }
          ]
        },
      }),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode != 200) {
      throw Exception('Gemini error (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    final first = candidates?.firstOrNull as Map<String, dynamic>?;
    final parts = first?['content']?['parts'] as List?;
    final text = parts?.firstOrNull?['text']?.toString() ?? 'No content returned.';

    yield const AiThinkingEvent('Streaming response...');
    final words = text.split(' ');
    String accumulated = '';
    for (int i = 0; i < words.length; i++) {
      final delta = i == 0 ? words[i] : ' ${words[i]}';
      accumulated += delta;
      yield AiStreamChunkEvent(delta, accumulated);
      await Future.delayed(const Duration(milliseconds: 14));
    }

    yield AiCompleteEvent(
      AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: accumulated,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Anthropic Claude execution with stream
  Stream<AiAssistantEvent> _sendAnthropicMessageStream(
    AiConfigModel config,
    List<AiChatMessage> history,
    String userPrompt,
  ) async* {
    yield const AiThinkingEvent('Connecting to AI...');
    final athleteProfile = await _getAthleteProfilePrompt();
    final todayWorkoutContext = await _getTodayWorkoutContextPrompt();
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final messages = <Map<String, dynamic>>[];
    for (final m in history.take(6)) {
      if (m.role == 'user' || m.role == 'assistant') {
        messages.add({'role': m.role, 'content': m.content});
      }
    }
    messages.add({'role': 'user', 'content': userPrompt});

    yield const AiThinkingEvent('Analyzing hypertrophy split...');
    final systemPrompt = 'You are a premier strength and hypertrophy AI Coach. You help athletes track workouts, progressive overload, and search exercise science.'
        '${athleteProfile.isNotEmpty ? '\n\n$athleteProfile' : ''}'
        '${todayWorkoutContext.isNotEmpty ? '\n\n$todayWorkoutContext' : ''}';

    final resp = await http.post(
      url,
      headers: {
        'x-api-key': config.apiKey.trim(),
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': config.modelName,
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': messages,
      }),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode != 200) {
      throw Exception('Anthropic error (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final contentList = data['content'] as List?;
    final text = contentList?.firstOrNull?['text']?.toString() ?? 'No content.';

    yield const AiThinkingEvent('Streaming response...');
    final words = text.split(' ');
    String accumulated = '';
    for (int i = 0; i < words.length; i++) {
      final delta = i == 0 ? words[i] : ' ${words[i]}';
      accumulated += delta;
      yield AiStreamChunkEvent(delta, accumulated);
      await Future.delayed(const Duration(milliseconds: 14));
    }

    yield AiCompleteEvent(
      AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: accumulated,
        timestamp: DateTime.now(),
      ),
    );
  }

  String _formatActionThinking(String toolName) {
    switch (toolName) {
      case 'log_set':
        return 'Logging set to active workout...';
      case 'edit_set':
        return 'Updating workout set details...';
      case 'delete_set':
        return 'Removing set from workout...';
      case 'add_exercise':
        return 'Adding exercise to session...';
      case 'remove_exercise':
        return 'Removing exercise from session...';
      case 'start_workout':
        return 'Starting workout session...';
      case 'finish_workout':
        return 'Completing workout session...';
      case 'edit_workout':
        return 'Updating workout details...';
      case 'delete_workout':
        return 'Preparing workout deletion...';
      case 'create_routine':
        return 'Saving routine preset...';
      case 'edit_routine':
        return 'Updating routine preset...';
      case 'delete_routine':
        return 'Deleting routine preset...';
      case 'edit_exercise':
        return 'Updating exercise settings...';
      case 'edit_setting':
        return 'Updating app preference...';
      case 'start_rest_timer':
        return 'Starting countdown rest timer...';
      case 'recommend_weights':
        return 'Analyzing strength progression...';
      case 'query_prs_and_history':
        return 'Checking personal records & history...';
      case 'export_backup':
        return 'Exporting database backup...';
      case 'search_web':
        return 'Searching training knowledge...';
      default:
        return 'Processing action...';
    }
  }

  /// Smart extractor for routine creation from natural language prompts
  Map<String, dynamic> _parseRoutineFromPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    String routineName = 'Custom Split';
    String category = 'Hypertrophy';

    if (lower.contains('push')) {
      category = 'Push';
      routineName = 'Push Day Hypertrophy';
    } else if (lower.contains('pull')) {
      category = 'Pull';
      routineName = 'Pull Day Hypertrophy';
    } else if (lower.contains('leg')) {
      category = 'Legs';
      routineName = 'Leg Day Hypertrophy';
    } else if (lower.contains('upper')) {
      category = 'Upper';
      routineName = 'Upper Body Power';
    } else if (lower.contains('lower')) {
      category = 'Lower';
      routineName = 'Lower Body Strength';
    } else if (lower.contains('full body') || lower.contains('full-body')) {
      category = 'Full Body';
      routineName = 'Full Body Blast';
    }

    final quoteMatch = RegExp(r'["“]([^"”]+)["”]').firstMatch(prompt);
    if (quoteMatch != null) {
      routineName = quoteMatch.group(1)!.trim();
    } else {
      final nameMatch = RegExp(
        r'(?:called|named|routine|preset)\s+([A-Za-z0-9\s\-]+?)(?:\s+(?:with|for|containing|consisting|exercises)|$)',
        caseSensitive: false,
      ).firstMatch(prompt);
      if (nameMatch != null && nameMatch.group(1) != null && nameMatch.group(1)!.trim().isNotEmpty) {
        final candidate = nameMatch.group(1)!.trim();
        if (candidate.length <= 40 &&
            !candidate.toLowerCase().startsWith('a ') &&
            !candidate.toLowerCase().startsWith('the ')) {
          routineName = candidate;
        }
      }
    }

    final exercises = <String>[];
    final afterWithMatch = RegExp(
      r'(?:with|including|consisting of|contains?|exercises?:)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(prompt);

    if (afterWithMatch != null) {
      final listSection = afterWithMatch.group(1)!;
      final parts = listSection.split(RegExp(r'[,;\n]|\s+and\s+'));
      for (final p in parts) {
        var clean = p.replaceAll(RegExp(r'^\s*[-•*0-9.]+\s*'), '').trim();
        clean = clean.replaceAll(RegExp(r'[.!?]+$'), '').trim();
        if (clean.isNotEmpty && clean.length > 2 && !clean.toLowerCase().startsWith('create')) {
          exercises.add(clean);
        }
      }
    }

    if (exercises.isEmpty) {
      if (category == 'Push') {
        exercises.addAll([
          'Bench Press (Barbell)',
          'Incline Dumbbell Press',
          'Overhead Press',
          'Lateral Raise (Dumbbell)',
          'Tricep Pushdown (Cable)',
        ]);
      } else if (category == 'Pull') {
        exercises.addAll([
          'Deadlift (Barbell)',
          'Lat Pulldown (Cable)',
          'Bent Over Row (Barbell)',
          'Face Pull (Cable)',
          'Dumbbell Curl',
        ]);
      } else if (category == 'Legs') {
        exercises.addAll([
          'Squat (Barbell)',
          'Romanian Deadlift (Dumbbell)',
          'Leg Press (Machine)',
          'Leg Extension (Machine)',
          'Standing Calf Raise',
        ]);
      } else if (category == 'Upper') {
        exercises.addAll([
          'Bench Press (Barbell)',
          'Bent Over Row (Barbell)',
          'Overhead Press',
          'Lat Pulldown (Cable)',
          'Dumbbell Curl',
          'Tricep Pushdown (Cable)',
        ]);
      } else if (category == 'Lower') {
        exercises.addAll([
          'Squat (Barbell)',
          'Romanian Deadlift (Barbell)',
          'Leg Press (Machine)',
          'Seated Leg Curl (Machine)',
          'Standing Calf Raise',
        ]);
      } else {
        exercises.addAll([
          'Bench Press (Barbell)',
          'Squat (Barbell)',
          'Bent Over Row (Barbell)',
          'Overhead Press',
          'Lat Pulldown (Cable)',
        ]);
      }
    }

    return {
      'name': routineName,
      'category': category,
      'exerciseNames': exercises,
    };
  }

  /// Smart local fallback streaming: parses natural language intent and executes tools directly
  Stream<AiAssistantEvent> _handleOfflineHeuristicStream(
    String prompt, {
    String? fallbackError,
    String? imagePath,
  }) async* {
    yield const AiThinkingEvent('Processing intent in local engine...');
    final lower = prompt.toLowerCase();
    final executed = <AiToolExecutionResult>[];
    final toolCalls = <AiToolCall>[];
    String reply = '';
    if (imagePath != null && imagePath.isNotEmpty) {
      reply = 'Image attached: ${imagePath.split('/').last}\n\n';
    }

    // 1. Rest Timer Intent
    if (lower.contains('rest') || lower.contains('timer')) {
      final match = RegExp(r'(\d+)\s*(s|sec|seconds|m|min|minutes)?').firstMatch(lower);
      int seconds = 90;
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '') ?? 90;
        final unit = match.group(2) ?? 's';
        seconds = unit.startsWith('m') ? val * 60 : val;
      }
      final call = AiToolCall(
        id: 'call_timer_${DateTime.now().millisecondsSinceEpoch}',
        name: 'start_rest_timer',
        arguments: {'seconds': seconds},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Configuring rest timer for ${seconds}s...');
      yield AiToolExecutingEvent('start_rest_timer', {'seconds': seconds});
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = 'Started countdown rest timer for ${seconds}s!';
    }
    // 2. Delete Workout Intent (Requires Confirmation)
    else if (lower.contains('delete workout') || lower.contains('remove workout') || lower.contains('discard workout') || lower.contains('delete today')) {
      final call = AiToolCall(
        id: 'call_del_wo_${DateTime.now().millisecondsSinceEpoch}',
        name: 'delete_workout',
        arguments: {},
      );
      toolCalls.add(call);
      yield const AiThinkingEvent('Preparing workout deletion...');
      yield AiToolExecutingEvent('delete_workout', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      if (res.data?['status'] == 'pending_confirmation') {
        reply = 'Please confirm below if you would like to permanently delete this workout.';
      } else {
        reply = res.summary;
      }
    }
    // 3. Edit or Delete Set Intent
    else if (lower.contains('delete set') || lower.contains('remove set')) {
      final indexMatch = RegExp(r'set\s*#?(\d+)').firstMatch(lower);
      final setIndex = indexMatch != null ? int.tryParse(indexMatch.group(1)!) : null;
      final args = <String, dynamic>{};
      if (setIndex != null) args['setIndex'] = setIndex;

      final call = AiToolCall(
        id: 'call_del_set_${DateTime.now().millisecondsSinceEpoch}',
        name: 'delete_set',
        arguments: args,
      );
      toolCalls.add(call);
      yield const AiThinkingEvent('Deleting set from today\'s workout...');
      yield AiToolExecutingEvent('delete_set', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    } else if (lower.contains('edit set') || lower.contains('change set') || lower.contains('update set')) {
      final weightMatch = RegExp(r'(\d+(\.\d+)?)\s*(kg|lbs)?').firstMatch(lower);
      final repsMatch = RegExp(r'(\d+)\s*(reps?|times)?').allMatches(lower);
      final indexMatch = RegExp(r'set\s*#?(\d+)').firstMatch(lower);
      final setIndex = indexMatch != null ? int.tryParse(indexMatch.group(1)!) : null;

      double? weight = weightMatch != null ? double.tryParse(weightMatch.group(1)!) : null;
      int? reps;
      for (final rm in repsMatch) {
        final val = int.tryParse(rm.group(1) ?? '');
        if (val != null && val != weight?.toInt() && val <= 50) {
          reps = val;
          break;
        }
      }

      String ex = '';
      if (lower.contains('bench')) ex = 'Bench Press';
      if (lower.contains('squat')) ex = 'Squat (Barbell)';
      if (lower.contains('deadlift')) ex = 'Deadlift (Barbell)';

      final args = <String, dynamic>{};
      if (ex.isNotEmpty) args['exerciseName'] = ex;
      if (setIndex != null) args['setIndex'] = setIndex;
      if (weight != null) args['weight'] = weight;
      if (reps != null) args['reps'] = reps;

      final call = AiToolCall(
        id: 'call_edit_set_${DateTime.now().millisecondsSinceEpoch}',
        name: 'edit_set',
        arguments: args,
      );
      toolCalls.add(call);
      yield const AiThinkingEvent('Updating workout set details...');
      yield AiToolExecutingEvent('edit_set', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    } else if (lower.contains('remove') && (lower.contains('exercise') || lower.contains('from workout'))) {
      String ex = 'Bench Press';
      if (lower.contains('squat')) ex = 'Squat (Barbell)';
      if (lower.contains('deadlift')) ex = 'Deadlift (Barbell)';
      if (lower.contains('curl')) ex = 'Dumbbell Curl';
      if (lower.contains('lat') || lower.contains('pull')) ex = 'Lat Pulldown (Cable)';

      final call = AiToolCall(
        id: 'call_rem_ex_${DateTime.now().millisecondsSinceEpoch}',
        name: 'remove_exercise',
        arguments: {'exerciseName': ex},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Removing $ex from workout...');
      yield AiToolExecutingEvent('remove_exercise', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 3. Query Today's or Yesterday's Workout Intent (e.g. "what did I do today?", "what did I log today?", "show today's workout", "today's logged data")
    else if (!lower.startsWith('log ') &&
             !RegExp(r'\d+\s*(kg|lbs)').hasMatch(lower) &&
             (((lower.contains('today') || lower.contains('todays') || lower.contains("today's")) &&
               (lower.contains('what') || lower.contains('show') || lower.contains('view') ||
                lower.contains('summary') || lower.contains('data') || lower.contains('detail') ||
                lower.contains('list') || lower.contains('check') || lower.contains('status') ||
                lower.contains('did') || lower.contains('have') || lower.contains('progress') ||
                lower.contains('workout') || lower.contains('exercises') || lower.contains('sets') ||
                lower.contains('log') || lower.contains('done'))) ||
              lower.contains('what did i do') ||
              lower.contains('what did i log') ||
              lower.contains('what have i logged') ||
              lower.contains('what is logged') ||
              lower.contains('logged data') ||
              lower.contains('current workout') ||
              lower.contains('active workout') ||
              lower.contains('today workout') ||
              lower.contains('todays workout') ||
              (lower.contains('yesterday') && (lower.contains('workout') || lower.contains('log') || lower.contains('do') || lower.contains('did') || lower.contains('data'))))) {
      final isYesterday = lower.contains('yesterday');
      final dateArg = isYesterday ? 'yesterday' : 'today';
      final call = AiToolCall(
        id: 'call_today_wo_${DateTime.now().millisecondsSinceEpoch}',
        name: 'get_today_workout',
        arguments: {'date': dateArg},
      );
      toolCalls.add(call);
      yield AiThinkingEvent(isYesterday
          ? 'Checking yesterday\'s workout data...'
          : 'Checking today\'s logged workout data...');
      yield AiToolExecutingEvent('get_today_workout', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = '**${isYesterday ? "Yesterday's" : "Today's"} Workout Summary:**\n\n${res.summary}';
    }
    // 4. Log Set Intent (e.g. "log 80kg bench 8 reps" or "bench 80kg 10" or "log set")
    else if ((lower.contains('log') && (lower.contains('set') || lower.contains('rep') || RegExp(r'\d+').hasMatch(lower))) ||
             (lower.contains('kg') && RegExp(r'\d+').hasMatch(lower)) ||
             (lower.contains('lbs') && RegExp(r'\d+').hasMatch(lower))) {
      final weightMatch = RegExp(r'(\d+(\.\d+)?)\s*(kg|lbs)?').firstMatch(lower);
      final repsMatch = RegExp(r'(\d+)\s*(reps?|times)?').allMatches(lower);

      double weight = weightMatch != null ? double.tryParse(weightMatch.group(1) ?? '60') ?? 60.0 : 60.0;
      int reps = 8;
      for (final rm in repsMatch) {
        final val = int.tryParse(rm.group(1) ?? '');
        if (val != null && val != weight.toInt() && val <= 50) {
          reps = val;
          break;
        }
      }

      String ex = 'Bench Press';
      if (lower.contains('squat')) ex = 'Squat (Barbell)';
      if (lower.contains('deadlift')) ex = 'Deadlift (Barbell)';
      if (lower.contains('press') && !lower.contains('bench')) ex = 'Overhead Press';
      if (lower.contains('curl')) ex = 'Dumbbell Curl';
      if (lower.contains('pull') || lower.contains('lat')) ex = 'Lat Pulldown (Cable)';

      final call = AiToolCall(
        id: 'call_log_${DateTime.now().millisecondsSinceEpoch}',
        name: 'log_set',
        arguments: {'exerciseName': ex, 'weight': weight, 'reps': reps, 'setType': 'working'},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Logging set for $ex...');
      yield AiToolExecutingEvent('log_set', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 3. Web Search Intent
    else if (lower.contains('search') || lower.contains('how to') || lower.contains('cue') || lower.contains('form')) {
      final query = prompt.replaceAll(RegExp(r'^(search|look up|find|google)\s*', caseSensitive: false), '').trim();
      final call = AiToolCall(
        id: 'call_search_${DateTime.now().millisecondsSinceEpoch}',
        name: 'search_web',
        arguments: {'query': query.isNotEmpty ? query : prompt},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Searching web for cues & exercise science...');
      yield AiToolExecutingEvent('search_web', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);

      final results = res.data as List?;
      if (results != null && results.isNotEmpty) {
        final top = results.first as Map<String, dynamic>;
        reply = '**Search Result for "$query":**\n${top['snippet']}\n\n*Source: ${top['url']}*';
      } else {
        reply = res.summary;
      }
    }
    // 4. Recommendation / Progressive Overload
    else if (lower.contains('recommend') || lower.contains('weight') || lower.contains('overload')) {
      String ex = 'Bench Press';
      if (lower.contains('squat')) ex = 'Squat (Barbell)';
      if (lower.contains('deadlift')) ex = 'Deadlift (Barbell)';

      final call = AiToolCall(
        id: 'call_rec_${DateTime.now().millisecondsSinceEpoch}',
        name: 'recommend_weights',
        arguments: {'exerciseName': ex},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Calculating progressive overload recommendation...');
      yield AiToolExecutingEvent('recommend_weights', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 5a. Delete Routine Intent
    else if ((lower.contains('delete') || lower.contains('remove') || lower.contains('discard')) &&
             (lower.contains('routine') || lower.contains('rotine') || lower.contains('preset') || lower.contains('split'))) {
      final cleanName = prompt
          .replaceAll(RegExp(r'\b(remove|delete|discard|the|routine|rotine|preset|split)\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final call = AiToolCall(
        id: 'call_del_routine_${DateTime.now().millisecondsSinceEpoch}',
        name: 'delete_routine',
        arguments: {'routineName': cleanName},
      );
      toolCalls.add(call);
      yield AiThinkingEvent('Deleting routine "$cleanName"...');
      yield AiToolExecutingEvent('delete_routine', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 5b. Create Routine Intent
    else if (lower.contains('routine') || lower.contains('preset') || lower.contains('split') || lower.contains('workout plan')) {
      final routineData = _parseRoutineFromPrompt(prompt);
      final call = AiToolCall(
        id: 'call_routine_${DateTime.now().millisecondsSinceEpoch}',
        name: 'create_routine',
        arguments: routineData,
      );
      toolCalls.add(call);
      final exCount = (routineData['exerciseNames'] as List).length;
      yield AiThinkingEvent('Creating preset "${routineData['name']}" with $exCount exercises...');
      yield AiToolExecutingEvent('create_routine', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 6. PRs and History Intent
    else if (lower.contains('pr') || lower.contains('record') || lower.contains('history') || lower.contains('1rm')) {
      final call = AiToolCall(
        id: 'call_prs_${DateTime.now().millisecondsSinceEpoch}',
        name: 'query_prs_and_history',
        arguments: {},
      );
      toolCalls.add(call);
      yield const AiThinkingEvent('Inspecting personal records from database...');
      yield AiToolExecutingEvent('query_prs_and_history', call.arguments);
      final res = await _toolService.executeTool(call);
      executed.add(res);
      yield AiToolCompletedEvent(res);
      reply = res.summary;
    }
    // 7. General Assistant Greeting / Help
    else {
      reply = 'I am your AI Workout Coach with live app control!\n\n'
          'Here is what I can execute directly:\n'
          '• **Log Sets**: "Log 80kg x 8 on Bench Press"\n'
          '• **Start Timers**: "Rest 90 seconds"\n'
          '• **Web Search**: "Search best cues for barbell squat"\n'
          '• **Progressive Overload**: "Recommend weight for Bench Press"\n'
          '• **Create Routines**: "Create a 4-day hypertrophy split"\n'
          '• **Personal Records**: "Show my PRs and history"\n\n'
          '*Tip: To connect an AI model or custom API endpoint, open Settings > AI Assistant.*';
    }

    if (fallbackError != null) {
      reply += '\n\n*(Notice: Used local execution mode. Endpoint reported: $fallbackError)*';
    }

    yield const AiThinkingEvent('Streaming response...');
    final words = reply.split(' ');
    String accumulated = '';
    for (int i = 0; i < words.length; i++) {
      final delta = i == 0 ? words[i] : ' ${words[i]}';
      accumulated += delta;
      yield AiStreamChunkEvent(delta, accumulated);
      await Future.delayed(const Duration(milliseconds: 14));
    }

    yield AiCompleteEvent(
      AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: accumulated,
        timestamp: DateTime.now(),
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
        toolResults: executed.isNotEmpty ? executed : null,
      ),
    );
  }
}
