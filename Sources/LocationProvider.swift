import CoreLocation

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:      return "Location access is off. Enable it in Settings to find nearby spots."
        case .unavailable: return "Couldn't determine your location."
        }
    }
}

/// One-shot async wrapper around CLLocationManager.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Coordinate, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentCoordinate() async throws -> Coordinate {
        if let c = manager.location?.coordinate, manager.location!.horizontalAccuracy >= 0 {
            return Coordinate(latitude: c.latitude, longitude: c.longitude)
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                self.finish(.failure(LocationError.denied))
                return
            default:
                break
            }
            manager.requestLocation()
        }
    }

    private func finish(_ result: Result<Coordinate, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(with: result)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                finish(.failure(LocationError.denied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coords = locations.map { Coordinate(latitude: $0.coordinate.latitude,
                                                longitude: $0.coordinate.longitude) }
        MainActor.assumeIsolated {
            guard let coord = coords.last else {
                finish(.failure(LocationError.unavailable))
                return
            }
            finish(.success(coord))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            finish(.failure(error))
        }
    }
}
