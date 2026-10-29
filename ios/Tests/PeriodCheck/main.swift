import Foundation

// Checks the pay period of the Shifts and Calendar screens (Shifty/Core/Period.swift): a period's shifts,
// days and hours missing, the calendar's weeks, the period picker's months and the period's name; and the
// net pay (Net.swift) and the vacation and sick days left (Leave.swift).
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

// the week of Wednesday 4 November: Sunday's two shifts, a sick and a vacation day that are no hours worked
let week = Calc.week(shifts, s, around: LocalTime.date(2026, 10, 4, 9), asOf: now.ms)
expect(week.count == 7 && LocalTime.dayKey(week[0].date) == "2026-10-1" && LocalTime.dayKey(week[6].date) == "2026-10-7", "Sunday to Shabbat")
expect(near(week[0].hours, 10) && near(week[2].hours, 0) && near(week[4].hours, 3) && near(week[5].hours, 2), "each day's hours worked")
expect(week[0].standard == 9.6 && week[4].standard == 8.6 && week[5].standard == nil && week[6].standard == nil, "each day's standard")

// November's income heading on: 4 days worked, 17 days left with a standard from the 7th
let asOfNovember = LocalTime.date(2026, 10, 6, 20)
let novemberTotal = Calc.aggregate(shifts, s, range: november, asOf: asOfNovember.ms).total
expect(near(Calc.projectedIncome(shifts, s, range: november, asOf: asOfNovember.ms), novemberTotal + novemberTotal / 4 * 17),
       "the average day worked for each day left")

// the next shortened day: Erev Rosh Hashana 5787, Friday 11 September 2026
if let next = Calc.nextHoliday(after: LocalTime.date(2026, 8, 6, 10), within: 14) {
    expect(LocalTime.dayKey(next.date) == "2026-8-11" && next.info.kind == .short, "Erev Rosh Hashana")
} else {
    expect(false, "a holiday within two weeks of 6 September")
}
expect(Calc.nextHoliday(after: LocalTime.date(2026, 10, 1), within: 14) == nil, "none in November")

// the dial: a shift from 7:15, a break 9:45 to 10:10, now 12:32 (Thursday 29 October, a goal of 8:36)
let dialStart = LocalTime.date(2026, 9, 29, 7, 15)
var running = Shift(id: "dial", start: dialStart)
running.breaks = [Break(start: LocalTime.date(2026, 9, 29, 9, 45), end: LocalTime.date(2026, 9, 29, 10, 10))]
let dialNow = LocalTime.date(2026, 9, 29, 12, 32)
expect(near(Calc.dialDegrees(dialStart), 217.5) && near(Calc.dialDegrees(dialNow), 16), "angles on twelve hours")
let layout = Calc.dial(running, s, at: dialNow)
expect(near(layout.startDeg, 217.5) && near(layout.nowDeg, 158.5), "the start, and now 5:17 after it")
expect(layout.pieces.map(\.kind) == [.work, .pause, .work, .ahead], "work, the break, work, and ahead to the goal")
expect(near(layout.pieces[1].from, 75) && near(layout.pieces[1].to, 87.5), "the break from 2:30 to 2:55")
// the goal: 8:36 of Thursday and the break's 25 minutes, 9:01 after the start
expect(near(layout.goalDeg ?? 0, 270.5) && near(Calc.goalTime(running, s, asOf: dialNow.ms).ms, LocalTime.date(2026, 9, 29, 16, 16).ms),
       "the goal at 16:16")
let late = Calc.dial(running, s, at: dialNow, leave: LocalTime.date(2026, 9, 29, 17, 16))
expect(late.pieces.suffix(2).map(\.kind) == [.ahead, .plannedOvertime] && near(late.leaveDeg ?? 0, 300.5), "an hour past the goal")
let early = Calc.dial(running, s, at: dialNow, leave: LocalTime.date(2026, 9, 29, 15, 16))
expect(early.pieces.suffix(2).map(\.kind) == [.ahead, .short], "an hour short of it")
expect(Calc.dialTime(16, start: dialStart, now: dialNow) == LocalTime.date(2026, 9, 29, 12, 30).addingTimeInterval(0)
       || Calc.dialTime(16, start: dialStart, now: dialNow) == dialNow, "a point is never before now")
