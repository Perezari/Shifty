import Foundation

/// A shift, as the web app keeps it (assets/js/store.js) and the cloud's `shifts` table holds it: hours
/// worked with their breaks, or a paid vacation or sick day, anchored at noon with its end at its start.
struct Shift: Identifiable, Hashable {
    var id: String
    var start: Date
    var end: Date?
    var breaks: [Break] = []
    /// Shabbat or a holiday: the whole shift at the holiday's multiplier.
    var isHoliday = false
    var note = ""
    var type: ShiftType = .work
    /// A deletion, kept so that the sync deletes the shift on the other devices too.
    var deleted = false
    var updatedAt: Date?
}

struct Break: Hashable {
    var start: Date
    var end: Date?
}

enum ShiftType: String {
    case work, vacation, sick
}

/// The settings, with the web app's keys and defaults (store.js DEFAULT_SETTINGS). Hours are decimal
/// (9.1 is 9:06).
struct Settings: Hashable {
    var appName = "Shifty"
    var workplaceName = "מקום העבודה שלי"
    var currency = "₪"
    /// "light" or "dark", as the web app's; here also "system", the iPhone's own appearance, by default.
    var theme = "system"

    var hourlyWage = 50.0
    /// The standard of a day without its own.
    var regularDailyHours = 9.6
    /// The standard ("תקן") hours of each weekday, Sunday to Shabbat, nil on a day off: both the
    /// threshold of the day's overtime and the day's goal on the ring.
    var standardByDay: [Double?] = [9.6, 9.6, 9.6, 9.6, 8.6, nil, nil]
    /// How long the first overtime tier lasts, and the multipliers of the two tiers.
    var overtime1Hours = 2.0
    var overtime1Mult = 1.25
    var overtime2Mult = 1.5

    var nightEnabled = false
    /// The night's window, in hours of the day (22.5 is 22:30); it may cross midnight.
    var nightStart = 22.0
    var nightEnd = 6.0
    var nightMult = 1.0

    /// The multiplier of a whole shift marked Shabbat or holiday.
    var holidayMult = 1.5

    /// Holidays found from the Hebrew calendar (Holidays), and the standard of a shortened day.
    var holidaysEnabled = true
    var holidayEveHours = 4.1

    /// The hours a paid vacation day pays, and the share of the standard a sick day pays, by its place
    /// in a run of sick days (the 1st, 2nd, 3rd, and 4th and on).
    var vacationHours = 8.6
    var sickDay1Pct = 0.0
    var sickDay2Pct = 50.0
    var sickDay3Pct = 50.0
    var sickDay4Pct = 100.0

    /// A break taken off every shift at least this long.
    var autoBreakMinutes = 0.0
    var autoBreakAfterHours = 6.0

    /// Travel paid for each day worked, up to a cap for the period (0: no cap).
    var travelPerDay = 0.0
    var travelMonthlyCap = 0.0

    /// 0: off.
    var monthlyIncomeGoal = 0.0
    /// The day the pay period starts (1 to 28).
    var monthStartDay = 1
    /// 0: Sunday.
    var weekStartsOn = 0

    /// The net pay's estimate (Net.swift): the income tax's credit points, and the share of the wage saved
    /// for the pension. The app's alone, as are the leave's.
    var creditPoints = 2.25
    var pensionPercent = 6.0
    /// The vacation and sick days left (Leave.swift): as the last payslip gives them, on its date (nil: not
    /// kept), and the vacation days a year of work adds.
    var vacationBalance = 0.0
    var sickBalance = 0.0
    var balanceDate: Date?
    var vacationDaysPerYear = 12.0

    var updatedAt: Date?

    /// The standard hours set for a weekday (0 Sunday … 6 Shabbat); nil on a day off.
    func standard(onWeekday weekday: Int) -> Double? {
        standardByDay.indices.contains(weekday) ? standardByDay[weekday] : nil
    }
}

// MARK: JSON, the web app's

/// Dates as the web app writes them: ISO 8601 in UTC, to the millisecond ("2026-10-28T07:00:00.000Z").
/// Written and read by arithmetic, not by a calendar and a formatter, which took most of a save's time;
/// another form is read by Foundation's (Tests/SyncCheck holds the two equal).
enum ISODate {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    static func parse(_ text: String) -> Date? {
        if let ms = webMs(text) { return Date(ms: Double(ms)) }
        guard let date = (try? withFraction.parse(text)) ?? (try? plain.parse(text)) else { return nil }
        return Date(ms: date.ms)
    }

    static func string(_ date: Date) -> String {
        let ms = Int(date.ms)
        let days = Int((Double(ms) / 86_400_000).rounded(.down))
        let time = ms - days * 86_400_000
        let day = civil(days)
        let clock = "\(digits(time / 3_600_000, 2)):\(digits(time / 60_000 % 60, 2)):\(digits(time / 1000 % 60, 2))"
        return "\(digits(day.year, 4))-\(digits(day.month, 2))-\(digits(day.day, 2))T\(clock).\(digits(time % 1000, 3))Z"
    }

