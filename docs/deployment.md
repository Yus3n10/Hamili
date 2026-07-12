# Hamili — Deployment Guide

This walks through taking Hamili from local dev to something a friend on the
other side of the country can install and use.

## How the pieces fit

```
Android APK / Web app  ──►  FastAPI backend (Render)  ──►  Google Gemini
   (Firebase Hosting)              │
                                   └──►  PostgreSQL (Aiven)
```

The app talks **only** to your backend. The backend holds the Gemini key and
the DB connection, so:

- Users never need their own Gemini key — every AI request uses **your** key
  via your backend (you pay for the shared usage; watch quota/rate limits).
- The Gemini key and JWT secret are **never** shipped in the APK — they live
  as server-side environment variables. This is why the app is useless until
  the backend is publicly deployed: `localhost` on a phone means the phone.

> **Security note:** everything below keeps secrets server-side or in
> gitignored files. Never commit `.env`, `android/key.properties`, or a
> `.jks` keystore. The repo's `.gitignore` already blocks them.

## Prerequisites

- Accounts: **GitHub** (done), **Render**, **Firebase/Google** (only if you
  want the web build hosted).
- Tools: Flutter SDK, `keytool` (ships with the JDK), and optionally the
  **Firebase CLI** and **GitHub CLI** (`gh`).
- The repo pushed to GitHub (it is: `github.com/Yus3n10/Hamili`).

---

## Part A — Deploy the backend to Render

1. In Render: **New → Blueprint**, and select this GitHub repo. Render reads
   [`render.yaml`](../render.yaml) and provisions a `hamili-api` web service
   (root dir `hamili-backend`, Python 3.11.9).
2. It will prompt for the secret env vars (marked `sync: false`). Set:
   - `DATABASE_URL` — your Aiven Postgres connection string
     (`postgresql+psycopg2://user:pass@host:port/dbname`).
   - `GEMINI_API_KEY` — your Google Gemini API key.
   - `CORS_ORIGINS` — leave as `http://localhost:5000` for now; you'll add the
     web URL in Part C. (`SECRET_KEY` is auto-generated; `AI_PROVIDER`,
     `ENVIRONMENT`, `PYTHON_VERSION` are preset.)
3. Deploy. The start command runs `alembic upgrade head` (idempotent) then
   `uvicorn`, so the schema is migrated automatically.
4. Verify: open `https://<your-service>.onrender.com/health` → `{"status":"ok"}`.
   Interactive API docs are at `/docs`.

> **Free-tier cold start:** Render's free plan sleeps the service after
> inactivity, so the first request after idle takes ~30–60s to wake. This is
> exactly why the app's recurring-item promotion is lazy rather than a
> background job (Milestone 4).

## Part B — Database (Aiven)

Already cloud-hosted, so nothing to move. Migrations are applied on every
deploy by the start command. To run them manually against a new DB:

```bash
cd hamili-backend
DATABASE_URL="postgresql+psycopg2://..." ./venv/Scripts/python -m alembic upgrade head
```

## Part C — Web app on Firebase Hosting (optional)

1. Set your project id in [`hamili-app/.firebaserc`](../hamili-app/.firebaserc)
   (replace `REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID`).
2. Build the web bundle pointed at your live backend:
   ```bash
   cd hamili-app
   flutter build web --dart-define=API_BASE_URL=https://<your-service>.onrender.com
   ```
3. Deploy:
   ```bash
   firebase login
   firebase deploy --only hosting
   ```
   ([`firebase.json`](../hamili-app/firebase.json) already points at
   `build/web` with SPA rewrites.)
4. **Important:** add the resulting URL (e.g. `https://hamili-xxxx.web.app`) to
   the backend's `CORS_ORIGINS` env var in Render, then redeploy — otherwise
   the browser blocks the app's API calls.

## Part D — Build the signed release APK

1. Generate a keystore **once** (keep it safe — you need the same one for every
   future update):
   ```bash
   keytool -genkey -v -keystore hamili-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hamili
   ```
2. Copy [`android/key.properties.example`](../hamili-app/android/key.properties.example)
   to `hamili-app/android/key.properties` and fill in your passwords, the alias
   (`hamili`), and the absolute `storeFile` path to the `.jks`. This file is
   gitignored — never commit it.
3. Build, pointed at your live backend:
   ```bash
   cd hamili-app
   flutter build apk --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`.

   The Gradle config ([`build.gradle.kts`](../hamili-app/android/app/build.gradle.kts))
   uses your `key.properties` when present and falls back to debug signing when
   it's absent, so `flutter run` still works without a keystore.

> Before publishing widely, change `applicationId`/`namespace` off
> `com.example.hamili` in `build.gradle.kts` to your own id.

## Part E — Distribute via GitHub Releases

```bash
cd hamili-app
gh release create v1.0.0 build/app/outputs/flutter-apk/app-release.apk \
  --title "Hamili v1.0.0" --notes "First public build."
```

Or use the GitHub web UI: **Releases → Draft a new release**, attach the APK.
Users download it and enable "install from unknown sources" to install (it's
not on the Play Store).

## Environment variable summary

| Variable | Where | Purpose |
|---|---|---|
| `DATABASE_URL` | Backend (Render) | Aiven Postgres connection string |
| `SECRET_KEY` | Backend (Render) | JWT signing key — auto-generated by the Blueprint |
| `GEMINI_API_KEY` | Backend (Render) | Google AI Studio key for Hami |
| `CORS_ORIGINS` | Backend (Render) | Comma-separated allowed frontend origins (add your `web.app` URL) |
| `API_BASE_URL` | Frontend (`--dart-define`) | Points the built app at the deployed backend |

## Post-deploy checklist

- [ ] `GET /health` returns `200` on the Render URL.
- [ ] Register + login works from the deployed web app / APK.
- [ ] `CORS_ORIGINS` includes the exact web URL (protocol + domain, no trailing slash).
- [ ] Gemini key has quota ([AI Studio](https://aistudio.google.com/)).
- [ ] `.env`, `android/key.properties`, and `*.jks` are all git-ignored.

## Production considerations

- **Shared Gemini cost/quota:** all users' chat + insights hit your one key.
  Fine for a demo; add per-user rate limiting on `/chat` and `/insights`
  before any high-traffic distribution.
- **Public backend:** JWT protects the endpoints, but anyone can register.
  Consider a registration cap or rate limiting if abuse is a concern.
- **Rotate secrets** if a keystore or `.env` ever leaks; the keystore
  especially cannot be recovered — losing it means you can't ship signed
  updates to the same app id.
