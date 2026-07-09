import UserNotifications

/// Schedules a single local notification at the start of the next good swim
/// window. Only ever one pending request — rescheduled whenever conditions load.
@MainActor
enum SwimNotifier {
    private static let id = "swim.good-window"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    static func scheduleGoodWindow(spot: SwimSpot, start: Date, end: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        // Only worth a heads-up if the window opens far enough ahead to matter.
        guard start > Date().addingTimeInterval(15 * 60) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good time for a swim"
        let range = "\(start.formatted(.dateTime.hour().minute()))–\(end.formatted(.dateTime.hour().minute()))"
        content.body = "\(spot.name): \(range) looks good for a dip."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
