import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/network/offline_queue.dart';
import 'package:hamili/features/budgets/domain/budget.dart';
import 'package:hamili/features/goals/data/goal_repository.dart';
import 'package:hamili/features/goals/domain/goal.dart';
import 'package:hamili/features/goals/presentation/goal_providers.dart';
import 'package:hamili/features/hami/domain/budget_alert_tracker.dart';
import 'package:hamili/features/hami/domain/hami_definition.dart';
import 'package:hamili/features/hami/domain/hami_pose.dart';
import 'package:hamili/features/hami/domain/hami_reaction.dart';
import 'package:hamili/features/hami/domain/hami_timeline.dart';
import 'package:hamili/features/hami/presentation/hami_avatar.dart';
import 'package:hamili/features/hami/presentation/hami_controller.dart';

final HamiDefinition def =
    HamiDefinition.fromJson(jsonDecode(File('assets/hami/hami.avatar.json').readAsStringSync()) as Map<String, dynamic>);

AppBudget budget(String level, {int id = 1, double pct = 50, DateTime? at}) {
  final now = at ?? DateTime.now();
  return AppBudget(
    id: id,
    categoryId: 3,
    month: now.month,
    year: now.year,
    limitAmount: 1000,
    spentAmount: pct * 10,
    remainingAmount: 1000 - pct * 10,
    percentageUsed: pct,
    alertLevel: level,
  );
}

Widget harness({bool reduced = false}) => ProviderScope(
      overrides: [hamiDefinitionProvider.overrideWith((ref) => def)],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Directionality(textDirection: TextDirection.ltr, child: Center(child: HamiAvatar(size: 100))),
      ),
    );

HamiPose poseOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(HamiAvatar), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as HamiPainter).frame.value!.pose;
}

HamiController controllerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HamiAvatar))).read(hamiControllerProvider.notifier);

HamiPlayback playbackOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HamiAvatar))).read(hamiControllerProvider);

class _FakeGoals extends GoalRepository {
  _FakeGoals(this.onContribute) : super(dio: Dio());

  final Future<AppSavingsGoal> Function() onContribute;

  static const goal = AppSavingsGoal(
    id: 7,
    title: 'Laptop',
    targetAmount: 1000,
    currentAmount: 100,
    remainingAmount: 900,
    progressPercentage: 10,
    status: 'in_progress',
  );

  @override
  Future<List<AppSavingsGoal>?> cached() async => null;

  @override
  Future<List<AppSavingsGoal>> list() async => [goal];

  @override
  Future<AppSavingsGoal> contribute(int id, double amount) => onContribute();
}

