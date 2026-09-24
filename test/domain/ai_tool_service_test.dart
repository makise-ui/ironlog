import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/ai_tool_service.dart';
import 'package:ironlog/domain/models/ai_config_model.dart';

void main() {
  group('AiToolService Tool Definitions & Edit Tools', () {
    test('openAiToolDefinitions contains all necessary CRUD and edit tools', () {
      final tools = AiToolService.openAiToolDefinitions;
      final toolNames = tools
          .map((t) => (t['function'] as Map<String, dynamic>)['name'] as String)
          .toSet();

      // Verify all 8 Edit and App-Control tools are present
      expect(toolNames, contains('edit_set'));
      expect(toolNames, contains('delete_set'));
      expect(toolNames, contains('remove_exercise'));
      expect(toolNames, contains('edit_workout'));
      expect(toolNames, contains('delete_workout'));
      expect(toolNames, contains('edit_routine'));
      expect(toolNames, contains('delete_routine'));
      expect(toolNames, contains('edit_exercise'));
      expect(toolNames, contains('edit_setting'));
      expect(toolNames, contains('create_custom_exercise'));
      expect(toolNames, contains('set_rest_day'));

      // Core functionality tools
      expect(toolNames, contains('get_today_workout'));
      expect(toolNames, contains('search_web'));
      expect(toolNames, contains('log_set'));
      expect(toolNames, contains('add_exercise'));
      expect(toolNames, contains('start_workout'));
      expect(toolNames, contains('finish_workout'));
      expect(toolNames, contains('create_routine'));
      expect(toolNames, contains('start_rest_timer'));
      expect(toolNames, contains('recommend_weights'));
      expect(toolNames, contains('query_prs_and_history'));
      expect(toolNames, contains('export_backup'));
      expect(toolNames, contains('calculate_warmup_sets'));
      expect(toolNames, contains('analyze_muscle_balance'));
      expect(toolNames, contains('get_exercise_technique'));
    });

    test('get_today_workout tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'get_today_workout',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('date'), true);
    });

    test('create_custom_exercise tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'create_custom_exercise',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('name'), true);
      expect(properties.containsKey('muscleGroup'), true);
      expect(properties.containsKey('equipment'), true);
      expect(params['required'], contains('name'));
    });

    test('set_rest_day tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'set_rest_day',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('date'), true);
      expect(properties.containsKey('isRest'), true);
      expect(properties.containsKey('note'), true);
    });

    test('log_set tool definition supports date parameter for past day logging', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'log_set',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('date'), true);
    });

    test('edit_set tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'edit_set',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('exerciseName'), true);
      expect(properties.containsKey('setIndex'), true);
      expect(properties.containsKey('weight'), true);
      expect(properties.containsKey('reps'), true);
      expect(properties.containsKey('setType'), true);
      expect(properties.containsKey('rpe'), true);
    });

    test('edit_workout tool definition has appropriate schema', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'edit_workout',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('title'), true);
      expect(properties.containsKey('note'), true);
      expect(properties.containsKey('feel'), true);
    });

    test('edit_routine tool definition has appropriate schema', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'edit_routine',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('routineName'), true);
      expect(properties.containsKey('newName'), true);
      expect(properties.containsKey('newCategory'), true);
      expect(properties.containsKey('addExercises'), true);
      expect(properties.containsKey('removeExercises'), true);
      expect(properties.containsKey('setExercises'), true);
    });

    test('edit_exercise tool definition has appropriate schema', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'edit_exercise',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('exerciseName'), true);
      expect(properties.containsKey('newName'), true);
      expect(properties.containsKey('muscleGroup'), true);
      expect(properties.containsKey('restSeconds'), true);
      expect(properties.containsKey('repMin'), true);
      expect(properties.containsKey('repMax'), true);
      expect(properties.containsKey('archive'), true);
    });

    test('edit_setting tool definition has valid schema and required fields', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'edit_setting',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('key'), true);
      expect(properties.containsKey('value'), true);
      final requiredFields = params['required'] as List;
      expect(requiredFields, containsAll(['key', 'value']));
    });

    test('delete_workout tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'delete_workout',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('workoutId'), true);
      expect(properties.containsKey('date'), true);
      expect(properties.containsKey('confirmed'), true);
    });

    test('delete_routine tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'delete_routine',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('routineName'), true);
      expect(params['required'], contains('routineName'));
    });

    test('calculate_warmup_sets tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'calculate_warmup_sets',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('exerciseName'), true);
      expect(properties.containsKey('targetWeight'), true);
      expect(properties.containsKey('barWeight'), true);
      expect(properties.containsKey('addToWorkout'), true);
      expect(params['required'], contains('exerciseName'));
      expect(params['required'], contains('targetWeight'));
    });

    test('analyze_muscle_balance tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'analyze_muscle_balance',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('days'), true);
    });

    test('get_exercise_technique tool definition has appropriate schema and parameters', () {
      final tool = AiToolService.openAiToolDefinitions.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'get_exercise_technique',
      );
      final functionDef = tool['function'] as Map<String, dynamic>;
      final params = functionDef['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('exerciseName'), true);
      expect(properties.containsKey('focus'), true);
      expect(params['required'], contains('exerciseName'));
    });
  });

  group('AiConfigModel tests', () {
    test('requireApiKey defaults to false and serializes properly', () {
      const config = AiConfigModel();
      expect(config.requireApiKey, false);
      expect(config.provider, AiProvider.universal);

      final map = config.toMap();
      expect(map['requireApiKey'], false);

      final decoded = AiConfigModel.fromMap(map);
      expect(decoded.requireApiKey, false);

      final updated = config.copyWith(requireApiKey: true);
      expect(updated.requireApiKey, true);
      expect(updated.toMap()['requireApiKey'], true);
    });
  });
}
