# Hamili 🪙

**Hamili** is an AI-powered personal finance tracker for Android and Web, built with Flutter and FastAPI. It combines traditional budgeting tools with **Hami**, a friendly AI financial companion (powered by Google Gemini) that explains spending trends, encourages saving, and answers budgeting questions in plain language.

## Why Hamili

Most budgeting apps show you numbers. Hamili tries to help you *act* on them — Hami proactively flags things like overspending trends, near-complete savings goals, or subscriptions worth reconsidering, and can hold a real conversation about your finances (e.g. *"Can I afford this?"*, *"Where am I overspending?"*).

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Android + Web, single codebase) |
| State management | Riverpod |
| Backend | FastAPI (Python) |
| Database | PostgreSQL |
| ORM / Migrations | SQLAlchemy + Alembic |
| AI | Google Gemini API (swappable via provider interface) |
| Charts | FL Chart |
| Auth | JWT (email/password), Google Sign-In planned |

## Project Structure

```
hamili/
├── hamili-backend/      # FastAPI backend — see docs/api.md, docs/database.md
├── hamili-app/           # Flutter frontend (Android + Web)
└── docs/                 # Installation, API, schema, deployment guides
```

## Documentation

- [Installation Guide](docs/installation.md)
- [API Documentation](docs/api.md)
- [Database Schema](docs/database.md)
- [Deployment Guide](docs/deployment.md)

## Current Status

**Milestones 1–3 — Foundation, Core Tracking, Budgets & Goals: complete.** Verified end-to-end against a live Aiven Postgres instance and the Gemini API.

- ✅ FastAPI skeleton with layered architecture (routers → services → repositories → ORM)
- ✅ PostgreSQL schema + Alembic migrations for all core tables
- ✅ Email/password auth (JWT access + refresh tokens)
- ✅ AI provider abstraction with a working Gemini implementation — Hami replies with real financial context
- ✅ Transactions: full CRUD, both backend and Flutter UI (list, add, edit, delete, search, category filter)
- ✅ Dashboard: real balance/income/expense figures, recent transactions
- ✅ Offline cache (Hive) for transactions and categories
- ✅ Budgets: per-category monthly limits with live usage tracking and near-limit/over-budget indicators
- ✅ Savings goals: progress tracking, contributions, estimated completion date, completion celebration

See the [development roadmap](docs/roadmap.md) for what's next.

## License

Not yet decided — add before making the repo public if you intend to open-source it.
