import 'package:flutter_test/flutter_test.dart';
import 'package:clawon/data/services/active_session_registry.dart';

void main() {
  late ActiveSessionRegistry registry;

  setUp(() {
    registry = ActiveSessionRegistry();
  });

  tearDown(() {
    registry.dispose();
  });

  group('Single session', () {
    test('getLastSessionKey returns the only registered session', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionKey = 'session-a';

      // Act
      registry.registerSession(connectionId, sessionKey);

      // Assert
      expect(registry.getLastSessionKey(connectionId), equals(sessionKey));
    });

    test('getLastSessionKey returns null when no session registered', () {
      // Assert
      expect(registry.getLastSessionKey('conn-1'), isNull);
    });

    test('sessionBelongsTo returns true for registered session', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionKey = 'session-a';
      registry.registerSession(connectionId, sessionKey);

      // Assert
      expect(registry.sessionBelongsTo(connectionId, sessionKey), isTrue);
    });

    test('sessionBelongsTo returns false for unknown session', () {
      // Arrange
      const connectionId = 'conn-1';
      registry.registerSession(connectionId, 'session-a');

      // Assert
      expect(registry.sessionBelongsTo(connectionId, 'session-z'), isFalse);
    });

    test('sessionBelongsTo returns false for null sessionKey', () {
      // Arrange
      const connectionId = 'conn-1';
      registry.registerSession(connectionId, 'session-a');

      // Assert
      expect(registry.sessionBelongsTo(connectionId, null), isFalse);
    });
  });

  group('Multi-session runId routing', () {
    test('getSessionKeyForRunId returns correct key after registerRunId', () {
      // Arrange
      const connectionId = 'conn-1';
      const runIdA = 'run-a';
      const sessionA = 'session-a';

      registry.registerSession(connectionId, sessionA);
      registry.registerRunId(connectionId, runIdA, sessionA);

      // Act & Assert
      expect(registry.getSessionKeyForRunId(runIdA), equals(sessionA));
    });

    test('getSessionKeyForRunId returns the right key, not the last session', () {
      // Arrange — two sessions registered; runId only belongs to session A
      const connectionId = 'conn-1';
      const runIdA = 'run-a';
      const sessionA = 'session-a';
      const sessionB = 'session-b';

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB);
      registry.registerRunId(connectionId, runIdA, sessionA);

      // Act
      final resolved = registry.getSessionKeyForRunId(runIdA);
      final last = registry.getLastSessionKey(connectionId);

      // Assert — runId maps to sessionA, while lastSessionKey is sessionB
      expect(resolved, equals(sessionA));
      expect(last, equals(sessionB));
      expect(resolved, isNot(equals(last)));
    });

    test('runIdBelongsTo returns true for registered connection', () {
      // Arrange
      const connectionId = 'conn-1';
      const runId = 'run-1';
      registry.registerRunId(connectionId, runId, 'session-a');

      // Assert
      expect(registry.runIdBelongsTo(connectionId, runId), isTrue);
    });

    test('runIdBelongsTo returns false for different connection', () {
      // Arrange
      registry.registerRunId('conn-1', 'run-1', 'session-a');

      // Assert
      expect(registry.runIdBelongsTo('conn-2', 'run-1'), isFalse);
    });

    test('runIdBelongsTo returns false for null runId', () {
      // Assert
      expect(registry.runIdBelongsTo('conn-1', null), isFalse);
    });
  });

  group('"started" handler fix — single registration with event sessionKey', () {
    test('registers runId with event sessionKey when provided', () {
      // Arrange — simulate "started" handler logic after the fix
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';
      const runId = 'run-1';
      const eventSessionKey = sessionA;

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB); // sessionB is now last

      // Act — prefer event sessionKey over getLastSessionKey (the fix)
      final resolvedSessionKey =
          (eventSessionKey.isNotEmpty) ? eventSessionKey : registry.getLastSessionKey(connectionId);
      registry.registerRunId(connectionId, runId, resolvedSessionKey);

      // Assert — runId maps to sessionA, not sessionB (the last)
      expect(registry.getSessionKeyForRunId(runId), equals(sessionA));
      expect(registry.getLastSessionKey(connectionId), equals(sessionB));
    });

    test('falls back to getLastSessionKey when event sessionKey is absent', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const runId = 'run-1';
      const String? eventSessionKey = null; // no sessionKey in event

      registry.registerSession(connectionId, sessionA);

      // Act — simulate fix: prefer event sessionKey; fall back when null
      final resolvedSessionKey =
          (eventSessionKey != null && eventSessionKey.isNotEmpty)
              ? eventSessionKey
              : registry.getLastSessionKey(connectionId);
      registry.registerRunId(connectionId, runId, resolvedSessionKey);

      // Assert — falls back to last session
      expect(registry.getSessionKeyForRunId(runId), equals(sessionA));
    });

    test('does not overwrite first runId mapping when second session registers', () {
      // Arrange — two concurrent sessions, each with their own runId
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';
      const runIdA = 'run-a';
      const runIdB = 'run-b';

      registry.registerSession(connectionId, sessionA);
      registry.registerRunId(connectionId, runIdA, sessionA);

      registry.registerSession(connectionId, sessionB);
      registry.registerRunId(connectionId, runIdB, sessionB);

      // Assert — each runId still maps to its own session
      expect(registry.getSessionKeyForRunId(runIdA), equals(sessionA));
      expect(registry.getSessionKeyForRunId(runIdB), equals(sessionB));
    });
  });

  group('Lifecycle end fix — clearing waiting state for correct session', () {
    test('getSessionKeyForRunId used as primary lookup before getLastSessionKey', () {
      // Arrange — simulate lifecycle end handler logic after the fix
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';
      const runIdA = 'run-a';

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB); // sessionB is now last
      registry.registerRunId(connectionId, runIdA, sessionA);

      // Act — simulate fix: prefer getSessionKeyForRunId over getLastSessionKey
      final effectiveSessionKey =
          registry.getSessionKeyForRunId(runIdA) ?? registry.getLastSessionKey(connectionId);

      // Assert — resolves to sessionA (owner of runIdA), not sessionB (the last)
      expect(effectiveSessionKey, equals(sessionA));
    });

    test('falls back to getLastSessionKey when runId has no mapping', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const runIdUnknown = 'run-unknown';

      registry.registerSession(connectionId, sessionA);
      // runIdUnknown is never registered

      // Act
      final effectiveSessionKey =
          registry.getSessionKeyForRunId(runIdUnknown) ?? registry.getLastSessionKey(connectionId);

      // Assert — falls back to last known session
      expect(effectiveSessionKey, equals(sessionA));
    });
  });

  group('Session isolation', () {
    test('clearSession removes only the specified session', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB);

      // Act — clear session A only
      registry.clearSession(connectionId, sessionA);

      // Assert — session B still registered
      expect(registry.sessionBelongsTo(connectionId, sessionA), isFalse);
      expect(registry.sessionBelongsTo(connectionId, sessionB), isTrue);
    });

    test('clearSession removes runId mappings only for the cleared session', () {
      // Arrange
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';
      const runIdA = 'run-a';
      const runIdB = 'run-b';

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB);
      registry.registerRunId(connectionId, runIdA, sessionA);
      registry.registerRunId(connectionId, runIdB, sessionB);

      // Act — clear session A
      registry.clearSession(connectionId, sessionA);

      // Assert — runIdA mapping gone, runIdB mapping intact
      expect(registry.getSessionKeyForRunId(runIdA), isNull);
      expect(registry.getSessionKeyForRunId(runIdB), equals(sessionB));
    });

    test('session A waiting state does not affect session B (registry isolation)', () {
      // Arrange — two sessions with separate runIds on the same connection
      const connectionId = 'conn-1';
      const sessionA = 'session-a';
      const sessionB = 'session-b';
      const runIdA = 'run-a';
      const runIdB = 'run-b';

      registry.registerSession(connectionId, sessionA);
      registry.registerSession(connectionId, sessionB);
      registry.registerRunId(connectionId, runIdA, sessionA);
      registry.registerRunId(connectionId, runIdB, sessionB);

      // Act — look up session for runIdA (simulating lifecycle end for session A)
      final sessionForRunA = registry.getSessionKeyForRunId(runIdA)
          ?? registry.getLastSessionKey(connectionId);

      // Assert — correctly identifies sessionA, not sessionB
      expect(sessionForRunA, equals(sessionA));

      // runIdB still correctly maps to sessionB
      expect(registry.getSessionKeyForRunId(runIdB), equals(sessionB));
    });

    test('clearConnection removes all sessions and runIds for the connection', () {
      // Arrange
      const connectionId = 'conn-1';
      registry.registerSession(connectionId, 'session-a');
      registry.registerSession(connectionId, 'session-b');
      registry.registerRunId(connectionId, 'run-a', 'session-a');

      // Act
      registry.clearConnection(connectionId);

      // Assert
      expect(registry.getSessionKeys(connectionId), isEmpty);
      expect(registry.getLastSessionKey(connectionId), isNull);
      expect(registry.runIdBelongsTo(connectionId, 'run-a'), isFalse);
    });

    test('two connections do not share session state', () {
      // Arrange
      const connA = 'conn-a';
      const connB = 'conn-b';
      const session1 = 'session-1';
      const session2 = 'session-2';

      registry.registerSession(connA, session1);
      registry.registerSession(connB, session2);

      // Assert — session1 only belongs to connA, not connB
      expect(registry.sessionBelongsTo(connA, session1), isTrue);
      expect(registry.sessionBelongsTo(connB, session1), isFalse);
      expect(registry.sessionBelongsTo(connA, session2), isFalse);
      expect(registry.sessionBelongsTo(connB, session2), isTrue);
    });
  });

  group('removeRunIdToSessionKey', () {
    test('removes the runId mapping', () {
      // Arrange
      const connectionId = 'conn-1';
      const runId = 'run-1';
      registry.registerRunId(connectionId, runId, 'session-a');

      // Act
      registry.removeRunIdToSessionKey(runId);

      // Assert
      expect(registry.getSessionKeyForRunId(runId), isNull);
    });

    test('does not affect other runId mappings', () {
      // Arrange
      registry.registerRunId('conn-1', 'run-1', 'session-a');
      registry.registerRunId('conn-1', 'run-2', 'session-b');

      // Act
      registry.removeRunIdToSessionKey('run-1');

      // Assert
      expect(registry.getSessionKeyForRunId('run-1'), isNull);
      expect(registry.getSessionKeyForRunId('run-2'), equals('session-b'));
    });
  });

  group('dispose', () {
    test('clears all state', () {
      // Arrange
      registry.registerSession('conn-1', 'session-a');
      registry.registerRunId('conn-1', 'run-1', 'session-a');

      // Act
      registry.dispose();

      // Assert
      expect(registry.getLastSessionKey('conn-1'), isNull);
      expect(registry.getSessionKeyForRunId('run-1'), isNull);
      expect(registry.runIdBelongsTo('conn-1', 'run-1'), isFalse);
    });
  });
}
