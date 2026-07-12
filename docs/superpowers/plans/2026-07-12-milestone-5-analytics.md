# Milestone 5 — Analytics Endpoints & Charts Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Server-side analytics aggregates power a charted Analytics page (category donut, income-vs-expense trend, monthly summary tiles) and the dashboard's now server-computed totals.

**Architecture:** New backend `analytics` router → service → repository doing SQL `SUM ... GROUP BY`. Flutter `analytics` feature (domain/data/presentation) with fl_chart 0.68 widgets, plus a dashboard refactor to read a server summary.

**Tech Stack:** FastAPI, SQLAlchemy (`func.sum`, `extract`), pytest; Flutter, Riverpod, Dio, fl_chart 0.68.0, intl.

## Global Constraints

- No new backend dependency, no model change, no migration.
- All analytics are SQL aggregates — never fetch rows and sum in Python (except zero-filling empty trend months).
- Dashboard summary is **all-time** (`/analytics/summary` with no params); Analytics page is **month-scoped**.
- `net = income - expense`.
- fl_chart pinned to 0.68.0 API.
- Every account-scoped Flutter provider calls `ref.watch(sessionIdProvider)` first line.
- Analytics providers are invalidated by BOTH `TransactionsNotifier` and `RecurringNotifier` via a shared `invalidateAnalytics(ref)` helper.
- Backend layering router → service → repository → ORM; ownership scoping by `user_id`.

---

## Task B1: Analytics schemas + repository + service

**Files:**
- Create: `hamili-backend/app/schemas/analytics.py`
- Create: `hamili-backend/app/repositories/analytics_repository.py`
- Create: `hamili-backend/app/services/analytics_service.py`
- Test: `hamili-backend/app/tests/test_analytics.py`

**Interfaces:**
- Produces: `AnalyticsSummaryOut{income,expense,net}`, `CategoryBreakdownOut{category_id,total}`, `TrendPointOut{year,month,income,expense}`; `AnalyticsRepository` with `summary`, `by_category`, `income_expense_by_month`; `AnalyticsService` with `summary`, `by_category`, `trend`; module fn `month_window(end_year, end_month, months) -> list[tuple[int,int]]`.

- [ ] **Step 1: Write the failing unit test for `month_window`**

Create `hamili-backend/app/tests/test_analytics.py`:

```python
from app.services.analytics_service import month_window


def test_month_window_basic():
    # 6 months ending at 2026-07 -> Feb..Jul 2026, oldest first
    assert month_window(2026, 7, 6) == [
        (2026, 2), (2026, 3), (2026, 4), (2026, 5), (2026, 6), (2026, 7)
    ]


def test_month_window_crosses_year():
    assert month_window(2026, 2, 4) == [(2025, 11), (2025, 12), (2026, 1), (2026, 2)]


def test_month_window_single():
    assert month_window(2026, 7, 1) == [(2026, 7)]
```

- [ ] **Step 2: Run it — expect failure**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_analytics.py -v`
Expected: FAIL — `ImportError: cannot import name 'month_window'`

- [ ] **Step 3: Write `app/schemas/analytics.py`**

```python
from pydantic import BaseModel


class AnalyticsSummaryOut(BaseModel):
    income: float
    expense: float
    net: float


class CategoryBreakdownOut(BaseModel):
    category_id: int
    total: float


class TrendPointOut(BaseModel):
    year: int
    month: int
    income: float
    expense: float
```

- [ ] **Step 4: Write `app/repositories/analytics_repository.py`**

```python
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.transaction import Transaction


