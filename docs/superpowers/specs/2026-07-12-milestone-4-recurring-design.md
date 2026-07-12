# Milestone 4 — Recurring Income & Expenses — Design

**Date:** 2026-07-12
**Status:** Approved (design)
**Depends on:** Milestones 1–3 (transactions, categories, budgets, session isolation)

## Goal

Let users define recurring income (salary, allowance) and expenses (rent,
subscriptions) once, and have them automatically become real `Transaction`
rows on their due dates. This keeps the ledger — and therefore the dashboard
and budgets, which are all computed from transactions — accurate without the
user re-entering the same amount every month.

The `RecurringItem` ORM model already exists
(`app/models/recurring.py`): `type`, `name`, `amount`, `category_id`,
`frequency` (`weekly|monthly|yearly`), `next_due_date`, `active`. **No schema
change / Alembic migration is required for this milestone.**

## Key decisions (locked)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Lazy catch-up promotion**, no background scheduler | Free-tier hosts (Render) sleep the web process, killing in-process timers; lazy promotion survives sleep and works after any downtime. |
| 2 | **Backfill every missed period with real historical dates** | Keeps monthly income/expense and per-month budgets historically correct (away Apr–Jun → 3 rows dated Apr/May/Jun 1, not one lump on return). |
| 3 | **Backfill cap = 60 periods per item per run** | Guards against an item accidentally dated years in the past creating hundreds of rows in one request. Beyond 60, promote the most recent 60 and fast-forward `next_due_date` past the rest. |
| 4 | **Accept monthly day-drift; no anchor column** | Model stores only `next_due_date`. A monthly item starting on the 31st drifts to the 28th after February. Preserving the anchor day would need a migration; the drift is a documented, acceptable v1 limitation. |
| 5 | **Plain creates, not upserts** (unlike budgets) | A user can legitimately have two different monthly expenses; uniqueness is not desired. |
| 6 | **Promotion triggered on read + manual endpoint** | Runs at the start of `GET /recurring`, `GET /transactions` (so the client-computed dashboard reflects promoted rows), and explicit `POST /recurring/run-due`. Idempotent, so redundant triggers are safe. |

## Architecture

Follows the existing `router → service → repository → ORM` layering exactly,
mirroring the transactions and goals features. Nothing outside the new files
changes except two small, documented edits (main.py registration, and a
promotion trigger in the transactions router).

### Promotion engine — the core

`RecurringService.promote_due(user, today=date.today()) -> int`

```
promoted = 0
for item in repo.list_due(user.id, today):        # active AND next_due_date <= today
    count = 0
    while item.next_due_date <= today and count < MAX_BACKFILL_PERIODS:  # 60
        create Transaction(
            user_id          = user.id,
            category_id      = item.category_id,
            amount           = item.amount,
            type             = item.type,
            note             = item.name,          # e.g. "Salary", "Netflix"
            transaction_date = item.next_due_date, # real historical date
        )
        item.next_due_date = _advance(item.next_due_date, item.frequency)
        count += 1
        promoted += 1
    if count == MAX_BACKFILL_PERIODS:
        # still overdue after the cap: skip ahead without creating more rows
        while item.next_due_date <= today:
            item.next_due_date = _advance(item.next_due_date, item.frequency)
commit once
return promoted
```

**Idempotency:** after promotion, every active item's `next_due_date` is in the
future, so an immediate second call is a no-op. This is what makes it safe to
call from GET requests.

**Cheap when nothing is due:** `list_due` is a single indexed query
(`user_id` is indexed) filtered on `active` and `next_due_date <= today`;
it returns empty in the common case, so triggering promotion on every read is
inexpensive.

`_advance(d: date, frequency: str) -> date` — pure Python, **no new dependency**:

- `weekly` → `d + timedelta(days=7)`
- `monthly` → same day next month, **clamped** to the month's length
  (Jan 31 → Feb 28; Feb 28 → Mar 28 — the documented drift).
- `yearly` → same month/day next year, clamped (Feb 29 → Feb 28 in non-leap
  years).

### Backend files

| File | Responsibility |
|------|----------------|
| `app/schemas/recurring.py` | `RecurringItemCreate`, `RecurringItemUpdate`, `RecurringItemOut` |
| `app/repositories/recurring_repository.py` | `list_for_user`, `get(id, user_id)`, `create`, `save`, `delete`, `list_due(user_id, today)` |
| `app/services/recurring_service.py` | `list/create/update/delete/_get_owned` (mirrors `goal_service`) + `promote_due` + `_advance` + `MAX_BACKFILL_PERIODS` |
| `app/routers/recurring.py` | `GET /recurring`, `POST /recurring` (201), `PATCH /recurring/{id}`, `DELETE /recurring/{id}` (204), `POST /recurring/run-due` → `{"promoted": n}` |

**Schemas:**

