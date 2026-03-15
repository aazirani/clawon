import 'dart:collection';

class QueuedMessage {
  final String id;
  final String connectionId;
  final String? sessionKey; // For session-scoped routing
  final String content;
  final DateTime queuedAt;

  QueuedMessage({
    required this.id,
    required this.connectionId,
    this.sessionKey,
    required this.content,
    required this.queuedAt,
  });
}

class MessageQueue {
  final Queue<QueuedMessage> _queue = Queue();

  void enqueue(QueuedMessage message) {
    _queue.add(message);
  }

  List<QueuedMessage> drainForConnection(String connectionId) {
    final messages = _queue.where((m) => m.connectionId == connectionId).toList();
    _queue.removeWhere((m) => m.connectionId == connectionId);
    return messages;
  }

  /// Remove a specific message from the queue by ID
  void removeMessage(String id) {
    _queue.removeWhere((m) => m.id == id);
  }

  bool get isEmpty => _queue.isEmpty;
}
