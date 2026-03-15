import 'package:flutter/material.dart';

/// Detects text direction based on the first strong directional character.
/// This follows the Unicode Bidirectional Algorithm's "first strong character" rule.
///
/// RTL scripts include: Arabic, Hebrew, Syriac, Thaana, N'Ko, and presentation forms.
/// Returns [TextDirection.rtl] if first strong character is RTL, otherwise [TextDirection.ltr].
TextDirection detectTextDirection(String text) {
  if (text.isEmpty) {
    return TextDirection.ltr;
  }

  // RTL Unicode ranges:
  // - Hebrew: U+0590-U+05FF
  // - Arabic: U+0600-U+06FF
  // - Syriac: U+0700-U+074F
  // - Thaana: U+0780-U+07BF
  // - N'Ko: U+07C0-U+07FF
  // - Hebrew Presentation Forms: U+FB1D-U+FB4F
  // - Arabic Presentation Forms-A: U+FB50-U+FDFF
  // - Arabic Presentation Forms-B: U+FE70-U+FEFC
  final rtlRegex = RegExp(r'[\u0590-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]');
  final ltrRegex = RegExp(r'[A-Za-z\u0400-\u052F]'); // Latin and Cyrillic

  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    if (rtlRegex.hasMatch(char)) {
      return TextDirection.rtl;
    } else if (ltrRegex.hasMatch(char)) {
      return TextDirection.ltr;
    }
  }

  return TextDirection.ltr; // Default to LTR
}

/// Extension to check if a text direction is RTL
extension TextDirectionExtension on TextDirection {
  bool get isRTL => this == TextDirection.rtl;
}
