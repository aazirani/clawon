import 'dart:ui' as ui;

import 'package:clawon/core/stores/error/error_store.dart';
import 'package:clawon/domain/entities/language/language.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:mobx/mobx.dart';

part 'language_store.g.dart';

const List<Language> kSupportedLanguages = [
  // LTR Languages
  Language(
    code: 'US',
    locale: 'en',
    language: 'English',
    englishName: 'English',
    flagEmoji: '🇺🇸',
    isRTL: false,
  ),
  Language(
    code: 'DK',
    locale: 'da',
    language: 'Dansk',
    englishName: 'Danish',
    flagEmoji: '🇩🇰',
    isRTL: false,
  ),
  Language(
    code: 'ES',
    locale: 'es',
    language: 'Español',
    englishName: 'Spanish',
    flagEmoji: '🇪🇸',
    isRTL: false,
  ),
  Language(
    code: 'NL',
    locale: 'nl',
    language: 'Nederlands',
    englishName: 'Dutch',
    flagEmoji: '🇳🇱',
    isRTL: false,
  ),
  Language(
    code: 'PL',
    locale: 'pl',
    language: 'Polski',
    englishName: 'Polish',
    flagEmoji: '🇵🇱',
    isRTL: false,
  ),
  Language(
    code: 'SE',
    locale: 'sv',
    language: 'Svenska',
    englishName: 'Swedish',
    flagEmoji: '🇸🇪',
    isRTL: false,
  ),
  Language(
    code: 'NO',
    locale: 'no',
    language: 'Norsk',
    englishName: 'Norwegian',
    flagEmoji: '🇳🇴',
    isRTL: false,
  ),
  Language(
    code: 'FI',
    locale: 'fi',
    language: 'Suomi',
    englishName: 'Finnish',
    flagEmoji: '🇫🇮',
    isRTL: false,
  ),
  Language(
    code: 'FR',
    locale: 'fr',
    language: 'Français',
    englishName: 'French',
    flagEmoji: '🇫🇷',
    isRTL: false,
  ),
  Language(
    code: 'DE',
    locale: 'de',
    language: 'Deutsch',
    englishName: 'German',
    flagEmoji: '🇩🇪',
    isRTL: false,
  ),
  Language(
    code: 'IT',
    locale: 'it',
    language: 'Italiano',
    englishName: 'Italian',
    flagEmoji: '🇮🇹',
    isRTL: false,
  ),
  Language(
    code: 'PT',
    locale: 'pt',
    language: 'Português',
    englishName: 'Portuguese',
    flagEmoji: '🇧🇷',
    isRTL: false,
  ),
  Language(
    code: 'RU',
    locale: 'ru',
    language: 'Русский',
    englishName: 'Russian',
    flagEmoji: '🇷🇺',
    isRTL: false,
  ),
  Language(
    code: 'TR',
    locale: 'tr',
    language: 'Türkçe',
    englishName: 'Turkish',
    flagEmoji: '🇹🇷',
    isRTL: false,
  ),
  Language(
    code: 'ID',
    locale: 'id',
    language: 'Bahasa Indonesia',
    englishName: 'Indonesian',
    flagEmoji: '🇮🇩',
    isRTL: false,
  ),
  Language(
    code: 'JP',
    locale: 'ja',
    language: '日本語',
    englishName: 'Japanese',
    flagEmoji: '🇯🇵',
    isRTL: false,
    fontFamily: 'Noto Sans JP',
    fontFallback: ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic'],
  ),
  Language(
    code: 'KR',
    locale: 'ko',
    language: '한국어',
    englishName: 'Korean',
    flagEmoji: '🇰🇷',
    isRTL: false,
    fontFamily: 'Noto Sans KR',
    fontFallback: ['Noto Sans KR', 'Apple SD Gothic Neo'],
  ),
  Language(
    code: 'CN',
    locale: 'zh',
    language: '中文',
    englishName: 'Chinese',
    flagEmoji: '🇨🇳',
    isRTL: false,
    fontFamily: 'Noto Sans SC',
    fontFallback: ['Noto Sans SC', 'PingFang SC', 'Heiti SC'],
  ),
  Language(
    code: 'VN',
    locale: 'vi',
    language: 'Tiếng Việt',
    englishName: 'Vietnamese',
    flagEmoji: '🇻🇳',
    isRTL: false,
  ),
  Language(
    code: 'IN',
    locale: 'hi',
    language: 'हिन्दी',
    englishName: 'Hindi',
    flagEmoji: '🇮🇳',
    isRTL: false,
  ),
  Language(
    code: 'BD',
    locale: 'bn',
    language: 'বাংলা',
    englishName: 'Bengali',
    flagEmoji: '🇧🇩',
    isRTL: false,
  ),
  Language(
    code: 'TZ',
    locale: 'sw',
    language: 'Kiswahili',
    englishName: 'Swahili',
    flagEmoji: '🇹🇿',
    isRTL: false,
  ),
  // RTL Languages
  Language(
    code: 'IR',
    locale: 'fa',
    language: 'فارسی',
    englishName: 'Persian',
    flagEmoji: '🇮🇷',
    isRTL: true,
    fontFamily: 'Vazirmatn',
    fontFallback: ['Vazirmatn', 'Noto Sans Arabic', 'Tahoma'],
  ),
  Language(
    code: 'SA',
    locale: 'ar',
    language: 'العربية',
    englishName: 'Arabic',
    flagEmoji: '🇸🇦',
    isRTL: true,
    fontFamily: 'Noto Sans Arabic',
    fontFallback: ['Noto Sans Arabic', 'Arial'],
  ),
  Language(
    code: 'PK',
    locale: 'ur',
    language: 'اردو',
    englishName: 'Urdu',
    flagEmoji: '🇵🇰',
    isRTL: true,
    fontFamily: 'Noto Nastaliq Urdu',
    fontFallback: ['Noto Nastaliq Urdu', 'Arial'],
  ),
];

