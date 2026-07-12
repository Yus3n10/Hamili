# Hamili — Master Continuation Prompt

*Paste this as the opening message in a new Claude Code chat to continue seamlessly. It is context **about** the codebase — the local repo is ground truth; read it, don't assume.*

---

## Prompt to paste into a new chat

> I'm building **Hamili**, an AI-powered personal finance tracker (Flutter + FastAPI + PostgreSQL + Gemini). Work has spanned several chats. Read the summary below as accurate context of what's already built, tested, and pushed. Act as lead architect / senior Flutter dev / senior Python backend dev / AI integration engineer. Plan before coding, keep the codebase modular and documented, flag any bugs you fix, and **verify with evidence** (run tests / drive the API) rather than assuming. Then continue from "What's next".

---

## Project

Flutter (Android + Web) personal finance tracker with an AI companion, **Hami**. Portfolio-quality, on GitHub.

- **Stack:** Flutter · FastAPI · PostgreSQL (Aiven, cloud) · SQLAlchemy + Alembic · Google Gemini · Riverpod · JWT · Hive (offline cache) · fl_chart.
- **Repo (local, ground truth):** `C:\Users\LENOVO\VS Code Files\Hamili`
  - `hamili-backend/app/` — routers → services → repositories → ORM
  - `hamili-app/lib/` — feature folders with `data/domain/presentation`
  - `docs/` — README, install, api, database, deployment, roadmap, specs & plans under `docs/superpowers/`
- **GitHub:** https://github.com/Yus3n10/Hamili (default branch `main`, all work pushed; latest at time of writing ≈ `133718e`).

## Status: Milestones 1–8 complete + a full design/UX pass + an AI action agent

All run against **live Aiven Postgres + real Gemini**, not just written. Backend has a pytest suite (15+ tests) that passes; the AI agent was verified end-to-end via live API calls.

### Backend (`hamili-backend/app/`)
- **Auth:** register/login (JWT), `GET/PATCH /auth/me` (profile update).
- **Transactions, Categories, Budgets** (live-computed spent, upsert), **Goals** (contributions, naive linear ETA, completion status).
- **Recurring (M4):** `recurring` router/service/repo. **Lazy catch-up promotion** — no scheduler (survives free-tier sleep). Backfills every missed period at its real date, capped **60/item/run**; monthly day-drift accepted (no migration). Triggered on `GET /recurring`, `GET /transactions`, and `POST /recurring/run-due`.
- **Analytics (M5):** `GET /analytics/summary` (all-time if no params; monthly if `?month=&year=`), `/by-category`, `/trend?months=6`. All server-side SQL aggregates (`func.sum`, `extract`).
- **Insights (M6):** `GET /insights` (daily-cached generate + persist), `POST /insights/refresh`, `PATCH /insights/{id}/dismiss`. Generation is failure-tolerant (Gemini error → empty, never 500). Uses the `AIInsight` model.
- **AI provider abstraction:** `app/services/ai/` — `AIProvider` interface + `GeminiProvider` (`gemini-flash-lite-latest`). Nothing outside `ai/` imports the Gemini SDK.
- **AI quota fallback:** Gemini quota/429 → `AIProviderUnavailable`; chat returns `"Hami's servers are down right now, try again tomorrow. 💤"` with `available=false`.
- **AI action agent (`agent_service.py`):** interprets a chat message into a structured JSON action and executes it against the domain services. Actions: `add_savings_goal`, `edit_savings_goal`, `delete_savings_goal`, `contribute_to_goal`, `set_budget`, `add_transaction`, `add_recurring_item`, `update_profile`, or `none`. Does **category-name matching** and **relative-date resolution** ("December 1 this year" → ISO). Returns `{reply, available, changed:[...]}`; `changed` names the app areas that updated. Goals are matched by title; edits touch only provided fields; a failed action rolls back the session. **Verified live.**

### Frontend (`hamili-app/lib/`)
- Core tracking/budget/goal/chat UI; live dashboard; Hive offline cache; per-account session isolation (`sessionIdProvider`).
- **Recurring page** (CRUD, pause switch, "Run due now").
- **Budget drill-down** (`BudgetDetailPage`) — tap a budget to see its contributing expense transactions.
- **Analytics page** — month selector, income/expense/net tiles, spending-by-category donut, income-vs-expense trend bars, and a **cumulative net-balance line chart** (all fl_chart, animate in).
- **Dashboard insights card** ("Insights from Hami", dismissible, refresh).
- **Onboarding** (shown once: register → `/onboarding` → dashboard; welcome + currency/goal, skippable), **editable Profile**, **profile picture** (pick + in-app circular pan/zoom crop → base64 in Hive, device-local per account).
- **Offline write queue** — failed transaction writes queue in Hive and replay on the next successful request; optimistic UI + a dashboard "N waiting to sync" banner.
- **Chat agent UX** — type natural language to Hami; a **"✓ Done" chip** appears on replies that performed an action, and the affected tab (Goals/Recurring/Budgets/Profile) refreshes automatically.
- **Goal cards show the "Due &lt;date&gt;"** target date; recurring items show "next: &lt;date&gt;".
- **Force login each session:** the stored token is cleared at app startup (device-level), so every cold start begins at login.
- **Light/Dark mode** selector in Profile, persisted in Hive (`app_settings`). **App defaults to dark.**

