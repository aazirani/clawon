import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ──────────────────────────────────────────

/// Connections table stores gateway connection configurations
class Connections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get gatewayUrl => text()();
  TextColumn get token => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  TextColumn get agentId => text().nullable()();
  TextColumn get agentName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sessions table stores session metadata per connection
class Sessions extends Table {
  TextColumn get sessionKey => text()(); // Primary key
  TextColumn get connectionId => text().references(Connections, #id)();
  TextColumn get title => text()();
  TextColumn get agentId => text().nullable()();
  TextColumn get agentName => text().nullable()();
  TextColumn get agentEmoji => text().nullable()();
  TextColumn get kind => text().nullable()(); // Session kind (e.g., 'main', 'tool', 'subtask')
  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastActive => dateTime()();
  DateTimeColumn get syncedAt => dateTime()(); // Last sync with gateway

  @override
  Set<Column> get primaryKey => {sessionKey};
}

/// Chat messages table stores all messages per session
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get connectionId => text().references(Connections, #id)();
  TextColumn get sessionKey => text().nullable()(); // Session scoping
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isSending => boolean().withDefault(const Constant(false))();
  BoolColumn get isFailed => boolean().withDefault(const Constant(false))();
  BoolColumn get isStreaming => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ────────────────────────────────────────

@DriftDatabase(tables: [Connections, Sessions, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test constructor - accepts any QueryExecutor (e.g. in-memory)
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'clawon');
  }
}
