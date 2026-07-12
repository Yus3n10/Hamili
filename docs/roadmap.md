# Development Roadmap

## ✅ Milestone 1 — Foundation (complete)
- Repo structure (backend + frontend), FastAPI skeleton, layered architecture
- PostgreSQL schema + Alembic migrations for all core tables
- Email/password auth (JWT), `get_current_user` dependency
- AI provider abstraction (`AIProvider` interface + `GeminiProvider`)
- Flutter skeleton: theming (light/dark), bottom-nav shell, GoRouter with auth redirect
- Transactions CRUD (backend) + basic chat UI wired to `/chat/message`

## ✅ Milestone 2 — Core Tracking (complete)
- `GET /categories` endpoint (backend)
- Flutter `TransactionsPage` wired to real backend data: list, add, edit, delete, search, category filter, swipe-to-delete
- Dashboard: real balance/income/expense figures computed from live transaction data, recent transactions list
- Reusable category picker bottom sheet, category icon mapping, currency formatter
- Local Hive cache for transactions and categories — falls back to last-known data when the network call fails

## ✅ Milestone 3 — Budgets & Goals (complete)
- `budgets` and `goals` routers/services (backend), with live usage/progress calculation
- Budget planner UI: per-category monthly limits, live spent/remaining, color-coded near-limit (≥80%) and over-budget (≥100%) states
- Savings goals UI: progress bars, contribution flow, naive linear estimated-completion-date projection, completion celebration dialog

## Milestone 4 — Recurring Items
- `recurring_items` router/service
- Scheduled job (APScheduler or cron) to promote due recurring items into transactions
- Recurring income/expense management UI

## Milestone 5 — Analytics
- `/analytics/summary`, `/trends`, `/category-breakdown` endpoints
- FL Chart implementations: income vs. expense, category breakdown, monthly trends, savings growth, budget utilization

## Milestone 6 — Hami AI (deepen)
- Proactive insights: scheduled generation via `InsightService.generate_proactive_insights`, surfaced on dashboard
- Insight dismiss/read tracking (`ai_insights.is_read`)
- Refine prompt templates based on real usage

## Milestone 7 — Polish
- Full offline sync (queue writes made offline, replay on reconnect)
- Animations (page transitions, chart entrance, goal-completion celebration)
- Empty states, error states, loading skeletons throughout
- Onboarding flow for first-time users

## Milestone 8 — Deployment
- Backend on Render, DB on Aiven, Web on Firebase Hosting, signed Android APK
- Full documentation pass (this docs/ folder)
- Post-deploy checklist verification (see deployment.md)

## Future Features (structured for, not yet built)
OCR receipt scanning · bank integration · investment tracking · debt payoff planner · family budgeting · multiple wallets · export to Excel/PDF · push notifications · home-screen widgets · gamification · multi-language support (English, Filipino, Hiligaynon)

Each of these maps cleanly onto the existing `features/<name>/{data,domain,presentation}` pattern on the frontend and a new `routers/<name>.py` + `services/<name>_service.py` pair on the backend — no architectural rework needed to add them.
