# Same-category Budget Prompt · Coded Piggy Mascot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Replace/Add prompt when setting a budget for a category that already has one, and add a pure-Flutter piggy mascot to the chat screen that idles, coin-flips on completed actions, and sleeps when the AI backend is down.

**Architecture:** Feature A is a client-side branch in the budget sheet's save handler (compute the total for "Add"; reuse the existing upsert endpoint). Feature B is a self-contained `CustomPaint` mascot widget driven by two `AnimationController`s, wired to `chatServersDownProvider` (sleep) and a new `hamiCoinFlipProvider` counter (flip) incremented by `ChatMessagesNotifier`.

**Tech Stack:** Flutter · Riverpod · CustomPaint/AnimationController. Frontend-only; no backend or package changes.

## Global Constraints

- No new packages; mascot uses raw `CustomPaint` + `AnimationController` (no image assets).
- Colors from `AppColors`; money via `CurrencyFormatter.format`.
- `flutter analyze` → 0 issues after each task; full `flutter build web` must compile at the end.
- Two independent features → separate commits.

---

## Task 1: Same-category budget Replace/Add prompt (Feature A)

**Files:**
- Modify: `hamili-app/lib/features/budgets/presentation/set_budget_sheet.dart`

**Interfaces:**
- Consumes: `budgetsProvider` (`List<AppBudget>` with `categoryId`, `limitAmount`), `CurrencyFormatter`, existing `budgetsProvider.notifier.setBudget`.

- [ ] **Step 1: Add imports**

At the top of `set_budget_sheet.dart`, add:

```dart
import '../../../core/utils/currency_formatter.dart';
import '../domain/budget.dart';
```

- [ ] **Step 2: Add the conflict enum + dialog + updated `_save`**

Add above the `_SetBudgetSheet` class:

```dart
enum _BudgetConflictChoice { replace, add }
```

Replace the existing `_save()` method with:

```dart
  Future<void> _save() async {
    final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text);
    if (_selectedCategory == null || amount == null || amount <= 0) {
      setState(() => _error = 'Pick a category and enter a valid amount');
      return;
    }

    // If this category already has a budget for the current period, ask
    // whether to replace the limit or add the two amounts together.
    final budgets = ref.read(budgetsProvider).valueOrNull ?? const <AppBudget>[];
    AppBudget? existing;
    for (final b in budgets) {
      if (b.categoryId == _selectedCategory!.id) {
        existing = b;
        break;
      }
    }

    var finalAmount = amount;
    if (existing != null) {
      final choice = await _askReplaceOrAdd(existing.limitAmount, amount);
      if (choice == null) return; // cancelled — keep the sheet open
      finalAmount = choice == _BudgetConflictChoice.add ? existing.limitAmount + amount : amount;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(budgetsProvider.notifier).setBudget(categoryId: _selectedCategory!.id, limitAmount: finalAmount);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = "Couldn't save budget. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_BudgetConflictChoice?> _askReplaceOrAdd(double existing, double added) {
    final total = existing + added;
    return showDialog<_BudgetConflictChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_selectedCategory!.name} already has a budget'),
        content: Text(
          'This category already has a ${CurrencyFormatter.format(existing)} budget this month.\n\n'
          'Replace it with ${CurrencyFormatter.format(added)}, or add them together?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _BudgetConflictChoice.replace),
            child: const Text('Replace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _BudgetConflictChoice.add),
            child: Text('Add → ${CurrencyFormatter.format(total)}'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 3: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

- [ ] **Step 4: Commit**

```bash
git add hamili-app/lib/features/budgets/presentation/set_budget_sheet.dart
git commit -m "feat(budgets): prompt to replace or add when a category already has a budget"
```

---

## Task 2: Coin-flip trigger provider (Feature B)

**Files:**
- Modify: `hamili-app/lib/features/chat/presentation/chat_providers.dart`

**Interfaces:**
- Produces: `hamiCoinFlipProvider` = `StateProvider<int>` — a counter incremented once per completed Hami action; the mascot listens for changes.

- [ ] **Step 1: Add the provider**

Below `chatServersDownProvider` in `chat_providers.dart`:

```dart
/// Bumped once each time Hami completes an action, so the chat mascot can
/// play its coin-flip. A counter (not a bool) so repeated actions each fire.
final hamiCoinFlipProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 2: Increment it after an action reply**

