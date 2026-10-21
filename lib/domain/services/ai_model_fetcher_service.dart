import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/remote_ai_model.dart';
import '../models/ai_config_model.dart';

class AiModelFetcherService {
  AiModelFetcherService._();

  /// Normalizes any user-entered base or endpoint URL into its clean base URL.
  /// Handles URLs ending in /chat/completions, /models, trailing slashes, etc.
  static String normalizeBaseUrl(String rawUrl) {
    var clean = rawUrl.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.endsWith('/chat/completions')) {
      clean = clean.substring(0, clean.length - '/chat/completions'.length);
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
    } else if (clean.endsWith('/models')) {
      clean = clean.substring(0, clean.length - '/models'.length);
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
    }
    return clean;
  }

  /// Builds the direct /models endpoint from the user's base URL.
  /// Directly appends /models to the normalized URL (e.g., https://api.kilo.ai/api/gateway -> .../models,
  /// or https://api.openai.com/v1 -> .../models).
  /// Users do not need to place /v1 in the endpoint.
  static String resolveModelsEndpoint(String rawUrl) {
    final clean = normalizeBaseUrl(rawUrl);
    return '$clean/models';
  }

  /// Builds the chat completions endpoint from the user's base URL.
  /// Directly appends /chat/completions to the normalized URL.
  static String resolveChatEndpoint(String rawUrl) {
    final clean = normalizeBaseUrl(rawUrl);
    return '$clean/chat/completions';
  }

  /// Fetches available models from an OpenAI-compatible /models endpoint (Kilo, OpenRouter, Groq, Ollama, LM Studio, OpenAI).
  static Future<List<RemoteAiModel>> fetchModels({
    required String baseUrl,
    String? apiKey,
    AiProvider? provider,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final cleanBase = normalizeBaseUrl(baseUrl);
      if (cleanBase.isEmpty) {
        throw Exception('Base URL cannot be empty');
      }

      // Generate endpoint candidate URLs:
      // 1. Direct /models from the user's provided URL:
      //    e.g. "https://api.kilo.ai/api/gateway" -> "https://api.kilo.ai/api/gateway/models"
      //    e.g. "https://api.openai.com/v1" -> "https://api.openai.com/v1/models"
      //    No need to place /v1 in the endpoint.
      final directModelsUrl = '$cleanBase/models';
      final candidateUrls = <String>[directModelsUrl];

      // 2. Fallbacks only if direct resolution fails:
      if (!cleanBase.endsWith('/v1') && !cleanBase.contains('/gateway')) {
        candidateUrls.add('$cleanBase/v1/models');
      }
      if (cleanBase.endsWith('/v1')) {
        final rootBase = cleanBase.substring(0, cleanBase.length - 3);
        if (rootBase.isNotEmpty) {
          candidateUrls.add('$rootBase/models');
        }
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${apiKey.trim()}';
      }

      http.Response? successfulResponse;
      Object? lastError;

      for (final url in candidateUrls) {
        try {
          final uri = Uri.parse(url);
          final res = await httpClient.get(uri, headers: headers).timeout(
            const Duration(seconds: 10),
          );
          if (res.statusCode >= 200 && res.statusCode < 300) {
            successfulResponse = res;
            break;
          } else {
            lastError = 'HTTP ${res.statusCode}: ${res.body.length > 120 ? res.body.substring(0, 120) : res.body}';
          }
        } catch (e) {
          lastError = e;
        }
      }

      if (successfulResponse == null) {
        throw Exception(lastError ?? 'Unable to connect to models endpoint at $directModelsUrl');
      }

      final decoded = jsonDecode(successfulResponse.body);
      final rawList = decoded is Map
          ? (decoded['data'] ?? decoded['models'] ?? [])
          : (decoded is List ? decoded : []);

      if (rawList is! List) return [];

      final models = <RemoteAiModel>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          models.add(RemoteAiModel.fromJson(item));
        } else if (item is Map) {
          models.add(RemoteAiModel.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String) {
          models.add(RemoteAiModel(id: item, name: item));
        }
      }

      // Sort: free models first, then alphabetical by model id
      models.sort((a, b) {
        if (a.isFree != b.isFree) {
          return a.isFree ? -1 : 1;
        }
        return a.id.toLowerCase().compareTo(b.id.toLowerCase());
      });

      return models;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
