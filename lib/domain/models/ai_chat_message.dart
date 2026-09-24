class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };

  factory AiToolCall.fromMap(Map<String, dynamic> map) {
    return AiToolCall(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      arguments: (map['arguments'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class AiToolExecutionResult {
  final String toolName;
  final bool success;
  final String summary;
  final dynamic data;
  /// How long this tool took to execute, in milliseconds
  final int? durationMs;

  const AiToolExecutionResult({
    required this.toolName,
    required this.success,
    required this.summary,
    this.data,
    this.durationMs,
  });

  Map<String, dynamic> toMap() => {
        'toolName': toolName,
        'success': success,
        'summary': summary,
        'data': data,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory AiToolExecutionResult.fromMap(Map<String, dynamic> map) {
    return AiToolExecutionResult(
      toolName: (map['toolName'] as String?) ?? '',
      success: (map['success'] as bool?) ?? true,
      summary: (map['summary'] as String?) ?? '',
      data: map['data'],
      durationMs: (map['durationMs'] as num?)?.toInt(),
    );
  }
}

class AiChatMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system' | 'tool'
  final String content;
  final DateTime timestamp;
  final List<AiToolCall>? toolCalls;
  final List<AiToolExecutionResult>? toolResults;
  final bool isError;
  final bool isStreaming;
  final String? liveThinking;
  final String? liveToolStatus;
  final List<String>? thoughtSteps;
  final String? imageAttachmentPath;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.toolResults,
    this.thoughtSteps,
    this.isError = false,
    this.isStreaming = false,
    this.liveThinking,
    this.liveToolStatus,
    this.imageAttachmentPath,
  });

  AiChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    List<AiToolCall>? toolCalls,
    List<AiToolExecutionResult>? toolResults,
    List<String>? thoughtSteps,
    bool? isError,
    bool? isStreaming,
    String? liveThinking,
    String? liveToolStatus,
    String? imageAttachmentPath,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
      thoughtSteps: thoughtSteps ?? this.thoughtSteps,
      isError: isError ?? this.isError,
      isStreaming: isStreaming ?? this.isStreaming,
      liveThinking: liveThinking ?? this.liveThinking,
      liveToolStatus: liveToolStatus ?? this.liveToolStatus,
      imageAttachmentPath: imageAttachmentPath ?? this.imageAttachmentPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'toolCalls': toolCalls?.map((t) => t.toMap()).toList(),
        'toolResults': toolResults?.map((r) => r.toMap()).toList(),
        if (thoughtSteps != null) 'thoughtSteps': thoughtSteps,
        'isError': isError,
        'imageAttachmentPath': imageAttachmentPath,
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    return AiChatMessage(
      id: (map['id'] as String?) ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: (map['role'] as String?) ?? 'assistant',
      content: (map['content'] as String?) ?? '',
      timestamp: DateTime.tryParse((map['timestamp'] as String?) ?? '') ?? DateTime.now(),
      toolCalls: (map['toolCalls'] as List?)
          ?.map((t) => AiToolCall.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
      toolResults: (map['toolResults'] as List?)
          ?.map((r) => AiToolExecutionResult.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
      thoughtSteps: (map['thoughtSteps'] as List?)?.map((e) => e.toString()).toList(),
      isError: (map['isError'] as bool?) ?? false,
      imageAttachmentPath: map['imageAttachmentPath'] as String?,
    );
  }
}

sealed class AiAssistantEvent {
  const AiAssistantEvent();
}

class AiThinkingEvent extends AiAssistantEvent {
  final String status;
  const AiThinkingEvent(this.status);
}

class AiToolExecutingEvent extends AiAssistantEvent {
  final String toolName;
  final Map<String, dynamic> arguments;
  const AiToolExecutingEvent(this.toolName, this.arguments);
}

class AiToolCompletedEvent extends AiAssistantEvent {
  final AiToolExecutionResult result;
  const AiToolCompletedEvent(this.result);
}

class AiStreamChunkEvent extends AiAssistantEvent {
  final String textDelta;
  final String accumulatedText;
  const AiStreamChunkEvent(this.textDelta, this.accumulatedText);
}

class AiCompleteEvent extends AiAssistantEvent {
  final AiChatMessage message;
  const AiCompleteEvent(this.message);
}

class AiErrorEvent extends AiAssistantEvent {
  final String error;
  const AiErrorEvent(this.error);
}

/// Represents one saved conversation session
class AiChatSession {
  final String id;
  final String title; // auto-derived from first user message
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final String previewText; // snippet of last message

  const AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    required this.previewText,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'messageCount': messageCount,
        'previewText': previewText,
      };

  factory AiChatSession.fromMap(Map<String, dynamic> map) {
    return AiChatSession(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Chat',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
      lastMessageAt: DateTime.tryParse((map['lastMessageAt'] as String?) ?? '') ?? DateTime.now(),
      messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
      previewText: (map['previewText'] as String?) ?? '',
    );
  }

  AiChatSession copyWith({
    String? title,
    DateTime? lastMessageAt,
    int? messageCount,
    String? previewText,
  }) {
    return AiChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      previewText: previewText ?? this.previewText,
    );
  }
}
