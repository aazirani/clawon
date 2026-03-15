import 'dart:async';

import 'package:clawon/data/services/device_identity_service.dart';
import 'package:clawon/domain/entities/connection.dart';
import 'package:clawon/domain/entities/connection_state.dart';
import 'package:clawon/domain/exceptions/duplicate_connection_exception.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/connection_repository.dart';
import 'package:clawon/presentation/connections/store/connections_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionRepository extends Mock implements ConnectionRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockDeviceIdentityService extends Mock implements DeviceIdentityService {}

void main() {
  late ConnectionsStore store;
  late MockConnectionRepository mockRepository;
  late MockChatRepository mockChatRepository;
  late MockDeviceIdentityService mockDeviceIdentityService;

  setUp(() {
    mockRepository = MockConnectionRepository();
    mockChatRepository = MockChatRepository();
    mockDeviceIdentityService = MockDeviceIdentityService();
    // Set up default fallback values for any unstubbed calls
    final now = DateTime.now();
    registerFallbackValue(Connection(
      id: 'fallback',
      name: 'Fallback',
      gatewayUrl: 'https://fallback.com',
      token: 'fallback-token',
      createdAt: now,
    ));
    when(() => mockChatRepository.connectionMetadataUpdates)
        .thenAnswer((_) => const Stream<String>.empty());
    when(() => mockChatRepository.connectionStatus(any()))
        .thenAnswer((_) => const Stream<ConnectionStatus>.empty());
    when(() => mockChatRepository.getWebSocketConnection(any()))
        .thenReturn(null);
    // Default: no device tokens stored
    when(() => mockDeviceIdentityService.getDeviceToken(any()))
        .thenAnswer((_) async => null);
    store = ConnectionsStore(mockRepository, mockChatRepository, mockDeviceIdentityService);
  });

  group('ConnectionsStore', () {
    final tConnection1 = Connection(
      id: '1',
      name: 'Connection 1',
      gatewayUrl: 'https://example.com/api',
      token: 'token1',
      createdAt: DateTime(2025, 1, 1, 10, 0),
      lastMessageAt: DateTime(2025, 1, 2, 12, 0),
      lastMessagePreview: 'Hello',
    );

    final tConnection2 = Connection(
      id: '2',
      name: 'Connection 2',
      gatewayUrl: 'https://example2.com/api',
      token: 'token2',
      createdAt: DateTime(2025, 1, 1, 9, 0),
      lastMessageAt: DateTime(2025, 1, 3, 14, 0),
      lastMessagePreview: 'World',
    );

    final tConnection3 = Connection(
      id: '3',
      name: 'Connection 3',
      gatewayUrl: 'https://example3.com/api',
      token: 'token3',
      createdAt: DateTime(2025, 1, 4, 8, 0),
      lastMessageAt: null, // No messages yet
      lastMessagePreview: null,
    );

    test(
        'loadConnections should load and sort connections by lastMessageAt descending',
        () async {
      // Arrange
      final connections = [tConnection1, tConnection2, tConnection3];
      when(() => mockRepository.getConnections())
          .thenAnswer((_) async => connections);

      // Act
      await store.loadConnections();

      // Assert
      expect(store.isLoading, false);
      expect(store.connections.length, 3);
      // Should be sorted by lastMessageAt descending
      // t3: 2025-01-04 08:00 (createdAt, no lastMessageAt) - NEWEST createdAt
      // t2: 2025-01-03 14:00 (lastMessageAt)
      // t1: 2025-01-02 12:00 (lastMessageAt) - OLDEST
      expect(
          store.connections[0].id, '3'); // No messages, uses createdAt (newest)
      expect(store.connections[1].id, '2'); // Most recent message
      expect(store.connections[2].id, '1');
      verify(() => mockRepository.getConnections()).called(1);
    });

    test('loadConnections should set loading state correctly', () async {
      // Arrange
      when(() => mockRepository.getConnections())
          .thenAnswer((_) async => [tConnection1]);

      // Act
      final future = store.loadConnections();
      expect(store.isLoading, true);
      await future;
      expect(store.isLoading, false);
    });

    test('deleteConnection should remove connection from list', () async {
      // Arrange
      store.connections.addAll([tConnection1, tConnection2]);
      when(() => mockRepository.deleteConnection('1')).thenAnswer((_) async {});

      // Act
      await store.deleteConnection('1');

      // Assert
      expect(store.connections.length, 1);
      expect(store.connections[0].id, '2');
      verify(() => mockRepository.deleteConnection('1')).called(1);
    });

    test('addConnection should add new connection at top of list', () async {
      // Arrange
      store.connections.addAll([tConnection1, tConnection2]);
      when(() => mockRepository.saveConnection(any())).thenAnswer((_) async {});

      // Act
      final result = await store.addConnection(
        name: 'New Connection',
        gatewayUrl: 'https://new.com/api',
        token: 'newtoken',
      );

      // Assert
      expect(store.connections.length, 3);
      expect(store.connections[0].id, result.id); // Should be at top
      expect(result.name, 'New Connection');
      expect(result.gatewayUrl, 'https://new.com/api');
      expect(result.token, 'newtoken');
      verify(() => mockRepository.saveConnection(any())).called(1);
    });

    test('addConnection should generate unique IDs', () async {
      // Arrange
      when(() => mockRepository.saveConnection(any())).thenAnswer((_) async {});

      // Act - create two connections quickly
      final conn1 = await store.addConnection(
        name: 'Connection 1',
        gatewayUrl: 'https://example1.com',
        token: 'token1',
      );

      // Add a small delay to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));

      final conn2 = await store.addConnection(
        name: 'Connection 2',
        gatewayUrl: 'https://example2.com',
        token: 'token2',
      );

      // Assert
      expect(conn1.id, isNot(equals(conn2.id)));
    });

    test('updateConnection should update existing connection', () async {
      // Arrange
      store.connections.addAll([tConnection1, tConnection2]);
      when(() => mockRepository.updateConnection(any()))
          .thenAnswer((_) async {});

      final updatedConnection = Connection(
        id: '1',
        name: 'Updated Connection 1',
        gatewayUrl: 'https://updated.com/api',
        token: 'updatedtoken',
        createdAt: tConnection1.createdAt,
        lastMessageAt: DateTime(2025, 1, 5, 10, 0), // Newer message
        lastMessagePreview: 'Updated preview',
      );

      // Act
      await store.updateConnection(updatedConnection);

      // Assert
      expect(store.connections.length, 2);
      final updated = store.connections.firstWhere((c) => c.id == '1');
      expect(updated.name, 'Updated Connection 1');
      expect(updated.gatewayUrl, 'https://updated.com/api');
      expect(updated.token, 'updatedtoken');
      verify(() => mockRepository.updateConnection(updatedConnection))
          .called(1);
    });

    test('updateConnection should re-sort connections after update', () async {
      // Arrange
      store.connections.addAll([tConnection1, tConnection2]);
      // t2 is first (more recent), t1 is second

      when(() => mockRepository.updateConnection(any()))
          .thenAnswer((_) async {});

      final updatedConnection = Connection(
        id: '1',
        name: 'Connection 1',
        gatewayUrl: tConnection1.gatewayUrl,
        token: tConnection1.token,
        createdAt: tConnection1.createdAt,
        lastMessageAt: DateTime(2025, 1, 10, 10, 0), // Even newer than t2
        lastMessagePreview: 'New message',
      );

      // Act
      await store.updateConnection(updatedConnection);

      // Assert - t1 should now be first
      expect(store.connections[0].id, '1');
      expect(store.connections[1].id, '2');
    });

    test('updateConnection with non-existent ID should not modify list',
        () async {
      // Arrange
      store.connections.addAll([tConnection1, tConnection2]);
      when(() => mockRepository.updateConnection(any()))
          .thenAnswer((_) async {});

      final nonExistentConnection = Connection(
        id: '999',
        name: 'Non-existent',
        gatewayUrl: 'https://nonexistent.com',
        token: 'token',
        createdAt: DateTime.now(),
      );

      // Act
      await store.updateConnection(nonExistentConnection);

      // Assert
      expect(store.connections.length, 2);
      expect(store.connections[0].id, '1'); // Updated with newest lastMessageAt
      expect(store.connections[1].id, '2');
      verify(() => mockRepository.updateConnection(nonExistentConnection))
          .called(1);
    });

    test('loadConnections should handle empty list', () async {
      // Arrange
      when(() => mockRepository.getConnections()).thenAnswer((_) async => []);

      // Act
      await store.loadConnections();

      // Assert
      expect(store.connections.isEmpty, true);
      expect(store.isLoading, false);
    });

    group('duplicate detection', () {
      test('addConnection throws when exact same URL and token already exists',
          () async {
        store.connections.add(Connection(
          id: 'existing',
          name: 'Existing',
          gatewayUrl: 'wss://example.com/gateway',
          token: 'mytoken',
          createdAt: DateTime.now(),
        ));

        expect(
          () => store.addConnection(
            name: 'Duplicate',
            gatewayUrl: 'wss://example.com/gateway',
            token: 'mytoken',
          ),
          throwsA(isA<DuplicateConnectionException>()),
        );
      });

      test(
          'addConnection throws when ws:// and wss:// point to the same server',
          () async {
        store.connections.add(Connection(
          id: 'existing',
          name: 'Existing',
          gatewayUrl: 'ws://example.com/gateway',
          token: 'mytoken',
          createdAt: DateTime.now(),
        ));

        expect(
          () => store.addConnection(
            name: 'Duplicate via wss',
            gatewayUrl: 'wss://example.com/gateway',
            token: 'mytoken',
          ),
          throwsA(isA<DuplicateConnectionException>()),
        );
      });

      test(
          'addConnection allows same URL with different token',
          () async {
        when(() => mockRepository.saveConnection(any())).thenAnswer((_) async {});
        store.connections.add(Connection(
          id: 'existing',
          name: 'Existing',
          gatewayUrl: 'wss://example.com/gateway',
          token: 'token-a',
          createdAt: DateTime.now(),
        ));

        // Different token — should not throw
        await store.addConnection(
          name: 'Different token',
          gatewayUrl: 'wss://example.com/gateway',
          token: 'token-b',
        );
        expect(store.connections.length, 2);
      });
    });

    test(
        'loadConnections should sort connections with only createdAt when no lastMessageAt',
        () async {
      // Arrange
      final conn1 = Connection(
        id: '1',
        name: 'Connection 1',
        gatewayUrl: 'https://example1.com',
        token: 'token1',
        createdAt: DateTime(2025, 1, 1, 10, 0),
      );
      final conn2 = Connection(
        id: '2',
        name: 'Connection 2',
        gatewayUrl: 'https://example2.com',
        token: 'token2',
        createdAt: DateTime(2025, 1, 2, 10, 0), // Newer
      );
      when(() => mockRepository.getConnections())
          .thenAnswer((_) async => [conn1, conn2]);

      // Act
      await store.loadConnections();

      // Assert
      expect(store.connections.length, 2);
      expect(store.connections[0].id, '2'); // Newer createdAt first
      expect(store.connections[1].id, '1');
    });

    group('connectionErrors', () {
      test('connectionErrors should store error when status has errorMessage', () async {
        final statusController = StreamController<ConnectionStatus>();
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);

        await store.loadConnections();

        // Emit a failed status with an error message
        statusController.add(ConnectionStatus(
          state: ConnectionState.failed,
          errorMessage: 'Authentication failed',
        ));
        await Future.microtask(() {});

        expect(store.connectionErrors['1'], 'Authentication failed');
        statusController.close();
      });

      test('connectionErrors should clear error when state recovers', () async {
        final statusController = StreamController<ConnectionStatus>();
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);

        await store.loadConnections();

        // First emit failed with error
        statusController.add(ConnectionStatus(
          state: ConnectionState.failed,
          errorMessage: 'Something went wrong',
        ));
        await Future.microtask(() {});
        expect(store.connectionErrors['1'], isNotNull);

        // Then emit connected with no error
        statusController.add(ConnectionStatus(
          state: ConnectionState.connected,
          errorMessage: null,
        ));
        await Future.microtask(() {});
        expect(store.connectionErrors['1'], isNull);
        statusController.close();
      });

      test('connectionErrors should clear when connection is removed', () async {
        final statusController = StreamController<ConnectionStatus>();
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);
        when(() => mockRepository.deleteConnection('1')).thenAnswer((_) async {});

        await store.loadConnections();
        statusController.add(ConnectionStatus(
          state: ConnectionState.failed,
          errorMessage: 'Auth failed',
        ));
        await Future.microtask(() {});
        expect(store.connectionErrors['1'], isNotNull);

        // Delete the connection
        when(() => mockRepository.getConnections()).thenAnswer((_) async => []);
        await store.loadConnections();

        expect(store.connectionErrors.containsKey('1'), isFalse);
        statusController.close();
      });
    });

    group('pairing status', () {
      test('loadConnections loads pairing status for all connections', () async {
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1, tConnection2]);
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'device-token-abc');
        when(() => mockDeviceIdentityService.getDeviceToken('2'))
            .thenAnswer((_) async => null);

        await store.loadConnections();

        expect(store.pairingStatus['1'], isTrue);
        expect(store.pairingStatus['2'], isFalse);
      });

      test('isPaired returns true for paired connection', () async {
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'device-token-abc');

        await store.loadConnections();

        expect(store.isPaired('1'), isTrue);
      });

      test('isPaired returns false for unpaired connection', () async {
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => null);

        await store.loadConnections();

        expect(store.isPaired('1'), isFalse);
      });

      test('isPaired returns false for unknown connection', () {
        expect(store.isPaired('unknown'), isFalse);
      });

      test('unpairConnection clears device token and updates pairing status', () async {
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'device-token-abc');
        when(() => mockChatRepository.disconnect('1')).thenAnswer((_) async {});
        when(() => mockDeviceIdentityService.deleteDeviceToken('1'))
            .thenAnswer((_) async {});

        await store.loadConnections();
        expect(store.isPaired('1'), isTrue);

        await store.unpairConnection('1');

        expect(store.isPaired('1'), isFalse);
        expect(store.connectionStates['1'], ConnectionState.disconnected);
        verify(() => mockDeviceIdentityService.deleteDeviceToken('1')).called(1);
        verify(() => mockChatRepository.disconnect('1')).called(1);
      });

      test('connecting triggers pairing status refresh and shows badge immediately', () async {
        final statusController = StreamController<ConnectionStatus>();
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);
        // Not paired initially
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => null);

        await store.loadConnections();
        expect(store.isPaired('1'), isFalse);

        // Now pairing happens (device token stored externally)
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'new-device-token');
        when(() => mockRepository.updateConnection(any())).thenAnswer((_) async {});

        // Connection becomes connected (gateway issued device token)
        statusController.add(ConnectionStatus(
          state: ConnectionState.connected,
          errorMessage: null,
        ));
        await Future.delayed(const Duration(milliseconds: 10));

        expect(store.isPaired('1'), isTrue);
        statusController.close();
      });

      test('on connect with new pairing, token is cleared from DB', () async {
        final statusController = StreamController<ConnectionStatus>();
        final connectionWithToken = tConnection1;
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [connectionWithToken]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);
        // Not paired initially
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => null);

        await store.loadConnections();
        expect(store.connections[0].token, 'token1');

        // Pairing occurs (device token issued by gateway)
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'new-device-token');
        when(() => mockRepository.updateConnection(any())).thenAnswer((_) async {});

        statusController.add(ConnectionStatus(
          state: ConnectionState.connected,
          errorMessage: null,
        ));
        await Future.delayed(const Duration(milliseconds: 10));

        // Token should be cleared in DB and in memory
        verify(() => mockRepository.updateConnection(
          any(that: predicate<Connection>((c) => c.token == '')),
        )).called(1);
        expect(store.connections[0].token, '');
        statusController.close();
      });

      test('on connect when already paired, token is not cleared again', () async {
        final statusController = StreamController<ConnectionStatus>();
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockChatRepository.connectionStatus('1'))
            .thenAnswer((_) => statusController.stream);
        // Already paired from the start
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'existing-device-token');

        await store.loadConnections();
        expect(store.isPaired('1'), isTrue);

        statusController.add(ConnectionStatus(
          state: ConnectionState.connected,
          errorMessage: null,
        ));
        await Future.delayed(const Duration(milliseconds: 10));

        // updateConnection should NOT be called since already paired
        verifyNever(() => mockRepository.updateConnection(any()));
        statusController.close();
      });

      test('unpairConnection clears connection error', () async {
        when(() => mockRepository.getConnections())
            .thenAnswer((_) async => [tConnection1]);
        when(() => mockDeviceIdentityService.getDeviceToken('1'))
            .thenAnswer((_) async => 'device-token-abc');
        when(() => mockChatRepository.disconnect('1')).thenAnswer((_) async {});
        when(() => mockDeviceIdentityService.deleteDeviceToken('1'))
            .thenAnswer((_) async {});

        await store.loadConnections();
        store.connectionErrors['1'] = 'Some error';

        await store.unpairConnection('1');

        expect(store.connectionErrors.containsKey('1'), isFalse);
      });
    });
  });
}
