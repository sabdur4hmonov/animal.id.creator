import 'package:biolivestock_capture/animal_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in [
    'CON',
    'PRN',
    'AUX',
    'NUL',
    for (var i = 1; i <= 9; i++) ...['COM$i', 'LPT$i'],
  ]) {
    test('rejects reserved ID $name in either case', () {
      expect(validateAnimalId(name), isNotNull);
      expect(validateAnimalId(name.toLowerCase()), isNotNull);
    });
  }
  test('accepts field IDs and rejects unsupported characters and lengths', () {
    for (final name in ['F01-C001', 'COM10', 'COW_2', 'A' * 64]) {
      expect(validateAnimalId(name), isNull);
    }
    for (final name in ['', '../escape', 'A B', '_COW', 'A' * 65]) {
      expect(validateAnimalId(name), isNotNull);
    }
  });
  testWidgets('invalid animal ID prevents a capture form submission', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    var captured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: Column(
              children: [
                TextFormField(initialValue: 'CON', validator: validateAnimalId),
                TextButton(
                  onPressed: () {
                    if (key.currentState!.validate()) captured = true;
                  },
                  child: const Text('Capture'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Capture'));
    await tester.pump();
    expect(captured, isFalse);
    expect(
      find.text('This animal ID is a reserved filesystem name'),
      findsOneWidget,
    );
  });
}
