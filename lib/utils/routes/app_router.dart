import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../di/service_locator.dart';
import '../../presentation/agents/agent_creation_assistant_screen.dart';
import '../../presentation/chat/chat_screen.dart';
import '../../presentation/connections/connections_list_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/sessions/sessions_list_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/skills/skill_creation_assistant_screen.dart';
import '../../presentation/skills/skills_list_screen.dart';

/// Global route observer for tracking route changes
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String connections = '/';
  static const String sessions = '/connections/:id/sessions';
  static const String chat = '/connections/:id/sessions/:sessionKey/chat';
  static const String skills = '/connections/:id/skills';
  static const String skillCreation = '/connections/:id/skills/create';
  static const String agentCreation = '/connections/:id/agents/create';
  static const String settings = '/settings';

  static GoRouter create() {
    return GoRouter(
      initialLocation: connections,
      observers: [routeObserver],
      restorationScopeId: 'clawon_router',
      redirect: (context, state) {
        final prefs = getIt<SharedPreferences>();
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        if (!hasSeenOnboarding && state.matchedLocation != onboarding) {
          return onboarding;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: connections,
          builder: (context, state) => const ConnectionsListScreen(),
        ),
        GoRoute(
          path: sessions,
          builder: (context, state) {
            final connectionId = state.pathParameters['id']!;
            final connectionName = state.uri.queryParameters['connectionName'] ?? 'Sessions';
            return SessionsListScreen(
              connectionId: connectionId,
              connectionName: connectionName,
            );
          },
        ),
        GoRoute(
          path: chat,
          builder: (context, state) {
            final connectionId = state.pathParameters['id']!;
            final sessionKey = state.pathParameters['sessionKey']!;
            final connectionName = state.uri.queryParameters['connectionName'] ?? 'Chat';
            final sessionTitle = state.uri.queryParameters['sessionTitle'] ?? 'Chat';
            final agentId = state.uri.queryParameters['agentId'];
            final agentEmoji = state.uri.queryParameters['agentEmoji'];
            return ChatScreen(
              connectionId: connectionId,
              connectionName: connectionName,
              sessionKey: sessionKey,
              sessionTitle: sessionTitle,
              agentId: agentId,
              agentEmoji: agentEmoji,
            );
          },
        ),
        GoRoute(
          path: skills,
          builder: (context, state) {
            final connectionId = state.pathParameters['id']!;
            return SkillsListScreen(connectionId: connectionId);
          },
        ),
        GoRoute(
          path: skillCreation,
          builder: (context, state) {
            final connectionId = state.pathParameters['id']!;
            final agentId = state.uri.queryParameters['agentId'];
            return SkillCreationAssistantScreen(
              connectionId: connectionId,
              agentId: agentId,
            );
          },
        ),
        GoRoute(
          path: agentCreation,
          builder: (context, state) {
            final connectionId = state.pathParameters['id']!;
            return AgentCreationAssistantScreen(connectionId: connectionId);
          },
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}
