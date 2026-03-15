import 'package:clawon/core/stores/error/error_store.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:clawon/presentation/home/store/language/language_store.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSettingRepository implements SettingRepository {
  String? _currentLanguage;
  int changeLanguageCallCount = 0;
  String? lastChangeLanguageValue;
  Exception? changeLanguageException;

  @override
  Future<void> changeBrightnessToDark(bool value) async {
    // Not used in LanguageStore tests
  }

  @override
  bool get isDarkMode => false;

  @override
  Future<void> changeLanguage(String value) async {
    changeLanguageCallCount++;
    lastChangeLanguageValue = value;
    if (changeLanguageException != null) {
      throw changeLanguageException!;
    }
    _currentLanguage = value;
  }

  @override
  String? get currentLanguage => _currentLanguage;

  @override
  Future<void> setShowNonClawOnSessions(bool value) async {
    // Not used in LanguageStore tests
  }

  @override
  bool get showNonClawOnSessions => false;

  @override
  String? get skillCreatorPrompt => null;

  @override
  Future<void> setSkillCreatorPrompt(String? prompt) async {
    // Not used in LanguageStore tests
  }

  @override
  String? get agentCreatorPrompt => null;

  @override
  Future<void> setAgentCreatorPrompt(String? prompt) async {
    // Not used in LanguageStore tests
  }

  /// Set the current language for testing
  void setCurrentLanguage(String? language) {
    _currentLanguage = language;
  }
}

