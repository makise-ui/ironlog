import 'package:flutter/foundation.dart';

enum SuggestionType {
  progress,
  stall,
  fatigue,
  comeback,
  balance,
  nextWorkout,
  pr,
}

@immutable
class Suggestion {
  final String id;
  final SuggestionType type;
  final String title;
  final String body;
  final String reasonCode;
  final double confidence;
  final Map<String, dynamic> payload;
  final String ruleName;
  final String explanation;
  final String? actionLabel;
  final VoidCallback? onAction;

  const Suggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.reasonCode,
    required this.confidence,
    this.payload = const {},
    required this.ruleName,
    required this.explanation,
    this.actionLabel,
    this.onAction,
  });
}
