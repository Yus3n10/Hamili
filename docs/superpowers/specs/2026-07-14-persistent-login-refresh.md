# Persistent Login (Remember Me) Design

**Goal:** Keep users signed in across app restarts so opening the app lands on the dashboard, without weakening security.

## Problem

- `main.dart` calls `clearStoredSession()` on every startup, deleting saved tokens.
- Access tokens expire after 60 minutes and there is no way to renew them: a 30-day refresh token is issued and stored but never exchanged (no refresh endpoint).

## Approach (refresh-token flow)

Stop clearing the session on startup, keep access tokens short, and renew them silently with the stored refresh token.

### Backend

- `schemas/user.py`: `TokenRefresh { refresh_token: str }`.
- `services/auth_service.py`: `refresh(refresh_token)` — decode the token, require `type == "refresh"`, confirm the user exists, return a new `TokenPair` (new access + new refresh). Raises 401 if the token is invalid, expired, or the user is gone.
- `routers/auth.py`: `POST /auth/refresh` returning `TokenPair`. No login rate limit (it is not a credential guess).

### App

- `main.dart`: remove `clearStoredSession()` so tokens persist.
- `auth_repository.dart`: `refreshSession()` — read the stored refresh token, POST `/auth/refresh`, store the new pair, return whether it worked.
- `api_client.dart`: `onError` interceptor. On a 401 for any path other than `/auth/login`, `/auth/register`, `/auth/refresh`, and only once per request, call `refreshSession()`. On success, replay the original request with the new access token and return its result. On failure, clear the session so the router sends the user to login. A single-flight lock prevents concurrent refreshes.

### Behaviour

- `CurrentUserNotifier.build()` already loads the user when a session exists; with the interceptor, an expired access token is refreshed transparently, so launch either lands on the dashboard or (if the refresh token is also expired, after ~30 days) on login.
- The existing Log Out button still clears the session on purpose.

## Out of scope

- Server-side token revocation / denylist (tokens are stateless JWTs).
- Biometric or PIN lock.
