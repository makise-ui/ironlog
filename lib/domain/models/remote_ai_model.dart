class RemoteAiModel {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final bool isFree;

  const RemoteAiModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.isFree = false,
  });

  factory RemoteAiModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['name']?.toString() ?? '';
    final name = json['name']?.toString() ?? id;
    final desc = json['description']?.toString();
    final ctx = (json['context_length'] ?? json['contextLength']) as num?;

    // Check if model is free (e.g. Kilo isFree, OpenRouter pricing, :free in id)
    bool free = json['isFree'] == true;
    if (!free && json['pricing'] is Map) {
      final pricing = json['pricing'] as Map;
      final prompt = pricing['prompt']?.toString();
      final completion = pricing['completion']?.toString();
      if ((prompt == '0' || prompt == '0.0' || prompt == '0.000000') &&
          (completion == '0' || completion == '0.0' || completion == '0.000000')) {
        free = true;
      }
    }
    if (!free) {
      final lowerId = id.toLowerCase();
      final lowerName = name.toLowerCase();
      if (lowerId.contains(':free') || lowerId.endsWith('/free') || lowerName.contains('(free)')) {
        free = true;
      }
    }

    return RemoteAiModel(
      id: id,
      name: name,
      description: desc,
      contextLength: ctx?.toInt(),
      isFree: free,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'contextLength': contextLength,
        'isFree': isFree,
      };
}
