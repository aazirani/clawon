import 'dart:async';

class HeartbeatMonitor {
  static const Duration checkInterval = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 90);
  static const int maxMissedChecks = 3;

  final void Function() _onConnectionDead;

  Timer? _checkTimer;
  Timer? _timeoutTimer;
  int _missedChecks = 0;
  DateTime? _lastFrameReceived;

  HeartbeatMonitor({
    required void Function() onConnectionDead,
  }) : _onConnectionDead = onConnectionDead;

  void start() {
    stop();
    _missedChecks = 0;
    _lastFrameReceived = DateTime.now();
    _checkTimer = Timer.periodic(checkInterval, (_) => _checkConnection());
  }

  void stop() {
    _checkTimer?.cancel();
    _timeoutTimer?.cancel();
    _lastFrameReceived = null;
    _missedChecks = 0;
  }

  /// Call this when any frame is received from the server.
  void onFrameReceived() {
    _lastFrameReceived = DateTime.now();
    _missedChecks = 0;
  }

  void _checkConnection() {
    final now = DateTime.now();
    final timeSinceLastFrame = _lastFrameReceived != null
        ? now.difference(_lastFrameReceived!)
        : connectionTimeout;

    if (timeSinceLastFrame > connectionTimeout) {
      _missedChecks++;
      if (_missedChecks >= maxMissedChecks) {
        stop();
        _onConnectionDead();
        return;
      }
    } else {
      _missedChecks = 0;
    }
  }

  void dispose() {
    stop();
  }
}
