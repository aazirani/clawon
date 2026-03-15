import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clawon/core/widgets/rtl_text_field.dart';

void main() {
  group('RtlTextField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: RtlTextField(
            controller: controller,
          ),
        ),
      );
    }

    testWidgets('starts with LTR alignment for empty text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.left);
      expect(textField.textDirection, TextDirection.ltr);
    });

    testWidgets('switches to RTL when typing Arabic', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate typing Arabic text
      controller.text = 'مرحبا';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);
      expect(textField.textDirection, TextDirection.rtl);
    });

    testWidgets('switches to RTL when typing Persian', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate typing Persian text
      controller.text = 'سلام';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);
      expect(textField.textDirection, TextDirection.rtl);
    });

    testWidgets('stays LTR when typing English', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate typing English text
      controller.text = 'Hello';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.left);
      expect(textField.textDirection, TextDirection.ltr);
    });

    testWidgets('direction changes dynamically when text changes', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Start with English
      controller.text = 'Hello';
      await tester.pump();

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.left);

      // Change to Persian
      controller.text = 'سلام';
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);

      // Clear text
      controller.text = '';
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.left);
    });

    testWidgets('handles Hebrew text as RTL', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate typing Hebrew text
      controller.text = 'שלום';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);
      expect(textField.textDirection, TextDirection.rtl);
    });

    testWidgets('handles Urdu text as RTL', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simulate typing Urdu text
      controller.text = 'سلام';
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);
      expect(textField.textDirection, TextDirection.rtl);
    });

    testWidgets('first strong character determines direction', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Text starts with RTL character
      controller.text = 'مرحبا Hello';
      await tester.pump();

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.right);

      // Text starts with LTR character
      controller.text = 'Hello مرحبا';
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textAlign, TextAlign.left);
    });
  });
}
