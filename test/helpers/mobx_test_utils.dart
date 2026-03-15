import 'dart:async';

import 'package:clawon/domain/entities/connection_state.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:mobx/mobx.dart';

/// Utility functions for testing MobX stores
class MobXTestUtils {
  /// Waits for MobX reactions to complete with proper microtask flushing
  ///
  /// Includes microtask flushing to ensure event loop processing.
  /// This is more reliable than arbitrary delays.
  ///
  /// [duration] Total wait time including reaction delay plus buffer (default 250ms)
  static Future<void> waitForReaction([
    Duration duration = const Duration(milliseconds: 250),
  ]) async {
    // Flush microtasks first (MobX reactions are scheduled as microtasks)
    await Future.microtask(() {});

    // Then wait for the reaction delay plus buffer
    await Future.delayed(duration);

    // Flush again to catch any delayed microtasks
    await Future.microtask(() {});
  }

  /// Runs code within a MobX action ensuring proper tracking
  ///
  /// Use this when directly modifying @observable properties in tests.
  static T runInTestAction<T>(T Function() fn) {
    return runInAction(fn);
  }

  /// Repeatedly executes a function until a condition is met or timeout
  ///
  /// Useful for waiting for specific state changes in tests.
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 1),
    Duration interval = const Duration(milliseconds: 10),
  }) async {
    final start = DateTime.now();
    while (!condition()) {
      if (DateTime.now().difference(start) > timeout) {
        throw TimeoutException('Condition not met within $timeout');
      }
      await Future.delayed(interval);
    }
  }

  /// Creates a fake repository with proper stream control
  static FakeChatRepository createFakeRepository() {
    return FakeChatRepository();
  }
}

/// Fake chat repository for testing with stream control
class FakeChatRepository {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messagesController = StreamController<List<Message>>.broadcast();
  final _agentResponsesController = StreamController<Message>.broadcast();

  void emitConnectionState(ConnectionStatus status) {
    _statusController.add(status);
  }

  void emitMessages(List<Message> messages) {
    _messagesController.add(messages);
  }

  void emitAgentResponse(Message message) {
    _agentResponsesController.add(message);
  }

  void dispose() {
    _statusController.close();
    _messagesController.close();
    _agentResponsesController.close();
  }

  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;

  Stream<List<Message>> get messages => _messagesController.stream;

  Stream<Message> get agentResponses => _agentResponsesController.stream;

  Future<void> connect(String url, String token) async {}

  Future<void> disconnect() async {}

  Future<void> sendMessage(String content) async {}
}
