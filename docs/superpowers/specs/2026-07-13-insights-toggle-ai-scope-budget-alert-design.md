# Design — Insights toggle · AI scope guard · Budget over-limit alert

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan

Three small, independent features for Hamili. Each is self-contained and ships as its own commit. No breaking changes; only Feature 2 touches the backend (prompt text only).

---

## Feature 1 — Turn off AI insights

### Goal
Let the user stop the dashboard "Insights from Hami" card from showing **and** from calling Gemini, via a toggle in Profile.

### Storage
- New key `insights_enabled` (bool, default `true`) in the existing `app_settings` Hive box.
- New `InsightsEnabledNotifier extends Notifier<bool>` in a new file
  `lib/features/dashboard/presentation/insights_enabled_provider.dart` (or colocated in settings),
  mirroring `ThemeModeNotifier` exactly: synchronous read in `build()` from the already-open box,
  `setEnabled(bool)` persists.
- **Device-level**, not account-scoped — consistent with theme/avatar. Survives logout; not reset on
  `sessionIdProvider` change.

### UI
- A `SwitchListTile` in `profile_page.dart`, placed near the existing theme selector, labelled
  "AI insights from Hami" with a one-line subtitle explaining it controls the dashboard nudges.

### Gating behavior
- `InsightsCard` watches `insightsEnabledProvider`; when `false` it returns `SizedBox.shrink()`.
- `InsightsNotifier.build()` reads the flag first: when disabled it returns `[]` **without** calling the
  repository, so **no Gemini call is made** while off. It must still `ref.watch(insightsEnabledProvider)`
  so toggling on re-runs `build()` and fetches.
- The card's manual "refresh" action is unreachable while the card is hidden; additionally guard
  `refresh()` to no-op when disabled (defensive).

### Backend
- Untouched. Insight generation only happens on an explicit `GET /insights` / `POST /insights/refresh`
  call; we simply stop making it.

### Verification
- `flutter analyze` clean.
- Manual (Opera GX): toggle off → card disappears and no `/insights` request fires (check network/logs);
  toggle on → card returns and fetches.

---

## Feature 2 — Hami declines out-of-scope "starter version" questions

### Goal
When asked for specific investment picks (individual stocks/crypto) or for things needing real-world /
real-time data the app does not have (nearest cafe, live market prices), Hami should give a warm
"I'm an early/starter version focused on your own money" deflection instead of guessing.

Representative prompts to handle:
- "What company is a good investment right now?"
- "What cryptocurrency should I invest in?"
- "What is the nearest cafe to lessen my transportation fees?"

### Approach — prompt only
- No keyword filter (brittle, easy to bypass/false-positive). Add a **"Scope & limits"** block to
  `HAMI_SYSTEM_PROMPT` in `app/services/ai/prompt_templates.py`. Because `HAMI_AGENT_SYSTEM` is built by
  concatenating `HAMI_SYSTEM_PROMPT`, both the chat/agent path and the insights path inherit it.
- The block instructs Hami that, for these cases, it should:
  - Use `action: "none"` (agent path) and answer normally otherwise.
  - Reply briefly and warmly that Hamili is an early/starter version built to track **the user's own**
    finances, so it can't recommend specific investments (stocks/crypto) or look up real-world places or
    live market data.
  - Optionally redirect to what it *can* do: budgets, savings goals, spending trends, recurring items.
  - Stay within the existing response-length rules (1–3 sentences).
- Reinforces the existing "not a licensed financial advisor / no personalized investment advice" stance.

### No API/schema change
- Same `{action, params, reply}` JSON contract. Only reply guidance improves.

### Verification
- Live chat calls against the three example prompts → Hami deflects with the starter-version message and
  the agent still returns valid JSON with `action: "none"` (no invented action, no crash).
- General finance questions grounded in the user's data still answer normally (no over-blocking).
- Existing pytest suite stays green.

---

## Feature 3 — Budget over-limit floating alert overlay

### Goal
A reddish, semi-transparent, closable toast that appears near the bottom of the screen (above the nav
bar) whenever a budget is over its limit, and follows the user across every authenticated screen — but
never appears on login/onboarding.

### Mount point
- Wrap `MainShell`'s `body` in a `Stack`: the existing animated branch content stays as the base layer, and
  a new `BudgetAlertOverlay` is positioned `bottom`-center, offset up so it clears the `NavigationBar`.
- Everything authenticated renders inside `MainShell`; login and onboarding are separate top-level routes
  outside the shell, so "follows everywhere except login/onboarding" is automatic — no per-route logic.

### Detection
- `BudgetAlertOverlay` is a `ConsumerWidget` that watches `budgetsProvider` (current month) and resolves
  category names (existing category provider / `category_visuals`).
- Over-limit predicate: `spentAmount > limitAmount` (equivalently `percentageUsed > 100`).
- Reactive: when a transaction change invalidates `budgetsProvider`, the overlay recomputes and appears
  automatically. When budgets are loading/empty/errored, the overlay shows nothing (never blocks UI).

### Layout & style
- One small toast per over-limit budget, stacked vertically in the bottom corner (cap the visible count,
  e.g. 3, to avoid covering the screen; extras can be implied or omitted — decide during implementation,
  default: show all but they stack upward from the nav bar).
- Each toast: category name + amount over, e.g. **"Food is ₱320 over budget"**, using the existing
  `currency_formatter` for `₱` formatting.
- Reddish translucent surface: `AppColors` error/coral tone at ~0.9 alpha over a slightly translucent
  background so underlying content remains faintly visible (non-obstructive). Rounded, soft-shadow card
  consistent with the app's floating-card look. Small entrance animation via `flutter_animate` (consistent
  with the rest of the app), storage-light.

### Dismissal
- Close via an `×` button **or** horizontal swipe (`Dismissible`).
- Dismissed budget IDs are held in a **session-scoped in-memory** provider — a `StateProvider<Set<int>>`
  (or a small Notifier) that `ref.watch(sessionIdProvider)` so it resets on logout, and is in-memory so it
  resets on cold start. A dismissed alert therefore returns next session if the budget is still over.
- The overlay filters out any budget whose id is in the dismissed set.

### Backend
- None.

### Verification
- `flutter analyze` clean.
- Manual (Opera GX): push a budget over limit (add an expense) → toast appears bottom, reddish/translucent,
  readable through it; multiple over-limit budgets → stacked toasts; close by `×` and by swipe; navigate
  across tabs → alert persists; log out → gone on login/onboarding; log back in while still over → alert
  returns.

---

## Cross-cutting notes
- Three features are independent; implement and commit separately (matches repo's commit-per-feature
  hygiene). Suggested order: Feature 2 (smallest, backend prompt) → Feature 1 → Feature 3.
- No new packages required (`flutter_animate` already present).
- Follow existing patterns: Hive `app_settings` for settings, `sessionIdProvider` first-watch for
  session-scoped state, `AppColors` for palette, `currency_formatter` for money.
