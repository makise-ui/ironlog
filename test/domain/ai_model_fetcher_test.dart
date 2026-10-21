import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironlog/domain/services/ai_model_fetcher_service.dart';

void main() {
  group('AiModelFetcherService URL Resolution Tests', () {
    test('normalizeBaseUrl strips trailing slashes, /chat/completions and /models', () {
      expect(
        AiModelFetcherService.normalizeBaseUrl('https://api.kilo.ai/api/gateway/'),
        equals('https://api.kilo.ai/api/gateway'),
      );
      expect(
        AiModelFetcherService.normalizeBaseUrl('https://api.kilo.ai/api/gateway/chat/completions'),
        equals('https://api.kilo.ai/api/gateway'),
      );
      expect(
        AiModelFetcherService.normalizeBaseUrl('https://api.kilo.ai/api/gateway/models/'),
        equals('https://api.kilo.ai/api/gateway'),
      );
      expect(
        AiModelFetcherService.normalizeBaseUrl('https://api.openai.com/v1'),
        equals('https://api.openai.com/v1'),
      );
      expect(
        AiModelFetcherService.normalizeBaseUrl('https://api.openai.com/v1/chat/completions'),
        equals('https://api.openai.com/v1'),
      );
      expect(
        AiModelFetcherService.normalizeBaseUrl('http://localhost:11434'),
        equals('http://localhost:11434'),
      );
    });

    test('resolveModelsEndpoint appends /models directly to url without injecting /v1', () {
      // For Kilo gateway: directly /gateway/models (no /v1)
      expect(
        AiModelFetcherService.resolveModelsEndpoint('https://api.kilo.ai/api/gateway'),
        equals('https://api.kilo.ai/api/gateway/models'),
      );
      expect(
        AiModelFetcherService.resolveModelsEndpoint('https://api.kilo.ai/api/gateway/chat/completions'),
        equals('https://api.kilo.ai/api/gateway/models'),
      );
      // For OpenAI or providers with /v1: directly /v1/models
      expect(
        AiModelFetcherService.resolveModelsEndpoint('https://api.openai.com/v1'),
        equals('https://api.openai.com/v1/models'),
      );
      expect(
        AiModelFetcherService.resolveModelsEndpoint('https://openrouter.ai/api/v1/chat/completions'),
        equals('https://openrouter.ai/api/v1/models'),
      );
    });

    test('resolveChatEndpoint appends /chat/completions directly to url', () {
      expect(
        AiModelFetcherService.resolveChatEndpoint('https://api.kilo.ai/api/gateway'),
        equals('https://api.kilo.ai/api/gateway/chat/completions'),
      );
      expect(
        AiModelFetcherService.resolveChatEndpoint('https://api.openai.com/v1'),
        equals('https://api.openai.com/v1/chat/completions'),
      );
    });

    test('fetchModels retrieves and prioritizes free models from direct endpoint', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://api.kilo.ai/api/gateway/models') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'paid/llama-3.1-70b',
                  'name': 'Llama 3.1 70B',
                  'pricing': {'prompt': '0.0005', 'completion': '0.0005'},
                },
                {
                  'id': 'kilo-auto/free',
                  'name': 'Kilo Auto Free',
                  'isFree': true,
                },
                {
                  'id': 'meta-llama/llama-3-8b:free',
                  'name': 'Llama 3 8B Free',
                },
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final models = await AiModelFetcherService.fetchModels(
        baseUrl: 'https://api.kilo.ai/api/gateway',
        client: mockClient,
      );

      expect(models.length, equals(3));
      // First two should be the free models (isFree = true)
      expect(models[0].isFree, isTrue);
      expect(models[1].isFree, isTrue);
      expect(models[2].isFree, isFalse);
      expect(models[2].id, equals('paid/llama-3.1-70b'));
    });
  });
}
