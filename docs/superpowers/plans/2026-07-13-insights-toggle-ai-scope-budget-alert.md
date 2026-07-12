# Insights Toggle · AI Scope Guard · Budget Alert — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three independent features to Hamili — a device-level toggle to disable AI insights, an AI scope guard so Hami declines out-of-scope "starter version" questions, and a follow-everywhere budget over-limit alert overlay.

**Architecture:** Feature 1 mirrors the existing `ThemeModeNotifier`/`app_settings` Hive pattern and gates both the insights fetch and card. Feature 2 is a prompt-text addition to `HAMI_SYSTEM_PROMPT` (inherited by agent + insights). Feature 3 mounts a reactive `ConsumerWidget` overlay inside `MainShell`'s body, driven by `budgetsProvider`, with session-scoped dismissal state.

**Tech Stack:** Flutter · Riverpod · Hive · GoRouter · flutter_animate (frontend); FastAPI · Gemini prompt text (backend).

## Global Constraints

- Never hardcode hex colors in widgets — use `AppColors` (`app_colors.dart`).
- Money is formatted with `CurrencyFormatter.format(amount)` (`₱` default).
- Account/session-scoped Riverpod providers `ref.watch(sessionIdProvider)` on their first line; device-level settings live in the `app_settings` Hive box and are NOT session-scoped.
- `flutter analyze` must report 0 issues after each frontend task.
- Backend pytest suite must stay green; the agent must always return valid `{action, params, reply}` JSON.
- Commit per feature (repo convention).

---

## Task 1: AI scope guard (Feature 2 — backend prompt)

**Files:**
- Modify: `hamili-backend/app/services/ai/prompt_templates.py` (add a "Scope & limits" block to `HAMI_SYSTEM_PROMPT`)

**Interfaces:**
- Consumes: nothing.
- Produces: no signature change. `HAMI_SYSTEM_PROMPT` (and therefore `HAMI_AGENT_SYSTEM`, which concatenates it) now instructs Hami to deflect out-of-scope questions.

- [ ] **Step 1: Add the scope block to `HAMI_SYSTEM_PROMPT`**

Insert this block inside the `HAMI_SYSTEM_PROMPT` string, immediately before the closing `"""`, after the existing "financial snapshot" paragraph:

```python
Scope & limits — Hamili is an early "starter" version:
- Hamili tracks and helps with the user's OWN money: budgets, savings goals, spending trends,
  recurring income/expenses, and simple habit advice grounded in their data.
- Do NOT recommend specific investments — no individual stocks, companies, cryptocurrencies, or
  "what should I buy" picks. You are not a licensed financial advisor.
- You have NO access to real-world locations, live market prices, news, or anything outside the
  user's own Hamili data. Never invent them (e.g. "the nearest cafe", "today's BTC price").
- When a request falls outside that scope, don't guess. Reply warmly in 1-2 sentences that Hamili
  is still an early/starter version focused on tracking their own finances, so you can't help with
  that yet, and (briefly) point them back to what you CAN do. Example:
  "I'm still an early version of Hami focused on your own budgets and goals, so I can't recommend
  specific investments — but I can help you plan savings toward one. 🙂"
```

- [ ] **Step 2: Start the backend**

Run: `cd hamili-backend && ./venv/Scripts/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` (background)
Expected: server boots, `/docs` reachable.

- [ ] **Step 3: Verify live — out-of-scope questions deflect**

Register/login to get a token, then POST each of the three prompts to the chat endpoint and confirm the reply is a friendly starter-version deflection (no invented stock/crypto pick, no fake cafe), and `available` is true:
- "What company is a good investment right now?"
- "What cryptocurrency should I invest in?"
- "What is the nearest cafe to lessen my transportation fees?"

Expected: each reply declines gently and redirects; JSON parses; if it's an agent response, `action` is `"none"`.

- [ ] **Step 4: Verify live — in-scope questions still answer**

Ask a normal grounded question (e.g. "How am I doing on my budgets this month?").
Expected: normal helpful answer (not deflected).

