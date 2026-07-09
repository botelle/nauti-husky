import Foundation

/// Local sunrise/sunset from the standard sunrise equation (no network).
/// Accurate to a minute or two — plenty for flagging dawn/dusk low-light hours.
enum Solar {
    private static let zenith = 90.833   // official, accounts for refraction + sun radius

    static func isLowLight(coord: Coordinate,
                           at date: Date,
                           marginMinutes: Double = 60,
                           calendar: Calendar = .current) -> Bool {
        let margin = marginMinutes * 60
        if let sr = event(coord: coord, date: date, rising: true, calendar: calendar),
           abs(date.timeIntervalSince(sr)) <= margin { return true }
        if let ss = event(coord: coord, date: date, rising: false, calendar: calendar),
           abs(date.timeIntervalSince(ss)) <= margin { return true }
        return false
    }

    static func sunrise(coord: Coordinate, date: Date, calendar: Calendar = .current) -> Date? {
        event(coord: coord, date: date, rising: true, calendar: calendar)
    }

    static func sunset(coord: Coordinate, date: Date, calendar: Calendar = .current) -> Date? {
        event(coord: coord, date: date, rising: false, calendar: calendar)
    }

    private static func event(coord: Coordinate, date: Date, rising: Bool, calendar: Calendar) -> Date? {
        let lat = coord.latitude, lon = coord.longitude
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return nil }
        let N = Double(dayOfYear)
        let lngHour = lon / 15.0

        let t = rising ? N + ((6 - lngHour) / 24) : N + ((18 - lngHour) / 24)
        let M = (0.9856 * t) - 3.289
        var L = M + 1.916 * sin(rad(M)) + 0.020 * sin(rad(2 * M)) + 282.634
        L = norm(L, 360)

        var RA = deg(atan(0.91764 * tan(rad(L))))
        RA = norm(RA, 360)
        RA += (floor(L / 90) * 90) - (floor(RA / 90) * 90)   // same quadrant as L
        RA /= 15.0

        let sinDec = 0.39782 * sin(rad(L))
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(rad(zenith)) - sinDec * sin(rad(lat))) / (cosDec * cos(rad(lat)))
        if cosH > 1 || cosH < -1 { return nil }   // sun never rises / never sets this day

        var H = rising ? 360 - deg(acos(cosH)) : deg(acos(cosH))
        H /= 15.0
        let T = H + RA - (0.06571 * t) - 6.622
        let ut = norm(T - lngHour, 24)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let ymd = calendar.dateComponents([.year, .month, .day], from: date)
        var comps = DateComponents()
        comps.year = ymd.year; comps.month = ymd.month; comps.day = ymd.day
        comps.hour = Int(ut)
        comps.minute = Int((ut - Double(comps.hour!)) * 60)
        guard var result = utc.date(from: comps) else { return nil }

        // The UTC assembly can land a calendar day off (e.g. western-hemisphere
        // sunset falls after 00:00 UTC). Snap into the local calendar day.
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = dayStart.addingTimeInterval(86400)
        while result < dayStart { result.addTimeInterval(86400) }
        while result >= dayEnd { result.addTimeInterval(-86400) }
        return result
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func norm(_ v: Double, _ max: Double) -> Double {
        let x = v.truncatingRemainder(dividingBy: max)
        return x < 0 ? x + max : x
    }
}