class AnalyticsRepository:
    def __init__(self, db: Session):
        self.db = db

    def _base(self, user_id: int):
        return self.db.query(Transaction).filter(Transaction.user_id == user_id)

    def totals(self, user_id: int, month: int | None, year: int | None) -> dict[str, float]:
        """Sum of income and of expense, optionally scoped to a month/year."""
        q = (
            self.db.query(
                Transaction.type,
                func.coalesce(func.sum(Transaction.amount), 0),
            )
            .filter(Transaction.user_id == user_id)
        )
        if month is not None and year is not None:
            q = q.filter(
                extract("month", Transaction.transaction_date) == month,
                extract("year", Transaction.transaction_date) == year,
            )
        rows = q.group_by(Transaction.type).all()
        out = {"income": 0.0, "expense": 0.0}
        for t_type, total in rows:
            out[t_type] = float(total or 0)
        return out

    def by_category(self, user_id: int, t_type: str, month: int, year: int) -> list[tuple[int, float]]:
        rows = (
            self.db.query(Transaction.category_id, func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.user_id == user_id,
                Transaction.type == t_type,
                extract("month", Transaction.transaction_date) == month,
                extract("year", Transaction.transaction_date) == year,
            )
            .group_by(Transaction.category_id)
            .all()
        )
        result = [(cat_id, float(total or 0)) for cat_id, total in rows]
        result.sort(key=lambda r: r[1], reverse=True)
        return result

    def income_expense_by_month(self, user_id: int, months: list[tuple[int, int]]) -> dict[tuple[int, int], dict[str, float]]:
        """Income and expense totals grouped by (year, month) over the given
        window. Returns only months that have data; the service zero-fills."""
        if not months:
            return {}
        years = {y for y, _ in months}
        rows = (
            self.db.query(
                extract("year", Transaction.transaction_date),
                extract("month", Transaction.transaction_date),
                Transaction.type,
                func.coalesce(func.sum(Transaction.amount), 0),
            )
            .filter(
                Transaction.user_id == user_id,
                extract("year", Transaction.transaction_date).in_(years),
            )
            .group_by(
                extract("year", Transaction.transaction_date),
                extract("month", Transaction.transaction_date),
                Transaction.type,
            )
            .all()
        )
        out: dict[tuple[int, int], dict[str, float]] = {}
        wanted = set(months)
        for year, month, t_type, total in rows:
            key = (int(year), int(month))
            if key not in wanted:
                continue
            out.setdefault(key, {"income": 0.0, "expense": 0.0})
            out[key][t_type] = float(total or 0)
        return out
```

- [ ] **Step 5: Write `app/services/analytics_service.py`**

```python
from datetime import date

from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.analytics_repository import AnalyticsRepository
from app.schemas.analytics import AnalyticsSummaryOut, CategoryBreakdownOut, TrendPointOut


def month_window(end_year: int, end_month: int, months: int) -> list[tuple[int, int]]:
    """The `months` (year, month) pairs ending at (end_year, end_month)
    inclusive, oldest first."""
    result: list[tuple[int, int]] = []
    y, m = end_year, end_month
    for _ in range(months):
        result.append((y, m))
        m -= 1
        if m == 0:
            m = 12
            y -= 1
    return list(reversed(result))


class AnalyticsService:
    def __init__(self, db: Session):
        self.repo = AnalyticsRepository(db)

    def summary(self, user: User, month: int | None, year: int | None) -> AnalyticsSummaryOut:
        totals = self.repo.totals(user.id, month, year)
        income, expense = totals["income"], totals["expense"]
        return AnalyticsSummaryOut(income=income, expense=expense, net=income - expense)

    def by_category(self, user: User, t_type: str, month: int | None, year: int | None) -> list[CategoryBreakdownOut]:
        today = date.today()
        month = month or today.month
        year = year or today.year
        rows = self.repo.by_category(user.id, t_type, month, year)
        return [CategoryBreakdownOut(category_id=cid, total=total) for cid, total in rows]

    def trend(self, user: User, month: int | None, year: int | None, months: int) -> list[TrendPointOut]:
        today = date.today()
        end_month = month or today.month
        end_year = year or today.year
        window = month_window(end_year, end_month, months)
        by_month = self.repo.income_expense_by_month(user.id, window)
        points: list[TrendPointOut] = []
        for y, m in window:
            data = by_month.get((y, m), {"income": 0.0, "expense": 0.0})
            points.append(TrendPointOut(year=y, month=m, income=data["income"], expense=data["expense"]))
        return points
```

- [ ] **Step 6: Run the unit tests — expect pass**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_analytics.py -v`
Expected: PASS (3 passed)

- [ ] **Step 7: Commit**

```bash
git add hamili-backend/app/schemas/analytics.py hamili-backend/app/repositories/analytics_repository.py hamili-backend/app/services/analytics_service.py hamili-backend/app/tests/test_analytics.py
git commit -m "feat(analytics): schemas, aggregate repository, service + month_window tests"
```

---

## Task B2: Analytics router + wiring + integration test

