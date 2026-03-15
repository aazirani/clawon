/// Represents a gateway session
class GatewaySession {
  final String sessionKey; // Unique session identifier from gateway
  final String sessionId; // Legacy ID (may be same as sessionKey)
  final String title;
  final DateTime createdAt;
  final DateTime lastActive; // Renamed from updatedAt for clarity
  final int messageCount;
  final String? agentId;
  final String? agentName;
  final String? agentEmoji;
  final String? kind; // Session kind (e.g., 'main', 'tool', 'subtask')
  final List<dynamic>? messages; // Optional: messages from initial fetch
  final String? lastMessagePreview; // Truncated preview of last message

  GatewaySession({
    required this.sessionKey,
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.lastActive,
    required this.messageCount,
    this.agentId,
    this.agentName,
    this.agentEmoji,
    this.kind,
    this.messages,
    this.lastMessagePreview,
  });

  GatewaySession copyWith({
    String? sessionKey,
    String? sessionId,
    String? title,
    DateTime? createdAt,
    DateTime? lastActive,
    int? messageCount,
    String? agentId,
    String? agentName,
    String? agentEmoji,
    String? kind,
    List<dynamic>? messages,
    String? lastMessagePreview,
  }) {
    return GatewaySession(
      sessionKey: sessionKey ?? this.sessionKey,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      messageCount: messageCount ?? this.messageCount,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      agentEmoji: agentEmoji ?? this.agentEmoji,
      kind: kind ?? this.kind,
      messages: messages ?? this.messages,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionKey': sessionKey,
      'sessionId': sessionId,
      'title': title,
      'agentId': agentId,
      'agentName': agentName,
      if (agentEmoji != null) 'agentEmoji': agentEmoji,
      'kind': kind,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'messageCount': messageCount,
      if (messages != null) 'messages': messages,
    };
  }

  factory GatewaySession.fromJson(Map<String, dynamic> json) {
    return GatewaySession(
      sessionKey: json['sessionKey'] as String? ?? json['sessionId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? json['sessionKey'] ?? json['sessionId'] ?? '',
      agentId: json['agentId'] as String?,
      agentName: json['agentName'] as String?,
      agentEmoji: json['agentEmoji'] as String?,
      kind: json['kind'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : DateTime.now(),
      messageCount: json['messageCount'] as int? ?? 0,
      messages: json['messages'] as List<dynamic>?,
    );
  }
}
