import 'package:clawon/constants/strings.dart';
import 'package:clawon/core/theme/app_theme.dart';
import 'package:clawon/core/theme/app_typography.dart';
import 'package:clawon/presentation/home/store/language/language_store.dart';
import 'package:clawon/presentation/home/store/theme/theme_store.dart';
import 'package:clawon/utils/locale/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../di/service_locator.dart';
import '../utils/routes/app_router.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  // Create your store as a final variable in a base Widget. This works better
  // with Hot Reload than creating it directly in the `build` function.
  final LanguageStore _languageStore = getIt<LanguageStore>();
  final ThemeStore _themeStore = getIt<ThemeStore>();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // Update typography locale before theme builds
        AppTypography.setLocale(_languageStore.locale);

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: Strings.appName,
          theme: AppTheme.light(locale: _languageStore.locale),
          darkTheme: AppTheme.dark(locale: _languageStore.locale),
          themeMode: _themeStore.themeMode,
          routerConfig: _router,
          restorationScopeId: 'clawon_app',
          locale: Locale(_languageStore.locale),
          supportedLocales: kSupportedLanguages
              .map((language) => Locale(language.locale, language.code))
              .toList(),
          localizationsDelegates: [
            // A class which loads the translations from JSON files
            AppLocalizations.delegate,
            // Built-in localization of basic text for Material widgets
            GlobalMaterialLocalizations.delegate,
            // Built-in localization for text direction LTR/RTL
            GlobalWidgetsLocalizations.delegate,
            // Built-in localization of basic text for Cupertino widgets
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
