# Hamili — Handoff Context

This file captures decisions, environment quirks, and in-progress context that live in chat history rather than in the code itself. Read this alongside the code — the code is the source of truth for *what* exists; this is the *why* and *what's next*.

## Where things stand

**Milestones 1–3 complete and verified working** against a live Aiven PostgreSQL instance and the Gemini API, on Windows 11 + VS Code. Several rounds of real bugs have been found and fixed through actual testing (not just written and assumed correct) — see "Bugs fixed" below.

**Milestone 4 (Recurring Income & Expenses) has not been started.**

## Environment specifics (Windows + this machine)

- Project root: `C:\Users\LENOVO\VS Code Files\Hamili`
- Backend venv: `hamili-backend\venv` — activate with `.\venv\Scripts\Activate.ps1` (the `.\` prefix is required in PowerShell, `cd` into `hamili-backend` first)
- Flutter SDK installed at a custom location; `flutter doctor` shows Android toolchain and Visual Studio (Windows desktop) as **intentionally not installed** — not needed since this project targets Android + Web only, not Windows desktop
- **Chrome automation via `flutter run -d chrome` was unreliable on this machine** (background Chrome processes reviving old sessions, 4-tab restore issue). Working solution: `flutter run -d web-server --web-port=5000 --dart-define=API_BASE_URL=http://localhost:8000`, then open `http://localhost:5000` manually in a browser. If Chrome automation is worth revisiting later: fully kill all `chrome.exe` in Task Manager (closing windows isn't enough) and disable "Continue running background apps" in `chrome://settings/system`.
- Standard dev workflow: two terminals — one running `uvicorn app.main:app --reload` in `hamili-backend`, one running the Flutter web-server command in `hamili-app`.

## Database

- Aiven PostgreSQL 17, free tier. Connection string needs the `postgresql+psycopg2://` prefix (not the `postgres://` Aiven gives you by default) and keeps `?sslmode=require`.
- Migrations: `alembic revision --autogenerate -m "..."` then `alembic upgrade head`. (First-time setup mistake worth remembering: the Alembic scaffolding existing isn't the same as a migration existing — `versions/` was empty until the first autogenerate was actually run.)
- Seed script (`python -m app.db.seed`) populates the 12 default categories and is idempotent — safe to re-run.

## Dependency pins that matter (don't "helpfully" upgrade these without checking)

- `bcrypt==4.0.1` pinned explicitly in `requirements.txt` — newer bcrypt breaks passlib's version detection (`AttributeError: module 'bcrypt' has no attribute '__about__'`), which manifests as a confusing "password cannot be longer than 72 bytes" error that has nothing to do with the real cause.
- `email-validator==2.2.0` required for Pydantic's `EmailStr` — not an implicit dependency, must be listed explicitly.
- Gemini model: `gemini-flash-lite-latest` (an alias, not a pinned version). **`gemini-1.5-flash` and `gemini-2.0-flash` are both fully shut down** as of mid-2026 — if chat starts 404ing again, check whether the alias has been retired too and search for the current model lineup rather than assuming.

## Bugs fixed (with root causes — useful if similar symptoms reappear)

1. **`StatefulNavigationShell` not found on web build** — missing `go_router` import in `main_shell.dart`. Recurred once because the fix was made locally but not synced back into the delivered source zip — worth double-checking that any "edit this file locally" instruction also gets applied to the actual project source, not just described in chat.
2. **Login/register/chat all failing at once** — CORS. Flutter's dev server port wasn't in the backend's `CORS_ORIGINS`. Fixed by pinning `--web-port=5000` and adding `http://localhost:5000` to `CORS_ORIGINS`.
3. **Category picker showing no options** — was using `ref.read()` (one-time snapshot) instead of `ref.watch()` inside a bottom sheet, so it could catch the categories provider mid-load and never retry. Fixed by making the picker a proper `ConsumerWidget` that watches the provider and shows loading/error/retry states.
4. **Category-fetch failures silently showing "No categories available"** — the repository's offline-cache fallback swallowed real errors (network failures, auth issues) and returned an empty list indistinguishable from "you truly have zero categories." Fixed to only fall back silently when the cache actually has data; otherwise rethrows so the UI shows a real error + retry.
5. **Budget usage not updating after adding a transaction** — budgets and transactions are separate Riverpod providers with no automatic dependency link; adding a transaction didn't tell the budgets screen to refetch. Fixed by explicitly invalidating `budgetsProvider` from every transaction create/edit/delete.
6. **Cross-account data leak** — logging out and creating a new account showed the previous account's cached balance/transactions. Two causes: (a) Riverpod providers keep their last-fetched state in memory across login/logout since nothing tells them to forget, (b) the offline Hive cache is keyed globally, not per-account. Fixed by invalidating all user-scoped providers (transactions, budgets, goals, chat) on both login and logout, and clearing the Hive transaction cache on logout.

## Design decisions worth knowing the reasoning behind

- **Budgets are upserts, not strict creates.** `POST /budgets` for a category/month/year that already has a budget updates it instead of erroring — matches the mental model of "set my Food budget to ₱3000," which should just work whether or not you'd set it before.
- **Budget `spent_amount` is computed live, not stored.** Every `GET /budgets` call sums actual expense transactions for that category/month/year on the fly. This is why it's correct by construction but also why the frontend has to remember to invalidate/refetch when transactions change (see bug #5 above) — there's no stored number to go stale, but there's a cached *response* that can.
- **Goal estimated-completion-date is a naive linear projection** (average contribution rate so far, extrapolated forward) — explicitly a placeholder. A better version would factor in recorded recurring income once that data is reliably tied to specific goals, which doesn't exist yet (that's Milestone 4+ territory).
- **"Others" category custom input** was implemented as reusing the transaction's `note` field rather than adding true dynamic user-created categories (which would need a schema change — nullable `user_id` on `categories`, a `POST /categories` endpoint, etc.). Revisit if users want custom categories to persist and be reusable across transactions, not just a one-off label.
- **Chat history resets on login/logout**, not for memory/performance reasons (a chat history list is trivially small in RAM even on a mid-end Android phone — this was a deliberate check, not an assumption) but for account-isolation correctness, consistent with the cross-account leak fix above.
- **AI provider abstraction** (`AIProvider` interface, `GeminiProvider` implementation, `get_ai_provider()` factory) exists specifically so a second LLM provider could be added later by writing one new class — nothing outside `app/services/ai/` should ever import the Gemini SDK directly.

## Not yet built (per the original roadmap)

- **Milestone 4 — Recurring Income & Expenses:** `recurring_items` router/service (model already exists), a scheduled job to promote due recurring items into real transactions, and the corresponding Flutter UI. The `RecurringPage` placeholder exists but is unwired.
- **Milestone 5 — Analytics:** dedicated `/analytics/summary`, `/trends`, `/category-breakdown` endpoints and FL Chart visualizations. Currently the Dashboard computes income/expense/balance client-side from the full transaction list, which is fine at small scale but was explicitly noted as something to replace once that stops being "free."
- **Milestone 6 — deepen Hami:** proactive insights (`ai_insights` table exists, nothing populates it yet), insight dismiss/read tracking.
- **Milestone 7 — Polish:** true offline write queue (currently offline only supports *reading* cached data, not queuing writes made while offline), animations, empty/loading states audit, onboarding flow.
- **Milestone 8 — Deployment:** Render + Aiven + Firebase Hosting + signed APK. Nothing deployed yet — everything has been tested on localhost only.
- **Theming/visual design pass** was explicitly deferred ("we'll talk later about the theme") — current UI uses a functional warm-gold Material 3 theme, not a final design pass.