- [ ] **Step 5: Run backend tests**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add hamili-backend/app/services/ai/prompt_templates.py
git commit -m "feat(ai): Hami declines out-of-scope questions (starter-version scope guard)"
```

---

## Task 2: Insights enabled provider (Feature 1 — state)

**Files:**
- Create: `hamili-app/lib/features/dashboard/presentation/insights_enabled_provider.dart`

**Interfaces:**
- Produces: `insightsEnabledProvider` = `NotifierProvider<InsightsEnabledNotifier, bool>`; `InsightsEnabledNotifier.setEnabled(bool)`. Default `true`. Backed by `app_settings` Hive box, key `insights_enabled`. Device-level (NOT session-scoped).

- [ ] **Step 1: Create the notifier/provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Whether the dashboard's AI insights card is shown and fetched. Device-level
/// (stored in `app_settings` like the theme preference), so it survives logout
/// and is deliberately not account-scoped. When off, no insight Gemini call is
/// made. Defaults to on.
class InsightsEnabledNotifier extends Notifier<bool> {
  static const _boxName = 'app_settings';
  static const _key = 'insights_enabled';

  @override
  bool build() {
    // Box is opened in main() before runApp — synchronous read.
    return Hive.box<String>(_boxName).get(_key) != 'off';
  }

  void setEnabled(bool enabled) {
    state = enabled;
    Hive.box<String>(_boxName).put(_key, enabled ? 'on' : 'off');
  }
}

final insightsEnabledProvider =
    NotifierProvider<InsightsEnabledNotifier, bool>(InsightsEnabledNotifier.new);
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

(No commit yet — committed with Task 4 as one feature.)

---

## Task 3: Gate the insights fetch on the flag (Feature 1)

**Files:**
- Modify: `hamili-app/lib/features/dashboard/presentation/insight_providers.dart`

**Interfaces:**
- Consumes: `insightsEnabledProvider` from Task 2.
- Produces: `InsightsNotifier.build()` returns `[]` without any network call when insights are disabled; re-runs (and fetches) when re-enabled. `refresh()` no-ops when disabled.

- [ ] **Step 1: Watch the flag in `build()` and short-circuit**

In `insight_providers.dart`, add the import and change `InsightsNotifier`:

```dart
import 'insights_enabled_provider.dart';
```

```dart
  @override
  Future<List<AiInsight>> build() async {
    ref.watch(sessionIdProvider); // reset on login/logout (account isolation)
    if (!ref.watch(insightsEnabledProvider)) return []; // off -> no Gemini call
    return ref.read(insightsRepositoryProvider).get();
  }
```

Guard `refresh()` too:

```dart
  Future<void> refresh() async {
    if (!ref.read(insightsEnabledProvider)) return;
    state = const AsyncLoading<List<AiInsight>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(insightsRepositoryProvider).refresh());
  }
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

---

## Task 4: Insights toggle UI + card gate (Feature 1)

**Files:**
- Modify: `hamili-app/lib/features/dashboard/presentation/widgets/insights_card.dart`
- Modify: `hamili-app/lib/features/profile/presentation/profile_page.dart`

**Interfaces:**
- Consumes: `insightsEnabledProvider` (Task 2).

- [ ] **Step 1: Hide the card when disabled**

In `insights_card.dart`, add the import and an early return at the top of `build`:

```dart
import '../insights_enabled_provider.dart';
```

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(insightsEnabledProvider)) return const SizedBox.shrink();
    final insightsAsync = ref.watch(insightsProvider);
    // ...unchanged below...
```

- [ ] **Step 2: Add the toggle to Profile**

In `profile_page.dart`, add the import:

```dart
import '../../dashboard/presentation/insights_enabled_provider.dart';
```

Insert this block into the `ListView` children, after the "Appearance" `SegmentedButton` `Padding` and before `const SizedBox(height: 28)`:

```dart
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('AI', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('AI insights from Hami'),
                    subtitle: const Text('Proactive nudges on your dashboard'),
                    value: ref.watch(insightsEnabledProvider),
                    onChanged: (v) => ref.read(insightsEnabledProvider.notifier).setEnabled(v),
                  ),
```

- [ ] **Step 3: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

- [ ] **Step 4: Manual check (Opera GX)**

Toggle off in Profile → dashboard insights card disappears and no `/insights` request fires; toggle on → card returns and fetches.

- [ ] **Step 5: Commit**

```bash
git add hamili-app/lib/features/dashboard/presentation/insights_enabled_provider.dart \
        hamili-app/lib/features/dashboard/presentation/insight_providers.dart \
        hamili-app/lib/features/dashboard/presentation/widgets/insights_card.dart \
        hamili-app/lib/features/profile/presentation/profile_page.dart
