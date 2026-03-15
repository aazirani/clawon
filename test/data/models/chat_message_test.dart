import 'package:clawon/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage Serialization', () {
    group('toJson', () {
      test('serializes all required fields correctly', () {
        // Arrange: Create a message with all fields set
        final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');
        final message = ChatMessage(
          id: 'msg-123',
          role: MessageRole.user,
          content: 'Hello, world!',
          timestamp: timestamp,
        );

        // Act: Serialize to JSON
        final json = message.toJson();

        // Assert: Verify all fields are serialized correctly
        expect(json['id'], equals('msg-123'));
        expect(json['role'], equals('user'));
        expect(json['content'], equals('Hello, world!'));
        expect(json['timestamp'], equals('2024-01-15T10:30:00.000Z'));
      });

      test('serializes boolean flags correctly when true', () {
        // Arrange: Create a message with all boolean flags set to true
        final message = ChatMessage(
          id: 'msg-456',
          role: MessageRole.assistant,
          content: 'Response message',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isSending: true,
          isFailed: true,
          isStreaming: true,
        );

        // Act: Serialize to JSON
        final json = message.toJson();

        // Assert: Verify boolean flags are serialized
        expect(json['isSending'], isTrue);
        expect(json['isFailed'], isTrue);
        expect(json['isStreaming'], isTrue);
      });

      test('serializes boolean flags correctly when false', () {
        // Arrange: Create a message with all boolean flags set to false (default)
        final message = ChatMessage(
          id: 'msg-789',
          role: MessageRole.system,
          content: 'System message',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isSending: false,
          isFailed: false,
          isStreaming: false,
        );

        // Act: Serialize to JSON
        final json = message.toJson();

        // Assert: Verify boolean flags are serialized
        expect(json['isSending'], isFalse);
        expect(json['isFailed'], isFalse);
        expect(json['isStreaming'], isFalse);
      });

      test('serializes all message role types correctly', () {
        // Arrange: Create messages for each role type
        final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');

        final userMessage = ChatMessage(
          id: 'msg-user',
          role: MessageRole.user,
          content: 'User content',
          timestamp: timestamp,
        );

        final assistantMessage = ChatMessage(
          id: 'msg-assistant',
          role: MessageRole.assistant,
          content: 'Assistant content',
          timestamp: timestamp,
        );

        final systemMessage = ChatMessage(
          id: 'msg-system',
          role: MessageRole.system,
          content: 'System content',
          timestamp: timestamp,
        );

        // Act: Serialize each to JSON
        final userJson = userMessage.toJson();
        final assistantJson = assistantMessage.toJson();
        final systemJson = systemMessage.toJson();

        // Assert: Verify role names are correct
        expect(userJson['role'], equals('user'));
        expect(assistantJson['role'], equals('assistant'));
        expect(systemJson['role'], equals('system'));
      });
    });

    group('fromJson', () {
      test('deserializes all required fields correctly', () {
        // Arrange: Create JSON with all fields
        final json = {
          'id': 'msg-123',
          'role': 'user',
          'content': 'Hello, world!',
          'timestamp': '2024-01-15T10:30:00.000Z',
          'isSending': false,
          'isFailed': false,
          'isStreaming': false,
        };

        // Act: Deserialize from JSON
        final message = ChatMessage.fromJson(json);

        // Assert: Verify all fields are deserialized correctly
        expect(message.id, equals('msg-123'));
        expect(message.role, equals(MessageRole.user));
        expect(message.content, equals('Hello, world!'));
        expect(message.timestamp,
            equals(DateTime.parse('2024-01-15T10:30:00.000Z')));
      });

      test('deserializes all message role types correctly', () {
        // Arrange: Create JSON for each role type
        final userJson = {
          'id': 'msg-user',
          'role': 'user',
          'content': 'User content',
          'timestamp': '2024-01-15T10:30:00.000Z',
        };

        final assistantJson = {
          'id': 'msg-assistant',
          'role': 'assistant',
          'content': 'Assistant content',
          'timestamp': '2024-01-15T10:30:00.000Z',
        };

        final systemJson = {
          'id': 'msg-system',
          'role': 'system',
          'content': 'System content',
          'timestamp': '2024-01-15T10:30:00.000Z',
        };

        // Act: Deserialize each from JSON
        final userMessage = ChatMessage.fromJson(userJson);
        final assistantMessage = ChatMessage.fromJson(assistantJson);
        final systemMessage = ChatMessage.fromJson(systemJson);

        // Assert: Verify roles are correct
        expect(userMessage.role, equals(MessageRole.user));
        expect(assistantMessage.role, equals(MessageRole.assistant));
        expect(systemMessage.role, equals(MessageRole.system));
      });

      test('deserializes boolean flags correctly when true', () {
        // Arrange: Create JSON with all boolean flags set to true
        final json = {
          'id': 'msg-456',
          'role': 'assistant',
          'content': 'Response message',
          'timestamp': '2024-01-15T10:30:00.000Z',
          'isSending': true,
          'isFailed': true,
          'isStreaming': true,
        };

        // Act: Deserialize from JSON
        final message = ChatMessage.fromJson(json);

        // Assert: Verify boolean flags are deserialized
        expect(message.isSending, isTrue);
        expect(message.isFailed, isTrue);
        expect(message.isStreaming, isTrue);
      });

      test('defaults boolean flags to false when missing', () {
        // Arrange: Create JSON without boolean flags
        final json = {
          'id': 'msg-789',
          'role': 'system',
          'content': 'System message',
          'timestamp': '2024-01-15T10:30:00.000Z',
        };

        // Act: Deserialize from JSON
        final message = ChatMessage.fromJson(json);

        // Assert: Verify boolean flags default to false
        expect(message.isSending, isFalse);
        expect(message.isFailed, isFalse);
        expect(message.isStreaming, isFalse);
      });

      test('throws ArgumentError for invalid role name', () {
        // Arrange: Create JSON with invalid role
        final json = {
          'id': 'msg-invalid',
          'role': 'invalid_role',
          'content': 'Invalid message',
          'timestamp': '2024-01-15T10:30:00.000Z',
        };

        // Act & Assert: Should throw ArgumentError
        expect(
          () => ChatMessage.fromJson(json),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', contains('Unknown message role'))),
        );
      });
    });

    group('Round-trip Serialization', () {
      test('produces identical message after toJson -> fromJson', () {
        // Arrange: Create a message with all fields set
        final original = ChatMessage(
          id: 'msg-roundtrip',
          role: MessageRole.user,
          content: 'Round-trip test message',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isSending: true,
          isFailed: false,
          isStreaming: true,
        );

        // Act: Serialize then deserialize
        final json = original.toJson();
        final restored = ChatMessage.fromJson(json);

        // Assert: Verify all fields match
        expect(restored.id, equals(original.id));
        expect(restored.role, equals(original.role));
        expect(restored.content, equals(original.content));
        expect(restored.timestamp, equals(original.timestamp));
        expect(restored.isSending, equals(original.isSending));
        expect(restored.isFailed, equals(original.isFailed));
        expect(restored.isStreaming, equals(original.isStreaming));
      });

      test('preserves all role types through round-trip', () {
        // Arrange: Create messages for each role
        final timestamp = DateTime.parse('2024-01-15T10:30:00.000Z');
        final roles = [
          MessageRole.user,
          MessageRole.assistant,
          MessageRole.system,
        ];

        for (final role in roles) {
          final original = ChatMessage(
            id: 'msg-$role',
            role: role,
            content: 'Content for $role',
            timestamp: timestamp,
          );

          // Act: Round-trip serialization
          final json = original.toJson();
          final restored = ChatMessage.fromJson(json);

          // Assert: Verify role is preserved
          expect(restored.role, equals(role),
              reason: 'Role $role should be preserved through round-trip');
        }
      });
    });

    group('Factory Constructors', () {
      test('creates user message with correct defaults', () {
        // Arrange: Test data
        final content = 'User message content';

        // Act: Create user message
        final message = ChatMessage.user(content);

        // Assert: Verify defaults
        expect(message.role, equals(MessageRole.user));
        expect(message.content, equals(content));
        expect(message.isSending, isFalse);
        expect(message.isFailed, isFalse);
        expect(message.isStreaming, isFalse);
        expect(message.id, isNotEmpty);
        expect(message.timestamp, isNotNull);
      });

      test('creates assistant message with isStreaming default false', () {
        // Arrange: Test data
        final content = 'Assistant response';

        // Act: Create assistant message without isStreaming
        final message = ChatMessage.assistant(content);

        // Assert: Verify defaults
        expect(message.role, equals(MessageRole.assistant));
        expect(message.content, equals(content));
        expect(message.isStreaming, isFalse);
        expect(message.isSending, isFalse);
        expect(message.isFailed, isFalse);
        expect(message.id, isNotEmpty);
        expect(message.timestamp, isNotNull);
      });

      test('creates assistant message with isStreaming true', () {
        // Arrange: Test data
        final content = 'Streaming response';

        // Act: Create assistant message with isStreaming true
        final message = ChatMessage.assistant(content, isStreaming: true);

        // Assert: Verify isStreaming is set
        expect(message.role, equals(MessageRole.assistant));
        expect(message.content, equals(content));
        expect(message.isStreaming, isTrue);
        expect(message.isSending, isFalse);
        expect(message.isFailed, isFalse);
      });
    });

    group('copyWith', () {
      test('creates new message with updated id', () {
        // Arrange: Original message
        final original = ChatMessage(
          id: 'msg-123',
          role: MessageRole.user,
          content: 'Original content',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
        );

        // Act: Update id
        final updated = original.copyWith(id: 'msg-456');

        // Assert: Verify only id changed
        expect(updated.id, equals('msg-456'));
        expect(updated.role, equals(original.role));
        expect(updated.content, equals(original.content));
        expect(updated.timestamp, equals(original.timestamp));
      });

      test('creates new message with updated content', () {
        // Arrange: Original message
        final original = ChatMessage(
          id: 'msg-123',
          role: MessageRole.assistant,
          content: 'Original content',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
        );

        // Act: Update content
        final updated = original.copyWith(content: 'Updated content');

        // Assert: Verify only content changed
        expect(updated.id, equals(original.id));
        expect(updated.role, equals(original.role));
        expect(updated.content, equals('Updated content'));
        expect(updated.timestamp, equals(original.timestamp));
      });

      test('creates new message with updated isStreaming flag', () {
        // Arrange: Original message
        final original = ChatMessage(
          id: 'msg-123',
          role: MessageRole.assistant,
          content: 'Streaming content',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isStreaming: true,
        );

        // Act: Update isStreaming to false
        final updated = original.copyWith(isStreaming: false);

        // Assert: Verify isStreaming changed
        expect(updated.id, equals(original.id));
        expect(updated.role, equals(original.role));
        expect(updated.content, equals(original.content));
        expect(updated.timestamp, equals(original.timestamp));
        expect(updated.isStreaming, isFalse);
      });

      test('creates new message with multiple updates', () {
        // Arrange: Original message
        final original = ChatMessage(
          id: 'msg-123',
          role: MessageRole.user,
          content: 'Original content',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isSending: false,
        );

        // Act: Update multiple fields
        final updated = original.copyWith(
          content: 'New content',
          isSending: true,
          isFailed: true,
        );

        // Assert: Verify all specified fields changed
        expect(updated.id, equals(original.id));
        expect(updated.role, equals(original.role));
        expect(updated.content, equals('New content'));
        expect(updated.timestamp, equals(original.timestamp));
        expect(updated.isSending, isTrue);
        expect(updated.isFailed, isTrue);
        expect(updated.isStreaming, equals(original.isStreaming));
      });

      test('preserves original when no parameters provided', () {
        // Arrange: Original message
        final original = ChatMessage(
          id: 'msg-123',
          role: MessageRole.assistant,
          content: 'Content',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
          isStreaming: true,
        );

        // Act: Call copyWith with no parameters
        final updated = original.copyWith();

        // Assert: Verify all fields are the same
        expect(updated.id, equals(original.id));
        expect(updated.role, equals(original.role));
        expect(updated.content, equals(original.content));
        expect(updated.timestamp, equals(original.timestamp));
        expect(updated.isStreaming, equals(original.isStreaming));
      });
    });

    group('Edge Cases', () {
      test('handles empty content string', () {
        // Arrange: Create message with empty content
        final message = ChatMessage(
          id: 'msg-empty',
          role: MessageRole.user,
          content: '',
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
        );

        // Act: Serialize and deserialize
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        // Assert: Verify empty content is preserved
        expect(restored.content, equals(''));
      });

      test('handles special characters in content', () {
        // Arrange: Create message with special characters
        final specialContent = 'Hello "world"! 🎉\nNew line\tTab';
        final message = ChatMessage(
          id: 'msg-special',
          role: MessageRole.assistant,
          content: specialContent,
          timestamp: DateTime.parse('2024-01-15T10:30:00.000Z'),
        );

        // Act: Serialize and deserialize
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        // Assert: Verify special characters are preserved
        expect(restored.content, equals(specialContent));
      });

      test('handles DateTime with microseconds', () {
        // Arrange: Create message with precise timestamp
        final timestamp = DateTime.parse('2024-01-15T10:30:00.123456Z');
        final message = ChatMessage(
          id: 'msg-time',
          role: MessageRole.user,
          content: 'Content',
          timestamp: timestamp,
        );

        // Act: Serialize and deserialize
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        // Assert: Verify timestamp is preserved
        expect(restored.timestamp, equals(timestamp));
      });
    });
  });

  group('fromGatewayHistory', () {
    test('parses content array format with single text item', () {
      // Arrange: Gateway format with content array
      final json = {
        'id': 'msg-123',
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'Hello, world!'},
        ],
        'timestamp': 1705315800000, // Unix epoch in ms
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: Content is extracted correctly
      expect(message.id, equals('msg-123'));
      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('Hello, world!'));
      expect(message.timestamp,
          equals(DateTime.fromMillisecondsSinceEpoch(1705315800000)));
    });

    test('joins multiple text content items with newlines', () {
      // Arrange: Gateway format with multiple text items
      final json = {
        'id': 'msg-456',
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'First paragraph.'},
          {'type': 'text', 'text': 'Second paragraph.'},
        ],
        'timestamp': 1705315800000,
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: Multiple text items are joined with newlines
      expect(message.content, equals('First paragraph.\nSecond paragraph.'));
    });

    test('handles plain string content (backwards compat)', () {
      // Arrange: Legacy format with content as string
      final json = {
        'id': 'msg-789',
        'role': 'user',
        'content': 'Plain string content',
        'timestamp': '2024-01-15T10:30:00.000Z',
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: String content is preserved
      expect(message.content, equals('Plain string content'));
    });

    test('handles ISO8601 timestamp', () {
      // Arrange: ISO8601 timestamp format
      final json = {
        'id': 'msg-iso',
        'role': 'user',
        'content': 'Test',
        'timestamp': '2024-01-15T10:30:00.000Z',
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: ISO8601 timestamp is parsed correctly
      expect(message.timestamp, equals(DateTime.parse('2024-01-15T10:30:00.000Z')));
    });

    test('handles Unix epoch timestamp in milliseconds', () {
      // Arrange: Unix epoch in milliseconds
      final expectedTimestamp = DateTime.fromMillisecondsSinceEpoch(1705315800000);
      final json = {
        'id': 'msg-unix',
        'role': 'user',
        'content': 'Test',
        'timestamp': 1705315800000,
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: Unix timestamp is parsed correctly
      expect(message.timestamp, equals(expectedTimestamp));
    });

    test('extracts sessionKey', () {
      // Arrange: JSON with sessionKey
      final json = {
        'id': 'msg-session',
        'role': 'user',
        'content': 'Test',
        'timestamp': 1705315800000,
        'sessionKey': 'session-abc-123',
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: sessionKey is extracted
      expect(message.sessionKey, equals('session-abc-123'));
    });

    test('ignores non-text content types', () {
      // Arrange: Content array with mixed types
      final json = {
        'id': 'msg-mixed',
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'Text content'},
          {'type': 'image', 'url': 'https://example.com/image.png'},
          {'type': 'text', 'text': 'More text'},
        ],
        'timestamp': 1705315800000,
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: Only text content is extracted, non-text is ignored
      expect(message.content, equals('Text content\nMore text'));
    });

    test('throws ArgumentError for missing role', () {
      // Arrange: JSON without role
      final json = {
        'id': 'msg-no-role',
        'content': 'Test',
        'timestamp': 1705315800000,
      };

      // Act & Assert: Should throw ArgumentError
      expect(
        () => ChatMessage.fromGatewayHistory(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid role', () {
      // Arrange: JSON with invalid role
      final json = {
        'id': 'msg-invalid-role',
        'role': 'invalid_role',
        'content': 'Test',
        'timestamp': 1705315800000,
      };

      // Act & Assert: Should throw ArgumentError
      expect(
        () => ChatMessage.fromGatewayHistory(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('defaults timestamp to now when missing', () {
      // Arrange: JSON without timestamp
      final before = DateTime.now();
      final json = {
        'id': 'msg-no-ts',
        'role': 'user',
        'content': 'Test',
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);
      final after = DateTime.now();

      // Assert: Timestamp is set to approximately now
      expect(message.timestamp.isAfter(before.subtract(Duration(seconds: 1))), isTrue);
      expect(message.timestamp.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('defaults to empty content when missing', () {
      // Arrange: JSON without content
      final json = {
        'id': 'msg-no-content',
        'role': 'user',
        'timestamp': 1705315800000,
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: Content defaults to empty string
      expect(message.content, equals(''));
    });

    test('generates UUID when id is missing', () {
      // Arrange: JSON without id
      final json = {
        'role': 'user',
        'content': 'Test',
        'timestamp': 1705315800000,
      };

      // Act: Parse from gateway history
      final message = ChatMessage.fromGatewayHistory(json);

      // Assert: A UUID is generated
      expect(message.id, isNotEmpty);
      expect(message.id.length, greaterThanOrEqualTo(36)); // UUID format
    });

    group('gateway metadata prefix stripping', () {
      // The OpenClaw gateway prepends conversation context to every user
      // message it sends to Claude. fromGatewayHistory must strip it.

      const metadataPreamble = 'Conversation info (untrusted metadata):\n'
          '```json\n'
          '{\n'
          '  "message_id": "10b3b7ba-4735-41bc-8295-ab45057edbfa",\n'
          '  "sender_id": "openclaw-macos",\n'
          '  "sender": "openclaw-macos"\n'
          '}\n'
          '```\n';

      test('strips metadata preamble and gateway timestamp from user message',
          () {
        final json = {
          'role': 'user',
          'content': '${metadataPreamble}[Sun 2026-03-15 17:19 GMT+1] Hi',
          'timestamp': 1705315800000,
        };

        final message = ChatMessage.fromGatewayHistory(json);

        expect(message.content, equals('Hi'));
      });

      test('strips metadata preamble and keeps text when no timestamp prefix',
          () {
        final json = {
          'role': 'user',
          'content': '${metadataPreamble}Hello without timestamp',
          'timestamp': 1705315800000,
        };

        final message = ChatMessage.fromGatewayHistory(json);

        expect(message.content, equals('Hello without timestamp'));
      });

      test('leaves assistant messages untouched even if they match the pattern',
          () {
        final content =
            '${metadataPreamble}[Sun 2026-03-15 17:19 GMT+1] Some text';
        final json = {
          'role': 'assistant',
          'content': content,
          'timestamp': 1705315800000,
        };

        final message = ChatMessage.fromGatewayHistory(json);

        // Assistant messages should not be stripped
        expect(message.content, equals(content));
      });

      test('leaves regular user messages without the header untouched', () {
        final json = {
          'role': 'user',
          'content': 'Just a plain message',
          'timestamp': 1705315800000,
        };

        final message = ChatMessage.fromGatewayHistory(json);

        expect(message.content, equals('Just a plain message'));
      });

      test('strips metadata from list content blocks', () {
        final json = {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': '${metadataPreamble}[Mon 2026-03-16 09:00 UTC] Good morning',
            }
          ],
          'timestamp': 1705315800000,
        };

        final message = ChatMessage.fromGatewayHistory(json);

        expect(message.content, equals('Good morning'));
      });
    });
  });
}