In `ChatMessagesNotifier.sendMessage`, the block that appends the assistant message is:

```dart
      state = [
        ...state,
        ChatMessage('assistant', response.data['reply'] as String, actionDone: changed.isNotEmpty),
      ];
```

Immediately after it, add:

```dart
      if (changed.isNotEmpty) {
        ref.read(hamiCoinFlipProvider.notifier).state++;
      }
```

- [ ] **Step 3: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

(No commit yet — committed with Task 4.)

---

## Task 3: HamiMascot widget (Feature B)

**Files:**
- Create: `hamili-app/lib/features/chat/presentation/widgets/hami_mascot.dart`

**Interfaces:**
- Consumes: `chatServersDownProvider`, `hamiCoinFlipProvider` (Task 2), `AppColors`.
- Produces: `HamiMascot` widget (`const HamiMascot({double size})`).

- [ ] **Step 1: Create the widget + painter**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../chat_providers.dart';

/// A lightweight, asset-free piggy-bank mascot for the chat header. Idles
/// (gentle bob + blink), plays a one-shot coin-flip when Hami completes an
/// action, and sleeps (eyes closed + "z z z") when the AI backend is down.
class HamiMascot extends ConsumerStatefulWidget {
  const HamiMascot({super.key, this.size = 52});

  final double size;

  @override
  ConsumerState<HamiMascot> createState() => _HamiMascotState();
}

class _HamiMascotState extends ConsumerState<HamiMascot> with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _idle.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleeping = ref.watch(chatServersDownProvider);

    // Play the coin-flip once whenever the action counter changes (unless asleep).
    ref.listen<int>(hamiCoinFlipProvider, (_, __) {
      if (!ref.read(chatServersDownProvider)) _flip.forward(from: 0);
    });

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _flip]),
        builder: (context, _) => CustomPaint(
          painter: _PiggyPainter(idle: _idle.value, flip: _flip.value, sleeping: sleeping),
        ),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  _PiggyPainter({required this.idle, required this.flip, required this.sleeping});

  final double idle; // 0..1 looping
  final double flip; // 0..1 one-shot (0 or 1 == inactive)
  final bool sleeping;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dark = const Color(0xFF3A2A0A);

    // Gentle bob (slower & deeper while asleep).
    final bob = math.sin(idle * 2 * math.pi) * (sleeping ? 1.4 : 0.8);
    canvas.translate(0, bob);

    final gold = Paint()..color = AppColors.primary;
    final goldDark = Paint()..color = AppColors.primaryDark;
    final goldLight = Paint()..color = AppColors.primaryLight;

    // Ear
    final ear = Path()
      ..moveTo(w * 0.30, h * 0.37)
      ..lineTo(w * 0.40, h * 0.19)
      ..lineTo(w * 0.49, h * 0.38)
      ..close();
    canvas.drawPath(ear, goldDark);

    // Legs
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        goldDark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        goldDark);

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.33, w * 0.76, h * 0.45), Radius.circular(h * 0.22)),
        gold);

    // Snout
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.49, w * 0.20, h * 0.19), Radius.circular(h * 0.07)),
        goldLight);
    final nostril = Paint()..color = AppColors.primaryDark;
    canvas.drawCircle(Offset(w * 0.77, h * 0.585), w * 0.018, nostril);
    canvas.drawCircle(Offset(w * 0.83, h * 0.585), w * 0.018, nostril);

    // Coin slot
    canvas.drawLine(
      Offset(w * 0.42, h * 0.355),
      Offset(w * 0.58, h * 0.355),
      Paint()
        ..color = AppColors.primaryDark
        ..strokeWidth = h * 0.02
        ..strokeCap = StrokeCap.round,
    );

    // Eye — closed (arc) when sleeping or mid-blink, else a dot.
    final phase = (idle * 2 * math.pi) % (2 * math.pi);
    final blinking = !sleeping && phase > 6.0; // brief blink near the end of each loop
    if (sleeping || blinking) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.55, h * 0.46)
          ..quadraticBezierTo(w * 0.60, h * 0.50, w * 0.65, h * 0.46),
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(Offset(w * 0.60, h * 0.46), w * 0.032, Paint()..color = dark);
    }

    // Coin-flip: a coin descends into the slot, flipping (scaleX oscillates).
    if (flip > 0.0 && flip < 1.0) {
      final y = (h * 0.02) + (h * 0.30 - h * 0.02) * Curves.easeIn.transform(flip);
      final scaleX = math.cos(flip * 4 * math.pi).abs().clamp(0.18, 1.0);
      final r = w * 0.10;
      canvas.save();
      canvas.translate(w * 0.50, y);
      canvas.scale(scaleX, 1.0);
      canvas.drawCircle(Offset.zero, r, Paint()..color = AppColors.primaryLight);
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02,
      );
      canvas.restore();
    }

    // Sleeping "z z z"
    if (sleeping) {
      for (var i = 0; i < 3; i++) {
        final prog = ((idle + i * 0.33) % 1.0);
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: AppColors.primaryDark.withValues(alpha: (1 - prog).clamp(0.0, 1.0)),
              fontSize: w * (0.11 + 0.05 * i),
              fontWeight: FontWeight.bold,
            ),
          ),
        )..layout();
        tp.paint(canvas, Offset(w * 0.70 + i * w * 0.07, h * 0.28 - prog * h * 0.22));
      }
    }
  }

  @override
  bool shouldRepaint(_PiggyPainter old) =>
      old.idle != idle || old.flip != flip || old.sleeping != sleeping;
}
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

