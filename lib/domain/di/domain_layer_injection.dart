import 'module/usecase_module.dart';

class DomainLayerInjection {
  static Future<void> configureDomainLayerInjection() async {
    // Register use cases
    await UseCaseModule.configureUseCaseModuleInjection();
  }
}
