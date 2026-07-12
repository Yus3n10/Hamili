# Milestone 6 — Proactive AI Insights — Design

**Date:** 2026-07-12
**Status:** Approved (design)
**Depends on:** Milestones 1–5; existing AI layer (`InsightService`, `GeminiProvider.generate_insights`, `AIInsight` model)

## Goal

Surface AI-generated, proactive financial insights (overspending alerts,
goal-progress nudges, subscription suggestions) on the dashboard, persisted so
they can be shown and dismissed outside a chat. Most of the AI plumbing already
exists — this milestone adds persistence, an endpoint layer, and the UI.

## What already exists (reused, not rebuilt)

- `AIProvider.generate_insights(snapshot) -> list[str]` (abstract) and its
  `GeminiProvider` implementation (parses a JSON list, returns `[]` on failure).
- `InsightService.build_financial_snapshot()` and `generate_proactive_insights()`.
- `AIInsight` ORM model (`insight_type`, `message`, `is_read`, `created_at`) and
  its `ai_insights` table (already in the initial migration — **no migration**).

## Key decisions (locked)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Daily cache + manual refresh** | Each generation is a Gemini call. Auto-generate at most once/day on dashboard load; a refresh button forces regeneration. Balances "proactive" with cost/latency. |
| 2 | **Persist insights; dismiss via `is_read`** | The model was built for this. Dismissed insights hide; a day's batch persists until replaced or dismissed. |
| 3 | **Generation replaces the prior unread batch** | On generate, delete existing unread insights for the user, then insert the new batch — the card shows the latest batch, not an accumulation. |
| 4 | **Generation is failure-tolerant** | Wrap the provider call in try/except; on any error store nothing and return `[]`. `GET /insights` is always 200, so a stale/невalid model never 500s the dashboard. |
| 5 | **Store as generic type** | Provider returns plain strings; store with `insight_type = "general"`. Rich typing/icons deferred. |
| 6 | **Insights are NOT cross-invalidated by transactions** | They're a daily snapshot, not a live figure — refreshing on every transaction would defeat the daily-cache cost control. Manual refresh covers immediacy. |

## Backend

Extend `InsightService`, add an `insights` router.

### InsightService additions

- `_has_todays_batch(user) -> bool`: any `AIInsight` for the user with
  `created_at::date == today` (read or unread — a dismissed-today batch still
  counts, so we don't regenerate the same day).
- `generate_and_store(user) -> list[AIInsight]`: build snapshot; call the
  provider inside try/except; delete the user's existing **unread** insights;
  insert one `AIInsight(insight_type="general", message=text)` per returned
  string; commit; return the stored rows. On provider error → deletes nothing,
  inserts nothing, returns `[]`.
- `list_active(user) -> list[AIInsight]`: unread insights, newest first.
- `ensure_daily(user) -> list[AIInsight]`: if not `_has_todays_batch`, call
  `generate_and_store`; return `list_active`.
- `dismiss(user, insight_id)`: mark owned insight `is_read = True`; 404 if not
  owned/found.

### Router (`app/routers/insights.py`, registered in `main.py`)

- `GET /insights` → `ensure_daily(user)` → `list[AIInsightOut]`.
- `POST /insights/refresh` → `generate_and_store(user)` → `list[AIInsightOut]`.
- `PATCH /insights/{id}/dismiss` → `dismiss`; 204.

### Schema

`AIInsightOut{ id: int, insight_type: str, message: str, created_at: datetime }`
(`from_attributes=True`).

## Frontend

Insights live under the dashboard feature (they're dashboard-surfaced).

| File | Responsibility |
|------|----------------|
| `features/dashboard/domain/ai_insight.dart` | `AiInsight{id, insightType, message, createdAt}` + `fromJson` |
| `features/dashboard/data/insights_repository.dart` | `get()`, `refresh()`, `dismiss(id)` |
| `features/dashboard/presentation/insight_providers.dart` | `insightsRepositoryProvider`, `InsightsNotifier` (AsyncNotifier, session-scoped) with `refresh()` and `dismiss(id)` |
| `features/dashboard/presentation/widgets/insights_card.dart` | "Insights from Hami" card: list rows with a dismiss ✕, a header refresh button, graceful empty state (renders nothing when no insights) |

- `dashboard_page.dart` inserts the insights card above "Recent Transactions".
- The insights provider loads independently, so the first-of-day Gemini latency
  never blocks the balance/transactions rendering; the card shows its own small
  loading state.
- `InsightsNotifier.build()` watches `sessionIdProvider` (account isolation).

## Testing

Backend `app/tests/test_insights.py` (TestClient, live DB) — deterministic,
avoids asserting non-deterministic AI content:
- `GET /insights` → 200 and a JSON list (generation is failure-tolerant, so this
  holds even if the model returns nothing).
- `PATCH /insights/999999/dismiss` → 404 (ownership/not-found).

Manual: dashboard shows an insights card after login; refresh regenerates;
dismiss removes a card; logging into another account shows no leaked insights.

## Out of scope

- Rich per-insight typing, icons, severity, or deep-linking to the relevant
  budget/goal.
- Push notifications / scheduled server-side generation (only on-access daily).
- Insight history view (dismissed insights aren't surfaced anywhere).

## Risks / notes

- **Gemini model drift** (noted in project history): a dead model id would make
  generation raise; decision #4's try/except turns that into an empty card
  rather than a broken dashboard. The current id is `gemini-flash-lite-latest`.
- **Cost:** ~1 generation/user/day plus manual refreshes. Acceptable for a
  portfolio app; revisit if usage grows.
