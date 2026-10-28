import Foundation

/// A span of time: from `start`, up to but not including `end`.
struct TimeRange: Hashable {
    var start: Date
    var end: Date
}

/// A shift's hours and pay (calc.js shiftBreakdown). Times are in milliseconds, as JavaScript counts them.
struct Breakdown {
    var id: String
    var type: ShiftType
    var startMs: Double
    var endMs: Double
    var ongoing: Bool
    var grossMs: Double
    var breakMs: Double
    var netMs: Double
    var netHours: Double
    var regularHours: Double
    var ot1Hours: Double
    var ot2Hours: Double
    var overtimeHours: Double
    var nightHours: Double
    var isHoliday: Bool
    var basePay: Double
    var otPay: Double
    var nightPremium: Double
    /// The shift's wage, without travel.
    var pay: Double
    /// A sick day's place in its run of sick days (1 to 4, the 4th and on), and the share of the
    /// day's standard it pays.
    var sickTier: Int? = nil
    var sickPct: Double? = nil
}

/// The hours and wages of a range of shifts (calc.js aggregate).
struct Totals {
    /// The work shifts: vacation and sick days are paid, but not hours or days worked.
    var count: Int
    var netHours: Double
    var overtimeHours: Double
    var nightHours: Double
    var holidayHours: Double
    /// The wages, without travel.
    var pay: Double
    var travel: Double
    /// The income: the wages and the travel.
    var total: Double
    var workedDays: Int
    var avgShiftHours: Double
}

/// The hours missing ("שעות חוסר"): each day's net hours against the standard it is expected to meet.
struct Shortfall {
    /// By day key (LocalTime.dayKey), the days that fell short.
    var byDay: [String: Double]
    var total: Double
}

/// The hours of a shift and the wage they earn, Israeli-style: the day's standard hours, then two
/// overtime tiers (125% for the first two hours, 150% after), Shabbat and holidays at their multiplier,
/// night hours, travel, and paid vacation and sick days. A line-by-line port of the web app's
/// assets/js/calc.js, proven equal to it by ios/Tests.
enum Calc {
    static let hour = 3_600_000.0

    /// The standard ("תקן") hours of the day of `date`: a shortened day's, else its weekday's, else
    /// regularDailyHours. Also the day's goal on the ring.
    static func standardHours(_ date: Date, _ s: Settings) -> Double {
        // a holiday (chag) itself counts as a regular day here, by the user's choice
        if s.holidaysEnabled && s.holidayEveHours > 0 && Holidays.info(date).kind == .short {
            return s.holidayEveHours
        }
        if let v = s.standard(onWeekday: LocalTime.parts(date).weekday), v > 0 { return v }
        return s.regularDailyHours != 0 ? s.regularDailyHours : 8.6
    }

    /// The standard a day is expected to meet for the hours missing: its weekday's or a shortened day's;
    /// nil on a day off, where working less is no shortfall (app.js expectedStandard).
    static func expectedStandard(_ date: Date, _ s: Settings) -> Double? {
        if s.holidaysEnabled && s.holidayEveHours > 0 && Holidays.info(date).kind == .short {
            return s.holidayEveHours
        }
        if let v = s.standard(onWeekday: LocalTime.parts(date).weekday), v > 0 { return v }
        return nil
    }

    /// The breaks of a shift, an open one up to `asOf`.
    static func breaksMs(_ shift: Shift, asOf: Double) -> Double {
        var ms = 0.0
        for b in shift.breaks {
            let bs = b.start.ms
            let be = b.end?.ms ?? asOf
            if be > bs { ms += be - bs }
        }
        return ms
    }

    /// The overlap of `startMs ..< endMs` with the night's window of each day around it. The window's
    /// edges are hours of the day (22.5 is 22:30), and it may cross midnight (22 to 6).
    static func nightMs(_ startMs: Double, _ endMs: Double, _ nightStart: Double, _ nightEnd: Double) -> Double {
        if endMs <= startMs { return 0 }
        func edge(_ day: Date, _ hours: Double) -> Date {
            let p = LocalTime.parts(day)
            let h = hours.rounded(.down)
            return LocalTime.date(p.year, p.month0, p.day, Int(h), Int(jsRound((hours - h) * 60)))
        }
        var total = 0.0
        let dayStart = LocalTime.startOfDay(Date(ms: startMs))
        for offset in -1...2 {
            let base = LocalTime.addingDays(offset, to: dayStart)
            let windowStart = edge(base, nightStart)
            var windowEnd = edge(base, nightEnd)
            if nightEnd <= nightStart { windowEnd = LocalTime.addingDays(1, to: windowEnd) }
            let a = max(startMs, windowStart.ms)
            let b = min(endMs, windowEnd.ms)
            if b > a { total += b - a }
        }
        return total
    }

