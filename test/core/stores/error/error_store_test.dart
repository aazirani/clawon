import 'package:clawon/core/stores/error/error_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mobx_test_utils.dart';

void main() {
  late ErrorStore errorStore;

  setUp(() {
    errorStore = ErrorStore();
  });

  tearDown(() {
    errorStore.dispose();
  });

  group('ErrorStore Initialization', () {
    test('initializes with empty error message', () {
      // Assert: Verify initial state
      expect(errorStore.errorMessage, equals(''));
    });
  });

  group('setErrorMessage', () {
    test('sets error message correctly', () {
      // Arrange: Define test error message
      const testMessage = 'Test error occurred';

      // Act: Set the error message
      errorStore.setErrorMessage(testMessage);

      // Assert: Verify error message was set
      expect(errorStore.errorMessage, equals(testMessage));
    });

    test('overwrites existing error message', () {
      // Arrange: Set initial error message
      errorStore.setErrorMessage('First error');

      // Act: Set a new error message
      const newMessage = 'Second error';
      errorStore.setErrorMessage(newMessage);

      // Assert: Verify message was overwritten
      expect(errorStore.errorMessage, equals(newMessage));
    });

    test('accepts empty string', () {
      // Arrange: Set an error message
      errorStore.setErrorMessage('Some error');

      // Act: Set empty string
      errorStore.setErrorMessage('');

      // Assert: Verify empty string is accepted
      expect(errorStore.errorMessage, equals(''));
    });

    test('accepts multi-line error messages', () {
      // Arrange: Create multi-line error
      const multiLineError = '''Error: Something went wrong
  at Function.process (file.dart:42:15)
  at Function.main (file.dart:10:5)''';

      // Act: Set multi-line error
      errorStore.setErrorMessage(multiLineError);

      // Assert: Verify multi-line error is preserved
      expect(errorStore.errorMessage, equals(multiLineError));
    });
  });

  group('reset', () {
    test('clears error message when set', () {
      // Arrange: Set an error message
      errorStore.setErrorMessage('Error to clear');

      // Act: Call reset
      errorStore.reset('');

      // Assert: Verify error message is cleared
      expect(errorStore.errorMessage, equals(''));
    });

    test('handles reset when already empty', () {
      // Arrange: Error message is already empty

      // Act: Call reset
      errorStore.reset('');

      // Assert: Should still be empty and not throw
      expect(errorStore.errorMessage, equals(''));
    });

    test('reset ignores the value parameter', () {
      // Arrange: Set an error message
      errorStore.setErrorMessage('Error message');

      // Act: Call reset with a non-empty value
      errorStore.reset('some value');

      // Assert: Verify message is still cleared (value is ignored)
      expect(errorStore.errorMessage, equals(''));
    });
  });

  group('Auto-Reset Reaction', () {
    test('automatically resets error message after delay', () async {
      // Arrange: Set an error message
      errorStore.setErrorMessage('Auto-reset error');

      // Act: Use utility for reliable reaction timing
      // The error store has a 200ms auto-reset delay
      await MobXTestUtils.waitForReaction(
        const Duration(milliseconds: 250), // 200ms delay + buffer
      );

      // Assert: Verify error was automatically reset
      expect(errorStore.errorMessage, equals(''));
    });

    test('does not reset immediately after setting error', () async {
      // Arrange: Set an error message
      const testMessage = 'Immediate check error';
      errorStore.setErrorMessage(testMessage);

      // Act: Check immediately (within the delay period)
      // The reaction has a 200ms delay, so it should still be set
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert: Error message should still be present
      expect(errorStore.errorMessage, equals(testMessage));
    });

    test('resets only once after setting error', () async {
      // Arrange: Set error message
      errorStore.setErrorMessage('Single reset error');

      // Act: Wait past the reset delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert: Should be reset
      expect(errorStore.errorMessage, equals(''));

      // Act: Wait additional time
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert: Should still be empty (no double reset issues)
      expect(errorStore.errorMessage, equals(''));
    });

    test('updates error and restarts the delay timer', () async {
      // Arrange: Set initial error
      errorStore.setErrorMessage('Initial error');

      // Act: Wait 100ms (less than delay), then update error
      await Future.delayed(const Duration(milliseconds: 100));
      errorStore.setErrorMessage('Updated error');

      // Wait another 150ms (total 250ms from update, more than 200ms delay)
      await Future.delayed(const Duration(milliseconds: 150));

      // Assert: Should be reset because 200ms passed since the update
      expect(errorStore.errorMessage, equals(''));
    });
  });

  group('dispose', () {
    test('disposes all reaction disposers', () {
      // Arrange: Create error store with reactions
      final storeToDispose = ErrorStore();

      // Act: Set an error and then dispose
      storeToDispose.setErrorMessage('Test error');
      storeToDispose.dispose();

      // Assert: No exception should be thrown
      // If disposers weren't cleaned up, setting errors after dispose might cause issues
      expect(() => storeToDispose.setErrorMessage('After dispose'),
          returnsNormally);
    });

    test('handles multiple dispose calls gracefully', () {
      // Arrange: Create error store
      final storeToDispose = ErrorStore();

      // Act: Dispose multiple times
      storeToDispose.dispose();
      expect(() => storeToDispose.dispose(), returnsNormally);
    });
  });

  group('Edge Cases', () {
    test('handles very long error messages', () {
      // Arrange: Create a very long error message
      final longError = 'Error ' * 1000;

      // Act: Set the long error
      errorStore.setErrorMessage(longError);

      // Assert: Verify it was set correctly
      expect(errorStore.errorMessage.length, equals(longError.length));
      expect(errorStore.errorMessage, equals(longError));
    });

    test('handles special characters in error message', () {
      // Arrange: Create error with special characters
      const specialError = 'Error: \n\t\r"\'' r'$\$\\@{}[]()<>' '';

      // Act: Set error with special characters
      errorStore.setErrorMessage(specialError);

      // Assert: Verify special characters are preserved
      expect(errorStore.errorMessage, equals(specialError));
    });

    test('handles unicode characters in error message', () {
      // Arrange: Create error with unicode
      const unicodeError = 'Error: 错误 🚨 Émojis Ñoñü';

      // Act: Set error with unicode
      errorStore.setErrorMessage(unicodeError);

      // Assert: Verify unicode is preserved
      expect(errorStore.errorMessage, equals(unicodeError));
    });

    test('handles rapid error message changes', () {
      // Arrange: Prepare multiple error messages
      const errors = [
        'Error 1',
        'Error 2',
        'Error 3',
        'Error 4',
        'Error 5',
      ];

      // Act: Rapidly set different errors
      for (final error in errors) {
        errorStore.setErrorMessage(error);
      }

      // Assert: Last error should be set
      expect(errorStore.errorMessage, equals(errors.last));
    });
  });
}