**Files:**
- Create: `hamili-backend/app/routers/analytics.py`
- Modify: `hamili-backend/app/main.py`
- Test: append to `hamili-backend/app/tests/test_analytics.py`

**Interfaces:**
- Produces: `GET /analytics/summary`, `GET /analytics/by-category`, `GET /analytics/trend`.

- [ ] **Step 1: Write `app/routers/analytics.py`**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.analytics import AnalyticsSummaryOut, CategoryBreakdownOut, TrendPointOut
from app.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/summary", response_model=AnalyticsSummaryOut)
def summary(
    month: int | None = None,
    year: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).summary(current_user, month, year)


@router.get("/by-category", response_model=list[CategoryBreakdownOut])
def by_category(
    type: str = "expense",
    month: int | None = None,
    year: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).by_category(current_user, type, month, year)


@router.get("/trend", response_model=list[TrendPointOut])
def trend(
    month: int | None = None,
    year: int | None = None,
    months: int = 6,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return AnalyticsService(db).trend(current_user, month, year, months)
```

- [ ] **Step 2: Register in `app/main.py`**

Import line:
```python
from app.routers import analytics, auth, budgets, categories, chat, goals, recurring, transactions
```
After `app.include_router(recurring.router)`:
```python
app.include_router(analytics.router)
```

- [ ] **Step 3: Append integration test to `app/tests/test_analytics.py`**

```python
from datetime import date

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers() -> dict:
    email = "analytics_test@example.com"
    password = "SecurePass123"
    client.post("/auth/register", json={"email": email, "password": password, "preferred_name": "Ana Test"})
    token = client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_analytics_endpoints():
    headers = _auth_headers()
    cats = client.get("/categories", headers=headers).json()
    expense_cat = next(c for c in cats if c["type"] == "expense")
    income_cat = next(c for c in cats if c["type"] == "income")
    today = date.today()

    client.post("/transactions", headers=headers, json={
        "category_id": expense_cat["id"], "amount": 200.0, "type": "expense",
        "note": "a5-test", "transaction_date": today.isoformat()})
    client.post("/transactions", headers=headers, json={
        "category_id": income_cat["id"], "amount": 1000.0, "type": "income",
        "note": "a5-test", "transaction_date": today.isoformat()})

    # Monthly summary: net = income - expense for this month.
    summ = client.get(f"/analytics/summary?month={today.month}&year={today.year}", headers=headers).json()
    assert summ["income"] >= 1000.0
    assert summ["expense"] >= 200.0
    assert abs(summ["net"] - (summ["income"] - summ["expense"])) < 0.001

    # by-category returns the expense category with a positive total, sorted desc.
    cat_rows = client.get(f"/analytics/by-category?month={today.month}&year={today.year}", headers=headers).json()
    assert any(r["category_id"] == expense_cat["id"] and r["total"] >= 200.0 for r in cat_rows)
    totals = [r["total"] for r in cat_rows]
    assert totals == sorted(totals, reverse=True)

    # trend returns exactly 6 points ending at the current month.
    trend = client.get("/analytics/trend?months=6", headers=headers).json()
    assert len(trend) == 6
    assert trend[-1]["month"] == today.month and trend[-1]["year"] == today.year
```

- [ ] **Step 4: Run full analytics suite**

Run: `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/test_analytics.py -v`
Expected: PASS (4 passed). Requires live DATABASE_URL (same as other tests).

- [ ] **Step 5: Commit**

```bash
git add hamili-backend/app/routers/analytics.py hamili-backend/app/main.py hamili-backend/app/tests/test_analytics.py
git commit -m "feat(analytics): router, registration, integration test"
```

---

## Task F1: Flutter analytics domain models

**Files:**
- Create: `hamili-app/lib/features/analytics/domain/analytics_models.dart`

- [ ] **Step 1: Write the models**

```dart
class AnalyticsSummary {
  final double income;
  final double expense;
  final double net;

  const AnalyticsSummary({required this.income, required this.expense, required this.net});

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => AnalyticsSummary(
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        net: (json['net'] as num).toDouble(),
      );
}

class CategoryBreakdown {
  final int categoryId;
  final double total;

  const CategoryBreakdown({required this.categoryId, required this.total});

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) => CategoryBreakdown(
        categoryId: json['category_id'] as int,
        total: (json['total'] as num).toDouble(),
      );
}

