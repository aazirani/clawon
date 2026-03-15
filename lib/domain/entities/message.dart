import '../../data/models/chat_message.dart';

class Message {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final MessageStatus status;
  final String? sessionKey; // Session scoping

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.status = MessageStatus.sent,
    this.sessionKey,
  });

  // Convert from data model
  static Message fromDataModel(ChatMessage model) {
    return Message(
      id: model.id,
      role: model.role.name,
      content: model.content,
      timestamp: model.timestamp,
      isStreaming: model.isStreaming,
      status: model.status,
      sessionKey: model.sessionKey,
    );
  }
}
