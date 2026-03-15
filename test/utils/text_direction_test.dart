import 'package:clawon/utils/text_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectTextDirection', () {
    group('RTL Detection', () {
      test('detects Persian text as RTL', () {
        expect(detectTextDirection('سلام'), equals(TextDirection.rtl));
        expect(detectTextDirection('چطورید؟'), equals(TextDirection.rtl));
        expect(detectTextDirection('این یک پیام فارسی است'), equals(TextDirection.rtl));
      });

      test('detects Arabic text as RTL', () {
        expect(detectTextDirection('مرحبا'), equals(TextDirection.rtl));
        expect(detectTextDirection('العربية'), equals(TextDirection.rtl));
        expect(detectTextDirection('كيف حالك؟'), equals(TextDirection.rtl));
      });

      test('detects Hebrew text as RTL', () {
        expect(detectTextDirection('שלום'), equals(TextDirection.rtl));
        expect(detectTextDirection('עברית'), equals(TextDirection.rtl));
      });

      test('detects Urdu text as RTL', () {
        expect(detectTextDirection('ہیلو'), equals(TextDirection.rtl));
        expect(detectTextDirection('اردو'), equals(TextDirection.rtl));
      });
    });

    group('LTR Detection', () {
      test('detects English text as LTR', () {
        expect(detectTextDirection('Hello'), equals(TextDirection.ltr));
        expect(detectTextDirection('How are you?'), equals(TextDirection.ltr));
      });

      test('detects Danish text as LTR', () {
        expect(detectTextDirection('Hej'), equals(TextDirection.ltr));
        expect(detectTextDirection('Hvordan går det?'), equals(TextDirection.ltr));
      });

      test('detects Spanish text as LTR', () {
        expect(detectTextDirection('Hola'), equals(TextDirection.ltr));
        expect(detectTextDirection('¿Cómo estás?'), equals(TextDirection.ltr));
      });

      test('detects Cyrillic text as LTR', () {
        expect(detectTextDirection('Привет'), equals(TextDirection.ltr));
        expect(detectTextDirection('Русский'), equals(TextDirection.ltr));
      });
    });

    group('Mixed Content', () {
      test('uses first strong character - LTR first', () {
        expect(detectTextDirection('Hello سلام'), equals(TextDirection.ltr));
        expect(detectTextDirection('Hi مرحبا'), equals(TextDirection.ltr));
      });

      test('uses first strong character - RTL first', () {
        expect(detectTextDirection('سلام Hello'), equals(TextDirection.rtl));
        expect(detectTextDirection('مرحبا Hi'), equals(TextDirection.rtl));
      });

      test('handles numbers at start', () {
        expect(detectTextDirection('123 Hello'), equals(TextDirection.ltr));
        expect(detectTextDirection('123 سلام'), equals(TextDirection.rtl));
      });

      test('handles punctuation at start', () {
        expect(detectTextDirection('...Hello'), equals(TextDirection.ltr));
        expect(detectTextDirection('...سلام'), equals(TextDirection.rtl));
      });
    });

    group('Edge Cases', () {
      test('returns LTR for empty string', () {
        expect(detectTextDirection(''), equals(TextDirection.ltr));
      });

      test('returns LTR for whitespace only', () {
        expect(detectTextDirection('   '), equals(TextDirection.ltr));
        expect(detectTextDirection('\n\t'), equals(TextDirection.ltr));
      });

      test('returns LTR for numbers only', () {
        expect(detectTextDirection('123'), equals(TextDirection.ltr));
        expect(detectTextDirection('456.789'), equals(TextDirection.ltr));
      });

      test('returns LTR for punctuation only', () {
        expect(detectTextDirection('...'), equals(TextDirection.ltr));
        expect(detectTextDirection('!?.'), equals(TextDirection.ltr));
      });

      test('handles emojis before text', () {
        expect(detectTextDirection('👋 Hello'), equals(TextDirection.ltr));
        expect(detectTextDirection('👋 سلام'), equals(TextDirection.rtl));
      });

      test('handles code snippets', () {
        expect(detectTextDirection('function test() {}'), equals(TextDirection.ltr));
        expect(detectTextDirection('def hello():'), equals(TextDirection.ltr));
      });
    });
  });

  group('TextDirectionExtension', () {
    test('isRTL returns true for RTL direction', () {
      expect(TextDirection.rtl.isRTL, isTrue);
    });

    test('isRTL returns false for LTR direction', () {
      expect(TextDirection.ltr.isRTL, isFalse);
    });
  });
}