    /// The milliseconds of exactly "2026-10-28T07:00:00.000Z", as the web app and `string` write a date; nil
    /// for any other form, and for a day or a time that does not exist.
    private static func webMs(_ text: String) -> Int? {
        var text = text
        return text.withUTF8 { b -> Int? in
            guard b.count == 24, b[4] == 0x2D, b[7] == 0x2D, b[10] == 0x54, b[13] == 0x3A, b[16] == 0x3A,
                  b[19] == 0x2E, b[23] == 0x5A else { return nil }
            func number(_ from: Int, _ count: Int) -> Int? {
                var value = 0
                for i in from..<from + count {
                    let digit = Int(b[i]) - 0x30
                    guard digit >= 0 && digit <= 9 else { return nil }
                    value = value * 10 + digit
                }
                return value
            }
            guard let year = number(0, 4), let month = number(5, 2), let day = number(8, 2),
                  let hour = number(11, 2), let minute = number(14, 2), let second = number(17, 2),
                  let milli = number(20, 3),
                  (1...12).contains(month), day >= 1, day <= monthLength(month, year),
                  hour < 24, minute < 60, second < 60 else { return nil }
            let time = hour * 3_600_000 + minute * 60_000 + second * 1000 + milli
            return days(year, month, day) * 86_400_000 + time
        }
    }

    /// `value` in `count` digits at least, zeros before it ("%02d").
    private static func digits(_ value: Int, _ count: Int) -> String {
        let text = String(value)
        return text.count < count ? String(repeating: "0", count: count - text.count) + text : text
    }

    /// The Gregorian year, month and day of a day counted from 1 January 1970 (Howard Hinnant's
    /// civil_from_days).
    private static func civil(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let m = (5 * dayOfYear + 2) / 153
        let month = m < 10 ? m + 3 : m - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, dayOfYear - (153 * m + 2) / 5 + 1)
    }

    /// Its inverse: the days from 1 January 1970 to a Gregorian date (days_from_civil).
    private static func days(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func monthLength(_ month: Int, _ year: Int) -> Int {
        switch month {
        case 2: year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func decode<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) throws -> Date {
        let text = try container.decode(String.self, forKey: key)
        guard let date = parse(text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Not an ISO 8601 date: \(text)")
        }
        return date
    }

    static func decodeIfPresent<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Date? {
        ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil).flatMap(parse)
    }
}

extension Shift: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, start, end, breaks, isHoliday, note, type, deleted, updatedAt
    }

    /// As the web app reads a shift: a missing or unknown type is work, a missing flag is false.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        start = try ISODate.decode(c, .start)
        end = ISODate.decodeIfPresent(c, .end)
        breaks = (try? c.decodeIfPresent([Break].self, forKey: .breaks)) ?? []
        isHoliday = (try? c.decodeIfPresent(Bool.self, forKey: .isHoliday)) ?? false
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        type = ((try? c.decodeIfPresent(String.self, forKey: .type)) ?? nil).flatMap(ShiftType.init(rawValue:)) ?? .work
        deleted = (try? c.decodeIfPresent(Bool.self, forKey: .deleted)) ?? false
        updatedAt = ISODate.decodeIfPresent(c, .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ISODate.string(start), forKey: .start)
        try c.encode(end.map(ISODate.string), forKey: .end)
        try c.encode(breaks, forKey: .breaks)
        try c.encode(isHoliday, forKey: .isHoliday)
        try c.encode(note, forKey: .note)
        try c.encode(type.rawValue, forKey: .type)
        if deleted { try c.encode(true, forKey: .deleted) }
        try c.encodeIfPresent(updatedAt.map(ISODate.string), forKey: .updatedAt)
    }
}

