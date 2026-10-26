"""
How full a budget is, in words the app and Hami share. The thresholds come
from settings so they can be tuned per deployment without a code change.
"""

from app.core.config import get_settings

ALERT_OK = "ok"
ALERT_APPROACHING = "approaching"
ALERT_HIGH = "high"
ALERT_OVER = "over"


def budget_alert_level(percentage_used: float) -> str:
    settings = get_settings()
    if percentage_used > 100:
        return ALERT_OVER
    if percentage_used >= settings.budget_warning_percent:
        return ALERT_HIGH
    if percentage_used >= settings.budget_concern_percent:
        return ALERT_APPROACHING
    return ALERT_OK
