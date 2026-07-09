# Nauti Husky

A swim-conditions app for people who swim with their dogs. SwiftUI, multiplatform
(iOS 17+ / macOS 14+ / watchOS 10+, plus widgets), and deliberately **zero-backend**:
the app ships with a static catalog of public data endpoints and checks them itself.
There is no server, no API key, no account, and no bill.

## What it does

- **Swim-spot picker** — beaches and lakes near you from OpenStreetMap (Overpass),
  plus a curated list for spots OSM misses or where dog/boat/parking rules matter.
- **Conditions per spot** — water temperature and tides from NOAA CO-OPS, hourly
  forecast and active alerts from NWS, lightning risk (heuristic from forecast today;
  provider seam for a real strike feed).
- **Best-time scoring** — ranks the next hours 0–100 and picks a best window,
  computed on-device from the live feeds.
- **Dog-cooling bands** — water temp translated into "how well will this actually
  cool the dog" bands, the reason the app exists.
- **Verdict** — one glanceable call per spot ("Good to go" → "Skip it"), with the
  reasons underneath. Widgets and a watch app show the latest snapshot.

## The architecture idea

Every data source in the app is a **free, keyless, public API designed for direct
consumption**: NOAA CO-OPS, the National Weather Service, OpenStreetMap's Overpass.
So the client fetches them directly — each source fails independently
(`ConditionsService` runs them as concurrent `async let`s and degrades gracefully),
and everything is scored and rendered on-device.

What this buys: no server to run or secure, no key to hide, no quota shared between
users, location data that goes nowhere except as lat/lon query params to government
APIs, and an app that keeps working even if I stop maintaining it.

Where the line is: the pattern only works because these feeds are keyless. You can't
ship a secret inside a client binary — so the moment a paid source (real lightning
strike data) or cross-user caching becomes worth it, a backend grows back. The
[`api/`](api/) directory is exactly that seam: a small FastAPI service that can take
over feed-merging when and if it's ever needed. The app doesn't use it.

Longer write-up: [The app checks itself](https://botelle.net/the-app-checks-itself.html).

## Build & run

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml`:

```sh
brew install xcodegen
xcodegen generate
open NautiHuskyTemp.xcodeproj
```

Pick the **NautiHuskyTemp-macOS** or **-iOS** scheme and ⌘R. Tests live under
`Tests/` (shared logic) and `UITests/` (XCUITest, iOS only).

Launching with `-UITestDemo` (or `UITEST_DEMO=1`) skips location + network and
renders fixed demo content — useful for screenshots and deterministic UI tests.

## Notes

- Curated spots are seeded for coastal Connecticut (the dogs are based there).
  Adding your own region is one entry in `Sources/KnownSpots.swift`.
- Station discovery uses NOAA's metadata API, so water temp/tides work anywhere
  NOAA has instruments; NWS coverage is US-only.

## License

MIT
