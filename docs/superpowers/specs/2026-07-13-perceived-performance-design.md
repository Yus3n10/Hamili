# Design — Perceived performance: skeletons, caching, optimistic UI, tooltips

**Date:** 2026-07-13
**Status:** Approved (design), implementing

Make Hamili feel instant: cached data shows immediately, background refresh swaps
in fresh data, deletes apply optimistically, first-load shows skeletons (not
spinners), and every icon button has a tooltip.

## 1. Shared skeleton widget
- Create `lib/shared/widgets/skeleton.dart`:
  - `Skeleton({width, height, radius})` — a shimmering rounded box (flutter_animate
    `.shimmer()`, repeating), tinted from `colorScheme.onSurface`.
  - `SkeletonTile()` (leading circle + two lines) and `SkeletonCard({height})` helpers
    for list/card placeholders.
- No new package (flutter_animate already present).

## 2. Stale-while-revalidate caching
Extend the Hive write-through pattern (already on transactions/categories/recurring)
to **budgets, goals, analytics summary**.
- Repository methods per entity:
  - `Future<List<T>?> cached(...)` — read Hive; `null` when empty.
  - existing `list()/summary()` — network fetch that **writes** the cache on success and
    falls back to cache on network error (offline).
  - `clearCache()` — called on logout (wired where transaction cache is cleared).
- AsyncNotifier `build()` pattern (budgets, goals, dashboard summary):
  ```dart
  final cached = await repo.cached(...);
  if (cached != null) {
    Future.microtask(_refreshSilently); // background, no loading flash
    return cached;                       // instant data, no skeleton
  }
  return repo.fetch(...);                // true first load -> skeleton
  ```
  `_refreshSilently()` sets `state = AsyncData(fresh)` on success, keeps cache on error.

## 3. Optimistic deletes
Make list removals instant across transactions/goals/budgets/recurring:
- On delete: capture current list, set `state = AsyncData(list without item)` immediately,
  then call the repo; on failure `ref.invalidateSelf()` (or restore) to reconcile.
- Adds already optimistic on transactions (offline queue); leave as-is.

## 4. Tooltips on icon buttons
Sweep every `IconButton` in `lib/**` and add a `tooltip:` where missing (e.g. avatar
camera, password show/hide already done, insights refresh done — fill the rest:
recurring run-due, transaction filters, chat send, etc.).

## Screens getting skeletons (replace CircularProgressIndicator loading branch)
dashboard, transactions, budgets, budget detail, goals, analytics, recurring.

## Verification
- `flutter analyze` 0 issues, `flutter build web` green.
- Manual (Opera GX): first load shows skeletons; revisits show data instantly then
  refresh; deleting an item removes it immediately; icon buttons show tooltips on hover.
- Offline (network down): cached data still shows.
