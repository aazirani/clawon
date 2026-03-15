class Connection {
  final String id;
  final String name;
  final String gatewayUrl;
  final String token;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? agentId;
  final String? agentName;

  Connection({
    required this.id,
    required this.name,
    required this.gatewayUrl,
    required this.token,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.agentId,
    this.agentName,
  });

  Connection copyWith({
    String? id,
    String? name,
    String? gatewayUrl,
    String? token,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? agentId,
    String? agentName,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
    );
  }
}
