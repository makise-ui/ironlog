import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/remote_ai_model.dart';
import '../models/ai_config_model.dart';

class AiModelFetcherService {
  AiModelFetcherService._();

  /// Fetches available models from an OpenAI-compatible /models endpoint (Kilo, OpenRouter, Groq, Ollama, LM Studio, OpenAI).
  static Future<List<RemoteAiModel>> fetchModels({
    required String baseUrl,
    String? apiKey,
    AiProvider? provider,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      var cleanUrl = baseUrl.trim();
      while (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      if (cleanUrl.isEmpty) {
        throw Exception('Base URL cannot be empty');
      }

      // Generate endpoint candidate URLs
      final candidateUrls = <String>[];
      if (cleanUrl.endsWith('/models')) {
        candidateUrls.add(cleanUrl);
      } else {
        candidateUrls.add('$cleanUrl/models');
        if (!cleanUrl.endsWith('/v1')) {
          candidateUrls.add('$cleanUrl/v1/models');
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
        throw Exception(lastError ?? 'Unable to connect to models endpoint at $baseUrl');
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
