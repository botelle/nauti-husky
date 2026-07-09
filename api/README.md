# nautihusky (API)

Backend for the **Nauti Husky** swim app (`~/dev/swim-time`). Moves the app's
client-side conditions fetching server-side so we can cache, merge feeds into one
call, and hide any future paid key (e.g. lightning strikes) behind the API.

## API

| Method | Path | Notes |
|--------|------|-------|
| GET | `/healthz` | liveness (tunnel/monitor) |
| GET | `/api/v1/conditions?lat=&lon=` | merged water/waves/tide/weather/alerts/lightning |
| GET | `/api/v1/best-time?lat=&lon=&prefer_high_tide=` | hours ranked 0-100 + best window |
| GET | `/api/v1/spots?lat=&lon=&radius_mi=` | NOAA stations + OSM beaches/lakes (stub) |

`best-time` runs a real scorer over live NWS hourly data today; water-temp,
waves, and tide are seams in `conditions.py` awaiting the NDBC/CO-OPS providers.

## Run locally

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
./run.sh                                   # uvicorn on :8002
curl -s "localhost:8002/api/v1/best-time?lat=41.17&lon=-73.18" | head
```

## Deploy

Any small always-on host works: run uvicorn bound to localhost behind your
reverse proxy or tunnel of choice, and gate it with an access token if it's
reachable from the internet (the app would inject the token as request headers).

## Seams / TODO

- `conditions.py` — add NDBC realtime buoys + CO-OPS tides.
- `spots` — Overpass query + CO-OPS station list.
- Point the app's client at the deployed API once it exists.