class TrendPoint {
  final int year;
  final int month;
  final double income;
  final double expense;

  const TrendPoint({required this.year, required this.month, required this.income, required this.expense});

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        year: json['year'] as int,
        month: json['month'] as int,
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
      );
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/analytics/domain/analytics_models.dart
git commit -m "feat(analytics): Flutter domain models"
```

---

## Task F2: Flutter analytics repository

**Files:**
- Create: `hamili-app/lib/features/analytics/data/analytics_repository.dart`

- [ ] **Step 1: Write the repository**

```dart
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

/// Analytics are online, server-computed views — no Hive cache (unlike
/// transactions). A failed fetch surfaces as an error to the UI.
class AnalyticsRepository {
  AnalyticsRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<AnalyticsSummary> summary({int? month, int? year}) async {
    final response = await _dio.get('/analytics/summary', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return AnalyticsSummary.fromJson(response.data);
  }

  Future<List<CategoryBreakdown>> byCategory({required int month, required int year, String type = 'expense'}) async {
    final response = await _dio.get('/analytics/by-category', queryParameters: {
      'type': type,
      'month': month,
      'year': year,
    });
    return (response.data as List).map((j) => CategoryBreakdown.fromJson(j)).toList();
  }

  Future<List<TrendPoint>> trend({required int month, required int year, int months = 6}) async {
    final response = await _dio.get('/analytics/trend', queryParameters: {
      'month': month,
      'year': year,
      'months': months,
    });
    return (response.data as List).map((j) => TrendPoint.fromJson(j)).toList();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/analytics/data/analytics_repository.dart
git commit -m "feat(analytics): Flutter repository"
```

---

## Task F3: Analytics providers + cross-invalidation

**Files:**
- Create: `hamili-app/lib/features/analytics/presentation/analytics_providers.dart`
- Modify: `hamili-app/lib/features/transactions/presentation/transaction_providers.dart`
- Modify: `hamili-app/lib/features/recurring/presentation/recurring_providers.dart`

**Interfaces:**
- Produces: `analyticsRepositoryProvider`, `analyticsPeriodProvider` (StateProvider<AnalyticsPeriod>), `dashboardSummaryProvider` (all-time), `monthlySummaryProvider`, `categoryBreakdownProvider`, `trendProvider`, and `void invalidateAnalytics(Ref ref)`.

- [ ] **Step 1: Write `analytics_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => AnalyticsRepository());

class AnalyticsPeriod {
  final int month;
  final int year;
  const AnalyticsPeriod({required this.month, required this.year});

  AnalyticsPeriod copyWith({int? month, int? year}) =>
      AnalyticsPeriod(month: month ?? this.month, year: year ?? this.year);
}

/// Month the Analytics page is viewing (default: current month). The
/// dashboard summary ignores this and is always all-time.
final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>((ref) {
  final now = DateTime.now();
  return AnalyticsPeriod(month: now.month, year: now.year);
});

/// All-time summary for the dashboard's balance/income/expense.
final dashboardSummaryProvider = FutureProvider<AnalyticsSummary>((ref) {
  ref.watch(sessionIdProvider);
  return ref.read(analyticsRepositoryProvider).summary();
});

final monthlySummaryProvider = FutureProvider<AnalyticsSummary>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).summary(month: p.month, year: p.year);
});

final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdown>>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).byCategory(month: p.month, year: p.year);
});

final trendProvider = FutureProvider<List<TrendPoint>>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).trend(month: p.month, year: p.year);
});

/// Called by any notifier that changes transactions (directly or via
/// recurring promotion) so the dashboard totals and every chart refetch.
void invalidateAnalytics(Ref ref) {
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(categoryBreakdownProvider);
  ref.invalidate(trendProvider);
}
```

- [ ] **Step 2: Wire into `transaction_providers.dart`**

Add import:
```dart
import '../../analytics/presentation/analytics_providers.dart';
```
In `TransactionsNotifier`, after each `ref.invalidate(budgetsProvider);` (there are three — in add/edit/delete), add:
```dart
    invalidateAnalytics(ref);
