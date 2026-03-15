/// Represents an agent available on an OpenClaw gateway
class Agent {
  final String id;
  final String? name;
  final String? emoji;

  Agent({
    required this.id,
    this.name,
    this.emoji,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    final identity = json['identity'] as Map<String, dynamic>?;
    return Agent(
      id: json['id'] as String,
      name: identity?['name'] as String? ?? json['name'] as String?,
      emoji: identity?['emoji'] as String?,
    );
  }

  /// Display label for UI: "emoji name" or "name" or "id"
  String get displayLabel {
    final parts = <String>[];
    if (emoji != null) parts.add(emoji!);
    parts.add(name ?? id);
    return parts.join(' ');
  }
}
