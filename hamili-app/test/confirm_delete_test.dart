import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/shared/widgets/confirm_delete.dart';

void main() {
  Future<bool?> tapDeleteThen(WidgetTester tester, String choice) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await confirmDelete(context, title: 'Delete goal?', message: 'Gone for good.'),
          child: const Text('trash'),
        ),
      ),
    ));
    await tester.tap(find.text('trash'));
    await tester.pumpAndSettle();
    expect(find.text('Delete goal?'), findsOneWidget);
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('confirming returns true', (tester) async {
    expect(await tapDeleteThen(tester, 'Delete'), isTrue);
  });

  testWidgets('cancelling returns false', (tester) async {
    expect(await tapDeleteThen(tester, 'Cancel'), isFalse);
  });
}