expect(Calc.dialTime(130, start: dialStart, now: dialNow) == LocalTime.date(2026, 9, 29, 16, 20), "16:20 on the dial")
let leavingLate = Calc.leaving(running, at: LocalTime.date(2026, 9, 29, 17, 16), s, now: dialNow)
expect(near(leavingLate.netHours, 9.6) && near(leavingLate.overtimeHours, 1), "leaving an hour late: an hour of overtime")

// the net pay, at 2026's rates, with 2.25 credit points and 6% to the pension
func cents(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }
let pay10k = Calc.netPay(gross: 10_000, pensionable: 9_000, s)
expect(cents(pay10k.pension, 540) && cents(pay10k.incomeTax, 386.1), "10,000: tax 1,119.6 less 544.5 of points and 189 for the pension")
expect(cents(pay10k.nationalInsurance, 240.9012) && cents(pay10k.health, 367.5618), "insurance: reduced up to 7,703, full above")
expect(cents(pay10k.net, 8_465.437), "10,000 is 8,465.44 net")
let pay5k = Calc.netPay(gross: 5_000, pensionable: 5_000, s)
expect(pay5k.incomeTax == 0 && cents(pay5k.net, 4_486.5), "5,000: the credits cover the tax")
let pay30k = Calc.netPay(gross: 30_000, pensionable: 20_000, s)
expect(cents(pay30k.incomeTax, 5_739.85), "30,000: up to the 35% bracket, the pension's credit at its most")
expect(cents(pay30k.net, 20_017.687), "30,000 is 20,017.69 net")
var points = s
points.creditPoints = 2.75
points.pensionPercent = 0
expect(cents(Calc.netPay(gross: 10_000, pensionable: 9_000, points).incomeTax, 1_119.6 - 2.75 * 242), "2.75 points, no pension")

// the vacation and sick days left: 8.5 and 20 on the payslip of 30 September
var leaveSettings = s
expect(Calc.leave([], leaveSettings, asOf: now) == nil, "not kept without the payslip's date")
leaveSettings.balanceDate = LocalTime.date(2026, 8, 30)
leaveSettings.vacationBalance = 8.5
leaveSettings.sickBalance = 20
let daysOff = [
    Shift(id: "before", start: LocalTime.date(2026, 8, 29, 8), type: .vacation),
    Shift(id: "v1", start: LocalTime.date(2026, 9, 12, 8), type: .vacation),
    Shift(id: "s1", start: LocalTime.date(2026, 9, 20, 8), type: .sick),
    Shift(id: "s2", start: LocalTime.date(2026, 9, 21, 8), type: .sick),
    Shift(id: "v2", start: LocalTime.date(2026, 10, 5, 8), type: .vacation),
]
let october29 = Calc.leave(daysOff, leaveSettings, asOf: now)
expect(october29 == LeaveBalance(vacation: 7.5, sick: 18, months: 0, vacationTaken: 1, sickTaken: 2),
       "29 October: no month yet, a vacation day and two sick days since")
let december2 = Calc.leave(daysOff, leaveSettings, asOf: LocalTime.date(2026, 11, 2, 9))
expect(december2.map { near($0.vacation, 8.5) && near($0.sick, 21) && $0.months == 2 } == true,
       "2 December: two months, 2 vacation days and 3 sick days more, two vacation days taken")
leaveSettings.sickBalance = 89
expect(Calc.leave(daysOff, leaveSettings, asOf: LocalTime.date(2026, 11, 2, 9)).map { near($0.sick, 88) } == true,
       "sick days up to 90")
expect(Calc.monthsBetween(LocalTime.date(2026, 8, 30), LocalTime.date(2026, 9, 30)) == 1
       && Calc.monthsBetween(LocalTime.date(2026, 8, 30), LocalTime.date(2026, 9, 29, 23, 59)) == 0, "a month on its day")

print(failures == 0 ? "Period: all checks passed" : "Period: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
