/// Exception thrown when attempting to add a connection with a
/// gateway URL and token combination that already exists.
class DuplicateConnectionException implements Exception {
  final String message;

  DuplicateConnectionException([String? message])
      : message = message ?? 'A connection with this gateway URL and token already exists';

  @override
  String toString() => 'DuplicateConnectionException: $message';
}
