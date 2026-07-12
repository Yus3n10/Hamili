# Deployment Guide

## Overview

| Component | Recommended host | Free tier? |
|---|---|---|
| Backend (FastAPI) | Render | Yes |
| Database (PostgreSQL) | Aiven | Yes |
| Frontend (Web) | Render Static Site / Firebase Hosting | Yes |
| Frontend (Android) | Signed APK, sideload or Play Console | APK: free; Play Console: one-time $25 |

## 1. Database — Aiven PostgreSQL

1. Create a free Aiven account and a PostgreSQL service.
2. Copy the connection string (Aiven gives you a full `postgresql://` URI with SSL params).
3. Use this as `DATABASE_URL` in the backend's environment — SQLAlchemy's `psycopg2` driver handles SSL automatically from the URI.

## 2. Backend — Render

1. Push `hamili-backend/` to GitHub.
2. On Render: New → Web Service → connect the repo, root directory `hamili-backend`.
3. Build command: `pip install -r requirements.txt`
4. Start command: `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT`
5. Add environment variables: `DATABASE_URL`, `SECRET_KEY`, `GEMINI_API_KEY`, `CORS_ORIGINS` (your deployed frontend URL).
6. Deploy. Verify with `GET /health`.

Render's free tier spins down after inactivity — the first request after idle will be slow (cold start). Fine for a portfolio demo; upgrade to a paid instance for production use.

## 3. Frontend — Web

```bash
cd hamili-app
flutter build web --dart-define=API_BASE_URL=https://your-backend.onrender.com
```

Deploy the `build/web` folder to any static host (Firebase Hosting, Render Static Site, Netlify, Vercel). Firebase Hosting has a generous free tier and is the most common pairing with Flutter Web.

## 4. Frontend — Android APK

1. Generate a signing keystore (one-time):
   ```bash
   keytool -genkey -v -keystore ~/hamili-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hamili
   ```
2. Configure `android/key.properties` and reference it in `android/app/build.gradle` (Flutter's official [Android deployment docs](https://docs.flutter.dev/deployment/android) cover this step by step — don't skip signing config verification before your first real release).
3. Build:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.onrender.com
   ```
4. **Never commit `key.properties` or the `.jks` file to git.** Add both to `.gitignore`.

## Environment Variable Summary

| Variable | Where | Purpose |
|---|---|---|
| `DATABASE_URL` | Backend | Postgres connection string |
| `SECRET_KEY` | Backend | JWT signing key — keep secret, rotate if leaked |
| `GEMINI_API_KEY` | Backend | Google AI Studio key for Hami |
| `CORS_ORIGINS` | Backend | Comma-separated list of allowed frontend origins |
| `API_BASE_URL` | Frontend (`--dart-define`) | Points the Flutter app at the deployed backend |

## Post-Deploy Checklist

- [ ] `GET /health` returns `200`
- [ ] Register + login flow works end-to-end from the deployed frontend
- [ ] CORS origins include the exact deployed frontend URL (protocol + domain, no trailing slash)
- [ ] Gemini API key has quota remaining (check [AI Studio](https://aistudio.google.com/))
- [ ] `.env`, `key.properties`, and `*.jks` are all git-ignored
