class AiUserMemory {
  final String id;
  final String fact;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiUserMemory({
    required this.id,
    required this.fact,
    this.category = 'general',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fact': fact,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiUserMemory.fromMap(Map<String, dynamic> map) {
    return AiUserMemory(
      id: map['id']?.toString() ?? 'mem_${DateTime.now().millisecondsSinceEpoch}',
      fact: map['fact']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AiUserMemory copyWith({
    String? id,
    String? fact,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiUserMemory(
      id: id ?? this.id,
      fact: fact ?? this.fact,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
