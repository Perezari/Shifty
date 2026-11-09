import Foundation

/// A pay period as the Shifts and Calendar screens show it (app.js renderShifts and renderCalendar): its
/// shifts, the newest first, with their hours and pay, their totals, the hours missing and each day's sum.
struct PeriodSummary {
    var range: TimeRange
    var shifts: [Shift]
    /// By id, each shift's hours and pay, a sick day's place in its run of sick days included.
    var breakdowns: [String: Breakdown]
    var totals: Totals
    var shortfall: Shortfall
    /// By day key (LocalTime.dayKey), the days with a shift.
    var days: [String: DaySum]
    /// The holidays it pays (Calc.holidayPays), the first first.
    var holidayPays: [HolidayPayDay] = []
}

/// A day's shifts on the calendar.
struct DaySum {
    var date: Date
    /// The net hours of the day's work shifts, and how many there are.
    var netHours = 0.0
    var count = 0
    /// The day's pay, a paid day off's too.
    var pay = 0.0
    /// A paid vacation or sick day.
    var dayOff: ShiftType?
    /// The day fell short of its standard.
    var short = false
    /// The sums once on it, those taken off below zero.
    var adjustment = 0.0
}

extension Calc {
    /// The period `range` at `now`. `shifts` are all of them, the newest first.
    static func summary(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf now: Double) -> PeriodSummary {
        let sick = sickDates(of: shifts)
        let before = workedBefore(shifts, s, range: range, asOf: now)
        let list = shifts.filter { inRange($0, range) }
        var breakdowns: [String: Breakdown] = [:]
        var days: [String: DaySum] = [:]
        for shift in list {
            let b = breakdown(shift, s, asOf: now, sickDates: sick, before: before[shift.id])
            breakdowns[shift.id] = b
            let key = LocalTime.dayKey(shift.start)
            var day = days[key] ?? DaySum(date: shift.start)
            if !s.isMonthly(shift) { day.pay += b.pay }
            if b.type == .adjustment {
                day.adjustment += shift.amount ?? 0
            } else if b.type != .work {
                day.dayOff = b.type
            } else {
                day.netHours += b.netHours
                day.count += 1
            }
            days[key] = day
        }
        let missing = shortfall(shifts, s, range: range, asOf: now)
        for key in missing.byDay.keys {
            days[key]?.short = true
        }
        return PeriodSummary(range: range, shifts: list, breakdowns: breakdowns,
                             totals: periodTotals(shifts, s, range: range, asOf: now), shortfall: missing, days: days,
                             holidayPays: holidayPays(shifts, s, range: range, asOf: now))
    }

    /// The calendar's days for a period: whole weeks from the Sunday before its first day to the Shabbat
    /// after its last.
    static func gridDays(_ range: TimeRange) -> [Date] {
        let first = LocalTime.parts(range.start)
        let last = LocalTime.parts(Date(ms: range.end.ms - 1))
        let gridStart = LocalTime.date(first.year, first.month0, first.day - first.weekday)
        let gridEnd = LocalTime.date(last.year, last.month0, last.day + (6 - last.weekday))
        let count = Int(jsRound((gridEnd.ms - gridStart.ms) / 86_400_000)) + 1
        let start = LocalTime.parts(gridStart)
        return (0..<count).map { LocalTime.date(start.year, start.month0, start.day + $0) }
    }

    /// The offset from the period of `now` to the period around the 15th of a month (app.js
    /// periodOffsetFor): the period picker's months.
    static func periodOffset(year: Int, month0: Int, monthStartDay: Int, now: Date) -> Int {
        let base = LocalTime.parts(period(around: now, monthStartDay: monthStartDay).start)
        let target = LocalTime.parts(period(around: LocalTime.date(year, month0, 15), monthStartDay: monthStartDay).start)
        return (target.year * 12 + target.month0) - (base.year * 12 + base.month0)
    }

    /// The period's name: "אוקטובר 2026" when it is a calendar month, else "25 בספטמבר – 24 באוקטובר 2026";
    /// without the year, the Now screen's card's, on one line beside the days left.
    static func periodTitle(_ range: TimeRange, year: Bool = true) -> String {
        let first = LocalTime.parts(range.start)
        let lastDay = Date(ms: range.end.ms - 1)
        let last = LocalTime.parts(lastDay)
        if first.day == 1 && first.month0 == last.month0 {
            return Format.monthName(first.month0) + (year ? " \(first.year)" : "")
        }
        return Format.dateLong(range.start) + " – " + Format.dateLong(lastDay) + (year ? " \(last.year)" : "")
    }

    /// The month the period mostly lies in, the period picker's: its middle's (app.js openPeriodPicker).
    static func periodMonth(_ range: TimeRange) -> (year: Int, month0: Int) {
        let middle = LocalTime.parts(Date(ms: (range.start.ms + range.end.ms) / 2))
        return (middle.year, middle.month0)
    }
}

/// A day of the week on the Now screen: the net hours worked on it and the standard it is expected to meet.
struct WeekDay: Hashable {
    var date: Date
    var hours: Double
    /// nil on a day off, where working less is no shortfall.
    var standard: Double?
}

extension Calc {
    /// The week of `date`, from the settings' first day: each day's net hours of work (paid days off are not
    /// hours worked) and its standard.
    static func week(_ shifts: [Shift], _ s: Settings, around date: Date, asOf now: Double) -> [WeekDay] {
        let first = LocalTime.parts(weekRange(date, weekStartsOn: s.weekStartsOn).start)
        return (0..<7).map { i in
            let day = LocalTime.date(first.year, first.month0, first.day + i)
            let hours = aggregate(shifts, s, range: dayRange(day), asOf: now).netHours
            return WeekDay(date: day, hours: hours, standard: expectedStandard(day, s))
        }
    }

    /// Where the pay period's income is heading: what it has, and its average day worked for each day left in
    /// it, from tomorrow, that has a standard and no reserve duty. A month's fixed pay, a bonus and the sums once stay
    /// as they are.
    static func projectedIncome(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf now: Double) -> Double {
        let totals = periodTotals(shifts, s, range: range, asOf: now)
        guard totals.workedDays > 0 else { return totals.total }
        let fixed = totals.salary + totals.bonus + totals.recuperation + totals.holidayPay + totals.additions - totals.deductions
            + monthlyTravel(shifts, s, range: range)
        let variable = totals.total - fixed
        let reserve = Set(shifts.filter { $0.type == .reserve && !$0.deleted }.map { LocalTime.dayKey($0.start) })
        var day = LocalTime.addingDays(1, to: LocalTime.startOfDay(Date(ms: now)))
        var left = 0
        // no days ahead once the work at every workplace has ended
        let ends = ([s.place(nil)] + s.workplaces).map(\.until)
        let last = ends.contains { $0 == nil } ? range.end : min(range.end, ends.compactMap { $0 }.max() ?? range.end)
        while day < last {
            if expectedStandard(day, s) != nil && !reserve.contains(LocalTime.dayKey(day)) { left += 1 }
            day = LocalTime.addingDays(1, to: day)
        }
        return fixed + variable + variable / Double(totals.workedDays) * Double(left)
    }

    /// The next shortened day or holiday after `date`, within `days` days.
    static func nextHoliday(after date: Date, within days: Int) -> (date: Date, info: Holidays.Info)? {
        let today = LocalTime.startOfDay(date)
        for i in 1...max(1, days) {
            let day = LocalTime.addingDays(i, to: today)
            let info = Holidays.info(day)
            if info.kind != nil { return (day, info) }
        }
        return nil
    }
}
