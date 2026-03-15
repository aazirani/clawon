import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../local/database/app_database.dart' as db;

const _uuid = Uuid();

/// Message role (sender)
enum MessageRole { user, assistant, system, toolResult }

/// Message delivery status
enum MessageStatus {
  sending,
  sent,
  queued,
  failed,
}

/// A single chat message
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isSending; // True while sending
  final bool isFailed; // True if send failed
  final bool isStreaming; // True while streaming
  final MessageStatus status; // Delivery status
  final String? sessionKey; // Session scoping

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isSending = false,
    this.isFailed = false,
    this.isStreaming = false,
    this.status = MessageStatus.sent,
    this.sessionKey,
  });

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isSending,
    bool? isFailed,
    bool? isStreaming,
    MessageStatus? status,
    String? sessionKey,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSending: isSending ?? this.isSending,
      isFailed: isFailed ?? this.isFailed,
      isStreaming: isStreaming ?? this.isStreaming,
      status: status ?? this.status,
      sessionKey: sessionKey ?? this.sessionKey,
    );
  }

  // Create user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  // Create assistant message from agent response
  factory ChatMessage.assistant(String content, {bool isStreaming = false}) {
    return ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      isStreaming: isStreaming,
    );
  }

  /// Create from Drift ChatMessage row
  factory ChatMessage.fromDriftRow(db.ChatMessage row) {
    final role = MessageRole.values.firstWhere(
      (e) => e.name == row.role,
      orElse: () => throw ArgumentError('Unknown message role: ${row.role}'),
    );

    final status = MessageStatus.values.firstWhere(
      (e) => e.name == row.status,
      orElse: () => MessageStatus.sent,
    );

    return ChatMessage(
      id: row.id,
      role: role,
      content: row.content,
      timestamp: row.timestamp,
      isSending: row.isSending,
      isFailed: row.isFailed,
      isStreaming: row.isStreaming,
      status: status,
      sessionKey: row.sessionKey,
    );
  }

  /// Convert to Drift Companion for insert/update
  db.ChatMessagesCompanion toDriftCompanion(
    String connectionId, [
    String? sessionKey,
  ]) {
    return db.ChatMessagesCompanion(
      id: Value(id),
      connectionId: Value(connectionId),
      sessionKey: Value.absentIfNull(sessionKey),
      role: Value(role.name),
      content: Value(content),
      timestamp: Value(timestamp),
      isSending: Value(isSending),
      isFailed: Value(isFailed),
      isStreaming: Value(isStreaming),
      status: Value(status.name),
    );
  }

  /// Convert to JSON for serialization (e.g., API requests/responses)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isSending': isSending,
      'isFailed': isFailed,
      'isStreaming': isStreaming,
      'status': status.name,
      if (sessionKey != null) 'sessionKey': sessionKey,
    };
  }

  /// Strips the gateway-injected metadata preamble from user message content.
  ///
  /// The OpenClaw gateway wraps every user message it sends to Claude with a
  /// metadata header so the model knows who sent it and from which client.
  /// That header must not be shown in the chat UI.
  ///
  /// Expected format (markdown):
  ///   Conversation info (untrusted metadata):\n```json\n{...}\n```\n[timestamp] text
  ///
  /// Returns the raw message text with the preamble and gateway timestamp
  /// removed. If the pattern is not found the content is returned unchanged.
  /// Public so other display layers (e.g. session list preview) can reuse it.
  static String stripGatewayMetadataPrefix(String content) {
    const header = 'Conversation info (untrusted metadata):';
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith(header)) return content;

    // Find opening ``` after the header
    final openFence = trimmed.indexOf('```', header.length);
    if (openFence == -1) return content;

    // Find closing ``` (the one after the JSON block)
    final closeFence = trimmed.indexOf('```', openFence + 3);
    if (closeFence == -1) return content;

    // Everything after the closing fence is the actual message
    final afterFence = trimmed.substring(closeFence + 3).trimLeft();

    // Strip optional gateway timestamp: [Day YYYY-MM-DD HH:MM TZ]
    final withoutTimestamp =
        afterFence.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');

    return withoutTimestamp.isEmpty ? afterFence : withoutTimestamp;
  }

  /// Create ChatMessage from JSON (for serialization)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handle role - can be string or null
    final roleStr = json['role'] is String ? json['role'] as String : null;
    if (roleStr == null) {
      throw ArgumentError('Message role is required: ${json.keys.toList()}, json: $json');
    }

    final role = MessageRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => throw ArgumentError('Unknown message role: $roleStr'),
    );

    // Handle status - can be string, list, or null/missing
    MessageStatus status = MessageStatus.sent;
    final statusValue = json['status'];
    if (statusValue is String) {
      status = MessageStatus.values.firstWhere(
        (e) => e.name == statusValue,
        orElse: () => MessageStatus.sent,
      );
    }

    return ChatMessage(
      id: json['id'] is String ? json['id'] as String : _uuid.v4(),
      role: role,
      content: json['content'] is String ? json['content'] as String : '',
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isSending: json['isSending'] is bool ? json['isSending'] as bool : false,
      isFailed: json['isFailed'] is bool ? json['isFailed'] as bool : false,
      isStreaming: json['isStreaming'] is bool ? json['isStreaming'] as bool : false,
      status: status,
      sessionKey: json['sessionKey'] is String ? json['sessionKey'] as String : null,
    );
  }

  /// Create ChatMessage from gateway history API format.
  ///
  /// The gateway returns content as an array of content objects:
  /// `[{"type": "text", "text": "..."}, {"type": "image", ...}]`
  /// This factory extracts text content by joining all text items.
  ///
  /// Timestamp can be Unix epoch (ms) or ISO8601 string.
  ///
  /// When the gateway doesn't provide an `id`, a deterministic UUID v5 is
  /// generated from role + timestamp + content so that repeated syncs produce
  /// the same ID and the DB upsert deduplicates correctly.
  factory ChatMessage.fromGatewayHistory(Map<String, dynamic> json) {
    // Parse role
    final roleStr = json['role'] as String?;
    if (roleStr == null) throw ArgumentError('Message role is required');
    final role = MessageRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => throw ArgumentError('Unknown message role: $roleStr'),
    );

    // Parse content - can be String or List (gateway format)
    String content;
    final contentValue = json['content'];
    if (contentValue is String) {
      content = contentValue;
    } else if (contentValue is List) {
      content = contentValue
          .whereType<Map<String, dynamic>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String? ?? '')
          .join('\n');
    } else {
      content = '';
    }

    // The gateway prepends conversation metadata to every user message it
    // forwards to Claude. Strip it so users only see the actual text.
    //
    // Format the gateway produces:
    //   Conversation info (untrusted metadata):
    //   ```json
    //   { "message_id": "...", "sender_id": "...", "sender": "..." }
    //   ```
    //   [Day YYYY-MM-DD HH:MM TZ] actual message text
    if (role == MessageRole.user) {
      content = stripGatewayMetadataPrefix(content);
    }

    // Parse timestamp - Unix epoch (ms) or ISO8601
    DateTime timestamp;
    final ts = json['timestamp'];
    if (ts is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      timestamp = DateTime.parse(ts);
    } else {
      timestamp = DateTime.now();
    }

    // Generate deterministic ID from message content when gateway provides none
    final String id;
    if (json['id'] is String) {
      id = json['id'] as String;
    } else {
      final contentKey = content.length > 200 ? content.substring(0, 200) : content;
      final name = '${role.name}:${timestamp.millisecondsSinceEpoch}:$contentKey';
      id = const Uuid().v5(Namespace.url.value, name);
    }

    return ChatMessage(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      sessionKey: json['sessionKey'] as String?,
    );
  }
}
