import SwiftUI
import WidgetKit

@MainActor
@Observable
final class SpotsModel {
    enum Phase: Equatable {
        case idle, locating, discovering, loading, ready
        case failed(String)
    }

    var phase: Phase = .idle
    var spots: [SwimSpot] = []
    var selected: SwimSpot?
    var conditions: SpotConditions?
    var isRefreshing = false

    private let prefs: Preferences
    private let location = LocationProvider()
    private let service = ConditionsService()
    private var stationCatalog: [NOAA.CatalogStation]?
    private var lastCoordinate: Coordinate?

    init(prefs: Preferences) {
        self.prefs = prefs
        // Demo mode: fixed offline content for UI tests / screenshots.
        if DemoMode.isActive {
            let demo = DemoData.conditions
            spots = [demo.spot]
            selected = demo.spot
            conditions = demo
            phase = .ready
            return
        }
        // Restore the last result so launch shows content immediately.
        if let cache = prefs.loadCache(), !cache.spots.isEmpty {
            spots = cache.spots
            selected = cache.spots.first { $0.id == cache.selectedID } ?? cache.spots.first
            conditions = cache.conditions
            lastCoordinate = cache.coordinate
            phase = .ready
        }
    }

    func refresh() async {
        // Demo mode keeps its fixed data; no location or network.
        if DemoMode.isActive { return }
        let hasContent = !spots.isEmpty
        isRefreshing = true
        defer { isRefreshing = false }
        if !hasContent { phase = .locating }

        let here: Coordinate
        do {
            here = try await location.currentCoordinate()
        } catch {
            // Fall back to the last known location rather than blanking out.
            if let last = lastCoordinate {
                here = last
            } else {
                phase = .failed(error.localizedDescription)
                return
            }
        }
        lastCoordinate = here

        if !hasContent { phase = .discovering }
        let found = await discoverSpots(near: here)
        guard !found.isEmpty else {
            if !hasContent {
                phase = .failed("No swim spots found within \(Int(prefs.radiusMiles)) miles.")
            }
            return   // keep showing stale content if we had any
        }
        spots = found
        // Prefer the closest pinned favorite, else the nearest station-backed
        // spot (has water temp), else nearest overall.
        let favIDs = Set(prefs.favorites.map(\.id))
        selected = found.first(where: { favIDs.contains($0.id) })
            ?? found.first(where: { $0.stationID != nil })
            ?? found.first
        await loadConditions()
    }

    func select(_ spot: SwimSpot) async {
        selected = spot
        conditions = nil          // don't show the previous spot's data
        await loadConditions()
    }

    func loadConditions() async {
        guard let spot = selected else { return }
        if conditions == nil { phase = .loading }
        conditions = await service.conditions(for: spot, radiusMiles: prefs.radiusMiles)
        phase = .ready
        saveCache()
        await refreshNotifications()
        writeWidgetSnapshot()
    }

    private func writeWidgetSnapshot() {
        guard let c = conditions else { return }
        let verdict = SwimVerdict.evaluate(c,
                                           tidePreference: prefs.tidePreference,
                                           tideWindowHours: prefs.tideWindowHours,
                                           avoidDawnDusk: prefs.avoidDawnDusk)
        let points = SwimOutlook.hours(c,
                                       tidePreference: prefs.tidePreference,
                                       tideWindowHours: prefs.tideWindowHours,
                                       avoidDawnDusk: prefs.avoidDawnDusk)
        let windowText = SwimOutlook.bestWindow(points).map {
            "\($0.start.formatted(.dateTime.hour()))–\($0.end.formatted(.dateTime.hour()))"
        }
        SwimWidgetSnapshot(spotName: c.spot.name,
                           waterF: c.water?.waterF,
                           verdictLevel: verdict.level.rawValue,
                           verdictHeadline: verdict.headline,
                           verdictSymbol: verdict.symbol,
                           bestWindow: windowText,
                           updatedAt: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Schedule (or clear) the next good-window notification from current data.
    func refreshNotifications() async {
        guard prefs.notifyOnGoodWindow, let c = conditions else {
            SwimNotifier.cancel()
            return
        }
        let points = SwimOutlook.hours(c,
                                       tidePreference: prefs.tidePreference,
                                       tideWindowHours: prefs.tideWindowHours,
                                       avoidDawnDusk: prefs.avoidDawnDusk)
        if let window = SwimOutlook.bestWindow(points) {
            await SwimNotifier.scheduleGoodWindow(spot: c.spot, start: window.start, end: window.end)
        } else {
            SwimNotifier.cancel()
        }
    }

    private func saveCache() {
        prefs.saveCache(Preferences.SpotsCache(
            spots: spots,
            selectedID: selected?.id,
            conditions: conditions,
            coordinate: lastCoordinate))
    }

    // MARK: - Discovery

    private func discoverSpots(near center: Coordinate) async -> [SwimSpot] {
        async let stationsTask = nearbyStations(center: center)
        async let osmTask: [SwimSpot] = (try? await OverpassService.spots(
            near: center, radiusMiles: prefs.radiusMiles)) ?? []

        let stations = await stationsTask
        let osm = await osmTask

        // Pull favorites in even if they're outside the current radius, with
        // distance recomputed from where we are now.
        let favIDs = Set(prefs.favorites.map(\.id))
        let favorites = prefs.favorites.map { fav in
            SwimSpot(source: fav.source,
                     name: fav.name,
                     coordinate: fav.coordinate,
                     distanceMiles: center.miles(to: fav.coordinate))
        }

        // Curated regional spots within radius (carry dog/boat/parking notes).
        let curated = KnownSpots.all.compactMap { c -> SwimSpot? in
            let d = center.miles(to: c.coordinate)
            guard d <= prefs.radiusMiles else { return nil }
            return SwimSpot(source: .curated(id: c.id),
                            name: c.name,
                            coordinate: c.coordinate,
                            distanceMiles: d)
        }

        // Dedupe by id and by name; ordering favours favorites, then curated
        // (notes), then stations (water temp), then OSM.
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var merged: [SwimSpot] = []
        for spot in favorites + curated + stations + osm {
            let nameKey = spot.name.lowercased()
            guard seenIDs.insert(spot.id).inserted, seenNames.insert(nameKey).inserted else { continue }
            merged.append(spot)
        }
        return merged.sorted { a, b in
            let af = favIDs.contains(a.id), bf = favIDs.contains(b.id)
            if af != bf { return af }          // favorites pinned to top
            return a.distanceMiles < b.distanceMiles
        }
    }

    private func nearbyStations(center: Coordinate) async -> [SwimSpot] {
        if stationCatalog == nil {
            stationCatalog = try? await NOAA.waterTempStations()
        }
        guard let catalog = stationCatalog else { return [] }
        return catalog.compactMap { st in
            let d = center.miles(to: st.coordinate)
            guard d <= prefs.radiusMiles else { return nil }
            return SwimSpot(source: .noaaStation(id: st.id),
                            name: st.name,
                            coordinate: st.coordinate,
                            distanceMiles: d)
        }
    }
}