    /// The days with a sick day, by day key.
    static func sickDates(of shifts: [Shift]) -> Set<String> {
        var dates = Set<String>()
        for shift in shifts where shift.type == .sick && !shift.deleted {
            dates.insert(LocalTime.dayKey(shift.start))
        }
        return dates
    }

    static func sickPct(_ s: Settings, tier: Int) -> Double {
        switch min(max(tier, 1), 4) {
        case 1: s.sickDay1Pct
        case 2: s.sickDay2Pct
        case 3: s.sickDay3Pct
        default: s.sickDay4Pct
        }
    }

    /// The sick days in a row ending on the day of `dateMs`, up to 4 ("the 4th and on"). A day off (one
    /// with no standard) neither counts nor breaks the run; any other day without a sick day breaks it.
    static func sickTier(_ dateMs: Double, _ sickDates: Set<String>, _ s: Settings) -> Int {
        var n = 1
        var day = LocalTime.startOfDay(Date(ms: dateMs))
        var i = 0
        while i < 120 && n < 4 {
            i += 1
            day = LocalTime.addingDays(-1, to: day)
            if sickDates.contains(LocalTime.dayKey(day)) {
                n += 1
                continue
            }
            if let standard = s.standard(onWeekday: LocalTime.parts(day).weekday), standard > 0 { break }
        }
        return n
    }

    /// A shift's hours and pay, an ongoing shift up to `asOf`. `sickDates` (sickDates(of:) of all the
    /// shifts) gives a sick day its place in its run; without it, every sick day is the first.
    static func breakdown(_ shift: Shift, _ s: Settings, asOf: Double? = nil, sickDates: Set<String>? = nil) -> Breakdown {
        let wage = s.hourlyWage
        let startMs = shift.start.ms

        // a paid day off: a flat amount, no overtime, night or break
        if shift.type == .vacation || shift.type == .sick {
            var hours = s.vacationHours
            var tier: Int? = nil
            var pct: Double? = nil
            if shift.type == .sick {
                let t = sickDates.map { sickTier(startMs, $0, s) } ?? 1
                let p = sickPct(s, tier: t)
                hours = standardHours(Date(ms: startMs), s) * p / 100
                tier = t
                pct = p
            }
            let pay = hours * wage
            return Breakdown(id: shift.id, type: shift.type, startMs: startMs, endMs: startMs, ongoing: false,
                             grossMs: 0, breakMs: 0, netMs: hours * hour, netHours: hours,
                             regularHours: hours, ot1Hours: 0, ot2Hours: 0, overtimeHours: 0, nightHours: 0,
                             isHoliday: false, basePay: pay, otPay: 0, nightPremium: 0, pay: pay,
                             sickTier: tier, sickPct: pct)
        }

        let ongoing = shift.end == nil
        let endMs = shift.end?.ms ?? asOf ?? Date().ms
        let grossMs = max(0, endMs - startMs)

        // the breaks logged, or the automatic break when the shift is long enough, whichever is longer
        var breakMs = breaksMs(shift, asOf: endMs)
        let autoMs = s.autoBreakMinutes * 60000
        if autoMs > 0 && grossMs >= s.autoBreakAfterHours * hour {
            breakMs = max(breakMs, autoMs)
        }
        breakMs = min(breakMs, grossMs)

        let netMs = max(0, grossMs - breakMs)
        let netHours = netMs / hour

        // the night's share of the span worked, breaks included
        let nightHours = s.nightEnabled ? nightMs(startMs, endMs, s.nightStart, s.nightEnd) / hour : 0

        // the regular hours up to the day's standard, then the overtime tiers
        let regular = min(netHours, standardHours(Date(ms: startMs), s))
        var rest = netHours - regular
        let ot1 = min(rest, s.overtime1Hours)
        rest -= ot1
        let ot2 = max(0, rest)

        let basePay: Double
        let otPay: Double
        var nightPremium: Double
        let pay: Double
        if shift.isHoliday {
            // the whole shift at the holiday's multiplier
            basePay = netHours * s.hourlyWage * s.holidayMult
            otPay = 0
            nightPremium = 0
            pay = basePay
        } else {
            basePay = regular * s.hourlyWage
            otPay = (ot1 * s.overtime1Mult + ot2 * s.overtime2Mult) * s.hourlyWage
            nightPremium = s.nightEnabled ? nightHours * s.hourlyWage * (s.nightMult - 1) : 0
            if nightPremium < 0 { nightPremium = 0 }
            pay = basePay + otPay + nightPremium
        }

        return Breakdown(id: shift.id, type: .work, startMs: startMs, endMs: endMs, ongoing: ongoing,
                         grossMs: grossMs, breakMs: breakMs, netMs: netMs, netHours: netHours,
                         regularHours: regular, ot1Hours: ot1, ot2Hours: ot2, overtimeHours: ot1 + ot2,
                         nightHours: nightHours, isHoliday: shift.isHoliday,
                         basePay: basePay, otPay: otPay, nightPremium: nightPremium, pay: pay)
    }

