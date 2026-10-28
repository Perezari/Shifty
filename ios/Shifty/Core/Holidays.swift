import Foundation

/// Israeli holidays from the Hebrew calendar, for any year and offline: the web app's
/// assets/js/holidays.js on Foundation's Hebrew calendar instead of Intl's.
/// - short: an eve of a holiday, or Yom HaZikaron: a shortened workday, with its own standard hours.
/// - chag: a holiday, or Yom Ha'atzmaut: marked on the calendar, with no effect on the wage.
enum Holidays {
    enum Kind: String {
        case short, chag
    }

    struct Info: Equatable {
        var kind: Kind?
        var name: String?
    }

    private static let hebrew: Calendar = {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    /// A Hebrew month and day. Foundation numbers the months Tishri 1 … Adar I 6, Adar (or Adar II) 7,
    /// Nisan 8, Iyar 9, Sivan 10 … Elul 13.
    private static func key(_ month: Int, _ day: Int) -> Int { month * 100 + day }

    /// The shortened workdays.
    private static let eves: [Int: String] = [
        key(13, 29): "ערב ראש השנה",
        key(1, 9): "ערב יום כיפור",
        key(1, 14): "ערב סוכות",
        key(1, 21): "ערב שמחת תורה",
        key(8, 14): "ערב פסח",
        key(8, 20): "ערב שביעי של פסח",
        key(10, 5): "ערב שבועות",
    ]

    /// The holidays, only marked.
    private static let holidays: [Int: String] = [
        key(1, 1): "ראש השנה", key(1, 2): "ראש השנה",
        key(1, 10): "יום כיפור",
        key(1, 15): "סוכות",
        key(1, 22): "שמחת תורה",
        key(8, 15): "פסח",
        key(8, 21): "שביעי של פסח",
        key(10, 6): "שבועות",
    ]

    static func info(_ date: Date) -> Info {
        let h = hebrew.dateComponents([.month, .day], from: date)
        let k = key(h.month ?? 0, h.day ?? 0)
        if let name = eves[k] { return Info(kind: .short, name: name) }
        if let name = holidays[k] { return Info(kind: .chag, name: name) }
        let national = nationalDays(LocalTime.parts(date).year)
        let day = LocalTime.dayKey(date)
        if day == national.memorial { return Info(kind: .short, name: "יום הזיכרון") }
        if day == national.independence { return Info(kind: .chag, name: "יום העצמאות") }
        return Info(kind: nil, name: nil)
    }

    // MARK: Yom HaZikaron and Yom Ha'atzmaut

    private static var national: [Int: (memorial: String, independence: String)] = [:]
    private static let lock = NSLock()

    /// Yom HaZikaron and Yom Ha'atzmaut of a Gregorian year, as day keys: 5 Iyar, moved so that neither
    /// adjoins Shabbat.
    private static func nationalDays(_ year: Int) -> (memorial: String, independence: String) {
        lock.lock()
        defer { lock.unlock() }
        if let days = national[year] { return days }
        var days = (memorial: "", independence: "")
        if let iyar5 = iyar5(year) {
            var independence = iyar5
            switch LocalTime.parts(iyar5).weekday {
            case 1: independence = LocalTime.addingDays(1, to: iyar5) // Monday: Tuesday, postponed
            case 5: independence = LocalTime.addingDays(-1, to: iyar5) // Friday: Thursday
            case 6: independence = LocalTime.addingDays(-2, to: iyar5) // Shabbat: Thursday
            case 0: independence = LocalTime.addingDays(1, to: iyar5) // Sunday: Monday (a guard)
            default: break
            }
            let memorial = LocalTime.addingDays(-1, to: independence)
            days = (LocalTime.dayKey(memorial), LocalTime.dayKey(independence))
        }
        national[year] = days
        return days
    }

    /// 5 Iyar of a Gregorian year, between April and June.
    private static func iyar5(_ year: Int) -> Date? {
        for month0 in 3...5 {
            for day in 1...31 {
                let date = LocalTime.date(year, month0, day)
                if LocalTime.parts(date).month0 != month0 { break }
                let h = hebrew.dateComponents([.month, .day], from: date)
                if h.month == 9 && h.day == 5 { return date }
            }
        }
        return nil
    }
}
