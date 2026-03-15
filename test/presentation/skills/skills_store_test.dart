import 'package:clawon/data/models/skill.dart';
import 'package:clawon/domain/entities/skill_install_result.dart';
import 'package:clawon/presentation/skills/skills_store.dart';
import 'package:clawon/domain/repositories/skills_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSkillsRepository extends Mock implements SkillsRepository {}

// Register fallback values for mocktail
class FakeSkill extends Fake implements Skill {}

void main() {
  late SkillsStore store;
  late MockSkillsRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeSkill());
  });

  setUp(() {
    mockRepository = MockSkillsRepository();
    store = SkillsStore(mockRepository);
  });

  group('SkillsStore', () {
    group('fetchSkills', () {
      test('sets isLoading to true during fetch, false after', () async {
        // Arrange
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);

        // Start the fetch but don't await yet to check isLoading
        final future = store.fetchSkills();
        // At this point isLoading should be true
        expect(store.isLoading, isTrue);

        // Wait for completion
        await future;
        expect(store.isLoading, isFalse);
      });

      test('populates skills list on success', () async {
        // Arrange
        final skills = [
          _createSkill('skill-1', name: 'First Skill'),
          _createSkill('skill-2', name: 'Second Skill'),
        ];
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => skills);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.skills.length, 2);
        expect(store.skills[0].name, 'First Skill');
        expect(store.skills[1].name, 'Second Skill');
      });

      test('sets errorMessage on failure', () async {
        // Arrange
        when(() => mockRepository.getSkills())
            .thenThrow(Exception('Network error'));

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.errorMessage, isNotNull);
        expect(store.errorMessage, contains('Network error'));
      });

      test('clearError clears errorMessage', () async {
        // Arrange
        store.errorMessage = 'Some error';

        // Act
        store.clearError();

        // Assert
        expect(store.errorMessage, isNull);
      });

      test('replaces skills on subsequent fetch', () async {
        // Arrange - first fetch
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);
        await store.fetchSkills();
        expect(store.skills.length, 1);

        // Arrange - second fetch
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-2'), _createSkill('skill-3')]);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.skills.length, 2);
        expect(store.skills.any((s) => s.skillKey == 'skill-1'), isFalse);
      });
    });

    group('toggleSkillEnabled', () {
      test('sets isToggling to true during toggle, false after', () async {
        // Arrange
        when(() => mockRepository.setSkillEnabled('skill-1', true))
            .thenAnswer((_) async {});
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Start toggle
        final future = store.toggleSkillEnabled('skill-1', true);
        expect(store.isToggling, isTrue);

        await future;
        expect(store.isToggling, isFalse);
      });

      test('calls repository.setSkillEnabled with correct params', () async {
        // Arrange
        when(() => mockRepository.setSkillEnabled('my-skill', false))
            .thenAnswer((_) async {});
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.toggleSkillEnabled('my-skill', false);

        // Assert
        verify(() => mockRepository.setSkillEnabled('my-skill', false)).called(1);
      });

      test('refreshes skills after successful toggle', () async {
        // Arrange
        when(() => mockRepository.setSkillEnabled(any(), any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);

        // Act
        await store.toggleSkillEnabled('skill-1', true);

        // Assert
        verify(() => mockRepository.getSkills()).called(1);
      });

      test('sets toggleErrorMessage on failure', () async {
        // Arrange
        when(() => mockRepository.setSkillEnabled(any(), any()))
            .thenThrow(Exception('Toggle failed'));

        // Act
        await store.toggleSkillEnabled('skill-1', true);

        // Assert
        expect(store.toggleErrorMessage, isNotNull);
        expect(store.toggleErrorMessage, contains('Toggle failed'));
      });

      test('clearToggleError clears toggleErrorMessage', () async {
        // Arrange
        store.toggleErrorMessage = 'Error';

        // Act
        store.clearToggleError();

        // Assert
        expect(store.toggleErrorMessage, isNull);
      });
    });

    group('updateSkillConfig', () {
      test('calls repository.updateSkill with correct params', () async {
        // Arrange
        when(() => mockRepository.updateSkill(
          any(),
          apiKey: any(named: 'apiKey'),
          env: any(named: 'env'),
        )).thenAnswer((_) async {});
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.updateSkillConfig(
          'skill-1',
          apiKey: 'secret-key',
          env: {'URL': 'https://api.example.com'},
        );

        // Assert
        verify(() => mockRepository.updateSkill(
          'skill-1',
          apiKey: 'secret-key',
          env: {'URL': 'https://api.example.com'},
        )).called(1);
      });

      test('refreshes skills after successful update', () async {
        // Arrange
        when(() => mockRepository.updateSkill(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);

        // Act
        await store.updateSkillConfig('skill-1');

        // Assert
        verify(() => mockRepository.getSkills()).called(1);
      });

      test('sets errorMessage on failure', () async {
        // Arrange
        when(() => mockRepository.updateSkill(any()))
            .thenThrow(Exception('Update failed'));

        // Act
        await store.updateSkillConfig('skill-1');

        // Assert
        expect(store.errorMessage, contains('Update failed'));
      });
    });

    group('computed properties', () {
      test('enabledSkills returns only eligible and not disabled skills', () async {
        // Arrange
        final skills = [
          _createSkill('enabled-1', eligible: true, disabled: false),
          _createSkill('enabled-2', eligible: true, disabled: false),
          _createSkill('disabled-1', eligible: true, disabled: true),
          _createSkill('unavailable-1', eligible: false, disabled: false),
        ];
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => skills);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.enabledSkills.length, 2);
        expect(store.enabledSkills.every((s) => s.eligible && !s.disabled), isTrue);
      });

      test('disabledSkills returns only disabled skills', () async {
        // Arrange
        final skills = [
          _createSkill('enabled-1', eligible: true, disabled: false),
          _createSkill('disabled-1', eligible: true, disabled: true),
          _createSkill('disabled-2', eligible: false, disabled: true),
        ];
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => skills);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.disabledSkills.length, 2);
        expect(store.disabledSkills.every((s) => s.disabled), isTrue);
      });

      test('unavailableSkills returns only not eligible and not disabled', () async {
        // Arrange
        final skills = [
          _createSkill('enabled-1', eligible: true, disabled: false),
          _createSkill('disabled-1', eligible: true, disabled: true),
          _createSkill('unavailable-1', eligible: false, disabled: false),
          _createSkill('unavailable-2', eligible: false, disabled: false),
        ];
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => skills);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.unavailableSkills.length, 2);
        expect(store.unavailableSkills.every((s) => !s.eligible && !s.disabled), isTrue);
      });

      test('all three lists cover all skills with no overlap', () async {
        // Arrange
        final skills = [
          _createSkill('enabled-1', eligible: true, disabled: false),
          _createSkill('enabled-2', eligible: true, disabled: false),
          _createSkill('disabled-1', eligible: true, disabled: true),
          _createSkill('disabled-2', eligible: false, disabled: true),
          _createSkill('unavailable-1', eligible: false, disabled: false),
        ];
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => skills);

        // Act
        await store.fetchSkills();

        // Assert
        final allComputed = [
          ...store.enabledSkills,
          ...store.disabledSkills,
          ...store.unavailableSkills,
        ];
        expect(allComputed.length, 5);
        expect(allComputed.toSet().length, 5); // No duplicates
      });

      test('empty lists when no skills match', () async {
        // Arrange
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.enabledSkills, isEmpty);
        expect(store.disabledSkills, isEmpty);
        expect(store.unavailableSkills, isEmpty);
      });
    });

    group('installSkillDependency', () {
      test('sets installingSkillKey during install, null after', () async {
        // Arrange
        when(() => mockRepository.installSkill(any(), any()))
            .thenAnswer((_) async => SkillInstallResult(ok: true, message: 'Done', stdout: '', stderr: ''));
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Start install
        final future = store.installSkillDependency('skill-1', 'ffmpeg', 'brew');
        expect(store.installingSkillKey, 'skill-1');

        await future;
        expect(store.installingSkillKey, isNull);
      });

      test('calls repository.installSkill with correct params', () async {
        // Arrange
        when(() => mockRepository.installSkill('ffmpeg', 'brew'))
            .thenAnswer((_) async => SkillInstallResult(ok: true, message: 'Done', stdout: '', stderr: ''));
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.installSkillDependency('skill-1', 'ffmpeg', 'brew');

        // Assert
        verify(() => mockRepository.installSkill('ffmpeg', 'brew')).called(1);
      });

      test('sets installOutput from result.displayOutput on success', () async {
        // Arrange
        when(() => mockRepository.installSkill(any(), any()))
            .thenAnswer((_) async => SkillInstallResult(
              ok: true,
              message: 'Installed',
              stdout: 'output text',
              stderr: '',
            ));
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.installSkillDependency('skill-1', 'ffmpeg', 'brew');

        // Assert
        expect(store.installOutput, isNotNull);
        expect(store.installOutput, contains('Installed'));
        expect(store.installOutput, contains('output text'));
      });

      test('refreshes skills after successful install', () async {
        // Arrange
        when(() => mockRepository.installSkill(any(), any()))
            .thenAnswer((_) async => SkillInstallResult(ok: true, message: '', stdout: '', stderr: ''));
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);

        // Act
        await store.installSkillDependency('skill-1', 'ffmpeg', 'brew');

        // Assert
        verify(() => mockRepository.getSkills()).called(1);
      });

      test('sets errorMessage and installOutput on failure', () async {
        // Arrange
        when(() => mockRepository.installSkill(any(), any()))
            .thenThrow(Exception('Install failed'));

        // Act
        await store.installSkillDependency('skill-1', 'ffmpeg', 'brew');

        // Assert
        expect(store.errorMessage, contains('Installation error'));
        expect(store.installOutput, contains('Installation failed'));
      });

      test('clearInstallOutput clears installOutput', () async {
        // Arrange
        store.installOutput = 'Some output';

        // Act
        store.clearInstallOutput();

        // Assert
        expect(store.installOutput, isNull);
      });
    });

    group('hasSkills computed', () {
      test('returns true when skills list is not empty', () async {
        // Arrange
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => [_createSkill('skill-1')]);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.hasSkills, isTrue);
      });

      test('returns false when skills list is empty', () async {
        // Arrange
        when(() => mockRepository.getSkills())
            .thenAnswer((_) async => []);

        // Act
        await store.fetchSkills();

        // Assert
        expect(store.hasSkills, isFalse);
      });
    });
  });
}

// Helper to create a Skill with defaults
Skill _createSkill(
  String skillKey, {
  String name = 'Test Skill',
  bool eligible = true,
  bool disabled = false,
}) {
  return Skill(
    name: name,
    description: 'A test skill',
    source: SkillSource.bundled,
    bundled: true,
    skillKey: skillKey,
    always: false,
    disabled: disabled,
    blockedByAllowlist: false,
    eligible: eligible,
    requirements: SkillRequirements(),
    missing: SkillRequirements(),
    configChecks: [],
    install: [],
  );
}
