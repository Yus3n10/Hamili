# Hamili

Hamili is an AI personal finance tracker for Android, iPhone, and the web. Alongside the usual budgeting tools it includes Hami, an assistant built on Google Gemini that reviews your spending, keeps your savings goals in view, and answers money questions in plain language.

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
- iPhone and iPad: add the web app to your home screen (steps below)

### Install on iPhone or iPad

There is no App Store version yet, but the web app installs to your home screen and opens full screen like a regular app.

1. Open https://hamili-48b45.web.app in **Safari**. Other browsers on iPhone can't add apps to the home screen.
2. Tap the **Share** button (the square with an arrow pointing up).
3. Scroll down and tap **Add to Home Screen**, then tap **Add**.
4. Open Hamili from the new icon and sign in.

It updates by itself, so there is nothing to reinstall when a new version comes out. The home screen app keeps its own sign-in, separate from Safari, so you sign in once inside it.

### Upgrading on Android from v1.0.x

Version 1.1.0 changed the app ID, so it installs as a separate app instead of replacing the old one. Your data is on the server and comes back when you sign in.

1. Open the old Hamili while online, so anything added offline finishes syncing.
2. Uninstall the old Hamili.
3. Install the new APK and sign in.

The backend runs on a free hosting tier. It is kept awake, but if it has gone to sleep the first request can take up to a minute.

## Documentation

- [Installation](docs/installation.md)
- [API](docs/api.md)
- [Database schema](docs/database.md)
- [Deployment](docs/deployment.md)

## Status

This is the first version. The project is still ongoing, and I am looking for testers who can try it and tell me what feels off, unclear, or missing.

## License

Not yet decided.
