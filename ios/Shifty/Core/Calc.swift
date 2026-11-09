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
    /// What it was counted after in its day and week, to count it again as it runs.
    var before: WorkedBefore? = nil
}

/// What came before a shift in its day and its week at its workplace, where overtime is counted by them
/// (Settings.lawOvertime, Calc.workedBefore).
struct WorkedBefore: Hashable {
    /// The day's regular hours and overtime so far: the day's standard and its first tier are of the whole day.
    var dayRegular = 0.0
    var dayOvertime = 0.0
    /// The week's regular hours so far, a paid day off's standard among them: a week's overtime is past its hours.
    var weekRegular = 0.0
}

/// The hours and wages of a range of shifts (calc.js aggregate).
struct Totals {
    /// The work shifts: vacation and sick days are paid, but not hours or days worked.
    var count: Int
    var netHours: Double
    var overtimeHours: Double
    var nightHours: Double
    var holidayHours: Double
    /// The wages, without travel; nothing for a shift paid by a month's fixed pay.
    var pay: Double
    var travel: Double
    /// The income: the wages and the travel, and in a pay period, the rest that follows.
    var total: Double
    var workedDays: Int
    var avgShiftHours: Double
    /// A pay period's (Calc.periodTotals): the fixed pay of the months paid so, for the part of the period
    /// their terms hold; the overtime that pay does not cover; and an annual bonus due in it.
    var salary = 0.0
    var extraOvertime = 0.0
    var bonus = 0.0
    /// The recuperation pay due in it (Calc.recuperation).
    var recuperation = 0.0
    /// The holiday pay due in it (Calc.holidayPays), and the sums once on its days: those added, and those taken off,
    /// which the income is without and the tax takes no account of (Shift.amount).
    var holidayPay = 0.0
    var additions = 0.0
    var deductions = 0.0
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

    /// The standard a work shift's overtime starts after: its day's (standardHours of its start), or 7 hours on a night
    /// shift, two hours or more of it up to `endMs` between 22:00 and 06:00, where the law's night shift is set
    /// (Settings.nightShift). `s` is the shift's own settings (effective(for:)).
    static func shiftStandard(_ startMs: Double, _ endMs: Double, _ s: Settings) -> Double {
        let standard = standardHours(Date(ms: startMs), s)
        guard s.nightShift, nightMs(startMs, endMs, 22, 6) >= 2 * hour else { return standard }
        return min(standard, 7)
    }

    /// The regular hours a work shift can hold: its day's standard (shiftStandard); where overtime is counted as the
    /// law does (Settings.lawOvertime), what its day and its week still have of theirs, so that the shifts of a day
    /// count together, and hours past the week's are overtime though no day passed its standard. `s` is the shift's own
    /// settings (effective(for:)).
    static func regularRoom(_ startMs: Double, _ endMs: Double, _ s: Settings, before: WorkedBefore?) -> Double {
        let standard = shiftStandard(startMs, endMs, s)
        return s.lawOvertime ? lawRoom(standard, s, before: before) : standard
    }

    /// What is left of a day's standard and of the week's hours.
    private static func lawRoom(_ standard: Double, _ s: Settings, before: WorkedBefore?) -> Double {
        let done = before ?? WorkedBefore()
        let week = s.weeklyHours > 0 ? s.weeklyHours : 42
        return max(0, min(standard - done.dayRegular, week - done.weekRegular))
    }

    /// The running shift's goal in hours: the standard of the day of `now`, as the web app's Now screen takes it; or
    /// a night shift's 7, where it is set, once its span up to now, or up to the goal at that standard, holds two
    /// hours of night. Where overtime is counted as the law does, what its day and week still have of that.
    static func goalHours(_ shift: Shift, _ s: Settings, asOf now: Double, before: WorkedBefore? = nil) -> Double {
        let s = s.effective(for: shift)
        var goal = standardHours(Date(ms: now), s)
        if s.nightShift {
            let planned = shift.start.ms + goal * hour + max(breaksMs(shift, asOf: now), s.autoBreakMinutes * 60000)
            if nightMs(shift.start.ms, max(now, planned), 22, 6) >= 2 * hour { goal = min(goal, 7) }
        }
        return s.lawOvertime ? lawRoom(goal, s, before: before) : goal
    }

