import 'package:drift/drift.dart';
import '../local/database/app_database.dart' as db;
import '../../domain/entities/connection.dart';

/// Connection configuration data model for local storage
class ConnectionConfig {
  final String id;
  final String name;
  final String gatewayUrl;
  final String token;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? agentId;
  final String? agentName;

  ConnectionConfig({
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

  factory ConnectionConfig.fromDriftRow(db.Connection row) {
    return ConnectionConfig(
      id: row.id,
      name: row.name,
      gatewayUrl: row.gatewayUrl,
      token: row.token,
      createdAt: row.createdAt,
      lastMessageAt: row.lastMessageAt,
      lastMessagePreview: row.lastMessagePreview,
      agentId: row.agentId,
      agentName: row.agentName,
    );
  }

  db.ConnectionsCompanion toDriftCompanion() {
    return db.ConnectionsCompanion(
      id: Value(id),
      name: Value(name),
      gatewayUrl: Value(gatewayUrl),
      token: Value(token),
      createdAt: Value(createdAt),
      lastMessageAt: lastMessageAt == null
          ? const Value.absent()
          : Value(lastMessageAt!),
      lastMessagePreview: lastMessagePreview == null
          ? const Value.absent()
          : Value(lastMessagePreview!),
      agentId: agentId == null
          ? const Value.absent()
          : Value(agentId!),
      agentName: agentName == null
          ? const Value.absent()
          : Value(agentName!),
    );
  }

  Connection toEntity() {
    return Connection(
      id: id,
      name: name,
      gatewayUrl: gatewayUrl,
      token: token,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      agentId: agentId,
      agentName: agentName,
    );
  }

  factory ConnectionConfig.fromEntity(Connection entity) {
    return ConnectionConfig(
      id: entity.id,
      name: entity.name,
      gatewayUrl: entity.gatewayUrl,
      token: entity.token,
      createdAt: entity.createdAt,
      lastMessageAt: entity.lastMessageAt,
      lastMessagePreview: entity.lastMessagePreview,
      agentId: entity.agentId,
      agentName: entity.agentName,
    );
  }
}
