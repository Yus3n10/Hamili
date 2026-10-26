import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/features/profile/presentation/privacy_notice_tile.dart';

void main() {
  testWidgets('the Privacy row explains what the admin can and cannot see', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PrivacyNoticeTile())));

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('your name and email'), findsOneWidget);
    expect(find.textContaining('Never your money, notes, or chats'), findsOneWidget);
    expect(find.textContaining('password'), findsOneWidget);
  });
}