class LanguageStore = _LanguageStore with _$LanguageStore;

abstract class _LanguageStore with Store {
  // repository instance
  final SettingRepository _repository;

  // store for handling errors
  final ErrorStore errorStore;

  // constructor:---------------------------------------------------------------
  _LanguageStore(this._repository, this.errorStore) {
    init();
  }

  // store variables:-----------------------------------------------------------
  @observable
  String _locale = "en";

  @computed
  String get locale => _locale;

  // actions:-------------------------------------------------------------------
  @action
  void changeLanguage(String value) {
    _locale = value;
    _repository.changeLanguage(value).then((_) {
      // write additional logic here
    });
  }

  String getCode() {
    final language = kSupportedLanguages.firstWhere(
      (lang) => lang.locale == _locale,
      orElse: () => kSupportedLanguages.first,
    );
    return language.code;
  }

  @action
  String? getLanguage() {
    return kSupportedLanguages[kSupportedLanguages
            .indexWhere((language) => language.locale == _locale)]
        .language;
  }

  // general:-------------------------------------------------------------------
  void init() async {
    // getting current language from shared preference
    if (_repository.currentLanguage != null) {
      _locale = _repository.currentLanguage!;
    } else {
      // No saved preference - try to use device language
      _locale = _getDeviceLanguageOrDefault();
    }
  }

  /// Returns the device language if supported, otherwise defaults to English
  String _getDeviceLanguageOrDefault() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale.languageCode;

    // Check if device locale is supported
    final supportedLanguage = kSupportedLanguages.firstWhere(
      (lang) => lang.locale == deviceLocale,
      orElse: () => kSupportedLanguages.first, // Default to English
    );

    return supportedLanguage.locale;
  }

  // dispose:-------------------------------------------------------------------
  void dispose() {}
}