    /// Whether a shift starting at `date` is on Shabbat or a holiday, by the clock and not by the sun: from 18:00 on its
    /// eve, up to 18:00 on its day. A new shift's mark, where overtime is counted as the law does; the editor can change it.
    static func isRestDay(_ date: Date, _ s: Settings) -> Bool {
        let p = LocalTime.parts(date)
        if p.weekday == 6 && p.hour < 18 || p.weekday == 5 && p.hour >= 18 { return true }
        guard s.holidaysEnabled else { return false }
        switch Holidays.info(date).kind {
        case .chag: return p.hour < 18
        case .short: return p.hour >= 18
        case nil: return false
        }
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
    /// shifts) gives a sick day its place in its run; without it, every sick day is the first. `before` (workedBefore)
    /// gives a shift its place in its day and week, where overtime is counted as the law does.
    static func breakdown(_ shift: Shift, _ s: Settings, asOf: Double? = nil, sickDates: Set<String>? = nil,
                          before: WorkedBefore? = nil) -> Breakdown {
        // its workplace's standard hours and the wage of its day's pay (Pay.swift)
        let s = s.effective(for: shift)
        let wage = s.hourlyWage
        let startMs = shift.start.ms

        // a day of reserve duty, for the record: no hours and no pay; and a sum once, which is the period's (periodTotals)
        if shift.type == .reserve || shift.type == .adjustment {
            return Breakdown(id: shift.id, type: shift.type, startMs: startMs, endMs: startMs, ongoing: false,
                             grossMs: 0, breakMs: 0, netMs: 0, netHours: 0, regularHours: 0, ot1Hours: 0, ot2Hours: 0,
                             overtimeHours: 0, nightHours: 0, isHoliday: false, basePay: 0, otPay: 0, nightPremium: 0, pay: 0)
        }

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

        // the regular hours up to the day's standard (a night shift's, where it is set), then the overtime tiers: the
        // first tier a day's, where the law's count is set
        let regular = min(netHours, regularRoom(startMs, endMs, s, before: before))
        var rest = netHours - regular
        let ot1 = min(rest, s.lawOvertime ? max(0, s.overtime1Hours - (before?.dayOvertime ?? 0)) : s.overtime1Hours)
        rest -= ot1
        let ot2 = max(0, rest)

        let basePay: Double
        let otPay: Double
        var nightPremium: Double
        let pay: Double
        if shift.isHoliday {
            if s.lawOvertime {
                // the regular hours at the holiday's multiplier, and the overtime's on top of it: 175%, then 200%
                basePay = regular * s.hourlyWage * s.holidayMult
                otPay = (ot1 * (s.holidayMult + s.overtime1Mult - 1) + ot2 * (s.holidayMult + s.overtime2Mult - 1)) * s.hourlyWage
            } else {
                // the whole shift at the holiday's multiplier
                basePay = netHours * s.hourlyWage * s.holidayMult
                otPay = 0
            }
            nightPremium = 0
            pay = basePay + otPay
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
                         basePay: basePay, otPay: otPay, nightPremium: nightPremium, pay: pay, before: before)
    }

    /// What came before each work shift in its day and week, by id, at the workplaces whose overtime is counted as the
    /// law does; empty where none is. Of the shifts of `range`, all of them without one; `shifts` are all of them. The
    /// days go in order through each week from its first: a day's regular hours add up, as the week's do, and a paid
    /// day off, and a holiday not worked on a day of work, count in the week's as a day worked in full, as
    /// kolzchut.org.il's examples have them.
    static func workedBefore(_ shifts: [Shift], _ s: Settings, range: TimeRange? = nil, asOf: Double? = nil) -> [String: WorkedBefore] {
        guard s.lawOvertime || s.workplaces.contains(where: { $0.rules.lawOvertime }) else { return [:] }
        let from = range.map { weekRange($0.start, weekStartsOn: s.weekStartsOn).start }
        let list = shifts.filter { shift in
            !shift.deleted && shift.type != .adjustment && (s.workplace(of: shift)?.rules.lawOvertime ?? s.lawOvertime)
                && (from.map { shift.start >= $0 } ?? true) && (range.map { shift.start < $0.end } ?? true)
        }.sorted { $0.start < $1.start }
        struct Walk {
            var week: Date
            var day: Date?
            var done = WorkedBefore()
        }
        var walks: [String: Walk] = [:]
        var before: [String: WorkedBefore] = [:]
        for shift in list {
            let own = s.effective(for: shift)
            let place = s.workplace(of: shift)?.id ?? ""
            let day = LocalTime.startOfDay(shift.start)
            let week = weekRange(shift.start, weekStartsOn: s.weekStartsOn).start
            var walk = walks[place] ?? Walk(week: week)
            if walk.week != week { walk = Walk(week: week) }
            if walk.day != day {
                // the days since the last shift here, for a holiday among them
                var gap = walk.day.map { LocalTime.addingDays(1, to: $0) } ?? week
                while gap < day {
                    if own.holidaysEnabled, Holidays.info(gap).kind == .chag, let standard = expectedStandard(gap, own) {
                        walk.done.weekRegular += standard
                    }
                    gap = LocalTime.addingDays(1, to: gap)
                }
                walk.day = day
                walk.done.dayRegular = 0
                walk.done.dayOvertime = 0
            }
            if shift.type == .work {
                before[shift.id] = walk.done
                let b = breakdown(shift, s, asOf: asOf, before: walk.done)
                walk.done.dayRegular += b.regularHours
                walk.done.dayOvertime += b.overtimeHours
                walk.done.weekRegular += b.regularHours
            } else {
                walk.done.weekRegular += expectedStandard(shift.start, own) ?? 0
            }
            walks[place] = walk
        }
        return before
    }

    /// What came before one shift in its day and week.
    static func workedBefore(of shift: Shift, in shifts: [Shift], _ s: Settings, asOf: Double? = nil) -> WorkedBefore? {
        workedBefore(shifts, s, range: dayRange(shift.start), asOf: asOf)[shift.id]
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

    /// The hours and wages of the shifts that start in `range` (all of them without one), travel included. A
    /// shift paid by a month's fixed pay earns no wage of its own (periodTotals adds the month's).
    static func aggregate(_ shifts: [Shift], _ s: Settings, range: TimeRange?, asOf: Double? = nil) -> Totals {
        let sick = sickDates(of: shifts)
        let before = workedBefore(shifts, s, range: range, asOf: asOf)
        let list = range.map { r in shifts.filter { inRange($0, r) } } ?? shifts
        var days = Set<String>()
        // the days worked at each workplace, for its travel (the settings' own under "")
        var daysAt: [String: Set<String>] = [:]
        var netHours = 0.0, overtimeHours = 0.0, nightHours = 0.0, pay = 0.0, holidayHours = 0.0
        var count = 0
        for shift in list {
            let b = breakdown(shift, s, asOf: asOf, sickDates: sick, before: before[shift.id])
            if !s.isMonthly(shift) { pay += b.pay } // vacation and sick days are paid…
            if b.type != .work { continue } // …but not hours or days worked
            netHours += b.netHours
            overtimeHours += b.overtimeHours
            nightHours += b.nightHours
            if b.isHoliday { holidayHours += b.netHours }
            count += 1
            days.insert(LocalTime.dayKey(shift.start))
            daysAt[s.workplace(of: shift)?.id ?? "", default: []].insert(LocalTime.dayKey(shift.start))
        }

        // travel for each day worked, up to the period's cap, each workplace's own
        var travel = 0.0
        for (id, worked) in daysAt {
            let place = s.workplaces.first { $0.id == id }
            // travel as a fixed sum a month is the period's (periodTotals), not each day's
            if (place == nil ? s.travelMonthly : place?.travelMonthly) != nil { continue }
            var amount = (place?.travelPerDay ?? s.travelPerDay) * Double(worked.count)
            let cap = place?.travelMonthlyCap ?? s.travelMonthlyCap
            if cap > 0 { amount = min(amount, cap) }
            travel += amount
        }

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
        // the days with a night shift, where it is set: their standard is its 7 hours
        var nights = Set<String>()
        for shift in shifts where inRange(shift, range) {
            if shift.type != .work { continue }
            let key = LocalTime.dayKey(shift.start)
            if net[key] == nil { keys.append(key) }
            let b = breakdown(shift, s, asOf: asOf, sickDates: sick)
            net[key] = (net[key] ?? 0) + b.netHours
            dates[key] = shift.start
            let own = s.effective(for: shift)
            if own.nightShift && nightMs(b.startMs, b.endMs, 22, 6) >= 2 * hour { nights.insert(key) }
        }
        var byDay: [String: Double] = [:]
        var total = 0.0
        for key in keys {
            guard let date = dates[key], let worked = net[key], var expected = expectedStandard(date, s) else { continue }
            if nights.contains(key) { expected = min(expected, 7) }
            let miss = max(0, expected - worked)
            if miss > 0.001 {
                byDay[key] = miss
                total += miss
            }
        }
        return Shortfall(byDay: byDay, total: total)
    }
}
