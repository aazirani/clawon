import '../entities/connection.dart';

abstract class ConnectionRepository {
  Future<List<Connection>> getConnections();
  Future<Connection?> getConnection(String id);
  Future<void> saveConnection(Connection connection);
  Future<void> updateConnection(Connection connection);
  Future<void> deleteConnection(String id);
}
