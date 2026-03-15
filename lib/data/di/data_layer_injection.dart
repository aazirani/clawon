import 'package:clawon/data/di/module/local_module.dart';
import 'package:clawon/data/di/module/repository_module.dart';

class DataLayerInjection {
  static Future<void> configureDataLayerInjection() async {
    await LocalModule.configureLocalModuleInjection();
    await RepositoryModule.configureRepositoryModuleInjection();
  }
}
