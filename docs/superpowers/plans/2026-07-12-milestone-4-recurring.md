# Milestone 4 — Recurring Income & Expenses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users define recurring income/expenses that auto-promote into real transactions on their due dates, via lazy catch-up (no scheduler).

**Architecture:** Backend adds a `recurring` router → service → repository over the existing `RecurringItem` model, mirroring transactions/goals. Promotion is a pure `_advance` date function plus a `promote_due` catch-up loop triggered on read + a manual endpoint. Flutter adds a `recurring` feature (domain/data/presentation) mirroring the transactions feature, replacing the placeholder page.

**Tech Stack:** FastAPI, SQLAlchemy, Pydantic, pytest (backend); Flutter, Riverpod, Dio, Hive, intl (frontend).

## Global Constraints

- No Alembic migration and no change to `app/models/recurring.py` — the model already has every field.
- No new backend dependency — `_advance` is pure Python (`calendar.monthrange`, `datetime`).
- `MAX_BACKFILL_PERIODS = 60` per item per run.
- Monthly/yearly advance clamps day to month length (Jan 31 → Feb 28); drift accepted.
- Amounts are `Numeric(12,2)` in the DB; transaction `note` for a promoted row = the recurring item's `name`.
- Every account-scoped Flutter provider calls `ref.watch(sessionIdProvider)` as the first line of `build()`.
- Recurring mutations invalidate `transactionsProvider` and `budgetsProvider` (promotion creates real transactions that shift balance and live budget usage).
- Repository caches only successful list fetches and falls back to cache only when it has data (don't mask errors as empty).
- Backend layering: router → service → repository → ORM. Ownership violations return 404.

---

## Task B1: Recurring schemas + repository

**Files:**
- Create: `hamili-backend/app/schemas/recurring.py`
- Create: `hamili-backend/app/repositories/recurring_repository.py`

**Interfaces:**
- Produces: `RecurringItemCreate`, `RecurringItemUpdate`, `RecurringItemOut` (Pydantic); `RecurringRepository(db)` with `list_for_user(user_id) -> list[RecurringItem]`, `get(item_id, user_id) -> RecurringItem | None`, `create(item) -> RecurringItem`, `save(item) -> RecurringItem`, `delete(item) -> None`, `list_due(user_id, today) -> list[RecurringItem]`.

- [ ] **Step 1: Write `app/schemas/recurring.py`**

```python
from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class RecurringItemCreate(BaseModel):
    type: str = Field(pattern="^(income|expense)$")
    name: str = Field(min_length=1, max_length=100)
    amount: float = Field(gt=0)
    category_id: int
    frequency: str = Field(pattern="^(weekly|monthly|yearly)$")
    next_due_date: date  # the first date this should fire
    active: bool = True


class RecurringItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    amount: float | None = Field(default=None, gt=0)
    category_id: int | None = None
    frequency: str | None = Field(default=None, pattern="^(weekly|monthly|yearly)$")
    next_due_date: date | None = None
    active: bool | None = None


class RecurringItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    name: str
    amount: float
    category_id: int
    frequency: str
    next_due_date: date
    active: bool
```

- [ ] **Step 2: Write `app/repositories/recurring_repository.py`**

```python
from datetime import date

from sqlalchemy.orm import Session

from app.models.recurring import RecurringItem


class RecurringRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: int) -> list[RecurringItem]:
        return (
            self.db.query(RecurringItem)
            .filter(RecurringItem.user_id == user_id)
            .order_by(RecurringItem.next_due_date.asc())
            .all()
        )

    def get(self, item_id: int, user_id: int) -> RecurringItem | None:
        return (
            self.db.query(RecurringItem)
            .filter(RecurringItem.id == item_id, RecurringItem.user_id == user_id)
            .first()
        )

    def list_due(self, user_id: int, today: date) -> list[RecurringItem]:
        return (
            self.db.query(RecurringItem)
            .filter(
                RecurringItem.user_id == user_id,
                RecurringItem.active.is_(True),
                RecurringItem.next_due_date <= today,
            )
            .all()
        )

    def create(self, item: RecurringItem) -> RecurringItem:
        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)
        return item

    def save(self, item: RecurringItem) -> RecurringItem:
        self.db.commit()
        self.db.refresh(item)
        return item

    def delete(self, item: RecurringItem) -> None:
        self.db.delete(item)
        self.db.commit()
```

- [ ] **Step 3: Verify imports compile**

Run: `cd hamili-backend && ./venv/Scripts/python -c "from app.schemas.recurring import RecurringItemCreate; from app.repositories.recurring_repository import RecurringRepository; print('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add hamili-backend/app/schemas/recurring.py hamili-backend/app/repositories/recurring_repository.py
git commit -m "feat(recurring): schemas and repository"
```

---

## Task B2: Recurring service — `_advance` + `promote_due` + CRUD

**Files:**
- Create: `hamili-backend/app/services/recurring_service.py`
- Test: `hamili-backend/app/tests/test_recurring.py`

**Interfaces:**
- Consumes: `RecurringRepository`, `RecurringItemCreate/Update`, `RecurringItem`, `Transaction`, `User`.
- Produces: `RecurringService(db)` with `list(user)`, `create(user, payload)`, `update(user, item_id, payload)`, `delete(user, item_id)`, `promote_due(user, today=None) -> int`; module-level `advance_date(d, frequency) -> date` and `MAX_BACKFILL_PERIODS = 60`.

- [ ] **Step 1: Write the failing test for `advance_date`**

Create `hamili-backend/app/tests/test_recurring.py`:

```python
from datetime import date

from app.services.recurring_service import advance_date


def test_weekly_advance():
    assert advance_date(date(2026, 7, 12), "weekly") == date(2026, 7, 19)


def test_monthly_advance_simple():
    assert advance_date(date(2026, 7, 12), "monthly") == date(2026, 8, 12)


def test_monthly_advance_clamps_month_end():
    # Jan 31 -> Feb 28 (2026 is not a leap year)
    assert advance_date(date(2026, 1, 31), "monthly") == date(2026, 2, 28)


def test_monthly_advance_year_rollover():
    assert advance_date(date(2026, 12, 15), "monthly") == date(2027, 1, 15)


def test_yearly_advance_leap_day_clamps():
    # Feb 29 2028 -> Feb 28 2029
    assert advance_date(date(2028, 2, 29), "yearly") == date(2029, 2, 28)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_recurring.py -v`
Expected: FAIL — `ModuleNotFoundError` / `ImportError: cannot import name 'advance_date'`

- [ ] **Step 3: Write `app/services/recurring_service.py`**

```python
from calendar import monthrange
from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.recurring import RecurringItem
from app.models.transaction import Transaction
from app.models.user import User
from app.repositories.recurring_repository import RecurringRepository
from app.schemas.recurring import RecurringItemCreate, RecurringItemUpdate

# Guard against an item accidentally dated years in the past generating
# hundreds of rows in a single catch-up pass.
MAX_BACKFILL_PERIODS = 60


def _add_months(d: date, months: int) -> date:
    total = d.month - 1 + months
    year = d.year + total // 12
    month = total % 12 + 1
    last_day = monthrange(year, month)[1]
    return date(year, month, min(d.day, last_day))


def advance_date(d: date, frequency: str) -> date:
    """Next occurrence after `d`. Monthly/yearly clamp the day to the
    target month's length (Jan 31 -> Feb 28), which means an item that
    starts on the 29th-31st drifts to the 28th once it passes February.
    This is an accepted limitation — the model stores no anchor day."""
    if frequency == "weekly":
        return d + timedelta(days=7)
    if frequency == "monthly":
        return _add_months(d, 1)
    if frequency == "yearly":
        return _add_months(d, 12)
    raise ValueError(f"Unknown frequency: {frequency}")


class RecurringService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = RecurringRepository(db)

    def list(self, user: User) -> list[RecurringItem]:
        return self.repo.list_for_user(user.id)

    def create(self, user: User, payload: RecurringItemCreate) -> RecurringItem:
        item = RecurringItem(user_id=user.id, **payload.model_dump())
        return self.repo.create(item)

    def update(self, user: User, item_id: int, payload: RecurringItemUpdate) -> RecurringItem:
        item = self._get_owned(user, item_id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(item, field, value)
        return self.repo.save(item)

    def delete(self, user: User, item_id: int) -> None:
        item = self._get_owned(user, item_id)
        self.repo.delete(item)

    def promote_due(self, user: User, today: date | None = None) -> int:
        """Turn every past-due active item into real Transaction rows, one
        per missed period at that period's real date, advancing the item's
        next_due_date past today. Idempotent: a second call the same day is
        a no-op because next_due_date is now in the future."""
        today = today or date.today()
        promoted = 0
        for item in self.repo.list_due(user.id, today):
            count = 0
            while item.next_due_date <= today and count < MAX_BACKFILL_PERIODS:
                self.db.add(
                    Transaction(
                        user_id=user.id,
                        category_id=item.category_id,
                        amount=item.amount,
                        type=item.type,
                        note=item.name,
                        transaction_date=item.next_due_date,
                    )
                )
                item.next_due_date = advance_date(item.next_due_date, item.frequency)
                count += 1
                promoted += 1
            # If still overdue after the cap, skip ahead without creating rows.
            while item.next_due_date <= today:
                item.next_due_date = advance_date(item.next_due_date, item.frequency)
        self.db.commit()
        return promoted

    def _get_owned(self, user: User, item_id: int) -> RecurringItem:
        item = self.repo.get(item_id, user.id)
        if not item:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Recurring item not found")
        return item
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_recurring.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add hamili-backend/app/services/recurring_service.py hamili-backend/app/tests/test_recurring.py
git commit -m "feat(recurring): service with advance_date and promote_due catch-up"
```

---

## Task B3: Recurring router + wiring + integration test

**Files:**
- Create: `hamili-backend/app/routers/recurring.py`
- Modify: `hamili-backend/app/main.py` (register router)
- Modify: `hamili-backend/app/routers/transactions.py` (promote before listing)
- Test: `hamili-backend/app/tests/test_recurring.py` (append integration test)

**Interfaces:**
- Consumes: `RecurringService`, `RecurringItemCreate/Update/Out`, `get_current_user`, `get_db`.
- Produces: routes `GET/POST /recurring`, `PATCH/DELETE /recurring/{id}`, `POST /recurring/run-due`.

- [ ] **Step 1: Write `app/routers/recurring.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.recurring import RecurringItemCreate, RecurringItemOut, RecurringItemUpdate
from app.services.recurring_service import RecurringService

router = APIRouter(prefix="/recurring", tags=["recurring"])


@router.get("", response_model=list[RecurringItemOut])
def list_recurring(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = RecurringService(db)
    service.promote_due(current_user)  # catch up any due items before returning the list
    return service.list(current_user)


@router.post("", response_model=RecurringItemOut, status_code=201)
def create_recurring(
    payload: RecurringItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return RecurringService(db).create(current_user, payload)


@router.patch("/{item_id}", response_model=RecurringItemOut)
def update_recurring(
    item_id: int,
    payload: RecurringItemUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return RecurringService(db).update(current_user, item_id, payload)


@router.delete("/{item_id}", status_code=204)
def delete_recurring(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    RecurringService(db).delete(current_user, item_id)


@router.post("/run-due")
def run_due(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    promoted = RecurringService(db).promote_due(current_user)
    return {"promoted": promoted}
```

- [ ] **Step 2: Register the router in `app/main.py`**

Change the import line:
```python
from app.routers import auth, budgets, categories, chat, goals, recurring, transactions
```
Add after `app.include_router(goals.router)`:
```python
app.include_router(recurring.router)
```

- [ ] **Step 3: Trigger promotion in `app/routers/transactions.py`**

Add import:
```python
from app.services.recurring_service import RecurringService
```
In `list_transactions`, before the return, so the client-computed dashboard reflects promoted rows:
```python
def list_transactions(
    category_id: int | None = None,
    search: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Recurring items are promoted lazily; do it here so the dashboard
    # (which is computed client-side from this list) is always current.
    RecurringService(db).promote_due(current_user)
    return TransactionService(db).list(current_user, category_id, search)
```

- [ ] **Step 4: Append the integration test to `app/tests/test_recurring.py`**

```python
from datetime import date

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers() -> dict:
    email = "recurring_test@example.com"
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Rec Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_recurring_crud_and_run_due():
    headers = _auth_headers()
    categories = client.get("/categories", headers=headers).json()
    income_cat = next(c for c in categories if c["type"] == "income")

    # Create an item already due today -> run-due should promote it.
    created = client.post(
        "/recurring",
        headers=headers,
        json={
            "type": "income",
            "name": "Integration Salary",
            "amount": 1234.00,
            "category_id": income_cat["id"],
            "frequency": "monthly",
            "next_due_date": date.today().isoformat(),
        },
    )
    assert created.status_code == 201
    item_id = created.json()["id"]

    run = client.post("/recurring/run-due", headers=headers)
    assert run.status_code == 200
    assert run.json()["promoted"] >= 1

    # After promotion, next_due_date has moved into the future.
    listed = client.get("/recurring", headers=headers).json()
    promoted_item = next(i for i in listed if i["id"] == item_id)
    assert promoted_item["next_due_date"] > date.today().isoformat()

    # A matching transaction now exists.
    txns = client.get("/transactions", headers=headers).json()
    assert any(t["note"] == "Integration Salary" and t["amount"] == 1234.0 for t in txns)

    # Cleanup.
    assert client.delete(f"/recurring/{item_id}", headers=headers).status_code == 204
```

- [ ] **Step 5: Run the full recurring test module**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_recurring.py -v`
Expected: PASS (6 passed). Requires the live test DATABASE_URL configured in `.env` (same as existing tests).

- [ ] **Step 6: Commit**

```bash
git add hamili-backend/app/routers/recurring.py hamili-backend/app/main.py hamili-backend/app/routers/transactions.py hamili-backend/app/tests/test_recurring.py
git commit -m "feat(recurring): router, wiring, and integration test"
```

---

## Task F1: Flutter recurring domain model

**Files:**
- Create: `hamili-app/lib/features/recurring/domain/recurring_item.dart`

**Interfaces:**
- Produces: `RecurringItem` with fields `id, type, name, amount, categoryId, frequency, nextDueDate, active`; `fromJson`, `toJson`.

- [ ] **Step 1: Write the model**

```dart
class RecurringItem {
  final int id;
  final String type; // "income" | "expense"
  final String name;
  final double amount;
  final int categoryId;
  final String frequency; // "weekly" | "monthly" | "yearly"
  final DateTime nextDueDate;
  final bool active;

  const RecurringItem({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.nextDueDate,
    required this.active,
  });

  factory RecurringItem.fromJson(Map<String, dynamic> json) => RecurringItem(
        id: json['id'] as int,
        type: json['type'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryId: json['category_id'] as int,
        frequency: json['frequency'] as String,
        nextDueDate: DateTime.parse(json['next_due_date'] as String),
        active: json['active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'amount': amount,
        'category_id': categoryId,
        'frequency': frequency,
        'next_due_date': nextDueDate.toIso8601String().split('T').first,
        'active': active,
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/recurring/domain/recurring_item.dart
git commit -m "feat(recurring): Flutter domain model"
```

---

## Task F2: Flutter recurring repository

**Files:**
- Create: `hamili-app/lib/features/recurring/data/recurring_repository.dart`

**Interfaces:**
- Consumes: `ApiClient`, `RecurringItem`.
- Produces: `RecurringRepository` with `list()`, `create(...)`, `update(id, ...)`, `delete(id)`, `runDue() -> int`, `clearCache()`.

> **Ordering note:** the logout cache-clear edit to `auth_providers.dart` lives in Task F3, after `recurring_providers.dart` (which exposes `recurringRepositoryProvider`) exists — so every commit compiles.

- [ ] **Step 1: Write `data/recurring_repository.dart`**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../domain/recurring_item.dart';

/// Mirrors TransactionRepository: successful list fetches overwrite a
/// per-cache-key Hive box; on fetch failure we fall back to the cache
/// ONLY when it actually holds data, so a real error is never masked as
/// an empty state. Writes require the network (Milestone 7 adds a queue).
class RecurringRepository {
  RecurringRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'recurring_cache';
  static const _cacheKey = 'all';

  Future<List<RecurringItem>> list() async {
    try {
      final response = await _dio.get('/recurring');
      final items = (response.data as List).map((json) => RecurringItem.fromJson(json)).toList();
      await _cache(items);
      return items;
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<RecurringItem> create({
    required String type,
    required String name,
    required double amount,
    required int categoryId,
    required String frequency,
    required DateTime nextDueDate,
    bool active = true,
  }) async {
    final response = await _dio.post('/recurring', data: {
      'type': type,
      'name': name,
      'amount': amount,
      'category_id': categoryId,
      'frequency': frequency,
      'next_due_date': nextDueDate.toIso8601String().split('T').first,
      'active': active,
    });
    return RecurringItem.fromJson(response.data);
  }

  Future<RecurringItem> update(
    int id, {
    String? name,
    double? amount,
    int? categoryId,
    String? frequency,
    DateTime? nextDueDate,
    bool? active,
  }) async {
    final response = await _dio.patch('/recurring/$id', data: {
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (frequency != null) 'frequency': frequency,
      if (nextDueDate != null) 'next_due_date': nextDueDate.toIso8601String().split('T').first,
      if (active != null) 'active': active,
    });
    return RecurringItem.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/recurring/$id');
  }

  /// Promotes any due items server-side; returns how many transactions
  /// were created so the UI can confirm the outcome.
  Future<int> runDue() async {
    final response = await _dio.post('/recurring/run-due');
    return (response.data['promoted'] as num).toInt();
  }

  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(_cacheKey);
  }

  Future<void> _cache(List<RecurringItem> items) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_cacheKey, jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  Future<List<RecurringItem>> _readCache() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((json) => RecurringItem.fromJson(json)).toList();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/recurring/data/recurring_repository.dart
git commit -m "feat(recurring): Flutter repository"
```

---

## Task F3: Flutter recurring providers

**Files:**
- Create: `hamili-app/lib/features/recurring/presentation/recurring_providers.dart`

**Interfaces:**
- Consumes: `RecurringRepository`, `RecurringItem`, `sessionIdProvider`, `transactionsProvider`, `budgetsProvider`.
- Produces: `recurringRepositoryProvider`, `recurringProvider` (AsyncNotifierProvider), `RecurringNotifier` with `addItem`, `editItem`, `deleteItem`, `toggleActive`, `runDue() -> int`.

- [ ] **Step 1: Write `presentation/recurring_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_item.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) => RecurringRepository());

class RecurringNotifier extends AsyncNotifier<List<RecurringItem>> {
  @override
  Future<List<RecurringItem>> build() async {
    ref.watch(sessionIdProvider); // reset on login/logout (account isolation)
    return ref.read(recurringRepositoryProvider).list();
  }

  /// Promotion (and an item first due today) creates real transactions,
  /// so balance and every budget's live-computed usage go stale.
  void _invalidateDerived() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(budgetsProvider);
  }

  Future<void> addItem({
    required String type,
    required String name,
    required double amount,
    required int categoryId,
    required String frequency,
    required DateTime nextDueDate,
  }) async {
    await ref.read(recurringRepositoryProvider).create(
          type: type,
          name: name,
          amount: amount,
          categoryId: categoryId,
          frequency: frequency,
          nextDueDate: nextDueDate,
        );
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
  }

  Future<void> editItem(
    int id, {
    String? name,
    double? amount,
    int? categoryId,
    String? frequency,
    DateTime? nextDueDate,
    bool? active,
  }) async {
    await ref.read(recurringRepositoryProvider).update(
          id,
          name: name,
          amount: amount,
          categoryId: categoryId,
          frequency: frequency,
          nextDueDate: nextDueDate,
          active: active,
        );
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
  }

  Future<void> toggleActive(int id, bool active) async {
    await ref.read(recurringRepositoryProvider).update(id, active: active);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteItem(int id) async {
    await ref.read(recurringRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }

  /// Returns the number of transactions created, for the UI's snackbar.
  Future<int> runDue() async {
    final promoted = await ref.read(recurringRepositoryProvider).runDue();
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
    return promoted;
  }
}

final recurringProvider = AsyncNotifierProvider<RecurringNotifier, List<RecurringItem>>(
  RecurringNotifier.new,
);
```

- [ ] **Step 2: Wire the logout cache-clear in `auth_providers.dart`**

Add import near the other feature imports at the top of the file:
```dart
import '../../recurring/presentation/recurring_providers.dart';
```
In `logout()`, immediately after the existing `transactionRepositoryProvider` cache clear (line ~38):
```dart
    await ref.read(transactionRepositoryProvider).clearCache();
    await ref.read(recurringRepositoryProvider).clearCache();
```

- [ ] **Step 3: Analyze**

Run: `cd hamili-app && flutter analyze lib/features/recurring lib/features/auth`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add hamili-app/lib/features/recurring/presentation/recurring_providers.dart hamili-app/lib/features/auth/presentation/auth_providers.dart
git commit -m "feat(recurring): Flutter providers with cross-invalidation + logout cache clear"
```

---

## Task F4: Flutter add/edit recurring page

**Files:**
- Create: `hamili-app/lib/features/recurring/presentation/add_edit_recurring_page.dart`

**Interfaces:**
- Consumes: `recurringProvider`, `categoriesProvider`, `showCategoryPicker`, `AppCategory`, `RecurringItem`, `ThousandsSeparatorInputFormatter`, `PrimaryButton`.
- Produces: `AddEditRecurringPage({RecurringItem? item})`.

- [ ] **Step 1: Write `presentation/add_edit_recurring_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/category_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/recurring_item.dart';
import 'recurring_providers.dart';

/// One form for both add (item == null) and edit (item != null).
class AddEditRecurringPage extends ConsumerStatefulWidget {
  const AddEditRecurringPage({super.key, this.item});

  final RecurringItem? item;

  @override
  ConsumerState<AddEditRecurringPage> createState() => _AddEditRecurringPageState();
}

class _AddEditRecurringPageState extends ConsumerState<AddEditRecurringPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late String _type;
  String _frequency = 'monthly';
  AppCategory? _selectedCategory;
  DateTime _nextDue = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;
  bool _categoryPrefilled = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _type = widget.item?.type ?? 'expense';
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _amountController.text = NumberFormat('#,##0.00').format(widget.item!.amount);
      _frequency = widget.item!.frequency;
      _nextDue = widget.item!.nextDueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Editing only carries categoryId; resolve the full AppCategory once
  /// categoriesProvider loads so the field shows the real name instead of
  /// "Select a category" (the bug #12 class — edit never pre-selecting).
  void _prefillCategoryIfNeeded(List<AppCategory> categories) {
    if (_categoryPrefilled || widget.item == null || categories.isEmpty) return;
    _categoryPrefilled = true;
    final matches = categories.where((c) => c.id == widget.item!.categoryId);
    final category = matches.isNotEmpty ? matches.first : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedCategory = category);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100), // recurring dates are usually in the future
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, type: _type);
    if (picked != null) setState(() => _selectedCategory = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please choose a category');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(recurringProvider.notifier);
      final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text)!;
      if (_isEditing) {
        await notifier.editItem(
          widget.item!.id,
          name: _nameController.text.trim(),
          amount: amount,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          nextDueDate: _nextDue,
        );
      } else {
        await notifier.addItem(
          type: _type,
          name: _nameController.text.trim(),
          amount: amount,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          nextDueDate: _nextDue,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _errorMessage = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesProvider).whenData(_prefillCategoryIfNeeded);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Recurring' : 'Add Recurring')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isEditing
                      ? null // type is fixed once created (matches backend update schema)
                      : (selection) => setState(() {
                            _type = selection.first;
                            _selectedCategory = null;
                          }),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Salary, Rent, Netflix',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
                  validator: (value) {
                    final parsed = ThousandsSeparatorInputFormatter.parseAmount(value ?? '');
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCategory,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Category'),
                    child: Text(_selectedCategory?.name ?? 'Select a category'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Next due date'),
                    child: Text(DateFormat.yMMMd().format(_nextDue)),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Add Recurring',
                  onPressed: _save,
                  isLoading: _isSaving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze lib/features/recurring`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add hamili-app/lib/features/recurring/presentation/add_edit_recurring_page.dart
git commit -m "feat(recurring): add/edit form"
```

---

## Task F5: Flutter recurring list page (replace placeholder)

**Files:**
- Modify (overwrite): `hamili-app/lib/features/recurring/presentation/recurring_page.dart`

**Interfaces:**
- Consumes: `recurringProvider`, `categoriesProvider`, `RecurringItem`, `CurrencyFormatter`, `CategoryVisuals`, `AddEditRecurringPage`.

- [ ] **Step 1: Overwrite `presentation/recurring_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/category_visuals.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/recurring_item.dart';
import 'add_edit_recurring_page.dart';
import 'recurring_providers.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  Future<void> _runDue(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final promoted = await ref.read(recurringProvider.notifier).runDue();
      messenger.showSnackBar(SnackBar(
        content: Text(promoted == 0 ? 'Nothing due right now.' : 'Added $promoted transaction(s).'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't run recurring items.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'run') _runDue(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'run', child: Text('Run due now')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditRecurringPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load recurring items."),
              const SizedBox(height: 12),
              TextButton(onPressed: () => ref.invalidate(recurringProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recurring items yet. Tap + to add a salary, rent, or subscription.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final income = items.where((i) => i.type == 'income').toList();
          final expenses = items.where((i) => i.type == 'expense').toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(recurringProvider.future),
            child: ListView(
              children: [
                if (income.isNotEmpty) _sectionHeader('Income'),
                ...income.map((i) => _tile(context, ref, i, categories)),
                if (expenses.isNotEmpty) _sectionHeader('Expenses'),
                ...expenses.map((i) => _tile(context, ref, i, categories)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _tile(BuildContext context, WidgetRef ref, RecurringItem item, List<AppCategory> categories) {
    final matches = categories.where((c) => c.id == item.categoryId);
    final icon = matches.isNotEmpty ? CategoryVisuals.iconFor(matches.first.icon) : Icons.autorenew;
    final freqLabel = '${item.frequency[0].toUpperCase()}${item.frequency.substring(1)}';
    final nextLabel = DateFormat.MMMd().format(item.nextDueDate);

    return Dismissible(
      key: ValueKey('recurring_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(recurringProvider.notifier).deleteItem(item.id),
      child: ListTile(
        leading: Icon(icon),
        title: Text(item.name),
        subtitle: Text('$freqLabel · next: $nextLabel'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditRecurringPage(item: item)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurrencyFormatter.format(item.amount)),
            const SizedBox(width: 8),
            Switch(
              value: item.active,
              onChanged: (value) => ref.read(recurringProvider.notifier).toggleActive(item.id, value),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze the whole app**

Run: `cd hamili-app && flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add hamili-app/lib/features/recurring/presentation/recurring_page.dart
git commit -m "feat(recurring): list page with sections, pause, swipe-delete, run-due"
```

---

## Final verification (manual, against live infra)

- [ ] Backend: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_recurring.py -v` → all pass.
- [ ] Start backend (`uvicorn app.main:app --reload`) and app (`flutter run -d web-server --web-port=5000`), open in Opera GX.
- [ ] Add a recurring income due today → a transaction appears; dashboard balance rises.
- [ ] Add a monthly expense dated ~2 months ago → "Run due now" reports 2+ and backfilled transactions carry the real past dates.
- [ ] Toggle an item's switch off → "Run due now" does not promote it.
- [ ] Edit an item → its category is pre-selected in the form.
- [ ] Log out, log into a different account → no recurring items leak across accounts.

## Self-Review

- **Spec coverage:** promotion engine (B2), backfill + real dates (B2 `promote_due`), 60-cap (B2), monthly drift (B2 `advance_date`), plain creates (B2 `create`), read+manual triggers (B3), all backend files (B1–B3), all Flutter files (F1–F5), routing already present (verified: `more_page.dart` links `/recurring`), bugs #8/#9/#10/#12 addressed (F2/F3/F4). ✓
- **Placeholder scan:** none — every step has full code/commands. ✓
- **Type consistency:** `advance_date`/`MAX_BACKFILL_PERIODS` (B2) used only in B2/B3; `recurringRepositoryProvider` defined F3, referenced F2 (documented forward ref, resolved before F2's analyze runs in F3 order — F2 commits before F3, so run `flutter analyze` at F3 which is where auth+recurring first fully resolve); `recurringProvider`, `runDue()`, `toggleActive`, `deleteItem`, `editItem`, `addItem` consistent across F3/F4/F5. ✓
