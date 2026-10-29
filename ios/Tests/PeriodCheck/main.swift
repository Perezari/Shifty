import Foundation

// Checks the pay period of the Shifts and Calendar screens (Shifty/Core/Period.swift): a period's shifts,
// days and hours missing, the calendar's weeks, the period picker's months and the period's name.
// TZ=Asia/Jerusalem period-check

var failures = 0
func expect(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok {
        failures += 1
        print("FAILED (line \(line)): \(what)")
    }
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

let s = Settings()
let now = LocalTime.date(2026, 9, 29, 10, 0) // Thursday 29 October 2026

// the calendar's weeks: Sunday to Shabbat around the period, across the change of the clocks (25 October)
let october = Calc.period(around: now, monthStartDay: 1)
let octoberDays = Calc.gridDays(october)
expect(octoberDays.count == 35 && LocalTime.dayKey(octoberDays[0]) == "2026-8-27" && LocalTime.dayKey(octoberDays[34]) == "2026-9-31",
       "October: from Sunday 27 September to Shabbat 31 October")
expect(octoberDays.allSatisfy { LocalTime.parts($0).hour == 0 }, "each day at midnight")
let fromThe25th = Calc.period(around: now, monthStartDay: 25)
let fromThe25thDays = Calc.gridDays(fromThe25th)
expect(fromThe25thDays.count == 35 && LocalTime.dayKey(fromThe25thDays[0]) == "2026-9-25" && LocalTime.dayKey(fromThe25thDays[34]) == "2026-10-28",
       "25 October to 24 November: to Shabbat 28 November")

// the period's name
expect(Calc.periodTitle(october) == "אוקטובר 2026", "a calendar month by its name")
expect(Calc.periodTitle(fromThe25th) == "25 באוקטובר – 24 בנובמבר 2026", "a period from the 25th by its days")

// the period picker: the month a period mostly lies in, and back from a month to its period
expect(Calc.periodMonth(october) == (2026, 9) && Calc.periodMonth(fromThe25th) == (2026, 10), "the month in the middle")
expect(Calc.periodOffset(year: 2026, month0: 0, monthStartDay: 1, now: now) == -9, "January, nine months back")
expect(Calc.periodOffset(year: 2027, month0: 1, monthStartDay: 1, now: now) == 4, "February next year, four ahead")
expect(Calc.periodOffset(year: 2026, month0: 10, monthStartDay: 25, now: now) == 0, "November is the period from 25 October")
expect(Calc.periodOffset(year: 2026, month0: 9, monthStartDay: 25, now: now) == -1, "October is the period from 25 September")

// a period's shifts (November 2026: no holidays; Sunday to Wednesday 9:36, Thursday 8:36)
func work(_ day: Int, _ from: Int, _ to: Int) -> Shift {
    Shift(id: "w\(day)-\(from)", start: LocalTime.date(2026, 10, day, from), end: LocalTime.date(2026, 10, day, to))
}
func off(_ day: Int, _ type: ShiftType) -> Shift {
    let noon = LocalTime.date(2026, 10, day, 12)
    return Shift(id: "\(type.rawValue)\(day)", start: noon, end: noon, type: type)
}
let shifts = [
    work(1, 8, 17), work(1, 18, 19), // Sunday: 9 hours and 1, the second tops up the first
    work(2, 8, 18), // Monday: 10 hours, overtime
    off(3, .sick), // Tuesday
    off(4, .vacation), // Wednesday
    work(5, 9, 12), // Thursday: 3 hours of 8:36
    work(6, 8, 10), // Friday, a day off: no standard to miss
    Shift(id: "before", start: LocalTime.date(2026, 9, 30, 8), end: LocalTime.date(2026, 9, 30, 17)),
].sorted { $0.start > $1.start }
let november = Calc.period(around: LocalTime.date(2026, 10, 15), monthStartDay: 1)
let summary = Calc.summary(shifts, s, range: november, asOf: now.ms)
expect(summary.shifts.count == 7 && summary.breakdowns.count == 7 && !summary.shifts.contains { $0.id == "before" },
       "the period's shifts alone")
expect(summary.shifts.map(\.start) == summary.shifts.map(\.start).sorted(by: >), "the newest first")
expect(summary.days.count == 6, "six days")
let sunday = summary.days["2026-10-1"]
expect(sunday?.count == 2 && near(sunday?.netHours ?? 0, 10) && sunday?.short == false, "two shifts make Sunday's day")
expect(summary.days["2026-10-5"]?.short == true && near(summary.shortfall.total, 8.6 - 3), "Thursday falls short")
expect(summary.days["2026-10-6"]?.short == false, "a day off misses nothing")
expect(summary.days["2026-10-3"]?.dayOff == .sick && summary.days["2026-10-3"]?.count == 0, "a sick day")
expect(summary.days["2026-10-4"]?.dayOff == .vacation && near(summary.days["2026-10-4"]?.pay ?? 0, 8.6 * 50), "a vacation day's pay")
expect(summary.totals.count == 5 && summary.totals.workedDays == 4, "five shifts on four days")
expect(summary.breakdowns["sick3"]?.sickTier == 1, "the first day of sickness")
expect(near(summary.days.values.reduce(0) { $0 + $1.pay }, summary.totals.pay), "the days' pay is the period's")

print(failures == 0 ? "Period: all checks passed" : "Period: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