extension Break: Codable {
    private enum CodingKeys: String, CodingKey {
        case start, end
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try ISODate.decode(c, .start)
        end = ISODate.decodeIfPresent(c, .end)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ISODate.string(start), forKey: .start)
        try c.encode(end.map(ISODate.string), forKey: .end)
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case appName, workplaceName, currency, theme, hourlyWage, regularDailyHours, standardByDay,
             overtime1Hours, overtime1Mult, overtime2Mult, nightEnabled, nightStart, nightEnd, nightMult,
             holidayMult, holidaysEnabled, holidayEveHours, vacationHours,
             sickDay1Pct, sickDay2Pct, sickDay3Pct, sickDay4Pct, autoBreakMinutes, autoBreakAfterHours,
             travelPerDay, travelMonthlyCap, monthlyIncomeGoal, monthStartDay, weekStartsOn,
             creditPoints, pensionPercent, vacationBalance, sickBalance, balanceDate, vacationDaysPerYear, updatedAt
    }

    /// As the web app reads its settings (store.getSettings): a missing key, or a null, takes the default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        appName = value(.appName, d.appName)
        workplaceName = value(.workplaceName, d.workplaceName)
        currency = value(.currency, d.currency)
        theme = value(.theme, d.theme)
        hourlyWage = value(.hourlyWage, d.hourlyWage)
        regularDailyHours = value(.regularDailyHours, d.regularDailyHours)
        standardByDay = value(.standardByDay, d.standardByDay)
        if (try? c.decodeNil(forKey: .standardByDay)) == true {
            // settings from before the standard of each weekday
            let base = regularDailyHours != 0 ? regularDailyHours : 8.6
            standardByDay = [base, base, base, base, base, nil, nil]
        }
        overtime1Hours = value(.overtime1Hours, d.overtime1Hours)
        overtime1Mult = value(.overtime1Mult, d.overtime1Mult)
        overtime2Mult = value(.overtime2Mult, d.overtime2Mult)
        nightEnabled = value(.nightEnabled, d.nightEnabled)
        nightStart = value(.nightStart, d.nightStart)
        nightEnd = value(.nightEnd, d.nightEnd)
        nightMult = value(.nightMult, d.nightMult)
        holidayMult = value(.holidayMult, d.holidayMult)
        holidaysEnabled = value(.holidaysEnabled, d.holidaysEnabled)
        holidayEveHours = value(.holidayEveHours, d.holidayEveHours)
        vacationHours = value(.vacationHours, d.vacationHours)
        sickDay1Pct = value(.sickDay1Pct, d.sickDay1Pct)
        sickDay2Pct = value(.sickDay2Pct, d.sickDay2Pct)
        sickDay3Pct = value(.sickDay3Pct, d.sickDay3Pct)
        sickDay4Pct = value(.sickDay4Pct, d.sickDay4Pct)
        autoBreakMinutes = value(.autoBreakMinutes, d.autoBreakMinutes)
        autoBreakAfterHours = value(.autoBreakAfterHours, d.autoBreakAfterHours)
        travelPerDay = value(.travelPerDay, d.travelPerDay)
        travelMonthlyCap = value(.travelMonthlyCap, d.travelMonthlyCap)
        monthlyIncomeGoal = value(.monthlyIncomeGoal, d.monthlyIncomeGoal)
        monthStartDay = value(.monthStartDay, d.monthStartDay)
        weekStartsOn = value(.weekStartsOn, d.weekStartsOn)
        creditPoints = value(.creditPoints, d.creditPoints)
        pensionPercent = value(.pensionPercent, d.pensionPercent)
        vacationBalance = value(.vacationBalance, d.vacationBalance)
        sickBalance = value(.sickBalance, d.sickBalance)
        balanceDate = ISODate.decodeIfPresent(c, .balanceDate)
        vacationDaysPerYear = value(.vacationDaysPerYear, d.vacationDaysPerYear)
        updatedAt = ISODate.decodeIfPresent(c, .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(appName, forKey: .appName)
        try c.encode(workplaceName, forKey: .workplaceName)
        try c.encode(currency, forKey: .currency)
        try c.encode(theme, forKey: .theme)
        try c.encode(hourlyWage, forKey: .hourlyWage)
        try c.encode(regularDailyHours, forKey: .regularDailyHours)
        try c.encode(standardByDay, forKey: .standardByDay)
        try c.encode(overtime1Hours, forKey: .overtime1Hours)
        try c.encode(overtime1Mult, forKey: .overtime1Mult)
        try c.encode(overtime2Mult, forKey: .overtime2Mult)
        try c.encode(nightEnabled, forKey: .nightEnabled)
        try c.encode(nightStart, forKey: .nightStart)
        try c.encode(nightEnd, forKey: .nightEnd)
        try c.encode(nightMult, forKey: .nightMult)
        try c.encode(holidayMult, forKey: .holidayMult)
        try c.encode(holidaysEnabled, forKey: .holidaysEnabled)
        try c.encode(holidayEveHours, forKey: .holidayEveHours)
        try c.encode(vacationHours, forKey: .vacationHours)
        try c.encode(sickDay1Pct, forKey: .sickDay1Pct)
        try c.encode(sickDay2Pct, forKey: .sickDay2Pct)
        try c.encode(sickDay3Pct, forKey: .sickDay3Pct)
        try c.encode(sickDay4Pct, forKey: .sickDay4Pct)
        try c.encode(autoBreakMinutes, forKey: .autoBreakMinutes)
        try c.encode(autoBreakAfterHours, forKey: .autoBreakAfterHours)
        try c.encode(travelPerDay, forKey: .travelPerDay)
        try c.encode(travelMonthlyCap, forKey: .travelMonthlyCap)
        try c.encode(monthlyIncomeGoal, forKey: .monthlyIncomeGoal)
        try c.encode(monthStartDay, forKey: .monthStartDay)
        try c.encode(weekStartsOn, forKey: .weekStartsOn)
        try c.encode(creditPoints, forKey: .creditPoints)
        try c.encode(pensionPercent, forKey: .pensionPercent)
        try c.encode(vacationBalance, forKey: .vacationBalance)
        try c.encode(sickBalance, forKey: .sickBalance)
        try c.encodeIfPresent(balanceDate.map(ISODate.string), forKey: .balanceDate)
        try c.encode(vacationDaysPerYear, forKey: .vacationDaysPerYear)
        try c.encodeIfPresent(updatedAt.map(ISODate.string), forKey: .updatedAt)
    }
}
