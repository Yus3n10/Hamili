# Design — Same-category budget (Replace/Add) · Coded piggy mascot in chat

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan

Two independent frontend-only features. (Part of the same session that fixed the budget-sync
bug and added the AI scope guard, but these two are separate deliverables.)

Related, already done this session:
- Budget drill-down / bar sync bug — fixed (`budgetTransactionsProvider` invalidation + agent
  `changed:["transactions","budgets"]`).
- "Hami asks for missing details" — verified already working; no change.
- Mascot asset decision — the provided `4751-9594-piggy-bank-loop-3s.{json,lottie}` is a ~30 MB
  raster flipbook (72 embedded 808×808 PNGs) with a single `loop` marker and no coin-flip/sleep
  segments, so it cannot drive distinct states and is too heavy to bundle. Decision: **coded
  piggy in pure Flutter** instead.

---

## Feature A — Same-category budget: Replace vs Add

### Goal
When the user sets a budget for a category that already has one for the current month, ask whether
to **Replace** the existing limit with the new amount or **Add** them into a new total — instead of
today's silent overwrite.

### Current behavior
- Backend `BudgetService.create_or_update` upserts by (user, category, month, year): if a budget
  exists it replaces `limit_amount`. `set_budget_sheet.dart` `_save()` calls
  `budgetsProvider.notifier.setBudget(categoryId, limitAmount)` → this upsert. Same category = silent
  replace.

### New behavior
- In `set_budget_sheet.dart` `_save()`, after validation and before saving: look up the selected
  category in the current `budgetsProvider` value. If a budget already exists for it:
  - Show an `AlertDialog`:
    > "{Category} already has a {₱existing} budget this month. Replace it with {₱new}, or add them
    > to {₱existing+new}?"
    - **Replace** → `setBudget(categoryId, newAmount)`
    - **Add** → `setBudget(categoryId, existingLimit + newAmount)`
    - **Cancel** → dismiss, keep sheet open, save nothing.
  - If no existing budget → save directly as today (no dialog).
- Both Replace and Add call the **same existing** `setBudget`/upsert endpoint; "Add" is computed
  client-side. **No backend change.**
- Amounts formatted with `CurrencyFormatter.format`.

### Edge cases
- `budgetsProvider` not yet loaded (`valueOrNull == null`): skip detection and save directly — no
  worse than current silent-replace.
- Scope: the manual budget sheet only. Hami's agent `set_budget` keeps replace semantics (out of
  scope per request).

### Verification
- `flutter analyze` clean. Backend upsert already covered by tests. Manual: set a budget on a
  category that already has one → dialog appears; Replace sets new amount; Add sums; Cancel aborts.

---

## Feature B — Coded piggy mascot in the chatbox

### Goal
Bring Hami to life in the chat screen with a lightweight, pure-Flutter (no-asset) piggy-bank mascot
that idles, does a coin-flip when Hami completes any action, and "sleeps" when the AI backend is
unavailable — so the user sees the animations right where they interact with Hami.

### Widget
- New `HamiMascot` — a `ConsumerStatefulWidget` in
  `hamili-app/lib/features/chat/presentation/widgets/hami_mascot.dart`.
- Renders a piggy bank via `CustomPaint`/`CustomPainter` (no image assets), warm-gold brand palette
  (`AppColors.primary` / `primaryLight` / `primaryDark`), sized ~52px in the header.
- Manages its own `AnimationController`s:
  - An idle loop (gentle vertical bob; periodic eye-blink).
  - A one-shot coin-flip controller (a gold coin flips and drops into the slot, ~900ms), then returns
    to idle.
- State enum `{ idle, coinFlip, sleeping }`. Precedence: `sleeping` overrides everything; a coin-flip
  trigger while awake plays the one-shot; otherwise idle. In `sleeping`, eyes are closed, bob slows,
  and floating "z z z" text is drawn.

### State wiring
- Add `hamiCoinFlipProvider = StateProvider<int>((ref) => 0)` in `chat_providers.dart` (mirrors the
  old `piggyCoinFlipProvider` pattern). In `ChatMessagesNotifier.sendMessage`, after appending an
  assistant message with `actionDone == true`, increment it (`state = state + 1`).
- `HamiMascot`:
  - `ref.watch(chatServersDownProvider)` → drives `sleeping`.
  - `ref.listen(hamiCoinFlipProvider, ...)` → on change (and not sleeping), play the coin-flip one-shot.
  - optionally `ref.watch(chatIsRespondingProvider)` only for the header status text.

### Placement
- A persistent header strip at the top of the chat body in `hami_chat_page.dart`, under the `AppBar`
  and above the messages `Expanded`:
  `Row[ HamiMascot(~52px), SizedBox, Column[ "Hami" (semibold), status caption ] ]` with a subtle
  divider/background.
- Status caption: `sleeping` → "Hami is napping…"; else if `chatIsRespondingProvider` → "Hami is
  thinking…"; else "Ask me about your money 🐷" (or "Hami").

### Files
- Create: `hamili-app/lib/features/chat/presentation/widgets/hami_mascot.dart`
- Modify: `hamili-app/lib/features/chat/presentation/chat_providers.dart` (add + increment
  `hamiCoinFlipProvider`)
- Modify: `hamili-app/lib/features/chat/presentation/hami_chat_page.dart` (mount header strip)

### Verification
- `flutter analyze` clean; full `flutter build web` compiles.
- Manual (Opera GX, CanvasKit not screenshot-able from tooling): piggy renders in the chat header;
  tell Hami "add a ₱50 allowance" → coin-flip plays; exhaust quota / servers-down reply → piggy
  sleeps with "z z z".

---

## Cross-cutting
- Both features are frontend-only, independent, and ship as separate commits.
- No new packages (`flutter_animate` already present; mascot uses raw `CustomPaint` +
  `AnimationController`).
- Follow existing patterns: `AppColors` palette, provider-per-feature, `CurrencyFormatter` for money.
