import 'package:clawon/data/di/data_layer_injection.dart';
import 'package:clawon/data/services/device_info_service.dart';
import 'package:clawon/domain/di/domain_layer_injection.dart';
import 'package:clawon/presentation/di/presentation_layer_injection.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

final getIt = GetIt.instance;

class ServiceLocator {
  static Future<void> configureDependencies() async {
    // Resolve app version from pubspec.yaml and platform-specific client info
    final packageInfo = await PackageInfo.fromPlatform();
    final clientInfo = await resolveGatewayClientInfo(packageInfo.version);
    getIt.registerSingleton<GatewayClientInfo>(clientInfo);

    await DataLayerInjection.configureDataLayerInjection();
    await DomainLayerInjection.configureDomainLayerInjection();
    await PresentationLayerInjection.configurePresentationLayerInjection();
  }
}
