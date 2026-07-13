# Hamili

Hamili is an AI personal finance tracker for Android and Web. Alongside the usual budgeting tools it includes Hami, an assistant built on Google Gemini that reviews your spending, keeps your savings goals in view, and answers money questions in plain language.

## What it does

- Record income and expenses with categories, notes, and search
- Set monthly budgets per category, with a warning before you go over
- Create savings goals and track progress toward each one
- See where your money goes through charts and a monthly breakdown
- Ask Hami things like "Can I afford this?" or "Where am I overspending?" and get answers based on your own numbers
- Keep working offline; changes sync once you reconnect

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter, one codebase for Android and Web |
| State | Riverpod |
| Backend | FastAPI (Python) |
| Database | PostgreSQL |
| ORM and migrations | SQLAlchemy, Alembic |
| AI | Google Gemini, behind a swappable provider interface |
| Charts | FL Chart |
| Auth | JWT with email and password |

## How it fits together

The Flutter app talks only to the FastAPI backend. The backend holds the Gemini key and the database connection, so no secret ships inside the app. Inside the backend, a request moves through routers, then services, then repositories, then the ORM.

```
hamili/
├── hamili-backend/   FastAPI backend
├── hamili-app/       Flutter frontend for Android and Web
└── docs/             installation, API, schema, and deployment guides
```

## Try it

- Web: https://hamili-48b45.web.app
- Android: download the latest APK from the [Releases page](https://github.com/Yus3n10/Hamili/releases)

The backend runs on a free tier that sleeps when idle, so the first request after a quiet stretch can take up to a minute to wake.

## Documentation

- [Installation](docs/installation.md)
- [API](docs/api.md)
- [Database schema](docs/database.md)
- [Deployment](docs/deployment.md)

## Status

This is the first version. The project is still ongoing, and I am looking for testers who can try it and tell me what feels off, unclear, or missing.

## License

Not yet decided.
