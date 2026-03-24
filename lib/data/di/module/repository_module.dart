import 'package:clawon/data/datasources/connection_local_datasource.dart';
import 'package:clawon/data/datasources/device_identity_storage.dart';
import 'package:clawon/data/local/database/app_database.dart';
import 'package:clawon/data/repositories/chat_repository_impl.dart';
import 'package:clawon/data/repositories/connection_repository_impl.dart';
import 'package:clawon/data/repositories/setting/setting_repository_impl.dart';
import 'package:clawon/data/repositories/session_repository_impl.dart';
import 'package:clawon/data/services/active_session_registry.dart';
import 'package:clawon/data/services/app_lifecycle_service.dart';
import 'package:clawon/data/services/device_identity_service.dart';
import 'package:clawon/data/services/device_info_service.dart';
import 'package:clawon/data/services/message_service.dart';
import 'package:clawon/data/services/streaming_response_handler.dart';
import 'package:clawon/data/services/websocket_connection_manager.dart';
import 'package:clawon/data/sharedpref/shared_preference_helper.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/connection_repository.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:clawon/domain/repositories/session_repository.dart';

import '../../../di/service_locator.dart';

class RepositoryModule {
  static Future<void> configureRepositoryModuleInjection() async {
    // Services:--------------------------------------------------------------
    // Register services first as they are dependencies for ChatRepository
    getIt.registerSingleton<ActiveSessionRegistry>(ActiveSessionRegistry());
    getIt.registerSingleton<StreamingResponseHandler>(StreamingResponseHandler());

    // Device identity services:
    getIt.registerSingleton<DeviceIdentityService>(
      DeviceIdentityService(getIt<DeviceIdentityStorage>()),
    );

    getIt.registerSingleton<WebSocketConnectionManager>(
      WebSocketConnectionManager(
        getIt<ConnectionLocalDatasource>(),
        getIt<DeviceIdentityService>(),
        getIt<GatewayClientInfo>(),
      ),
    );
    getIt.registerSingleton<MessageService>(
      MessageService(
        getIt<ConnectionLocalDatasource>(),
        getIt<StreamingResponseHandler>(),
      ),
    );
    getIt.registerSingleton<AppLifecycleService>(
      AppLifecycleService(
        getIt<WebSocketConnectionManager>(),
        getIt<MessageService>(),
        getIt<AppDatabase>().executor,
      ),
    );

    // repository:--------------------------------------------------------------
    getIt.registerSingleton<SettingRepository>(SettingRepositoryImpl(
      getIt<SharedPreferenceHelper>(),
    ));

    // Connection repository:---------------------------------------------------
    getIt.registerSingleton<ConnectionRepository>(
      ConnectionRepositoryImpl(
        getIt<ConnectionLocalDatasource>(),
      ),
    );

    // Chat repository:-----------------------------------------------------------
    getIt.registerSingleton<ChatRepository>(
      ChatRepositoryImpl(
        getIt<ConnectionLocalDatasource>(),
        getIt<WebSocketConnectionManager>(),
        getIt<ActiveSessionRegistry>(),
        getIt<StreamingResponseHandler>(),
        getIt<MessageService>(),
      ),
    );

    // Session repository:---------------------------------------------------
    getIt.registerSingleton<SessionRepository>(
      SessionRepositoryImpl(
        getIt<ChatRepository>(),
        getIt<ConnectionLocalDatasource>(),
        getIt<SettingRepository>(),
      ),
    );

    // Skills repository is created per-connection in SkillsListScreen
    // and is not registered in DI.
  }
}
