import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/features/analytics/domain/analytics_models.dart';
import 'package:hamili/features/analytics/presentation/analytics_providers.dart';
import 'package:hamili/features/auth/domain/app_user.dart';
import 'package:hamili/features/auth/presentation/auth_providers.dart';
import 'package:hamili/features/budgets/data/budget_repository.dart';
import 'package:hamili/features/budgets/domain/budget.dart';
import 'package:hamili/features/budgets/presentation/budget_providers.dart';
import 'package:hamili/features/chat/presentation/hami_chat_page.dart';
import 'package:hamili/features/hami/domain/hami_definition.dart';
import 'package:hamili/features/hami/domain/hami_pose.dart';
import 'package:hamili/features/hami/domain/hami_reaction.dart';
import 'package:hamili/features/hami/presentation/hami_avatar.dart';
import 'package:hamili/features/hami/presentation/hami_controller.dart';
import 'package:hamili/features/hami/presentation/hami_reaction_overlay.dart';
import 'package:hamili/features/transactions/data/transaction_repository.dart';
import 'package:hamili/features/transactions/domain/category.dart';
import 'package:hamili/features/transactions/domain/transaction.dart';
import 'package:hamili/features/transactions/presentation/transaction_providers.dart';

// The whole path a real expense takes: the server's refreshed budget level
// reaches the tracker, the controller and the floating Hami.

class _Budgets extends BudgetRepository {
  _Budgets() : super(dio: Dio());
  String level = 'approaching';
  double pct = 70;

  @override
  Future<List<AppBudget>?> cached({int? month, int? year}) async => null;

  @override
  Future<List<AppBudget>> list({int? month, int? year}) async {
    final now = DateTime.now();
    return [
      AppBudget(
        id: 1,
        categoryId: 1,
        month: now.month,
        year: now.year,
        limitAmount: 1000,
        spentAmount: pct * 10,
        remainingAmount: 1000 - pct * 10,
        percentageUsed: pct,
        alertLevel: level,
      ),
    ];
  }
}

class _Transactions extends TransactionRepository {
  _Transactions(this.budgets) : super(dio: Dio());
  final _Budgets budgets;

  @override
  Future<List<AppTransaction>?> cached() async => null;

  @override
  Future<List<AppTransaction>> list({int? categoryId, String? search}) async => const [];

  @override
  Future<AppTransaction> create({
    required int categoryId,
    required double amount,
    required String type,
    required DateTime transactionDate,
    String? note,
  }) async {
    if (type == 'expense') {
      budgets
        ..pct = 85
        ..level = 'high';
    }
    return AppTransaction(id: 9, categoryId: categoryId, amount: amount, type: type, transactionDate: transactionDate);
  }
}

class _SignedIn extends CurrentUserNotifier {
  @override
  Future<AppUser?> build() async =>
      const AppUser(id: 1, email: 'flow@example.com', preferredName: 'Flow', preferredCurrency: 'PHP');
}

void main() {
  final def = HamiDefinition.fromJson(jsonDecode(File('assets/hami/hami.avatar.json').readAsStringSync()) as Map<String, dynamic>);

  testWidgets('an expense that pushes a budget to high makes the floating Hami warn', (tester) async {
    final budgets = _Budgets();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hamiDefinitionProvider.overrideWith((ref) => def),
        currentUserProvider.overrideWith(_SignedIn.new),
        budgetRepositoryProvider.overrideWithValue(budgets),
        transactionRepositoryProvider.overrideWithValue(_Transactions(budgets)),
        categoriesProvider.overrideWith((ref) => const [AppCategory(id: 1, name: 'Food', type: 'expense')]),
        dashboardSummaryProvider.overrideWith((ref) => const AnalyticsSummary(income: 2000, expense: 700, net: 1300)),
      ],
      child: MaterialApp(
        builder: (context, child) => Stack(fit: StackFit.expand, children: [if (child != null) child, const HamiReactionOverlay()]),
        home: const Scaffold(),
      ),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(budgetsProvider.future);
    await tester.pump();
    expect(find.byType(HamiAvatar), findsNothing);

    await container.read(transactionsProvider.future);
    await container.read(transactionsProvider.notifier).addTransaction(
          categoryId: 1,
          amount: 150,
          type: 'expense',
          transactionDate: DateTime.now(),
        );
    await tester.pump();
    await tester.pump();

    expect(container.read(hamiControllerProvider).reaction, HamiReaction.warnSpending);
    expect(find.byType(HamiAvatar), findsOneWidget);
    expect(find.text('Food is at 85% of its budget!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(HamiAvatar), findsNothing);
  });

  testWidgets('the chat header Hami shakes his head for a negative answer', (tester) async {
    tester.view.physicalSize = const Size(2400, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [hamiDefinitionProvider.overrideWith((ref) => def)],
      child: const MaterialApp(home: HamiChatPage()),
    ));
    await tester.pump();
    final avatar = find.byType(HamiAvatar);
    HamiPose pose() =>
        (tester.widget<CustomPaint>(find.descendant(of: avatar, matching: find.byType(CustomPaint))).painter! as HamiPainter)
            .frame
            .value!
            .pose;

    ProviderScope.containerOf(tester.element(avatar)).read(hamiControllerProvider.notifier).play(HamiReaction.answerNo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(pose().yaw.abs(), greaterThan(10));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
}
