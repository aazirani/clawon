import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import 'message_service.dart';
import 'websocket_connection_manager.dart';

/// Bridges Flutter's app lifecycle events to the WebSocket layer.
/// Enables automatic reconnection when the app returns from background,
/// and orderly cleanup of services on app termination.
class AppLifecycleService with WidgetsBindingObserver {
  final WebSocketConnectionManager _wsManager;
  final MessageService _messageService;
  final QueryExecutor _dbExecutor;

  AppLifecycleService(
    this._wsManager,
    this._messageService,
    this._dbExecutor,
  );

  /// Start listening to app lifecycle events.
  /// Call this after DI setup is complete.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop listening to app lifecycle events.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Called on macOS/desktop when the user requests the app to exit (Cmd+Q).
  /// Async — we can await the database close before returning, which prevents
  /// SQLite's functionDestroy from firing during Dart VM teardown and aborting.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _shutdown();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _wsManager.onAppResumed();
      case AppLifecycleState.detached:
        // Fallback for mobile/platforms where didRequestAppExit is not called.
        // Fire-and-forget — best effort cleanup before the runtime tears down.
        _shutdown();
      default:
        break;
    }
  }

  Future<void> _shutdown() async {
    _wsManager.dispose();
    _messageService.dispose();
    await _dbExecutor.close();
    dispose();
  }
}
