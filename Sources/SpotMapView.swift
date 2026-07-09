#if os(iOS) || os(macOS)
import SwiftUI
import MapKit

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A map of discovered spots; tap a pin to select it and dismiss.
struct SpotMapView: View {
    @Bindable var model: SpotsModel
    var prefs: Preferences

    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                ForEach(model.spots) { spot in
                    Annotation(spot.name, coordinate: spot.coordinate.clCoordinate) {
                        Button {
                            Task { await model.select(spot) }
                            dismiss()
                        } label: {
                            pin(for: spot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Nearby spots")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func pin(for spot: SwimSpot) -> some View {
        let isSelected = model.selected == spot
        let isFav = prefs.isFavorite(spot)
        let symbol = isFav ? "star.fill" : spot.kindSymbol
        let color: Color = {
            if isFav { return .yellow }
            switch spot.source {
            case .noaaStation: return .blue
            case .curated:     return .purple
            case .osm:         return .green
            }
        }()
        return Image(systemName: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 1))
            .scaleEffect(isSelected ? 1.35 : 1.0)
            .shadow(radius: 2)
    }
}
#endif
