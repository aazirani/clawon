import 'dart:async';

import 'package:clawon/data/services/app_lifecycle_service.dart';
import 'package:clawon/data/services/device_identity_service.dart';
import 'package:clawon/di/service_locator.dart';
import 'package:clawon/presentation/my_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts runtime fetching — all fonts must be bundled locally.
  // This prevents network calls to Google servers, which is required for
  // App Store compliance and offline support.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize dependencies
  await ServiceLocator.configureDependencies();
  await getIt.allReady();

  // Initialize device identity (generates keypair on first launch)
  await getIt<DeviceIdentityService>().ensureDeviceIdentityInitialized();

  // Initialize app lifecycle service for connection recovery on resume
  getIt<AppLifecycleService>().initialize();

  await setPreferredOrientations();
  runApp(const MyApp());
}

Future<void> setPreferredOrientations() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
}
