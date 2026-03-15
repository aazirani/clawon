import 'package:flutter_test/flutter_test.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:clawon/data/models/chat_message.dart';

void main() {
  group('Message', () {
    group('fromDataModel', () {
      test('should copy all fields from ChatMessage including sessionKey', () {
        // Arrange
        final chatMessage = ChatMessage(
          id: 'test-id',
          role: MessageRole.assistant,
          content: 'Test content',
          timestamp: DateTime(2024, 1, 1, 12, 0),
          isStreaming: true,
          status: MessageStatus.sent,
          sessionKey: 'session-123',
        );

        // Act
        final message = Message.fromDataModel(chatMessage);

        // Assert
        expect(message.id, 'test-id');
        expect(message.role, 'assistant');
        expect(message.content, 'Test content');
        expect(message.timestamp, DateTime(2024, 1, 1, 12, 0));
        expect(message.isStreaming, true);
        expect(message.status, MessageStatus.sent);
        expect(message.sessionKey, 'session-123');
      });

      test('should handle null sessionKey', () {
        // Arrange
        final chatMessage = ChatMessage(
          id: 'test-id',
          role: MessageRole.user,
          content: 'User message',
          timestamp: DateTime.now(),
          sessionKey: null,
        );

        // Act
        final message = Message.fromDataModel(chatMessage);

        // Assert
        expect(message.sessionKey, isNull);
      });

      test('should convert MessageRole enum to string', () {
        // Arrange
        final userMessage = ChatMessage(
          id: 'user-1',
          role: MessageRole.user,
          content: 'User',
          timestamp: DateTime.now(),
        );
        final assistantMessage = ChatMessage(
          id: 'assistant-1',
          role: MessageRole.assistant,
          content: 'Assistant',
          timestamp: DateTime.now(),
        );

        // Act
        final userResult = Message.fromDataModel(userMessage);
        final assistantResult = Message.fromDataModel(assistantMessage);

        // Assert
        expect(userResult.role, 'user');
        expect(assistantResult.role, 'assistant');
      });
    });
  });
}
