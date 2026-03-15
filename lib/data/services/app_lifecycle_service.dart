import 'package:flutter/widgets.dart';

import 'websocket_connection_manager.dart';

/// Bridges Flutter's app lifecycle events to the WebSocket layer.
/// Enables automatic reconnection when the app returns from background.
class AppLifecycleService with WidgetsBindingObserver {
  final WebSocketConnectionManager _wsManager;

  AppLifecycleService(this._wsManager);

  /// Start listening to app lifecycle events.
  /// Call this after DI setup is complete.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop listening to app lifecycle events.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wsManager.onAppResumed();
    }
  }
}
