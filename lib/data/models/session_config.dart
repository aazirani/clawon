import 'package:drift/drift.dart';
import '../local/database/app_database.dart' as db;
import '../../domain/entities/session.dart';

/// Session configuration data model for local storage
/// Maps to the Sessions table in Drift database
class SessionConfig {
  final String sessionKey;
  final String connectionId;
  final String title;
  final String? agentId;
  final String? agentName;
  final String? agentEmoji;
  final String? kind;
  final int messageCount;
  final DateTime createdAt;
  final DateTime lastActive;
  final DateTime syncedAt;

  SessionConfig({
    required this.sessionKey,
    required this.connectionId,
    required this.title,
    this.agentId,
    this.agentName,
    this.agentEmoji,
    this.kind,
    required this.messageCount,
    required this.createdAt,
    required this.lastActive,
    required this.syncedAt,
  });

  /// Create SessionConfig from Drift Session row
  factory SessionConfig.fromDriftRow(db.Session row) {
    return SessionConfig(
      sessionKey: row.sessionKey,
      connectionId: row.connectionId,
      title: row.title,
      agentId: row.agentId,
      agentName: row.agentName,
      agentEmoji: row.agentEmoji,
      kind: row.kind,
      messageCount: row.messageCount,
      createdAt: row.createdAt,
      lastActive: row.lastActive,
      syncedAt: row.syncedAt,
    );
  }

  /// Convert to Drift Companion for database operations
  db.SessionsCompanion toDriftCompanion() {
    return db.SessionsCompanion(
      sessionKey: Value(sessionKey),
      connectionId: Value(connectionId),
      title: Value(title),
      agentId: agentId == null
          ? const Value.absent()
          : Value(agentId!),
      agentName: agentName == null
          ? const Value.absent()
          : Value(agentName!),
      agentEmoji: agentEmoji == null
          ? const Value.absent()
          : Value(agentEmoji!),
      kind: kind == null
          ? const Value.absent()
          : Value(kind!),
      messageCount: Value(messageCount),
      createdAt: Value(createdAt),
      lastActive: Value(lastActive),
      syncedAt: Value(syncedAt),
    );
  }

  /// Convert to domain entity (clean architecture layer boundary)
  GatewaySession toEntity() {
    return GatewaySession(
      sessionKey: sessionKey,
      sessionId: sessionKey,
      title: title,
      agentId: agentId,
      agentName: agentName,
      agentEmoji: agentEmoji,
      kind: kind,
      messageCount: messageCount,
      createdAt: createdAt,
      lastActive: lastActive,
    );
  }
}
