import 'package:clawon/domain/entities/language/language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Language Entity', () {
    test('creates language with all required fields', () {
      const language = Language(
        code: 'IR',
        locale: 'fa',
        language: 'فارسی',
        englishName: 'Persian',
        flagEmoji: '🇮🇷',
        isRTL: true,
      );

      expect(language.code, equals('IR'));
      expect(language.locale, equals('fa'));
      expect(language.language, equals('فارسی'));
      expect(language.englishName, equals('Persian'));
      expect(language.flagEmoji, equals('🇮🇷'));
      expect(language.isRTL, isTrue);
    });

    test('creates LTR language', () {
      const language = Language(
        code: 'US',
        locale: 'en',
        language: 'English',
        englishName: 'English',
        flagEmoji: '🇺🇸',
        isRTL: false,
      );

      expect(language.isRTL, isFalse);
    });

    test('supports optional dictionary', () {
      const language = Language(
        code: 'US',
        locale: 'en',
        language: 'English',
        englishName: 'English',
        flagEmoji: '🇺🇸',
        isRTL: false,
        dictionary: {'key': 'value'},
      );

      expect(language.dictionary, isNotNull);
      expect(language.dictionary!['key'], equals('value'));
    });

    test('can be created as const without dictionary', () {
      // This tests that the entity can be used as a compile-time constant
      const language = Language(
        code: 'DK',
        locale: 'da',
        language: 'Dansk',
        englishName: 'Danish',
        flagEmoji: '🇩🇰',
        isRTL: false,
      );

      expect(language.code, equals('DK'));
      expect(language.locale, equals('da'));
    });

    test('RTL languages have isRTL true', () {
      const rtlLanguages = [
        Language(code: 'IR', locale: 'fa', language: 'فارسی', englishName: 'Persian', flagEmoji: '🇮🇷', isRTL: true),
        Language(code: 'SA', locale: 'ar', language: 'العربية', englishName: 'Arabic', flagEmoji: '🇸🇦', isRTL: true),
        Language(code: 'PK', locale: 'ur', language: 'اردو', englishName: 'Urdu', flagEmoji: '🇵🇰', isRTL: true),
      ];

      for (final lang in rtlLanguages) {
        expect(lang.isRTL, isTrue, reason: '${lang.englishName} should be RTL');
      }
    });

    test('LTR languages have isRTL false', () {
      const ltrLanguages = [
        Language(code: 'US', locale: 'en', language: 'English', englishName: 'English', flagEmoji: '🇺🇸', isRTL: false),
        Language(code: 'DK', locale: 'da', language: 'Dansk', englishName: 'Danish', flagEmoji: '🇩🇰', isRTL: false),
        Language(code: 'ES', locale: 'es', language: 'Español', englishName: 'Spanish', flagEmoji: '🇪🇸', isRTL: false),
      ];

      for (final lang in ltrLanguages) {
        expect(lang.isRTL, isFalse, reason: '${lang.englishName} should be LTR');
      }
    });
  });
}
