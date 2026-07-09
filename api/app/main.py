from __future__ import annotations

from fastapi import FastAPI, Query

from .conditions import fetch_conditions
from .scoring import best_hours, score_day

app = FastAPI(title="nautihusky", version="0.1.0")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "nautihusky"}


@app.get("/api/v1/conditions")
async def conditions(lat: float = Query(...), lon: float = Query(...)):
    """Merged swim conditions for a point: water temp, waves, tide, weather,
    alerts, lightning risk. Aggregated server-side so the app makes one call —
    and so we can cache and hide any future paid key (e.g. lightning strikes).
    """
    return await fetch_conditions(lat, lon)


@app.get("/api/v1/best-time")
async def best_time(
    lat: float = Query(...),
    lon: float = Query(...),
    prefer_high_tide: bool = True,
):
    """Rank the coming daylight hours 0-100 for swimming (the SwiftUI SwimScorer,
    moved server-side) and return the best window(s)."""
    cond = await fetch_conditions(lat, lon)
    hours = score_day(cond, prefer_high_tide=prefer_high_tide)
    return {"best": best_hours(hours), "hours": hours}


@app.get("/api/v1/spots")
async def spots(
    lat: float = Query(...),
    lon: float = Query(...),
    radius_mi: float = 30.0,
):
    """Nearby swim spots: NOAA tide/temp stations + OSM beaches/lakes.
    TODO: wire Overpass + the CO-OPS station list (WaterCatalog in the app)."""
    return {"spots": [], "note": "stub — see conditions.py providers seam"}