```

- [ ] **Step 3: Wire into `recurring_providers.dart`**

Add import:
```dart
import '../../analytics/presentation/analytics_providers.dart';
```
In the `_invalidateDerived()` helper, add after the budgets invalidate:
```dart
  void _invalidateDerived() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(budgetsProvider);
    invalidateAnalytics(ref);
  }
```

- [ ] **Step 4: Analyze**

Run: `cd hamili-app && flutter analyze lib/features/analytics lib/features/transactions lib/features/recurring`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add hamili-app/lib/features/analytics/presentation/analytics_providers.dart hamili-app/lib/features/transactions/presentation/transaction_providers.dart hamili-app/lib/features/recurring/presentation/recurring_providers.dart
git commit -m "feat(analytics): providers + cross-invalidation from transactions & recurring"
```

---

## Task F4: Category donut widget

**Files:**
- Create: `hamili-app/lib/features/analytics/presentation/widgets/category_donut.dart`

- [ ] **Step 1: Write the donut**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/category.dart';
import '../../domain/analytics_models.dart';

/// Donut of spending-by-category plus a ranked legend. Colors come from a
/// fixed palette assigned by rank, so the biggest slice is always the same
/// hue regardless of category.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.breakdown, required this.categories});

  final List<CategoryBreakdown> breakdown;
  final List<AppCategory> categories;

  static const List<Color> _palette = [
    Color(0xFFF5A623), Color(0xFF2ECC71), Color(0xFFE74C3C), Color(0xFF3498DB),
    Color(0xFF9B59B6), Color(0xFF1ABC9C), Color(0xFFE67E22), Color(0xFF34495E),
  ];

  String _nameFor(int categoryId) {
    final matches = categories.where((c) => c.id == categoryId);
    return matches.isNotEmpty ? matches.first.name : 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No spending this month yet.')),
      );
    }

    final total = breakdown.fold(0.0, (sum, b) => sum + b.total);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              sections: [
                for (var i = 0; i < breakdown.length; i++)
                  PieChartSectionData(
                    value: breakdown[i].total,
                    color: _palette[i % _palette.length],
                    title: '',
                    radius: 44,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < breakdown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(
                  color: _palette[i % _palette.length], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(_nameFor(breakdown[i].categoryId))),
                Text(CurrencyFormatter.format(breakdown[i].total)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    total > 0 ? '${(breakdown[i].total / total * 100).round()}%' : '0%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/analytics/presentation/widgets/category_donut.dart
git commit -m "feat(analytics): category donut chart widget"
```

---

## Task F5: Trend bar chart widget

**Files:**
- Create: `hamili-app/lib/features/analytics/presentation/widgets/trend_bar_chart.dart`

- [ ] **Step 1: Write the bar chart**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_models.dart';

/// Income vs expense per month over the trend window. Two rods per group.
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Not enough data yet.')),
      );
    }

    final maxVal = points
        .expand((p) => [p.income, p.expense])
        .fold(0.0, (m, v) => v > m ? v : m);
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(enabled: true),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final label = DateFormat.MMM().format(DateTime(points[i].year, points[i].month));
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(fontSize: 11)));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: points[i].income, color: AppColors.income, width: 7, borderRadius: BorderRadius.circular(2)),
                BarChartRodData(toY: points[i].expense, color: AppColors.expense, width: 7, borderRadius: BorderRadius.circular(2)),
              ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hamili-app/lib/features/analytics/presentation/widgets/trend_bar_chart.dart
git commit -m "feat(analytics): income-vs-expense trend bar chart widget"
```

---

## Task F6: Analytics page (replace placeholder)

**Files:**
- Modify (overwrite): `hamili-app/lib/features/analytics/presentation/analytics_page.dart`

- [ ] **Step 1: Overwrite the page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'analytics_providers.dart';
import 'widgets/category_donut.dart';
import 'widgets/trend_bar_chart.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  void _shiftMonth(WidgetRef ref, int delta) {
    final p = ref.read(analyticsPeriodProvider);
    var m = p.month + delta;
    var y = p.year;
    if (m < 1) { m = 12; y -= 1; }
    if (m > 12) { m = 1; y += 1; }
    ref.read(analyticsPeriodProvider.notifier).state = p.copyWith(month: m, year: y);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final trendAsync = ref.watch(trendProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final monthLabel = DateFormat.yMMMM().format(DateTime(period.year, period.month));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateAnalytics(ref);
          await ref.read(monthlySummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _shiftMonth(ref, -1), icon: const Icon(Icons.chevron_left)),
                Text(monthLabel, style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => _shiftMonth(ref, 1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            // Summary tiles
            summaryAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, __) => const Text("Couldn't load summary."),
              data: (s) => Row(
                children: [
                  _tile(context, 'Income', s.income, AppColors.income),
                  const SizedBox(width: 8),
                  _tile(context, 'Expenses', s.expense, AppColors.expense),
                  const SizedBox(width: 8),
                  _tile(context, 'Net', s.net, s.net >= 0 ? AppColors.income : AppColors.expense),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            breakdownAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (_, __) => const Text("Couldn't load category breakdown."),
              data: (breakdown) => CategoryDonut(breakdown: breakdown, categories: categories),
            ),
            const SizedBox(height: 24),
            Text('Income vs Expenses', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            trendAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (_, __) => const Text("Couldn't load trend."),
              data: (points) => TrendBarChart(points: points),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd hamili-app && flutter analyze lib/features/analytics`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add hamili-app/lib/features/analytics/presentation/analytics_page.dart
git commit -m "feat(analytics): charted Analytics page with month selector"
```

---

## Task F7: Dashboard uses server summary

**Files:**
- Modify: `hamili-app/lib/features/dashboard/presentation/dashboard_page.dart`

- [ ] **Step 1: Switch dashboard totals to `dashboardSummaryProvider`**

Add import:
```dart
import '../../analytics/presentation/analytics_providers.dart';
```
Replace the client-side computation. The `transactionsAsync.when` data builder currently computes `income`, `expense`, `balance` by folding. Change so those three come from `dashboardSummaryProvider` while the recent-transactions list still comes from `transactionsAsync`. Concretely, watch the summary near the top of `build`:
```dart
    final summaryAsync = ref.watch(dashboardSummaryProvider);
```
And in the data builder, remove:
```dart
          final income = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
          final expense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
          final balance = income - expense;
          final recent = transactions.take(5).toList();
```
Replace with:
```dart
          final recent = transactions.take(5).toList();
          final summary = summaryAsync.valueOrNull;
          final income = summary?.income ?? 0;
          final expense = summary?.expense ?? 0;
          final balance = summary?.net ?? 0;
```
The balance card and both SummaryCards already read `balance`/`income`/`expense`, so they now show server figures. Also make pull-to-refresh refresh both:
```dart
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              await ref.refresh(transactionsProvider.future);
            },
```

- [ ] **Step 2: Analyze the whole app**

Run: `cd hamili-app && flutter analyze`
Expected: No new issues (pre-existing warnings in other files may remain).

- [ ] **Step 3: Commit**

```bash
git add hamili-app/lib/features/dashboard/presentation/dashboard_page.dart
git commit -m "feat(dashboard): use server-computed analytics summary for totals"
```

---

## Final verification (manual, against live infra)

- [ ] `cd hamili-backend && ./venv/Scripts/python -m pytest app/tests/ -v` → all pass.
- [ ] Start backend + app; open in Opera GX.
- [ ] Dashboard balance/income/expense match the sum of your transactions (now server-computed).
- [ ] Analytics tab: month selector changes the tiles + donut; donut slices match category spending; trend shows 6 months of bars.
- [ ] Add a transaction → dashboard totals and analytics charts update without manual refresh.
- [ ] Log out / into another account → no analytics data leaks across accounts.

## Self-Review

- **Spec coverage:** summary/by-category/trend endpoints (B1/B2), server-side aggregates (B1 repo), month_window + zero-fill (B1), dashboard all-time vs analytics monthly (F3 providers, F7), donut + trend + tiles (F4/F5/F6), cross-invalidation from both notifiers (F3), fl_chart 0.68 API (F4/F5). ✓
- **Placeholder scan:** none; full code in every step. ✓
- **Type consistency:** `AnalyticsSummary{income,expense,net}`, `CategoryBreakdown{categoryId,total}`, `TrendPoint{year,month,income,expense}` consistent across domain/providers/widgets; `invalidateAnalytics(ref)` defined F3, used F3 (both notifiers) + F6 refresh; `dashboardSummaryProvider` defined F3, used F7. ✓