ProviderContainer goalsContainer(Future<AppSavingsGoal> Function() onContribute) {
  final container = ProviderContainer(overrides: [
    hamiDefinitionProvider.overrideWith((ref) => def),
    goalRepositoryProvider.overrideWithValue(_FakeGoals(onContribute)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('exported definition', () {
    test('has an animation for every reaction', () {
      for (final reaction in HamiReaction.values) {
        expect(def.animations, contains(reaction.animation), reason: reaction.name);
      }
      expect(def.bodyColor, const Color(0xFFF9B7BE));
    });

    test('angry turns Hami red and slants the brows; worried raises them', () {
      final angry = poseFor(def, 'angry-glare');
      expect(angry.skin, isNot(def.bodyColor));
      expect(angry.brow, greaterThan(0.8));
      expect(angry.shake, 1);
      expect(poseFor(def, 'worried').brow, lessThan(-0.5));
      expect(poseFor(def, 'excited-wide').isGoogly, isTrue);
    });
  });

  group('timeline', () {
    test('a once animation ends on its last step', () {
      final yes = def.animations['answer-yes']!;
      final end = evaluate(def, yes, yes.durationMs + 500);
      expect(end.pitch, poseFor(def, 'friendly').pitch);
    });

    test('an interrupted animation starts from the pose Hami held', () {
      final from = poseFor(def, 'angry-glare');
      final start = evaluate(def, def.animations['answer-yes']!, 0, from: from);
      expect(start.skin, from.skin);
      expect(start.pitch, from.pitch);
    });

    test('blinks close and reopen', () {
      expect(blinkOpenness(0, 240), 1);
      expect(blinkOpenness(120, 240), 0);
      expect(blinkOpenness(240, 240), 1);
    });
  });

  group('budget tracker', () {
    test('crossing the warning threshold after spending warns once', () {
      final tracker = BudgetAlertTracker();
      expect(tracker.update([budget('ok', pct: 50)]), isNull);
      tracker.expectSpending();
      final alert = tracker.update([budget('high', pct: 85)]);
      expect(alert?.reaction, HamiReaction.warnSpending);
      tracker.expectSpending();
      expect(tracker.update([budget('high', pct: 88)]), isNull);
    });

    test('repeated refreshes and first loads never warn', () {
      final tracker = BudgetAlertTracker();
      tracker.expectSpending();
      expect(tracker.update([budget('over', pct: 120)]), isNull);
      for (var i = 0; i < 5; i++) {
        expect(tracker.update([budget('over', pct: 120)]), isNull);
      }
    });

    test('a crossing without a spending event in this app stays quiet', () {
      final tracker = BudgetAlertTracker();
      tracker.update([budget('ok')]);
      expect(tracker.update([budget('high', pct: 85)]), isNull);
    });

    test('distinguishes approaching, high and over', () {
      for (final (level, reaction) in [
        ('approaching', HamiReaction.budgetConcern),
        ('high', HamiReaction.warnSpending),
        ('over', HamiReaction.overBudget),
      ]) {
        final tracker = BudgetAlertTracker()..update([budget('ok')]);
        tracker.expectSpending();
        expect(tracker.update([budget(level)])?.reaction, reaction);
      }
    });

    test('reads the server level, not its own arithmetic', () {
      final tracker = BudgetAlertTracker()..update([budget('ok', pct: 10)]);
      tracker.expectSpending();
      expect(tracker.update([budget('ok', pct: 95)]), isNull);
    });

    test('ignores offline placeholders and other months', () {
      final tracker = BudgetAlertTracker();
      final lastYear = DateTime.now().subtract(const Duration(days: 400));
      tracker.update([budget('ok', id: -5), budget('ok', id: 2, at: lastYear)]);
      tracker.expectSpending();
      expect(tracker.update([budget('over', id: -5), budget('over', id: 2, at: lastYear)]), isNull);
    });

    test('balance dropping below zero after spending is flagged once', () {
      final tracker = BudgetAlertTracker();
      expect(tracker.updateBalance(200), isFalse);
      tracker.expectSpending();
      expect(tracker.updateBalance(-50), isTrue);
      expect(tracker.updateBalance(-60), isFalse);
    });

    test('budgets parse the server alert level, defaulting to ok', () {
      final json = {
        'id': 1,
        'category_id': 3,
        'month': 1,
        'year': 2026,
        'limit_amount': 100,
        'spent_amount': 90,
        'remaining_amount': 10,
        'percentage_used': 90,
      };
      expect(AppBudget.fromJson(json).alertLevel, 'ok');
      expect(AppBudget.fromJson({...json, 'alert_level': 'high'}).alertLevel, 'high');
    });
  });

  group('chat replies', () {
    test('an explicit negative answer shakes the head', () {
      expect(HamiReaction.forChatReply(answer: 'negative', actionDone: false), HamiReaction.answerNo);
    });

    test('an affirmative answer nods', () {
      expect(HamiReaction.forChatReply(answer: 'affirmative', actionDone: false), HamiReaction.answerYes);
      expect(HamiReaction.forChatReply(answer: 'warning', actionDone: false), HamiReaction.budgetConcern);
    });

    test('replies without a typed answer make no gesture, whatever their words', () {
      // "No worries, yes you can track that" carries no answer field.
      expect(HamiReaction.forChatReply(answer: null, actionDone: false), isNull);
      expect(HamiReaction.forChatReply(answer: 'no', actionDone: false), isNull);
      expect(HamiReaction.forChatReply(answer: 'yes', actionDone: false), isNull);
    });

    test('money effects celebrate only when the action went through', () {
      expect(HamiReaction.forChatReply(effect: 'savings', actionDone: true), HamiReaction.celebrateSavings);
      expect(HamiReaction.forChatReply(effect: 'income', actionDone: true), HamiReaction.celebrateIncome);
      expect(HamiReaction.forChatReply(effect: 'income', actionDone: false), isNull);
    });
  });

  group('savings contributions', () {
    test('a successful contribution celebrates', () async {
      final container = goalsContainer(() async => _FakeGoals.goal);
      await container.read(goalsProvider.future);
      await container.read(goalsProvider.notifier).contribute(7, 50);
      expect(container.read(hamiControllerProvider).reaction, HamiReaction.celebrateSavings);
      expect(container.read(hamiControllerProvider).caption, contains('Laptop'));
    });

    test('a failed contribution does not', () async {
      final container = goalsContainer(
        () async => throw DioException.badResponse(
          statusCode: 422,
          requestOptions: RequestOptions(path: '/goals/7/contribute'),
          response: Response(requestOptions: RequestOptions(path: '/goals/7/contribute'), statusCode: 422),
        ),
      );
      await container.read(goalsProvider.future);
      await expectLater(container.read(goalsProvider.notifier).contribute(7, 50), throwsA(isA<DioException>()));
      expect(container.read(hamiControllerProvider).isIdle, isTrue);
    });

    test('an unsaved, offline-queued contribution does not', () async {
      final container = goalsContainer(() async => throw const OfflineQueuedException());
      await container.read(goalsProvider.future);
      await container.read(goalsProvider.notifier).contribute(7, 50);
      expect(container.read(hamiControllerProvider).isIdle, isTrue);
    });
  });

  group('avatar', () {
    testWidgets('renders in the neutral state', (tester) async {
      await tester.pumpWidget(harness());
      final pose = poseOf(tester);
      expect(pose.skin, def.bodyColor);
      expect(pose.eyeScale, 1);
      expect(pose.brow, 0);
      expect(pose.pitch, 0);
      expect(find.bySemanticsLabel('Hami'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('idling does not block a reaction', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(seconds: 2));
      expect(controllerOf(tester).play(HamiReaction.answerYes), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(poseOf(tester).pitch, lessThan(-8));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a stronger reaction interrupts cleanly; a weaker one waits its turn', (tester) async {
      await tester.pumpWidget(harness());
      controllerOf(tester).play(HamiReaction.budgetConcern);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final before = poseOf(tester);

      expect(controllerOf(tester).play(HamiReaction.warnSpending), isTrue);
      await tester.pump();
      expect(poseOf(tester).roll, closeTo(before.roll, 0.001));
      await tester.pump(const Duration(milliseconds: 600));
      expect(poseOf(tester).skin, isNot(def.bodyColor));

      expect(controllerOf(tester).play(HamiReaction.budgetConcern), isFalse);
      expect(playbackOf(tester).reaction, HamiReaction.warnSpending);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('returns to idle after the animation completes', (tester) async {
      await tester.pumpWidget(harness());
      controllerOf(tester).play(HamiReaction.answerNo);
      await tester.pump();
      expect(playbackOf(tester).reaction, HamiReaction.answerNo);
      await tester.pump(Duration(milliseconds: def.animations['answer-no']!.durationMs + 50));
      expect(playbackOf(tester).isIdle, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(poseOf(tester).yaw, closeTo(0, 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rebuilds do not replay a reaction', (tester) async {
      await tester.pumpWidget(harness());
      controllerOf(tester).play(HamiReaction.celebrateIncome);
      await tester.pump();
      final seq = playbackOf(tester).seq;
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(harness());
      }
      expect(playbackOf(tester).seq, seq);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion shows a still expression and no running animation', (tester) async {
      await tester.pumpWidget(harness(reduced: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      controllerOf(tester).play(HamiReaction.warnSpending);
      await tester.pump();
      final pose = poseOf(tester);
      expect(pose.skin, poseFor(def, 'angry-glare').skin);
      expect(pose.brow, greaterThan(0.8));
      expect(pose.pitch, 0);
      expect(pose.shake, 0);
      expect(pose.hop, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
