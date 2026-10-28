import Foundation

/// Local dates the way the web app's JavaScript `Date` makes them, so that the Swift engine gives its
/// results: the Gregorian calendar in the device's time zone, months counted from 0, and days and months
/// past their ends carried over (`new Date(2026, 1, 30)` is 2 March).
enum LocalTime {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    struct Parts {
        let year: Int
        /// The month from 0, as JavaScript counts it.
        let month0: Int
        let day: Int
        /// 0 for Sunday … 6 for Shabbat.
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    static func parts(_ date: Date) -> Parts {
        let c = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: date)
        return Parts(year: c.year ?? 1970, month0: (c.month ?? 1) - 1, day: c.day ?? 1,
                     weekday: (c.weekday ?? 1) - 1, hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// `new Date(year, month0, day, hour, minute)`.
    static func date(_ year: Int, _ month0: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month0 + 1, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// `date.setDate(date.getDate() + days)`: the same time of day, `days` later.
    static func addingDays(_ days: Int, to date: Date) -> Date {
        shifted(date) { $0.day = ($0.day ?? 1) + days }
    }

    /// `date.setMonth(date.getMonth() + months)`.
    static func addingMonths(_ months: Int, to date: Date) -> Date {
        shifted(date) { $0.month = ($0.month ?? 1) + months }
    }

    private static func shifted(_ date: Date, _ change: (inout DateComponents) -> Void) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        change(&components)
        return calendar.date(from: components) ?? date
    }

    /// Midnight of the local day of `date`.
    static func startOfDay(_ date: Date) -> Date {
        let p = parts(date)
        return self.date(p.year, p.month0, p.day)
    }

    /// The web app's key of a local day, its month from 0: "2026-9-28" (calc.dayKeyOf).
    static func dayKey(_ date: Date) -> String {
        let p = parts(date)
        return "\(p.year)-\(p.month0)-\(p.day)"
    }
}

extension Date {
    /// Milliseconds since 1970, a whole number, as JavaScript's `getTime()`.
    var ms: Double { (timeIntervalSince1970 * 1000).rounded() }

    init(ms: Double) {
        self.init(timeIntervalSince1970: ms / 1000)
    }
}

/// JavaScript's `Math.round`: to the nearest whole number, and a half up, toward +∞.
func jsRound(_ x: Double) -> Double {
    let down = x.rounded(.down)
    return x - down >= 0.5 ? down + 1 : down
}
