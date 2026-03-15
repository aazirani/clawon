import 'package:drift/drift.dart';

import '../app_database.dart';

part 'connection_dao.g.dart';

@DriftAccessor(tables: [Connections])
class ConnectionDao extends DatabaseAccessor<AppDatabase>
    with _$ConnectionDaoMixin {
  ConnectionDao(super.db);

  /// Get all connections, ordered by creation date (newest first)
  Future<List<Connection>> getAllConnections() =>
      (select(connections)..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).get();

  /// Watch all connections for real-time UI updates
  Stream<List<Connection>> watchAllConnections() =>
      (select(connections)..orderBy([(c) => OrderingTerm.desc(c.createdAt)])).watch();

  /// Get a single connection by ID
  Future<Connection?> getConnectionById(String id) =>
      (select(connections)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Insert a new connection
  Future<void> insertConnection(ConnectionsCompanion entry) =>
      into(connections).insert(entry);

  /// Upsert a connection (insert or update if exists)
  Future<void> upsertConnection(ConnectionsCompanion entry) =>
      into(connections).insertOnConflictUpdate(entry);

  /// Update an existing connection
  Future<void> updateConnection(ConnectionsCompanion entry) =>
      (update(connections)..where((c) => c.id.equals(entry.id.value))).write(entry);

  /// Delete a connection by ID
  Future<void> deleteConnectionById(String id) =>
      (delete(connections)..where((c) => c.id.equals(id))).go();

  /// Update last message metadata
  Future<void> updateMetadata(
    String id, {
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) {
    return (update(connections)..where((c) => c.id.equals(id))).write(
      ConnectionsCompanion(
        lastMessageAt: Value.absentIfNull(lastMessageAt),
        lastMessagePreview: Value.absentIfNull(lastMessagePreview),
      ),
    );
  }

  /// Update agent info for a connection
  Future<void> updateAgentInfo(String id, String? agentId, String? agentName) {
    return (update(connections)..where((c) => c.id.equals(id))).write(
      ConnectionsCompanion(
        agentId: Value.absentIfNull(agentId),
        agentName: Value.absentIfNull(agentName),
      ),
    );
  }
}