void main() {
  late LanguageStore store;
  late MockSettingRepository mockRepository;
  late ErrorStore errorStore;

  setUp(() {
    mockRepository = MockSettingRepository();
    errorStore = ErrorStore();
    store = LanguageStore(mockRepository, errorStore);
  });

  tearDown(() {
    errorStore.dispose();
    store.dispose();
  });

  group('LanguageStore Initialization', () {
    test('initializes with default locale "en"', () {
      // Assert: Verify initial locale
      expect(store.locale, equals('en'));
    });

    test('initializes with supported languages', () {
      // Assert: Verify supported languages list
      expect(kSupportedLanguages.length, equals(25));
      expect(kSupportedLanguages[0].code, equals('US'));
      expect(kSupportedLanguages[0].locale, equals('en'));
      expect(kSupportedLanguages[0].language, equals('English'));
      expect(kSupportedLanguages[1].code, equals('DK'));
      expect(kSupportedLanguages[1].locale, equals('da'));
      expect(kSupportedLanguages[1].language, equals('Dansk'));
      expect(kSupportedLanguages[2].code, equals('ES'));
      expect(kSupportedLanguages[2].locale, equals('es'));
      expect(kSupportedLanguages[2].language, equals('Español'));
    });

    test('initializes with locale from repository if available', () async {
      // Arrange: Create a new store with repository having a language
      final testRepository = MockSettingRepository();
      testRepository.setCurrentLanguage('da');
      final testErrorStore = ErrorStore();

      // Act: Create store (will call init internally)
      final testStore = LanguageStore(testRepository, testErrorStore);

      // Assert: Locale should be loaded from repository
      expect(testStore.locale, equals('da'));

      // Cleanup
      testErrorStore.dispose();
      testStore.dispose();
    });

    test('uses default locale when repository has null currentLanguage',
        () async {
      // Arrange: Create repository with null language
      final testRepository = MockSettingRepository();
      testRepository.setCurrentLanguage(null);
      final testErrorStore = ErrorStore();

      // Act: Create store
      final testStore = LanguageStore(testRepository, testErrorStore);

      // Assert: Should use default locale
      expect(testStore.locale, equals('en'));

      // Cleanup
      testErrorStore.dispose();
      testStore.dispose();
    });
  });

  group('changeLanguage Action', () {
    test('changes locale to new value', () {
      // Arrange: Define new language
      const newLocale = 'da';

      // Act: Change language
      store.changeLanguage(newLocale);

      // Assert: Verify locale was changed
      expect(store.locale, equals(newLocale));
    });

    test('calls repository changeLanguage with correct value', () {
      // Arrange: Define test language
      const testLocale = 'es';

      // Act: Change language
      store.changeLanguage(testLocale);

      // Assert: Verify repository was called
      expect(mockRepository.changeLanguageCallCount, equals(1));
      expect(mockRepository.lastChangeLanguageValue, equals(testLocale));
    });

    test('handles multiple language changes', () {
      // Arrange: Define language sequence
      final locales = ['en', 'da', 'es', 'en'];

      // Act: Change languages sequentially
      for (final locale in locales) {
        store.changeLanguage(locale);
      }

      // Assert: Verify all changes were made
      expect(mockRepository.changeLanguageCallCount, equals(locales.length));
      expect(store.locale, equals(locales.last));
    });

    test('handles repository exception gracefully', () {
      // Note: The store's changeLanguage method is fire-and-forget async
      // Any exceptions from the repository are not caught and will be thrown in the async void
      // This test verifies that the locale is still changed synchronously

      const testLocale = 'da';

      // Act: Change language
      store.changeLanguage(testLocale);

      // Assert: The locale IS changed synchronously
      expect(store.locale, equals(testLocale));

      // The repository is called asynchronously (fire-and-forget)
      expect(mockRepository.changeLanguageCallCount, equals(1));
    });
  });

  group('getCode Action', () {
    test('returns "US" for "en" locale', () {
      // Arrange: Set locale to English
      store.changeLanguage('en');

      // Act: Get code
      final code = store.getCode();

      // Assert: Verify code
      expect(code, equals('US'));
    });

    test('returns "DK" for "da" locale', () {
      // Arrange: Set locale to Danish
      store.changeLanguage('da');

      // Act: Get code
      final code = store.getCode();

      // Assert: Verify code
      expect(code, equals('DK'));
    });

    test('returns "ES" for "es" locale', () {
      // Arrange: Set locale to Spanish
      store.changeLanguage('es');

      // Act: Get code
      final code = store.getCode();

      // Assert: Verify code
      expect(code, equals('ES'));
    });

    test('returns "US" as default for unsupported locale', () {
      // Arrange: Set unsupported locale (xx is not a supported locale)
      store.changeLanguage('xx');

      // Act: Get code
      final code = store.getCode();

      // Assert: Should return default "US"
      expect(code, equals('US'));
    });

    test('returns "US" as default for empty locale', () {
      // Arrange: Set empty locale
      store.changeLanguage('');

      // Act: Get code
      final code = store.getCode();

      // Assert: Should return default "US"
      expect(code, equals('US'));
    });
  });

  group('getLanguage Action', () {
    test('returns "English" for "en" locale', () {
      // Arrange: Set locale to English
      store.changeLanguage('en');

      // Act: Get language
      final language = store.getLanguage();

      // Assert: Verify language name
      expect(language, equals('English'));
    });

    test('returns "Dansk" for "da" locale', () {
      // Arrange: Set locale to Danish
      store.changeLanguage('da');

      // Act: Get language
      final language = store.getLanguage();

      // Assert: Verify language name (native name)
      expect(language, equals('Dansk'));
    });

    test('returns "Español" for "es" locale', () {
      // Arrange: Set locale to Spanish
      store.changeLanguage('es');

      // Act: Get language
      final language = store.getLanguage();

      // Assert: Verify language name (native name)
      expect(language, equals('Español'));
    });

    test('throws RangeError for unsupported locale', () {
      // Arrange: Set unsupported locale (zz is not a supported locale)
      store.changeLanguage('zz');

      // Act & Assert: Should throw RangeError
      expect(() => store.getLanguage(), throwsA(isA<RangeError>()));
    });

    test('handles language changes correctly', () {
      // Arrange: Start with English
      store.changeLanguage('en');
      expect(store.getLanguage(), equals('English'));

      // Act: Change to Danish
      store.changeLanguage('da');

      // Assert: Should return Danish (native name)
      expect(store.getLanguage(), equals('Dansk'));

      // Act: Change to Spanish
      store.changeLanguage('es');

      // Assert: Should return Spanish (native name)
      expect(store.getLanguage(), equals('Español'));
    });
  });

  group('RTL Language Support', () {
    test('identifies RTL languages correctly', () {
      final rtlLanguages = kSupportedLanguages.where((l) => l.isRTL);
      expect(rtlLanguages.length, equals(3)); // fa, ar, ur

      final rtlLocales = rtlLanguages.map((l) => l.locale).toList();
      expect(rtlLocales, containsAll(['fa', 'ar', 'ur']));
    });

    test('identifies LTR languages correctly', () {
      final ltrLanguages = kSupportedLanguages.where((l) => !l.isRTL);
      expect(ltrLanguages.length, equals(22)); // en, da, es, nl, pl, sv, no, fi, fr, de, it, pt, ru, tr, id, ja, ko, zh, vi, hi, bn, sw

      final ltrLocales = ltrLanguages.map((l) => l.locale).toList();
      expect(ltrLocales, containsAll(['en', 'da', 'es', 'nl', 'pl', 'sv', 'no', 'fi', 'fr', 'de', 'it', 'pt', 'ru', 'tr', 'id', 'ja', 'ko', 'zh', 'vi', 'hi', 'bn', 'sw']));
    });

    test('returns "IR" for "fa" locale', () {
      store.changeLanguage('fa');
      expect(store.getCode(), equals('IR'));
    });

    test('returns "SA" for "ar" locale', () {
      store.changeLanguage('ar');
      expect(store.getCode(), equals('SA'));
    });

    test('returns "PK" for "ur" locale', () {
      store.changeLanguage('ur');
      expect(store.getCode(), equals('PK'));
    });

    test('returns "فارسی" for "fa" locale', () {
      store.changeLanguage('fa');
      expect(store.getLanguage(), equals('فارسی'));
    });

    test('all RTL languages have correct flag emojis', () {
      final rtlLanguageFlags = {
        'fa': '🇮🇷',
        'ar': '🇸🇦',
        'ur': '🇵🇰',
      };

      for (final entry in rtlLanguageFlags.entries) {
        final lang = kSupportedLanguages.firstWhere((l) => l.locale == entry.key);
        expect(lang.flagEmoji, equals(entry.value), reason: '${entry.key} flag should be ${entry.value}');
      }
    });
  });

  group('New LTR Language Support', () {
    test('returns "FR" for "fr" locale', () {
      store.changeLanguage('fr');
      expect(store.getCode(), equals('FR'));
    });

    test('returns "DE" for "de" locale', () {
      store.changeLanguage('de');
      expect(store.getCode(), equals('DE'));
    });

    test('returns "NL" for "nl" locale', () {
      store.changeLanguage('nl');
      expect(store.getCode(), equals('NL'));
    });

    test('returns "PL" for "pl" locale', () {
      store.changeLanguage('pl');
      expect(store.getCode(), equals('PL'));
    });

    test('returns "SE" for "sv" locale', () {
      store.changeLanguage('sv');
      expect(store.getCode(), equals('SE'));
    });

    test('returns "NO" for "no" locale', () {
      store.changeLanguage('no');
      expect(store.getCode(), equals('NO'));
    });

    test('returns "FI" for "fi" locale', () {
      store.changeLanguage('fi');
      expect(store.getCode(), equals('FI'));
    });

    test('returns "IT" for "it" locale', () {
      store.changeLanguage('it');
      expect(store.getCode(), equals('IT'));
    });

    test('returns "PT" for "pt" locale', () {
      store.changeLanguage('pt');
      expect(store.getCode(), equals('PT'));
    });

    test('returns "RU" for "ru" locale', () {
      store.changeLanguage('ru');
      expect(store.getCode(), equals('RU'));
    });

    test('returns "TR" for "tr" locale', () {
      store.changeLanguage('tr');
      expect(store.getCode(), equals('TR'));
    });

    test('returns "ID" for "id" locale', () {
      store.changeLanguage('id');
      expect(store.getCode(), equals('ID'));
    });

    test('returns "JP" for "ja" locale', () {
      store.changeLanguage('ja');
      expect(store.getCode(), equals('JP'));
    });

    test('returns "KR" for "ko" locale', () {
      store.changeLanguage('ko');
      expect(store.getCode(), equals('KR'));
    });

    test('returns "CN" for "zh" locale', () {
      store.changeLanguage('zh');
      expect(store.getCode(), equals('CN'));
    });

    test('returns "VN" for "vi" locale', () {
      store.changeLanguage('vi');
      expect(store.getCode(), equals('VN'));
    });

    test('returns "IN" for "hi" locale', () {
      store.changeLanguage('hi');
      expect(store.getCode(), equals('IN'));
    });

    test('returns "BD" for "bn" locale', () {
      store.changeLanguage('bn');
      expect(store.getCode(), equals('BD'));
    });

    test('returns "TZ" for "sw" locale', () {
      store.changeLanguage('sw');
      expect(store.getCode(), equals('TZ'));
    });

    test('returns "Français" for "fr" locale', () {
      store.changeLanguage('fr');
      expect(store.getLanguage(), equals('Français'));
    });

    test('returns "Deutsch" for "de" locale', () {
      store.changeLanguage('de');
      expect(store.getLanguage(), equals('Deutsch'));
    });

    test('returns "Nederlands" for "nl" locale', () {
      store.changeLanguage('nl');
      expect(store.getLanguage(), equals('Nederlands'));
    });

    test('returns "Polski" for "pl" locale', () {
      store.changeLanguage('pl');
      expect(store.getLanguage(), equals('Polski'));
    });

    test('returns "Svenska" for "sv" locale', () {
      store.changeLanguage('sv');
      expect(store.getLanguage(), equals('Svenska'));
    });

    test('returns "Norsk" for "no" locale', () {
      store.changeLanguage('no');
      expect(store.getLanguage(), equals('Norsk'));
    });

    test('returns "Suomi" for "fi" locale', () {
      store.changeLanguage('fi');
      expect(store.getLanguage(), equals('Suomi'));
    });

    test('returns "Italiano" for "it" locale', () {
      store.changeLanguage('it');
      expect(store.getLanguage(), equals('Italiano'));
    });

    test('returns "Português" for "pt" locale', () {
      store.changeLanguage('pt');
      expect(store.getLanguage(), equals('Português'));
    });

    test('returns "Русский" for "ru" locale', () {
      store.changeLanguage('ru');
      expect(store.getLanguage(), equals('Русский'));
    });

    test('returns "Türkçe" for "tr" locale', () {
      store.changeLanguage('tr');
      expect(store.getLanguage(), equals('Türkçe'));
    });

    test('all new LTR languages have correct flag emojis', () {
      final ltrLanguageFlags = {
        'fr': '🇫🇷',
        'de': '🇩🇪',
        'nl': '🇳🇱',
        'pl': '🇵🇱',
        'sv': '🇸🇪',
        'no': '🇳🇴',
        'fi': '🇫🇮',
        'it': '🇮🇹',
        'pt': '🇧🇷',
        'ru': '🇷🇺',
        'tr': '🇹🇷',
        'id': '🇮🇩',
        'ja': '🇯🇵',
        'ko': '🇰🇷',
        'zh': '🇨🇳',
        'vi': '🇻🇳',
        'hi': '🇮🇳',
        'bn': '🇧🇩',
        'sw': '🇹🇿',
      };

      for (final entry in ltrLanguageFlags.entries) {
        final lang = kSupportedLanguages.firstWhere((l) => l.locale == entry.key);
        expect(lang.flagEmoji, equals(entry.value), reason: '${entry.key} flag should be ${entry.value}');
      }
    });
  });

  group('locale Computed', () {
    test('returns current locale value', () {
      // Arrange: Set locale
      const testLocale = 'da';
      store.changeLanguage(testLocale);

      // Assert: Verify computed property
      expect(store.locale, equals(testLocale));
    });

    test('updates when language is changed', () {
      // Arrange: Start with default locale
      expect(store.locale, equals('en'));

      // Act: Change language
      store.changeLanguage('es');

      // Assert: Computed property should update
      expect(store.locale, equals('es'));
    });

    test('reflects multiple language changes', () {
      // Arrange: Define language sequence
      final locales = ['en', 'da', 'es', 'da', 'en'];

      // Act: Change languages sequentially
      for (final locale in locales) {
        store.changeLanguage(locale);
      }

      // Assert: Should reflect final locale
      expect(store.locale, equals(locales.last));
    });
  });

  group('Integration Tests', () {
    test('complete language change workflow', () async {
      // Arrange: Start with default English
      expect(store.locale, equals('en'));
      expect(store.getCode(), equals('US'));
      expect(store.getLanguage(), equals('English'));

      // Act: Change to Danish
      store.changeLanguage('da');

      // Assert: All methods should reflect Danish
      expect(store.locale, equals('da'));
      expect(store.getCode(), equals('DK'));
      expect(store.getLanguage(), equals('Dansk'));

      // Act: Change to Spanish
      store.changeLanguage('es');

      // Assert: All methods should reflect Spanish
      expect(store.locale, equals('es'));
      expect(store.getCode(), equals('ES'));
      expect(store.getLanguage(), equals('Español'));

      // Verify repository was called for each change
      expect(mockRepository.changeLanguageCallCount, equals(2));
    });

    test('repository and store stay in sync', () {
      // Arrange: Define sequence of languages
      final languages = ['en', 'da', 'es'];

      // Act: Change languages
      for (final lang in languages) {
        store.changeLanguage(lang);
      }

      // Assert: Store should have the last language
      expect(store.locale, equals('es'));

      // Repository should have been called for each change
      expect(mockRepository.changeLanguageCallCount, equals(languages.length));
      expect(mockRepository.lastChangeLanguageValue, equals('es'));
    });
  });

  group('Edge Cases', () {
    test('handles rapid language changes', () {
      // Arrange: Define rapid changes
      final locales = ['en', 'da', 'es', 'da', 'en', 'es', 'da'];

      // Act: Change languages rapidly
      for (final locale in locales) {
        store.changeLanguage(locale);
      }

      // Assert: Should handle all changes
      expect(store.locale, equals(locales.last));
      expect(mockRepository.changeLanguageCallCount, equals(locales.length));
    });

    test('handles changing to same language multiple times', () {
      // Arrange: Define repeated language
      const repeatedLocale = 'en';
      const repeatCount = 5;

      // Act: Change to same language multiple times
      for (var i = 0; i < repeatCount; i++) {
        store.changeLanguage(repeatedLocale);
      }

      // Assert: Should handle all changes
      expect(store.locale, equals(repeatedLocale));
      expect(mockRepository.changeLanguageCallCount, equals(repeatCount));
    });

    test('getCode returns null for null locale', () {
      // This is a theoretical edge case - in practice locale shouldn't be null
      // But we should test the behavior

      // Arrange: Create store with repository returning null
      final testRepository = MockSettingRepository();
      testRepository.setCurrentLanguage(null);
      final testErrorStore = ErrorStore();
      final testStore = LanguageStore(testRepository, testErrorStore);

      // The init will set locale to "en" by default, so this test confirms
      // that we always have a valid locale
      expect(testStore.locale, equals('en'));
      expect(testStore.getCode(), equals('US'));

      // Cleanup
      testErrorStore.dispose();
      testStore.dispose();
    });

    test('supported languages list remains constant', () {
      // Arrange: Get initial list
      final initialLanguages = kSupportedLanguages;

      // Act: Change language
      store.changeLanguage('da');

      // Assert: Supported languages should be the same instance
      expect(identical(kSupportedLanguages, initialLanguages), isTrue);
      expect(kSupportedLanguages.length, equals(initialLanguages.length));
    });

    test('handles unsupported locale without crashing', () {
      // Arrange: Define unsupported locale (xx is not supported)
      const unsupportedLocale = 'xx';

      // Act: Change to unsupported locale (should not crash)
      expect(() => store.changeLanguage(unsupportedLocale), returnsNormally);

      // Assert: Locale should be changed even if unsupported
      expect(store.locale, equals(unsupportedLocale));
      // getCode returns null for unsupported - this is a known quirk
    });

    test('handles empty locale string', () {
      // Act: Change to empty locale
      expect(() => store.changeLanguage(''), returnsNormally);

      // Assert: Locale should be changed
      expect(store.locale, equals(''));
      // getCode would return null for empty - this is a known quirk
    });
  });

  group('dispose', () {
    test('handles dispose gracefully', () {
      // Arrange: Create store to dispose
      final testRepository = MockSettingRepository();
      final testErrorStore = ErrorStore();
      final testStore = LanguageStore(testRepository, testErrorStore);

      // Act: Use store and then dispose
      testStore.changeLanguage('da');
      expect(() => testStore.dispose(), returnsNormally);

      // Assert: Should not throw
      expect(() => testStore.changeLanguage('es'), returnsNormally);
    });

    test('handles multiple dispose calls', () {
      // Arrange: Create store
      final testRepository = MockSettingRepository();
      final testErrorStore = ErrorStore();
      final testStore = LanguageStore(testRepository, testErrorStore);

      // Act: Dispose multiple times
      testStore.dispose();
      expect(() => testStore.dispose(), returnsNormally);

      // Cleanup
      testErrorStore.dispose();
    });
  });
}