---

## Task 4: Mount the mascot header in the chat screen (Feature B)

**Files:**
- Modify: `hamili-app/lib/features/chat/presentation/hami_chat_page.dart`

**Interfaces:**
- Consumes: `HamiMascot` (Task 3), `chatServersDownProvider`, `chatIsRespondingProvider`.

- [ ] **Step 1: Import the mascot**

Add to the imports of `hami_chat_page.dart`:

```dart
import 'widgets/hami_mascot.dart';
```

- [ ] **Step 2: Add the header strip at the top of the chat body**

In `HamiChatPage.build`, the body is `Column(children: [ Expanded(...), SafeArea(...) ])`. Insert the header as the first child of that `Column`, before the `Expanded`:

```dart
          const _HamiHeader(),
```

- [ ] **Step 3: Add the `_HamiHeader` widget**

Add at the end of the file (a `ConsumerWidget`):

```dart
class _HamiHeader extends ConsumerWidget {
  const _HamiHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeping = ref.watch(chatServersDownProvider);
    final thinking = ref.watch(chatIsRespondingProvider);
    final status = sleeping
        ? 'Hami is napping…'
        : thinking
            ? 'Hami is thinking…'
            : 'Ask me about your money';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          const HamiMascot(size: 52),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hami', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Analyze + build**

Run: `cd hamili-app && flutter analyze` → 0 issues.
Run: `cd hamili-app && flutter build web` → compiles.

- [ ] **Step 5: Manual check (Opera GX)**

Open the Hami tab → piggy shows in the header, idling/blinking. Tell Hami "add a ₱50 allowance" → coin-flip plays. Trigger the servers-down reply (quota) → piggy sleeps with "z z z".

- [ ] **Step 6: Commit**

```bash
git add hamili-app/lib/features/chat/presentation/chat_providers.dart \
        hamili-app/lib/features/chat/presentation/widgets/hami_mascot.dart \
        hamili-app/lib/features/chat/presentation/hami_chat_page.dart
git commit -m "feat(chat): coded piggy mascot with idle/coin-flip/sleep states"
```

---

## Self-Review

**Spec coverage:**
- Feature A (Replace/Add prompt on same-category budget, client-side total, no backend change, sheet-only) → Task 1. ✓
- Feature B (pure-Flutter piggy, header strip, idle/coin-flip/sleep, `hamiCoinFlipProvider` bumped on action, `chatServersDownProvider` → sleep) → Tasks 2–4. ✓

**Placeholder scan:** none — every step has full code. ✓

**Type consistency:** `hamiCoinFlipProvider` (`StateProvider<int>`, `.state++`), `HamiMascot({size})`, `_PiggyPainter(idle, flip, sleeping)`, `AppBudget.categoryId/limitAmount`, `CurrencyFormatter.format` — consistent across tasks and matches source files. ✓
