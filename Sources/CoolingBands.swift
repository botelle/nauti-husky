import SwiftUI

// Tweak these to match how your dogs handle heat.
enum DogTemp {
    static let coolMaxF: Double = 70            // < this  -> "Great heat sink"
    static let warmMaxF: Double = 75            // < this  -> "OK, manage shade"
                                                // >= warmMaxF -> "Limited cooling"
    static let autoRefreshSeconds: TimeInterval = 600   // 10 min

    struct Band {
        let label: String
        let shortLabel: String
        let color: Color
    }

    static func band(for waterF: Double) -> Band {
        switch waterF {
        case ..<coolMaxF:
            return Band(label: "Great heat sink",
                        shortLabel: "Great heat sink",
                        color: .teal)
        case coolMaxF..<warmMaxF:
            return Band(label: "OK, manage shade",
                        shortLabel: "Manage shade",
                        color: .orange)
        default:
            return Band(label: "Limited cooling — keep it short",
                        shortLabel: "Keep it short",
                        color: .red)
        }
    }
}
