from __future__ import annotations


def score_day(cond: dict, prefer_high_tide: bool = True) -> list[dict]:
    """Rank each forecast hour 0-100 for swimming.

    Mirrors the app's SwimScorer intent: reward comfortable air temp, penalize
    wind, rain, and thunder. Water-temp and tide inputs are stubbed until the
    NDBC/CO-OPS providers land in conditions.py (``prefer_high_tide`` is wired
    through but inert until tide data exists).
    """
    out: list[dict] = []
    for p in cond.get("weather", {}).get("forecast", []):
        s = 60.0
        t = p.get("tempF")
        if isinstance(t, (int, float)):
            s += max(-30.0, min(25.0, (t - 70) * 1.2))  # sweet spot ~70-90F
        short = (p.get("short") or "").lower()
        if "thunder" in short or "t-storm" in short:
            s -= 50
        if "rain" in short:
            s -= 15
        digits = "".join(ch for ch in (p.get("wind") or "") if ch.isdigit())
        if digits:
            s -= max(0, int(digits) - 10) * 1.5  # penalize wind over ~10 mph
        out.append({"time": p.get("time"), "score": round(max(0.0, min(100.0, s)))})
    return out


def best_hours(hours: list[dict], n: int = 3) -> list[dict]:
    return sorted(hours, key=lambda h: h["score"], reverse=True)[:n]
