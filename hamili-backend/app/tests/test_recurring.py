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
