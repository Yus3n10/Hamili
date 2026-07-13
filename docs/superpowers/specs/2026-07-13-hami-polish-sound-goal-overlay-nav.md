# Design — Hami polish: income ding, goal overlay, tab reset, expense animation, pink oval pig

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan

Six refinements, mostly to this session's mascot/overlay/nav work, plus a small backend signal.

## 1. "Ding!" on income actions
- Add `audioplayers` dependency and a bundled `assets/sounds/ding.wav` (synthesized bell tone,
  ~300ms, swappable).
- Play the ding when **Hami performs an income action** (chat/agent path). Expense actions play no
  sound. Driven by the new `effect` signal (§4).

## 2. Savings-goal-met overlay (green, semi-transparent)
- New `GoalAlertOverlay` mirroring `BudgetAlertOverlay`, mounted in `MainShell`'s Stack. Watches
  `goalsProvider`; for each `isCompleted` goal not dismissed this session, shows a green celebratory
  toast ("🎉 You hit '<title>'!"), closable by × or swipe.
- New `dismissedGoalAlertsProvider` (session-scoped `Set<int>`, resets on `sessionIdProvider`).
- **Transparency:** lower both overlays' fill alpha from 0.9 → ~0.8 so they don't block the view.

## 3. Tabs reset to default on switch
- In `MainShell.onDestinationSelected`, change `goBranch(index, initialLocation: index == current)`
  to `goBranch(index, initialLocation: true)` — every tab tap resets that branch to its root, so a
  pushed add-transaction window is cleared when you return to the tab.

## 4. Reverse coin-flip on expense (+ backend effect)
- **Backend:** `AgentService.respond` returns a new `effect` field: `'income'` / `'expense'` for
  `add_transaction` (from `params['type']`), else `None`. Add `effect` to `ChatReply` schema and the
  chat router response.
- **Frontend:** `hamiCoinFlipProvider` becomes a `StateProvider<CoinFlip>` carrying `seq` + `reverse`.
  `ChatMessagesNotifier.sendMessage` bumps it on any action with `reverse = (effect == 'expense')`.
- **Mascot:** coin-flip painter takes a `reverse` flag — income plays coin **into** the slot
  (current), expense plays it **out** (coin rises from the slot). Sound: income → ding.

## 5. Make Hami pink
- Recolor the piggy mascot from brand green to normal pig pink: body `#F4A6C0`, snout `#F8C6D8`,
  ear/legs `#E07BA0`, eye brand navy (unchanged). The **coin stays gold** (`#FFD86B` fill, `#E0A700`
  edge) so "money" reads against the pink.

## 6. Remove the triangle; oval body
- Drop the triangular ear (the odd spike). Change the body from a rounded-rect to an **oval**
  (`drawOval`), keeping snout, eye, legs, coin slot, so Hami reads as a normal oval pig. Optional
  small rounded ear bump instead of the triangle.

## Files
- Backend: `agent_service.py`, `schemas/chat.py`, `routers/chat.py`.
- Frontend: `pubspec.yaml` (+ `assets/sounds/`), `chat_providers.dart`, `hami_mascot.dart`,
  `budget_alert_overlay.dart`, new `goal_alert_overlay.dart`, `budget_alert_provider.dart` (add goal
  dismissed provider or a sibling file), `main_shell.dart`.

## Verification
- Backend: extend/keep `test_agent_actions.py` — assert `respond`/effect for income vs expense.
- Frontend: `flutter analyze` 0 issues, `flutter build web`. Sound + visuals are the user's Opera GX
  check.
- Honest note: `audioplayers` on web plays the bundled WAV; first play may need a user gesture
  (browsers gate autoplay) — the chat send is a user gesture, so it should be fine.
