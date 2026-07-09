from __future__ import annotations

import os
import time

import httpx

_UA = os.getenv("NWS_USER_AGENT", "nautihusky (justin@botelle.net)")
_TTL = float(os.getenv("CONDITIONS_TTL", "600"))  # seconds
_cache: dict[str, tuple[float, dict]] = {}


def _cached(key: str) -> dict | None:
    hit = _cache.get(key)
    if hit and (time.monotonic() - hit[0]) < _TTL:
        return hit[1]
    return None


async def _nws_weather(lat: float, lon: float) -> dict:
    """Keyless NWS hourly forecast + active alerts. Best-effort: any failure
    degrades to empty rather than taking the whole endpoint down."""
    try:
        async with httpx.AsyncClient(timeout=15, headers={"User-Agent": _UA}) as c:
            pt = (await c.get(f"https://api.weather.gov/points/{lat},{lon}")).json()
            fc_url = pt["properties"]["forecastHourly"]
            fc = (await c.get(fc_url)).json()["properties"]["periods"][:12]
            alerts = (
                await c.get(f"https://api.weather.gov/alerts/active?point={lat},{lon}")
            ).json().get("features", [])
        return {
            "forecast": [
                {
                    "time": p["startTime"],
                    "tempF": p["temperature"],
                    "wind": p["windSpeed"],
                    "short": p["shortForecast"],
                }
                for p in fc
            ],
            "alerts": [a["properties"]["event"] for a in alerts],
        }
    except Exception as e:  # noqa: BLE001
        return {"forecast": [], "alerts": [], "error": f"nws: {e}"}


def _tstorm_risk(weather: dict) -> str:
    text = " ".join(p.get("short", "") for p in weather.get("forecast", [])).lower()
    return "elevated" if ("thunder" in text or "t-storm" in text) else "low"


async def fetch_conditions(lat: float, lon: float) -> dict:
    key = f"{lat:.3f},{lon:.3f}"
    hit = _cached(key)
    if hit is not None:
        return {**hit, "cached": True}

    weather = await _nws_weather(lat, lon)
    result = {
        "location": {"lat": lat, "lon": lon},
        # TODO seams — nearest NDBC buoy / CO-OPS station (WaterCatalog in the app):
        "water": {"tempF": None, "source": "TODO: nearest NDBC buoy / CO-OPS"},
        "waves": {"heightFt": None, "source": "TODO: NDBC realtime"},
        "tide": {"state": None, "source": "TODO: CO-OPS predictions hilo"},
        "weather": weather,
        # No free real-time strike feed exists — surface NWS thunderstorm risk;
        # swap for a paid strike API behind this same field later.
        "lightning": {"risk": _tstorm_risk(weather), "source": "NWS shortForecast"},
        "cached": False,
    }
    _cache[key] = (time.monotonic(), result)
    return result
