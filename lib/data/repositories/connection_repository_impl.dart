import '../../domain/entities/connection.dart';
import '../../domain/repositories/connection_repository.dart';
import '../datasources/connection_local_datasource.dart';
import '../models/connection_config.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  final ConnectionLocalDatasource _localDatasource;

  ConnectionRepositoryImpl(this._localDatasource);

  @override
  Future<List<Connection>> getConnections() async {
    final configs = await _localDatasource.getConnections();
    return configs.map((c) => c.toEntity()).toList();
  }

  @override
  Future<Connection?> getConnection(String id) async {
    final config = await _localDatasource.getConnection(id);
    return config?.toEntity();
  }

  @override
  Future<void> saveConnection(Connection connection) async {
    await _localDatasource
        .saveConnection(ConnectionConfig.fromEntity(connection));
  }

  @override
  Future<void> updateConnection(Connection connection) async {
    final config = ConnectionConfig.fromEntity(connection);
    // Check if connection exists
    final existing = await _localDatasource.getConnection(connection.id);
    if (existing == null) {
      // If doesn't exist, save as new
      await _localDatasource.saveConnection(config);
    } else {
      // If exists, update
      await _localDatasource.updateConnection(config);
    }
  }

  @override
  Future<void> deleteConnection(String id) async {
    await _localDatasource.deleteConnection(id);
    await _localDatasource.deleteConnectionMessages(id);
  }
}