    // MARK: Ranges

    /// The pay period around `ref`: from `monthStartDay` of its month (or of the month before, when
    /// `ref` comes earlier in the month) for one month, moved `offset` periods.
    static func period(around ref: Date, monthStartDay: Int, offset: Int = 0) -> TimeRange {
        let p = LocalTime.parts(ref)
        let day = monthStartDay != 0 ? monthStartDay : 1
        var start = LocalTime.date(p.year, p.month0, day)
        if p.day < day { start = LocalTime.date(p.year, p.month0 - 1, day) }
        var range = TimeRange(start: start, end: LocalTime.addingMonths(1, to: start))
        if offset != 0 {
            range.start = LocalTime.addingMonths(offset, to: range.start)
            range.end = LocalTime.addingMonths(offset, to: range.end)
        }
        return range
    }

    /// The local day of `ref`.
    static func dayRange(_ ref: Date) -> TimeRange {
        let start = LocalTime.startOfDay(ref)
        return TimeRange(start: start, end: LocalTime.addingDays(1, to: start))
    }

    /// The week of `ref`, from `weekStartsOn` (0 Sunday).
    static func weekRange(_ ref: Date, weekStartsOn: Int) -> TimeRange {
        let p = LocalTime.parts(ref)
        let diff = (p.weekday - weekStartsOn + 7) % 7
        let start = LocalTime.date(p.year, p.month0, p.day - diff)
        return TimeRange(start: start, end: LocalTime.addingDays(7, to: start))
    }

    /// Whether a shift starts in the range.
    static func inRange(_ shift: Shift, _ range: TimeRange) -> Bool {
        let t = shift.start.ms
        return t >= range.start.ms && t < range.end.ms
    }

    // MARK: Sums

    /// The hours and wages of the shifts that start in `range` (all of them without one), travel included.
    static func aggregate(_ shifts: [Shift], _ s: Settings, range: TimeRange?, asOf: Double? = nil) -> Totals {
        let sick = sickDates(of: shifts)
        let list = range.map { r in shifts.filter { inRange($0, r) } } ?? shifts
        var days = Set<String>()
        var netHours = 0.0, overtimeHours = 0.0, nightHours = 0.0, pay = 0.0, holidayHours = 0.0
        var count = 0
        for shift in list {
            let b = breakdown(shift, s, asOf: asOf, sickDates: sick)
            pay += b.pay // vacation and sick days are paid…
            if b.type == .vacation || b.type == .sick { continue } // …but not hours or days worked
            netHours += b.netHours
            overtimeHours += b.overtimeHours
            nightHours += b.nightHours
            if b.isHoliday { holidayHours += b.netHours }
            count += 1
            days.insert(LocalTime.dayKey(shift.start))
        }

        // travel for each day worked, up to the period's cap
        var travel = s.travelPerDay * Double(days.count)
        if s.travelMonthlyCap > 0 { travel = min(travel, s.travelMonthlyCap) }

        return Totals(count: count, netHours: netHours, overtimeHours: overtimeHours, nightHours: nightHours,
                      holidayHours: holidayHours, pay: pay, travel: travel, total: pay + travel,
                      workedDays: days.count, avgShiftHours: count > 0 ? netHours / Double(count) : 0)
    }

    /// The hours missing in a range: each day's net hours, all its shifts together (a second shift tops
    /// up the first), against the standard it is expected to meet. Paid days off miss nothing.
    /// `shifts` are all of them, the newest first, as the web app adds them up (app.js renderShifts).
    static func shortfall(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> Shortfall {
        let sick = sickDates(of: shifts)
        var keys: [String] = []
        var net: [String: Double] = [:]
        var dates: [String: Date] = [:]
        for shift in shifts where inRange(shift, range) {
            if shift.type == .vacation || shift.type == .sick { continue }
            let key = LocalTime.dayKey(shift.start)
            if net[key] == nil { keys.append(key) }
            net[key] = (net[key] ?? 0) + breakdown(shift, s, asOf: asOf, sickDates: sick).netHours
            dates[key] = shift.start
        }
        var byDay: [String: Double] = [:]
        var total = 0.0
        for key in keys {
            guard let date = dates[key], let worked = net[key], let expected = expectedStandard(date, s) else { continue }
            let miss = max(0, expected - worked)
            if miss > 0.001 {
                byDay[key] = miss
                total += miss
            }
        }
        return Shortfall(byDay: byDay, total: total)
    }
}
