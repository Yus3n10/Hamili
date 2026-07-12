# Installation Guide

## Prerequisites

- Python 3.11+
- Flutter SDK 3.22+ (`flutter --version` to check)
- PostgreSQL 14+ (locally, or a free Aiven instance — see [deployment.md](deployment.md))
- A Google Gemini API key from [Google AI Studio](https://aistudio.google.com/) (free tier)

## Backend Setup

```bash
cd hamili-backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edit .env: set DATABASE_URL, SECRET_KEY, GEMINI_API_KEY

# Run migrations
alembic upgrade head

# Seed default categories (Food, Transportation, Salary, etc.)
python -m app.db.seed

# Start the dev server
uvicorn app.main:app --reload
```

The API is now live at `http://localhost:8000`. Interactive docs (Swagger UI) at `http://localhost:8000/docs`.

### Generating a SECRET_KEY

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

## Frontend Setup

```bash
cd hamili-app
flutter pub get

# Run on web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# Run on Android emulator/device
flutter run -d <device_id> --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Note: 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
# Use your machine's LAN IP if testing on a physical device.
```

## Running Tests

**Backend:**
```bash
cd hamili-backend
pytest
```

**Frontend:**
```bash
cd hamili-app
flutter test
```

## Building an APK

```bash
cd hamili-app
flutter build apk --release --dart-define=API_BASE_URL=https://your-deployed-api.com
```

The signed APK will be at `build/app/outputs/flutter-apk/app-release.apk`. See [deployment.md](deployment.md) for signing key setup.