### Design / UX pass (driven by the `ui-ux-pro-max` skill)
- **Theme:** warm gold brand (Hami), blue accent, fresh green / coral for income/expense; **Nunito** (headings) + **DM Sans** (body) via `google_fonts` (runtime fetch — tiny app size, needs network on first launch, falls back offline). Soft floating cards; **dark premium navy** palette (`#0C0E15` bg / `#161A24` cards) carried through the whole app to match the login.
- **Login:** responsive **two-panel** — dark premium hero with a **custom-painted live "portfolio" chart animation** (`AnimatedFinancePreview`) + sign-in form; stacks on mobile.
- **Motion (`flutter_animate`):** staggered list/section entrances, drifting light orbs on the gradient balance hero, count-up figures, animated budget progress bars, spring press-scale on tappable tiles, **page-transition slides** (GoRouter `CustomTransitionPage`), **bottom-nav tab glide** (`MainShell`), animated chart entrances, and **confetti on goal completion** (`confetti` pkg). All storage-light (pure-Dart, no image/Lottie assets).

### Deployment prep (M8 — you must execute the account-gated steps)
- `render.yaml` (Blueprint, Python 3.11.9, migrate-on-start), `runtime.txt`, `firebase.json` + `.firebaserc` (web hosting), Android release signing via gitignored `android/key.properties` (+ `.example`), `.gitignore` blocks keystores. Full guide in `docs/deployment.md`. Web release build verified.
- **The app is useless until the backend is deployed publicly** — it currently targets `http://localhost:8000` (`AppConstants.apiBaseUrl`, override with `--dart-define=API_BASE_URL=…`). `localhost` on a phone means the phone. All users share **your** Gemini key via your backend (secure — key never ships in the APK; you pay usage → consider rate limiting before wide release).

## Packages added this era
Flutter: `flutter_animate`, `confetti`, `image_picker`. (`rive` was added then removed — see mascot note.)

## The piggy-bank mascot (removed) + Lottie path
A Rive `.riv` piggy mascot was fully wired (coin-flip on income/goal, blink in chat, freeze-mid-blink "sleeping" for the servers-down state) — but the `.riv` ships with an **opaque background baked into the artboard** that can't be stripped without the Rive editor, so per the user it was **ditched** (widget, provider, asset, `rive` dep, all integrations removed; confetti + chat animations kept). **To bring it back:** convert to a **Lottie** (JSON, transparent bg is removable/default) — export with a **transparent background** and either **markers** for blink/coin-flip or **separate files per action** (Lottie is a linear timeline, not a Rive state machine; the "sleeping freeze" is actually easier via seeking to a frame). The removal is in git history and can be re-enabled quickly once a good Lottie exists.

## Key decisions / gotchas worth keeping
- `bcrypt==4.0.1` pinned; `email-validator` explicit; Gemini model names go stale — currently `gemini-flash-lite-latest`.
- CORS must include the Flutter dev origin (`http://localhost:5000`); backend reads `CORS_ORIGINS` env.
- Every account-scoped Riverpod provider watches `sessionIdProvider` first line (login/logout resets all).
- Offline cache falls back to cache **only when it has data** (never masks a real error as empty).
- Budget `spent` is computed live → the frontend invalidates budgets/analytics when transactions change.
- Theme mode + avatar are **device-level** (Hive), deliberately not account-scoped, so the force-login reset doesn't wipe them.
- Agent edits use only provided fields (explicit `None` + `exclude_unset` would otherwise blank columns); failed actions call `db.rollback()`.

## How to run / verify (Windows, this machine)
- **Backend:** `cd hamili-backend && ./venv/Scripts/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` (docs at `/docs`).
- **App:** `cd hamili-app && flutter run -d web-server --web-port=5000 --web-hostname=localhost`, then open **Opera GX** (`opera.exe`) at `http://localhost:5000`. Chrome automation is unreliable here; use `-d web-server` + open manually.
- **Backend tests:** `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/` (needs live `DATABASE_URL` in `.env`).
- **Flutter:** `cd hamili-app && flutter analyze` (should be 0 issues).
- **Verification limitation:** Flutter web renders to CanvasKit, which the in-tool browser pane usually can't screenshot — visual checks are done by the user in Opera GX. Prefer verifying backend via pytest + live `curl`, and the AI agent via live API calls.
- **Git:** commit per feature; feature branch then fast-forward `main`; push via PowerShell (Git Credential Manager is configured). Secrets (`.env`) and build artifacts are gitignored.

## What's next (open ideas, none started)
- **Lottie mascot** once a transparent-background file exists (re-enable from git history).
- **Actual deployment** (Render + Firebase + signed APK) — needs the user's accounts, a signing keystore, and `--dart-define=API_BASE_URL`.
- **Date/period pickers** when creating goals/budgets in the UI (the agent handles dates, but manual sheets may lack them).
- **Rate limiting** on `/chat` and `/insights` before a public backend.
- **More agent actions** (set a transaction date, contribute by %, "pay off" a goal, delete budget/transaction).
- Server-side avatar storage (currently device-local) if cross-device sync is wanted.
- Revisit the goal ETA (naive linear) once recurring income can be tied to goals.
