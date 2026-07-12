# Milestone 5 — Analytics Endpoints & Charts — Design

**Date:** 2026-07-12
**Status:** Approved (design)
**Depends on:** Milestones 1–4 (transactions, categories, budgets, recurring)

## Goal

Replace the dashboard's client-side summing with server-side analytics
aggregates, and give the currently-placeholder Analytics page real charts:
spending-by-category, an income-vs-expenses trend, and period summary tiles.
`fl_chart ^0.68.0` is already a dependency.

## Key decisions (locked)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Server-side SQL aggregates** (`SUM ... GROUP BY`), never fetch-and-sum | The whole point of the milestone; scales past the point where client-side summing is free. Mirrors the existing `BudgetRepository.spent_amount` pattern. |
| 2 | **Dashboard summary stays all-time**, just server-computed | Preserves current dashboard meaning (running balance + all-time income/expense); only the computation moves. |
| 3 | **Analytics page is month-scoped** with prev/next navigation | Mirrors the budgets `BudgetPeriod` pattern the user already knows. Monthly breakdowns live here, not on the dashboard. |
| 4 | **Three endpoints, three views** — category donut, trend bars, summary tiles | Focused scope. Net-balance line chart, custom ranges, and export are explicitly deferred. |
| 5 | **Reuse existing category data** for names/icons | The Flutter `categoriesProvider` already caches categories; charts join on `category_id` client-side, so analytics endpoints return ids + totals only. |

## Backend

New `analytics` router → service → repository, following the existing
layering. No new model, no migration.

### Endpoints

1. `GET /analytics/summary`
   - No params → all-time `{income, expense, net}` (the **dashboard** uses this).
   - `?month=&year=` → that month's `{income, expense, net}` (analytics tiles).
   - `net = income - expense`. Returned as `AnalyticsSummaryOut`.

2. `GET /analytics/by-category?month=&year=&type=expense`
   - `SUM(amount) GROUP BY category_id` filtered by user, type, month, year.
   - Returns `[{category_id, total}]` sorted by `total` desc. Percentage is
     computed client-side (total / sum-of-totals) to keep the endpoint simple.
   - `type` defaults to `expense`; `month`/`year` default to the current month.

3. `GET /analytics/trend?month=&year=&months=6`
   - The `months` months ending at `(month, year)` inclusive (default current
     month, default 6). For each: `{year, month, income, expense}`.
   - Implemented as one grouped query
     (`GROUP BY EXTRACT(year), EXTRACT(month), type`) over the window, then
     zero-filled in Python so months with no activity still appear.

### Files

| File | Responsibility |
|------|----------------|
| `app/schemas/analytics.py` | `AnalyticsSummaryOut`, `CategoryBreakdownOut`, `TrendPointOut` |
| `app/repositories/analytics_repository.py` | `summary(user_id, month?, year?)`, `by_category(user_id, type, month, year)`, `trend(user_id, end_month, end_year, months)` — all SQL aggregates |
| `app/services/analytics_service.py` | Thin orchestration: param defaults, window math for trend, zero-fill, net calc |
| `app/routers/analytics.py` | The three GET routes; registered in `main.py` |

### Schemas

- `AnalyticsSummaryOut`: `income: float`, `expense: float`, `net: float`.
- `CategoryBreakdownOut`: `category_id: int`, `total: float`.
- `TrendPointOut`: `year: int`, `month: int`, `income: float`, `expense: float`.

## Frontend

The `analytics` feature currently has only a placeholder page. Fill it out
mirroring the transactions/budgets feature shape.

### Files

| File | Responsibility |
|------|----------------|
| `domain/analytics_models.dart` | `AnalyticsSummary`, `CategoryBreakdown`, `TrendPoint` + `fromJson` |
| `data/analytics_repository.dart` | `summary({month,year})`, `byCategory({month,year})`, `trend({month,year,months})` over Dio |
| `presentation/analytics_providers.dart` | `analyticsPeriodProvider` (month/year state), `analyticsSummaryProvider` (all-time, for dashboard), month-scoped `summary`/`byCategory`/`trend` providers — all `ref.watch(sessionIdProvider)` first |
| `presentation/analytics_page.dart` | Month selector, summary tiles, category donut + list, trend bar chart |
| `presentation/widgets/category_donut.dart` | `fl_chart` PieChart (donut) + ranked legend |
| `presentation/widgets/trend_bar_chart.dart` | `fl_chart` BarChart, income vs expense per month |

### Dashboard refactor

- Add `analyticsSummaryProvider` (no-params `/analytics/summary`, all-time).
- Dashboard replaces its `transactions.fold(...)` income/expense/balance with
  this provider's values. Recent-transactions list is unchanged.
- The analytics providers are invalidated wherever transactions change.
  Both `TransactionsNotifier` (add/edit/delete — already invalidates
  `budgetsProvider`) **and** `RecurringNotifier` (add + run-due, which create
  real transactions via promotion) must also invalidate
  `analyticsSummaryProvider` and the month-scoped analytics providers.
  Invalidating `transactionsProvider` alone does **not** refresh the separate
  analytics providers, so this is an explicit addition in both notifiers.
  To avoid repetition, expose a small helper (e.g. a top-level
  `invalidateAnalytics(Ref ref)` in `analytics_providers.dart`) both notifiers
  call.

### Period model

`analyticsPeriodProvider` holds `{month, year}` (default current month), with
prev/next controls on the Analytics page. The summary tiles and category donut
read the selected month; the trend chart shows the trailing 6 months ending at
the selected month. The dashboard's `analyticsSummaryProvider` ignores the
period (always all-time).

### Charts (fl_chart)

- **Donut:** `PieChart` with a center hole; one section per category colored
  from `CategoryVisuals`; empty state when no spending. Ranked list below:
  category name · ₱total · % (percentage computed client-side).
- **Bars:** `BarChart`, two bars (income/expense) per month, x-axis labelled by
  short month name, currency-formatted tooltips.

## Testing

Backend `app/tests/test_analytics.py` (TestClient against the live DB, like
existing tests):
- Register/login, seed a couple of transactions, then assert:
  - `/analytics/summary` all-time net = income − expense.
  - `/analytics/summary?month=&year=` scopes to that month.
  - `/analytics/by-category` groups and sums correctly, sorted desc.
  - `/analytics/trend?months=6` returns 6 points, zero-filled where empty,
    newest window aligned to the requested end month.

Flutter: `flutter analyze` clean; manual verification in Opera GX — dashboard
totals match, donut and bars render, month navigation works.

## Out of scope (deliberately)

- Net-balance line chart, cumulative-balance view.
- Custom/arbitrary date ranges (only whole-month + trailing-6-months).
- CSV/PDF export.
- Server-side percentage/precomputed colors (done client-side).
- Caching analytics responses in Hive (dashboard/analytics are online views;
  revisit if offline analytics is wanted later).

## Risks / notes

- **Timezone:** aggregates use the stored `transaction_date` (a date, no tz) and
  server month/year for "current month" defaults — consistent with budgets and
  recurring. Fine for a single-region app.
- **`fl_chart 0.68` API:** pin usage to that version's API (BarChart/PieChart
  constructors); verify against installed version during implementation.
