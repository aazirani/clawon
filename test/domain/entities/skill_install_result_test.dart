import 'package:clawon/domain/entities/skill_install_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkillInstallResult', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'ok': true,
          'message': 'Installation successful',
          'stdout': 'Downloading package...',
          'stderr': '',
          'code': 0,
          'warnings': ['deprecated API used'],
        };

        final result = SkillInstallResult.fromJson(json);

        expect(result.ok, isTrue);
        expect(result.message, equals('Installation successful'));
        expect(result.stdout, equals('Downloading package...'));
        expect(result.stderr, isEmpty);
        expect(result.code, equals(0));
        expect(result.warnings, equals(['deprecated API used']));
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = SkillInstallResult.fromJson(json);

        expect(result.ok, isFalse);
        expect(result.message, isEmpty);
        expect(result.stdout, isEmpty);
        expect(result.stderr, isEmpty);
        expect(result.code, isNull);
        expect(result.warnings, isEmpty);
      });

      test('parses failure response', () {
        final json = {
          'ok': false,
          'message': 'Installation failed',
          'stdout': '',
          'stderr': 'Error: package not found',
          'code': 1,
        };

        final result = SkillInstallResult.fromJson(json);

        expect(result.ok, isFalse);
        expect(result.message, equals('Installation failed'));
        expect(result.stderr, equals('Error: package not found'));
        expect(result.code, equals(1));
      });

      test('handles null code', () {
        final json = {
          'ok': true,
          'message': 'Done',
          'stdout': '',
          'stderr': '',
          'code': null,
        };

        final result = SkillInstallResult.fromJson(json);

        expect(result.ok, isTrue);
        expect(result.code, isNull);
      });
    });

    group('displayOutput', () {
      test('combines message, stdout, stderr, and warnings', () {
        final result = SkillInstallResult(
          ok: true,
          message: 'Success',
          stdout: 'output text',
          stderr: 'error text',
          warnings: ['warning 1', 'warning 2'],
        );

        final output = result.displayOutput;

        expect(output, contains('Success'));
        expect(output, contains('output text'));
        expect(output, contains('error text'));
        expect(output, contains('Warnings: warning 1, warning 2'));
      });

      test('excludes empty fields', () {
        final result = SkillInstallResult(
          ok: true,
          message: 'Done',
          stdout: '',
          stderr: '',
        );

        final output = result.displayOutput;

        expect(output, equals('Done'));
      });

      test('returns empty string when all fields empty', () {
        final result = SkillInstallResult(
          ok: false,
          message: '',
          stdout: '',
          stderr: '',
        );

        expect(result.displayOutput, isEmpty);
      });

      test('shows only stdout when message and stderr empty', () {
        final result = SkillInstallResult(
          ok: true,
          message: '',
          stdout: 'Installation output',
          stderr: '',
        );

        expect(result.displayOutput, equals('Installation output'));
      });
    });
  });
}
