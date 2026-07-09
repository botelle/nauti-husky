import Foundation

/// Gathers all conditions for a single spot, letting each source fail independently.
struct ConditionsService: Sendable {
    var lightning: LightningProvider = StubLightningProvider()

    func conditions(for spot: SwimSpot, radiusMiles: Double) async -> SpotConditions {
        async let weatherTask = try? NWSWeather.snapshot(at: spot.coordinate)

        async let waterTask: Reading? = {
            guard let id = spot.stationID else { return nil }
            return try? await NOAA.reading(station: id)
        }()
        async let tideTask: TideState? = {
            guard let id = spot.stationID else { return nil }
            return try? await NOAA.tides(station: id)
        }()
        async let strikeTask = lightning.risk(at: spot.coordinate, radiusMiles: radiusMiles)

        let weather = await weatherTask
        let water = await waterTask
        let tides = await tideTask
        let strike = await strikeTask

        let resolvedLightning: LightningRisk = {
            if case .unknown = strike { return LightningHeuristic.fromWeather(weather) }
            return strike
        }()

        return SpotConditions(spot: spot,
                              water: water,
                              tides: tides,
                              weather: weather,
                              lightning: resolvedLightning)
    }
}