git commit -m "feat(insights): device-level toggle to turn off AI insights"
```

---

## Task 5: Dismissed-alerts session state (Feature 3 — state)

**Files:**
- Create: `hamili-app/lib/features/budgets/presentation/budget_alert_provider.dart`

**Interfaces:**
- Produces: `dismissedBudgetAlertsProvider` = `NotifierProvider<DismissedBudgetAlertsNotifier, Set<int>>`; methods `dismiss(int id)`. Session-scoped (watches `sessionIdProvider`) and in-memory, so it resets on logout and on cold start.

- [ ] **Step 1: Create the notifier/provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';

/// Budget ids whose over-limit alert the user has closed this session. In-memory
/// only and reset when the session changes (logout), so a dismissed alert returns
/// on the next cold start / login if the budget is still over limit.
class DismissedBudgetAlertsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(sessionIdProvider); // reset on login/logout
    return <int>{};
  }

  void dismiss(int budgetId) {
    state = {...state, budgetId};
  }
}

final dismissedBudgetAlertsProvider =
    NotifierProvider<DismissedBudgetAlertsNotifier, Set<int>>(DismissedBudgetAlertsNotifier.new);
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

---

## Task 6: Budget alert overlay widget (Feature 3 — UI)

**Files:**
- Create: `hamili-app/lib/features/budgets/presentation/budget_alert_overlay.dart`

**Interfaces:**
- Consumes: `budgetsProvider` (`List<AppBudget>` with `id`, `categoryId`, `limitAmount`, `spentAmount`), `categoriesProvider` (`List<AppCategory>` with `id`, `name`), `dismissedBudgetAlertsProvider` (Task 5), `CurrencyFormatter.format`, `AppColors.expense`.
- Produces: `BudgetAlertOverlay` widget — renders nothing when no budget is over limit or all are dismissed; otherwise a stack of closable reddish-translucent toasts.

- [ ] **Step 1: Create the overlay**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'budget_alert_provider.dart';
import 'budget_providers.dart';

/// Floating, closable alerts shown near the bottom of every authenticated screen
/// whenever a budget is over its limit. Reddish and translucent so it never fully
/// obstructs the content behind it. Mounted inside MainShell, so it follows the
/// user across tabs but never appears on login/onboarding.
class BudgetAlertOverlay extends ConsumerWidget {
  const BudgetAlertOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final dismissed = ref.watch(dismissedBudgetAlertsProvider);

    final over = budgets
        .where((b) => b.spentAmount > b.limitAmount && !dismissed.contains(b.id))
        .toList();
    if (over.isEmpty) return const SizedBox.shrink();

    String nameFor(int categoryId) {
      final match = categories.where((c) => c.id == categoryId);
      return match.isNotEmpty ? match.first.name : 'A budget';
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in over)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AlertToast(
                  key: ValueKey(b.id),
                  message:
                      '${nameFor(b.categoryId)} is ${CurrencyFormatter.format(b.spentAmount - b.limitAmount)} over budget',
                  onClose: () => ref.read(dismissedBudgetAlertsProvider.notifier).dismiss(b.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertToast extends StatelessWidget {
  const _AlertToast({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onClose(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: 'Dismiss',
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.3, end: 0, duration: 250.ms);
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

---

## Task 7: Mount the overlay in MainShell (Feature 3)

**Files:**
- Modify: `hamili-app/lib/shared/widgets/main_shell.dart`

**Interfaces:**
- Consumes: `BudgetAlertOverlay` (Task 6).

- [ ] **Step 1: Wrap the shell body in a Stack with the overlay**

`MainShell` is currently a `StatefulWidget` whose `build` returns `Scaffold(body: AnimatedBuilder(...), bottomNavigationBar: ...)`. Add the import and wrap the `AnimatedBuilder` in a `Stack` so the overlay sits above the branch content but the `NavigationBar` (in `bottomNavigationBar`) stays below it:

```dart
import 'budget_alert_overlay.dart';
```

Change the `body:` from the bare `AnimatedBuilder(...)` to:

```dart
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              final dx = (1 - _controller.value) * (_forward ? 0.05 : -0.05) * width;
              return Opacity(
                opacity: 0.35 + 0.65 * _controller.value,
                child: Transform.translate(offset: Offset(dx, 0), child: child),
              );
            },
            child: widget.navigationShell,
          ),
          const BudgetAlertOverlay(),
        ],
      ),
```

(The `BudgetAlertOverlay` returns a `Positioned` when active and `SizedBox.shrink()` when not — a bare `SizedBox` is a valid non-positioned `Stack` child, so this is safe either way.)

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Manual check (Opera GX)**

Add an expense that pushes a budget over its limit → a reddish translucent toast appears above the nav bar, readable through it. Multiple over-limit budgets → toasts stack. Close by `×` and by swipe. Navigate across tabs → alert persists. It does NOT appear on login/onboarding. Log out and back in while still over → alert returns.

- [ ] **Step 4: Commit**

```bash
git add hamili-app/lib/features/budgets/presentation/budget_alert_provider.dart \
        hamili-app/lib/features/budgets/presentation/budget_alert_overlay.dart \
        hamili-app/lib/shared/widgets/main_shell.dart
git commit -m "feat(budgets): follow-everywhere over-limit alert overlay"
```

---

## Self-Review

**Spec coverage:**
- Feature 1 (turn off insights) → Tasks 2–4 (provider, fetch gate, UI toggle + card gate). ✓
- Feature 2 (AI starter-version deflection) → Task 1. ✓
- Feature 3 (budget over-limit overlay, follows everywhere, closable by swipe/×, reddish translucent, above nav bar, one toast per budget, returns next session) → Tasks 5–7. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `insightsEnabledProvider` (bool), `dismissedBudgetAlertsProvider` (`Set<int>`, `.dismiss(id)`), `BudgetAlertOverlay`, `AppBudget.spentAmount/limitAmount/categoryId/id`, `AppCategory.id/name`, `CurrencyFormatter.format`, `AppColors.expense` — all consistent with the read source files. ✓