- `RecurringItemCreate`: `type` (`^(income|expense)$`), `name` (1–100),
  `amount` (>0), `category_id` (int), `frequency`
  (`^(weekly|monthly|yearly)$`), `next_due_date` (date — the first due date),
  `active` (bool, default `True`).
- `RecurringItemUpdate`: all fields optional (partial update, `exclude_unset`).
- `RecurringItemOut` (`from_attributes=True`): `id`, `type`, `name`, `amount`,
  `category_id`, `frequency`, `next_due_date`, `active`.

**Two external edits (documented in-code):**

1. `app/main.py` — `app.include_router(recurring.router)`.
2. `app/routers/transactions.py` — call
   `RecurringService(db).promote_due(current_user)` at the start of the list
   endpoint, so the client-computed dashboard reflects newly promoted rows.
   Justified cross-feature coupling; commented as such.

### Frontend files (mirror the `transactions` feature)

| File | Responsibility |
|------|----------------|
| `features/recurring/domain/recurring_item.dart` | Model + `fromJson`/`toJson` |
| `features/recurring/data/recurring_repository.dart` | `list/create/update/delete/runDue`; per-account Hive cache + `clearCache()` |
| `features/recurring/presentation/recurring_providers.dart` | `recurringRepositoryProvider`, `RecurringNotifier` (AsyncNotifier) |
| `features/recurring/presentation/recurring_page.dart` | Replaces the placeholder; list + actions |
| `features/recurring/presentation/add_edit_recurring_page.dart` | Add/edit form |

**Provider behaviour (applies bugs #8/#9/#10 lessons):**

- `RecurringNotifier.build()` calls `ref.watch(sessionIdProvider)` as its first
  line — account switch tears it down automatically (bug #10).
- Mutations (`add`, `edit`, `delete`, `toggleActive`, `runDue`) call
  `ref.invalidateSelf()` **and** `ref.invalidate(transactionsProvider)` +
  `ref.invalidate(budgetsProvider)` — because promotion (and an item first-due
  today) creates real transactions that shift the balance and every budget's
  live-computed usage (bug #9).
- Repository caches only successful list fetches and only falls back to the
  cache **when the cache actually has data**, so a real fetch error is not
  masked as an empty state (bug #8). `clearCache()` is wired into logout
  alongside the transactions cache, for per-account isolation (bug #10).

**UI (`recurring_page.dart`):**

- Two sections: **Income** and **Expenses**.
- Each tile: name · ₱amount (via `currency_formatter`) · frequency ·
  "next: <date>", with an `active`/pause `Switch` and category visuals
  (`category_visuals`).
- Swipe-to-delete (matches transactions).
- FAB → add.
- Overflow menu → **"Run due now"** → calls `runDue`, then a snackbar
  "Added N transactions" (or "Nothing due" when `promoted == 0`).
- Loading / error / retry states (no silent empty on error).

**Form (`add_edit_recurring_page.dart`)** — mirrors
`add_edit_transaction_page.dart`:

- income/expense toggle, name, amount (`thousands_separator_formatter`),
  category picker (`category_picker`), frequency dropdown, first-due date
  picker, active switch.
- **Edit mode pre-selects the existing category** (explicitly avoiding the
  bug #12 class of "edit didn't pre-select").

**Routing:** `/recurring` already exists in `app_router.dart` under "More".
Confirm `more_page.dart` links to it; add the link if missing. No new route.

## Testing

Backend tests in `app/tests/` following the existing style
(`test_auth.py`), a new `test_recurring.py`:

- `_advance` edge cases: month-end clamp (Jan 31 → Feb 28 → Mar 28), leap-year
  (Feb 29 → Feb 28), weekly, yearly.
- `promote_due`: single due period; multi-period backfill with correct
  historical dates; the 60-period cap fast-forwarding; idempotency (second call
  promotes 0); inactive items are skipped; only the owner's items are touched.
- Ownership: `PATCH`/`DELETE` on another user's item → 404.
- `run-due` endpoint returns the promoted count.

Manual verification (per project norms — run against live infra):
create a recurring item due today → confirm a transaction appears and the
dashboard balance updates; create one dated in the past → confirm backfill;
toggle active off → confirm no promotion.

## Out of scope (deliberately)

- No scheduler dependency (APScheduler, cron) — lazy catch-up only.
- No schema migration / no `RecurringItem` model change.
- No changes to the AI/chat layer.
- Analytics stays client-side (that is Milestone 5).
- No offline **write** queue for recurring items (Milestone 7); failed writes
  surface an error, matching the current transactions behaviour.

## Risks / limitations (documented)

- **Monthly day-drift** (decision #4) — accepted for v1.
- **Promotion on GET is a side effect** — unusual but safe because it is
  idempotent; chosen over a dedicated dashboard endpoint that does not exist
  yet. Revisit if/when Milestone 5 adds server-side analytics endpoints, which
  would become a natural single trigger point.
- **Timezone** — promotion uses server `date.today()`. Acceptable for a
  single-region (Philippines) app; note it if multi-region is ever added.
