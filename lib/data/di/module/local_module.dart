import 'package:clawon/data/datasources/connection_local_datasource.dart';
import 'package:clawon/data/datasources/device_identity_storage.dart';
import 'package:clawon/data/local/database/app_database.dart';
import 'package:clawon/data/local/database/daos/connection_dao.dart';
import 'package:clawon/data/local/database/daos/message_dao.dart';
import 'package:clawon/data/local/database/daos/session_dao.dart';
import 'package:clawon/data/sharedpref/shared_preference_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../di/service_locator.dart';

class LocalModule {
  static Future<void> configureLocalModuleInjection() async {
    // preference manager:------------------------------------------------------
    getIt.registerSingletonAsync<SharedPreferences>(
        SharedPreferences.getInstance);
    getIt.registerSingleton<SharedPreferenceHelper>(
      SharedPreferenceHelper(await getIt.getAsync<SharedPreferences>()),
    );

    // Secure storage for device identity:--------------------------------------
    getIt.registerSingleton<DeviceIdentityStorage>(DeviceIdentityStorage());

    // database:----------------------------------------------------------------
    getIt.registerSingletonAsync<AppDatabase>(() async {
      return AppDatabase();
    });
    // Register DAOs - created from the AppDatabase singleton
    getIt.registerSingletonWithDependencies<ConnectionDao>(
      () => ConnectionDao(getIt<AppDatabase>()),
      dependsOn: [AppDatabase],
    );
    getIt.registerSingletonWithDependencies<MessageDao>(
      () => MessageDao(getIt<AppDatabase>()),
      dependsOn: [AppDatabase],
    );

    // Register SessionDao for ConnectionLocalDatasource
    getIt.registerSingletonWithDependencies<SessionDao>(
      () => SessionDao(getIt<AppDatabase>()),
      dependsOn: [AppDatabase],
    );

    // Wait for all async singletons (AppDatabase, DAOs) to be ready
    await getIt.allReady();

    // OpenClaw datasources:---------------------------------------------------
    getIt.registerSingleton<ConnectionLocalDatasource>(
      ConnectionLocalDatasource(
        getIt<ConnectionDao>(),
        getIt<MessageDao>(),
        getIt<SessionDao>(),
      ),
    );
  }
}
