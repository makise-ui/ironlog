import 'dart:convert';

enum AiProvider {
  universal,
  gemini,
  openai,
  anthropic,
}

extension AiProviderExtension on AiProvider {
  String get displayName {
    switch (this) {
      case AiProvider.universal:
        return 'Universal (OpenAI-Compatible)';
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.openai:
        return 'OpenAI (ChatGPT)';
      case AiProvider.anthropic:
        return 'Anthropic (Claude)';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case AiProvider.universal:
        return 'https://api.kilo.ai/api/gateway';
      case AiProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AiProvider.openai:
        return 'https://api.openai.com/v1';
      case AiProvider.anthropic:
        return 'https://api.anthropic.com/v1';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProvider.universal:
        return 'kilo-auto/free';
      case AiProvider.gemini:
        return 'gemini-1.5-flash';
      case AiProvider.openai:
        return 'gpt-4o-mini';
      case AiProvider.anthropic:
        return 'claude-3-5-haiku-20241022';
    }
  }

  String get apiKeyUrl {
    switch (this) {
      case AiProvider.universal:
        return '';
      case AiProvider.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case AiProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case AiProvider.anthropic:
        return 'https://console.anthropic.com/settings/keys';
    }
  }
}

class AiConfigModel {
  final String id;
  final String name;
  final AiProvider provider;
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final double temperature;
  final bool enableWebSearch;
  final bool requireApiKey;

  const AiConfigModel({
    this.id = 'kilo_free',
    this.name = 'Default AI Coach',
    this.provider = AiProvider.universal,
    this.apiKey = '',
    this.baseUrl = 'https://api.kilo.ai/api/gateway',
    this.modelName = 'kilo-auto/free',
    this.temperature = 0.7,
    this.enableWebSearch = true,
    this.requireApiKey = false,
  });

  static List<AiConfigModel> get defaultProfiles => const [
    AiConfigModel(
      id: 'kilo_free',
      name: 'Default AI Coach',
      provider: AiProvider.universal,
      baseUrl: 'https://api.kilo.ai/api/gateway',
      modelName: 'kilo-auto/free',
      apiKey: '',
      requireApiKey: false,
    ),
    AiConfigModel(
      id: 'ollama_local',
      name: 'Ollama (Local)',
      provider: AiProvider.universal,
      baseUrl: 'http://localhost:11434/v1',
      modelName: 'llama3.2',
      apiKey: '',
      requireApiKey: false,
    ),
    AiConfigModel(
      id: 'openai_mini',
      name: 'OpenAI GPT-4o Mini',
      provider: AiProvider.openai,
      baseUrl: 'https://api.openai.com/v1',
      modelName: 'gpt-4o-mini',
      apiKey: '',
      requireApiKey: true,
    ),
    AiConfigModel(
      id: 'gemini_flash',
      name: 'Google Gemini Flash',
      provider: AiProvider.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      modelName: 'gemini-1.5-flash',
      apiKey: '',
      requireApiKey: true,
    ),
    AiConfigModel(
      id: 'anthropic_haiku',
      name: 'Anthropic Claude 3.5 Haiku',
      provider: AiProvider.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      modelName: 'claude-3-5-haiku-20241022',
      apiKey: '',
      requireApiKey: true,
    ),
  ];

  AiConfigModel copyWith({
    String? id,
    String? name,
    AiProvider? provider,
    String? apiKey,
    String? baseUrl,
    String? modelName,
    double? temperature,
    bool? enableWebSearch,
    bool? requireApiKey,
  }) {
    return AiConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      temperature: temperature ?? this.temperature,
      enableWebSearch: enableWebSearch ?? this.enableWebSearch,
      requireApiKey: requireApiKey ?? this.requireApiKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider': provider.name,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'modelName': modelName,
      'temperature': temperature,
      'enableWebSearch': enableWebSearch,
      'requireApiKey': requireApiKey,
    };
  }

  factory AiConfigModel.fromMap(Map<String, dynamic> map) {
    AiProvider p = AiProvider.universal;
    final pStr = map['provider'] as String?;
    if (pStr != null) {
      if (pStr == 'agnes' || pStr == 'custom') {
        p = AiProvider.universal;
      } else {
        p = AiProvider.values.firstWhere(
          (e) => e.name == pStr,
          orElse: () => AiProvider.universal,
        );
      }
    }

    final id = (map['id'] as String?) ?? 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final name = (map['name'] as String?) ?? (p == AiProvider.universal ? 'Kilo Free' : p.displayName);

    return AiConfigModel(
      id: id,
      name: name,
      provider: p,
      apiKey: (map['apiKey'] as String?) ?? '',
      baseUrl: (map['baseUrl'] as String?) ?? (p == AiProvider.universal ? 'https://api.kilo.ai/api/gateway' : p.defaultBaseUrl),
      modelName: (map['modelName'] as String?) ?? (p == AiProvider.universal ? 'kilo-auto/free' : p.defaultModel),
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      enableWebSearch: (map['enableWebSearch'] as bool?) ?? true,
      requireApiKey: (map['requireApiKey'] as bool?) ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AiConfigModel.fromJson(String source) =>
      AiConfigModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
