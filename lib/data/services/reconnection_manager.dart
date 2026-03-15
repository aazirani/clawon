import 'dart:async';
import 'dart:math';

enum DisconnectReason {
  intentional, // User called disconnect()
  unexpected, // Server closed, network error
  shutdown, // Gateway sent shutdown event
}

class ReconnectionManager {
  static const int maxRetries = 10;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 60);
  static const Duration shutdownDelay = Duration(seconds: 3);

  final Future<void> Function() _connectCallback;
  final void Function(int attempt, Duration nextDelay) _onRetryScheduled;
  final void Function() _onMaxRetriesReached;

  int _retryCount = 0;
  Timer? _retryTimer;
  bool _isRetrying = false;

  ReconnectionManager({
    required Future<void> Function() connectCallback,
    required void Function(int attempt, Duration nextDelay) onRetryScheduled,
    required void Function() onMaxRetriesReached,
  })  : _connectCallback = connectCallback,
        _onRetryScheduled = onRetryScheduled,
        _onMaxRetriesReached = onMaxRetriesReached;

  bool get isRetrying => _isRetrying;
  int get retryCount => _retryCount;
  bool get shouldRetry => _retryCount < maxRetries;

  Duration get _nextDelay {
    final exponential = baseDelay * pow(2, _retryCount).toInt();
    final capped = exponential > maxDelay ? maxDelay : exponential;
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    return capped + jitter;
  }

  /// Called when a disconnection is detected.
  /// Only triggers auto-reconnect for unexpected/shutdown reasons.
  void onDisconnected(DisconnectReason reason) {
    if (reason == DisconnectReason.intentional) {
      cancel(); // Stop any pending retry
      return;
    }

    if (!shouldRetry) {
      _onMaxRetriesReached();
      return;
    }

    final delay = reason == DisconnectReason.shutdown
        ? shutdownDelay
        : _nextDelay;

    _scheduleRetry(delay);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _isRetrying = true;
    _retryCount++;
    _onRetryScheduled(_retryCount, delay);

    _retryTimer = Timer(delay, () async {
      try {
        await _connectCallback();
        // Success -- reset
        reset();
      } catch (_) {
        // Failed -- try again if allowed
        if (shouldRetry) {
          _scheduleRetry(_nextDelay);
        } else {
          _isRetrying = false;
          _onMaxRetriesReached();
        }
      }
    });
  }

  /// Reset retry state (call on successful connection).
  void reset() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _isRetrying = false;
  }

  /// Cancel any pending retry (call on intentional disconnect or dispose).
  void cancel() {
    _retryTimer?.cancel();
    _isRetrying = false;
  }

  void dispose() {
    cancel();
  }
}
