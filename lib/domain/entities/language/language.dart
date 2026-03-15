class Language {
  /// The country/region code (US, IR, SA, etc.)
  final String code;

  /// The locale code (en, fa, ar, etc.)
  final String locale;

  /// The native name of the language (English, فارسی, العربية)
  final String language;

  /// The English name for sorting and accessibility
  final String englishName;

  /// Flag emoji for visual recognition (🇺🇸, 🇮🇷, 🇸🇦)
  final String flagEmoji;

  /// Whether this language is right-to-left
  final bool isRTL;

  /// Map of translation keys to localized strings
  final Map<String, String>? dictionary;

  /// Primary font family for this language (null = use default Inter)
  final String? fontFamily;

  /// Font fallback chain for this language
  final List<String>? fontFallback;

  const Language({
    required this.code,
    required this.locale,
    required this.language,
    required this.englishName,
    required this.flagEmoji,
    required this.isRTL,
    this.dictionary,
    this.fontFamily,
    this.fontFallback,
  });
}
