# API Documentation

Base URL (dev): `http://localhost:8000`
Interactive docs: `/docs` (Swagger) and `/redoc`

All protected endpoints require an `Authorization: Bearer <access_token>` header, obtained from `/auth/login`.

## Auth

### `POST /auth/register`
Create a new account.

**Body:**
```json
{ "email": "juan@example.com", "password": "SecurePass123", "preferred_name": "Juan" }
```
**Response `201`:** `UserOut` object.

### `POST /auth/login`
**Body:** `{ "email": "...", "password": "..." }`
**Response `200`:**
```json
{ "access_token": "...", "refresh_token": "...", "token_type": "bearer" }
```

### `GET /auth/me` 🔒
Returns the current authenticated user's profile.

## Transactions

### `GET /transactions` 🔒
Query params: `category_id` (optional), `search` (optional, matches note text).

### `POST /transactions` 🔒
```json
{ "category_id": 1, "amount": 250.00, "type": "expense", "note": "Lunch", "transaction_date": "2026-07-10" }
```

### `PATCH /transactions/{id}` 🔒
Partial update — send only the fields you want to change.

### `DELETE /transactions/{id}` 🔒
Returns `204 No Content`.

## Chat (Hami)

### `GET /chat/history` 🔒
Returns the full chat history for the current user, oldest first.

### `POST /chat/message` 🔒
```json
{ "content": "Where am I overspending?" }
```
**Response:** `{ "reply": "..." }`

Internally: the message is persisted, a financial snapshot is built from the user's recent transactions/budgets/goals/recurring items, and both are sent to the configured `AIProvider` (Gemini by default). The reply is persisted as well, so history is always complete on reload.

## Budgets

### `GET /budgets` 🔒
Query params: `month`, `year` (both optional, default to current month/year).
Returns each budget with **live-computed** `spent_amount`, `remaining_amount`, and `percentage_used` — these aren't stored, they're calculated from actual expense transactions in that category/month/year on every request.

### `POST /budgets` 🔒
Upsert — setting a budget for a category/month/year that already has one updates it instead of erroring.
```json
{ "category_id": 1, "month": 7, "year": 2026, "limit_amount": 3000.00 }
```

### `PATCH /budgets/{id}` 🔒
```json
{ "limit_amount": 3500.00 }
```

### `DELETE /budgets/{id}` 🔒

## Savings Goals

### `GET /goals` 🔒
Returns each goal with computed `remaining_amount`, `progress_percentage`, and `estimated_completion_date` (a naive linear projection from average contribution rate — `null` if there's no progress yet).

### `POST /goals` 🔒
```json
{ "title": "Emergency Fund", "target_amount": 20000.00, "target_date": "2026-12-31" }
```

### `PATCH /goals/{id}` 🔒
Partial update — title, target_amount, target_date.

### `POST /goals/{id}/contribute` 🔒
```json
{ "amount": 500.00 }
```
Adds to `current_amount`. If this contribution reaches the target, `status` flips to `"completed"` in the response — the frontend uses this to trigger the completion celebration.

### `DELETE /goals/{id}` 🔒

## Planned Endpoints (Milestones 4–5)

| Endpoint | Milestone |
|---|---|
| `GET/POST/PATCH/DELETE /recurring` | 4 |
| `GET /analytics/summary`, `/trends`, `/category-breakdown` | 5 |
| `GET /insights` (proactive insights feed) | 6 |

## Error Format

FastAPI's default error shape:
```json
{ "detail": "Human-readable message" }
```
Validation errors (422) include per-field detail from Pydantic.
