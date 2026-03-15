import 'dart:async';

import 'package:clawon/domain/usecase/get_skills_usecase.dart';

import '../../../di/service_locator.dart';

class UseCaseModule {
  static Future<void> configureUseCaseModuleInjection() async {
    // GetSkillsUseCase: factory for fetching skills
    getIt.registerFactory<GetSkillsUseCase>(() => GetSkillsUseCase(
          getIt(),
        ));
  }
}
