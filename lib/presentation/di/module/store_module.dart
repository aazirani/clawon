import 'package:clawon/core/stores/error/error_store.dart';
import 'package:clawon/data/services/device_identity_service.dart';
import 'package:clawon/domain/repositories/connection_repository.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:clawon/presentation/connections/store/connections_store.dart';
import 'package:clawon/presentation/home/store/language/language_store.dart';
import 'package:clawon/presentation/home/store/theme/theme_store.dart';
import 'package:clawon/presentation/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../di/service_locator.dart';

class StoreModule {
  static Future<void> configureStoreModuleInjection() async {
    // factories:---------------------------------------------------------------
    getIt.registerFactory(() => ErrorStore());

    // stores:------------------------------------------------------------------
    getIt.registerSingleton<LanguageStore>(
      LanguageStore(
        getIt<SettingRepository>(),
        getIt<ErrorStore>(),
      ),
    );

    getIt.registerSingleton<ThemeStore>(
      ThemeStore(getIt<SharedPreferences>()),
    );

    getIt.registerSingleton<SettingsStore>(
      SettingsStore(getIt<SettingRepository>()),
    );

    // ConnectionsStore: singleton for the list screen
    getIt.registerSingleton<ConnectionsStore>(
      ConnectionsStore(
        getIt<ConnectionRepository>(),
        getIt<ChatRepository>(),
        getIt<DeviceIdentityService>(),
      ),
    );

    // SkillsStore is created per-connection in SkillsListScreen
    // and is not registered in DI.

    // ConnectionStore and ChatStore: NOT registered here.
    // Created per-connection in ChatScreen.
  }
}
