import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/features/admin/domain/admin_models.dart';
import 'package:hamili/features/admin/presentation/widgets/admin_privacy_footer.dart';
import 'package:hamili/features/auth/domain/app_user.dart';

Map<String, dynamic> _row({String? lastActive}) => {
      'id': 7,
      'name': 'Rowan',
      'email': 'rowan@example.com',
      'joined_at': '2026-10-01T02:00:00+00:00',
      'last_active_at': lastActive,
      'days_active_30d': 3,
      'transactions_count': 12,
      'budgets_count': 2,
      'goals_count': 1,
      'hami_messages_total': 34,
      'hami_tokens_total': 18200,
      'hami_tokens_7d': 900,
      'hami_tokens_chat': 15000,
      'hami_tokens_insight': 3200,
    };

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);

  test('a tester who never made a request reads as never active', () {
    final tester = AdminTester.fromJson(_row());
    expect(tester.lastActiveAt, isNull);
    expect(tester.lastActiveLabel(now), 'Never active');
  });

  test('last active is shown relative to now', () {
    expect(AdminTester.fromJson(_row(lastActive: '2026-10-27T11:59:30+00:00')).lastActiveLabel(now), 'Active just now');
    expect(AdminTester.fromJson(_row(lastActive: '2026-10-27T10:00:00+00:00')).lastActiveLabel(now), 'Active 2h ago');
    expect(AdminTester.fromJson(_row(lastActive: '2026-10-24T12:00:00+00:00')).lastActiveLabel(now), 'Active 3d ago');
  });

  test('tester rows parse every count', () {
    final t = AdminTester.fromJson(_row());
    expect([t.transactionsCount, t.hamiMessagesTotal, t.hamiTokensChat, t.hamiTokensInsight], [12, 34, 15000, 3200]);
  });

  test('overview parses the daily trend in order', () {
    final overview = AdminOverview.fromJson({
      'testers_total': 5,
      'active_today': 2,
      'active_7d': 3,
      'active_30d': 4,
      'new_7d': 1,
      'hami_messages_7d': 9,
      'hami_tokens_7d': 1200,
      'daily': [
        {'day': '2026-10-26', 'active_testers': 1, 'hami_tokens': 300},
        {'day': '2026-10-27', 'active_testers': 2, 'hami_tokens': 900},
      ],
      'tracking_since': null,
    });
    expect(overview.daily.map((d) => d.activeTesters), [1, 2]);
    expect(overview.trackingSince, isNull);
  });

  test('users are not admins unless the server says so', () {
    final base = {'id': 1, 'email': 'a@b.c', 'preferred_name': 'A', 'preferred_currency': 'PHP'};
    expect(AppUser.fromJson(base).isAdmin, isFalse);
    expect(AppUser.fromJson({...base, 'is_admin': true}).isAdmin, isTrue);
  });

  testWidgets('the privacy footer states exactly what admins can see', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AdminPrivacyFooter())));
    expect(
      find.text('Admins see names, emails and usage counts only. Amounts, notes and Hami chats are never shown.'),
      findsOneWidget,
    );
  });

  test('the usage line pluralizes counts', () {
    final one = AdminTester.fromJson({..._row(), 'transactions_count': 1, 'hami_messages_total': 1, 'hami_tokens_total': 1});
    final many = AdminTester.fromJson(_row());
    expect(one.usageSummary, '1 transaction · 1 Hami message · 1 token');
    expect(many.usageSummary, '12 transactions · 34 Hami messages · 18.2K tokens');
  });
}
