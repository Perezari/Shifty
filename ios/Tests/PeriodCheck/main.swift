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
expect(Calc.periodTitle(october, year: false) == "אוקטובר" && Calc.periodTitle(fromThe25th, year: false) == "25 באוקטובר – 24 בנובמבר",
       "on the Now screen's card, without the year")

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

// the pay from a date (Pay.swift): a raise from Monday 16 November; shifts before it keep 50 an hour
let beforeRaise = work(9, 8, 16) // Monday 9 November: 8 hours
let afterRaise = Shift(id: "after", start: LocalTime.date(2026, 10, 16, 8), end: LocalTime.date(2026, 10, 16, 16))
expect(s.effective(for: beforeRaise) == s, "one workplace and one pay: the settings themselves")
var raised = s
raised.payTerms = [PayTerms(id: "base", from: PayTerms.start, hourlyWage: 50),
                   PayTerms(id: "raise", from: LocalTime.date(2026, 10, 16), hourlyWage: 60)]
expect(near(Calc.breakdown(beforeRaise, raised).pay, 8 * 50) && near(Calc.breakdown(afterRaise, raised).pay, 8 * 60),
       "each shift at the wage of its day")

// a global pay from the 16th: 12,000 a month, an hour of overtime covered; Tuesday 17th, 12 hours: 9:36, 2 and 0:24 over
var global = s
global.payTerms = [PayTerms(id: "base", from: PayTerms.start, hourlyWage: 50),
                   PayTerms(id: "global", from: LocalTime.date(2026, 10, 16), kind: .monthly, monthlySalary: 12_000,
                            overtimeCover: .upTo, overtimeHours: 1)]
let long = Shift(id: "long", start: LocalTime.date(2026, 10, 17, 8), end: LocalTime.date(2026, 10, 17, 20))
let mixed = [long, afterRaise, beforeRaise]
let mixedTotals = Calc.periodTotals(mixed, global, range: november, asOf: now.ms)
expect(near(mixedTotals.pay, 8 * 50), "the shift before the global pay at its wage; those after it earn none of their own")
expect(near(mixedTotals.salary, 12_000.0 * 15 / 30), "the month's pay from the 16th: 15 of November's 30 days")
let hourWorth = 12_000.0 / 182
expect(near(mixedTotals.extraOvertime, (2 * 1.25 + 0.4 * 1.5) * hourWorth * 1.4 / 2.4), "the overtime past the hour covered")
expect(near(mixedTotals.total, mixedTotals.pay + mixedTotals.salary + mixedTotals.extraOvertime), "the period's income")
expect(Calc.monthlyOvertime(mixed, global, range: november, asOf: now.ms).map { near($0.hours, 2.4) && $0.terms.target(after: $0.hours) == 1 } == true,
       "2:24 of overtime, of an hour covered")
expect(near(Calc.periodNet(mixed, global, range: november, asOf: now.ms, projected: false).pension, (8 * 50 + 6_000) * 0.06),
       "the pension from the wages and the month's pay, not from its overtime")
global.payTerms[1].overtimeCover = .all
expect(Calc.periodTotals(mixed, global, range: november, asOf: now.ms).extraOvertime == 0, "all of it covered")
global.payTerms[1].overtimeCover = .none
expect(near(Calc.periodTotals(mixed, global, range: november, asOf: now.ms).extraOvertime, (2 * 1.25 + 0.4 * 1.5) * hourWorth),
       "none of it covered")

// a bonus at targets of overtime: 300 at 2 hours, 500 more at 4; 2:24 reaches the first alone
global.payTerms[1].overtimeCover = .tiers
global.payTerms[1].overtimeTiers = [OvertimeTier(hours: 2, amount: 300), OvertimeTier(hours: 4, amount: 500)]
expect(near(Calc.periodTotals(mixed, global, range: november, asOf: now.ms).extraOvertime, 300), "the first target's bonus")
expect(global.payTerms[1].target(after: 2.4) == 4 && global.payTerms[1].target(after: 4) == nil && global.payTerms[1].target(after: 1) == 2,
       "the next target, none past the last")

// an annual bonus of 5,000 with December's pay, while the global pay holds on 1 December
global.payTerms[1].bonus = 5_000
global.payTerms[1].bonusMonth = 11
let december = Calc.period(around: LocalTime.date(2026, 11, 15), monthStartDay: 1)
let decemberTotals = Calc.periodTotals([], global, range: december, asOf: now.ms)
expect(near(decemberTotals.bonus, 5_000) && near(decemberTotals.salary, 12_000) && near(decemberTotals.total, 17_000),
       "December: a whole month's pay with no shifts, and the bonus")
expect(Calc.periodTotals(mixed, global, range: november, asOf: now.ms).bonus == 0, "no bonus in November")
let decemberWork = [Shift(id: "d1", start: LocalTime.date(2026, 11, 1, 8), end: LocalTime.date(2026, 11, 1, 16))]
expect(near(Calc.projectedIncome(decemberWork, global, range: december, asOf: LocalTime.date(2026, 11, 1, 20).ms), 17_000),
       "heading on, the month's pay and the bonus stay as they are")

// a second workplace by the hour on Fridays, with its own wage, standard and travel
var two = s
two.travelPerDay = 20
two.workplaces = [Workplace(id: "cafe", name: "קפה", pay: [PayTerms(id: "cafe-pay", from: PayTerms.start, hourlyWage: 40)],
                            standardByDay: [nil, nil, nil, nil, nil, 5, nil], travelPerDay: 10)]
var friday = Shift(id: "fri", start: LocalTime.date(2026, 10, 6, 8), end: LocalTime.date(2026, 10, 6, 14)) // 6 hours of 5
friday.workplaceId = "cafe"
let fridayPay = Calc.breakdown(friday, two)
expect(near(fridayPay.regularHours, 5) && near(fridayPay.ot1Hours, 1) && near(fridayPay.pay, 5 * 40 + 40 * 1.25),
       "its own wage and standard")
let twoTotals = Calc.periodTotals([friday, beforeRaise], two, range: november, asOf: now.ms)
expect(near(twoTotals.travel, 20 + 10) && near(twoTotals.pay, 8 * 50 + fridayPay.pay), "each workplace's wages and travel")
var gone = friday
gone.workplaceId = "deleted"
expect(near(Calc.breakdown(gone, two).pay, 6 * 50), "a shift of a workplace that is gone counts as the own one's")

// its employer's rules: overtime at 150% from the first hour, and 10% to the pension
two.workplaces[0].rules.overtime1Mult = 1.5
two.workplaces[0].rules.pensionPercent = 10
expect(near(Calc.breakdown(friday, two).pay, 5 * 40 + 40 * 1.5), "its own overtime's rate")
expect(near(Calc.breakdown(beforeRaise, two).pay, 8 * 50) && two.overtime1Mult == 1.25, "the own one's rules unchanged")
let twoNet = Calc.periodNet([friday, beforeRaise], two, range: november, asOf: now.ms, projected: false)
expect(near(twoNet.pension, 8 * 50 * 0.06 + 5 * 40 * 0.10), "each employer's share of the pension")

// the days off left of each workplace: its own payslip, its own days off
two.workplaces[0].rules.balanceDate = LocalTime.date(2026, 9, 30)
two.workplaces[0].rules.vacationBalance = 4
var cafeVacation = Shift(id: "cv", start: LocalTime.date(2026, 10, 13, 12), end: LocalTime.date(2026, 10, 13, 12), type: .vacation)
cafeVacation.workplaceId = "cafe"
let ownVacation = Shift(id: "ov", start: LocalTime.date(2026, 10, 12, 12), end: LocalTime.date(2026, 10, 12, 12), type: .vacation)
let cafeLeave = Calc.leave([cafeVacation, ownVacation], two, asOf: LocalTime.date(2026, 10, 20), at: "cafe")
expect(cafeLeave.map { $0.vacationTaken == 1 && $0.months == 0 && near($0.vacation, 4 - 1) } == true,
       "the café's balance: no month yet, its day off alone")
expect(Calc.leave([cafeVacation, ownVacation], two, asOf: LocalTime.date(2026, 10, 20)) == nil, "the own one's not kept")
expect(two.place("cafe").rules.pensionPercent == 10 && two.place(nil).rules == s.rules, "each workplace's rules read alike")

// in JSON and back
let twoBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(two))
let globalBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(global))
let fridayBack = try! JSONDecoder().decode(Shift.self, from: try! JSONEncoder().encode(friday))
expect(twoBack.workplaces == two.workplaces && globalBack.payTerms == global.payTerms && fridayBack.workplaceId == "cafe",
       "the workplaces, the pay's terms and a shift's workplace")
expect((try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(s))).payTerms.isEmpty, "none by default")

// a workplace saved before each employer's rules were its own keeps the own one's, without its payslip's days off
var ruled = Settings()
ruled.autoBreakMinutes = 30
ruled.vacationBalance = 5
ruled.balanceDate = LocalTime.date(2026, 9, 30)
ruled.workplaces = [Workplace(id: "cafe", name: "קפה", pay: [PayTerms(id: "cafe-pay", from: PayTerms.start)])]
var olderJSON = try! JSONSerialization.jsonObject(with: try! JSONEncoder().encode(ruled)) as! [String: Any]
var olderPlaces = olderJSON["workplaces"] as! [[String: Any]]
olderPlaces[0]["rules"] = nil
olderJSON["workplaces"] = olderPlaces
let older = try! JSONDecoder().decode(Settings.self, from: try! JSONSerialization.data(withJSONObject: olderJSON))
expect(older.workplaces[0].rules.autoBreakMinutes == 30 && older.workplaces[0].rules.balanceDate == nil
       && older.workplaces[0].rules.vacationBalance == 0 && older.rules == ruled.rules,
       "an older workplace takes the own rules, not the own payslip")
let kept = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(ruled))
expect(kept.workplaces[0].rules.autoBreakMinutes == 0 && kept.workplaces == ruled.workplaces, "a workplace's own rules stay its own")

// each workplace's own pay month: the café's from the 10th, its target counted by it, and a month November holds in
// part for its share of the days. 1:30 over on Thursday 5 November (the month from 10 October), 1:30 and 0:36 over on
// 15 and 16 November (the month from 10 November): only the second month reaches the target of 2 hours
var tenth = s
tenth.workplaces = [Workplace(id: "cafe", name: "קפה",
                              pay: [PayTerms(id: "cafe-global", from: PayTerms.start, kind: .monthly, monthlySalary: 6_000,
                                             overtimeCover: .tiers, overtimeTiers: [OvertimeTier(hours: 2, amount: 300)])],
                              monthStartDay: 10)]
func atCafe(_ id: String, _ day: Int, _ endHour: Int, _ endMinute: Int) -> Shift {
    var shift = Shift(id: id, start: LocalTime.date(2026, 10, day, 8), end: LocalTime.date(2026, 10, day, endHour, endMinute))
    shift.workplaceId = "cafe"
    return shift
}
let cafeMonths = [atCafe("c5", 5, 18, 6), atCafe("c15", 15, 18, 6), atCafe("c16", 16, 17, 12)]
expect(tenth.monthStartDay(of: "cafe") == 10 && tenth.monthStartDay(of: nil) == 1 && two.monthStartDay(of: "cafe") == 1,
       "a workplace's month, or else the own one's")
expect(near(Calc.extraOvertime(cafeMonths, tenth, range: november, asOf: now.ms), 300 * 21.0 / 30),
       "the target of the month from 10 November, for its 21 days in November")
tenth.workplaces[0].monthStartDay = nil
expect(near(Calc.extraOvertime(cafeMonths, tenth, range: november, asOf: now.ms), 300), "by the own month: all of it in November")
var ownMonth = s
var ownPlace = ownMonth.place(nil)
ownPlace.monthStartDay = 25
ownMonth.setPlace(nil, ownPlace)
expect(ownMonth.monthStartDay == 25 && ownMonth.place(nil).monthStartDay == 25, "the own workplace's month is the settings'")
tenth.workplaces[0].monthStartDay = 10
let tenthBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(tenth))
expect(tenthBack.workplaces[0].monthStartDay == 10 && twoBack.workplaces[0].monthStartDay == nil, "in JSON, and none until chosen")

// what the employer saves besides, and the study fund taken off the net up to its ceiling of 15,712 a month
var saving = s
saving.studyFundPercent = 2.5
saving.studyFundEmployerPercent = 7.5
saving.severancePercent = 8.33
let saved = Calc.netPay(gross: 20_000, pensionable: 20_000, saving)
let unsaved = Calc.netPay(gross: 20_000, pensionable: 20_000, s)
expect(near(saved.studyFund, 15_712 * 0.025) && near(saved.employer.studyFund, 15_712 * 0.075), "the study fund up to its ceiling")
expect(near(saved.employer.pension, 20_000 * 0.065) && near(saved.employer.severance, 20_000 * 0.0833), "the employer's pension and severance")
expect(near(unsaved.net - saved.net, 15_712 * 0.025) && unsaved.studyFund == 0, "the study fund off the net, none by default")

// travel as a fixed sum a month: in a period worked in, instead of each day's
var monthTravel = s
monthTravel.travelPerDay = 20
monthTravel.travelMonthly = 600
expect(near(Calc.periodTotals([beforeRaise], monthTravel, range: november, asOf: now.ms).travel, 600), "the month's sum, not 20 a day")
expect(Calc.periodTotals([], monthTravel, range: november, asOf: now.ms).travel == 0, "none in a period not worked in")
monthTravel.travelMonthly = nil
expect(near(Calc.periodTotals([beforeRaise], monthTravel, range: november, asOf: now.ms).travel, 20), "by the day again")

// a yearly bonus of 12,000 with July's pay, accrued on 1 November 2026: 123 of the 365 days from 1 July
var yearly = s
yearly.payTerms = [PayTerms(id: "base", from: PayTerms.start, hourlyWage: 50, bonus: 12_000, bonusMonth: 6)]
let accrued = Calc.accruedBonuses(yearly, at: LocalTime.date(2026, 10, 1))
expect(accrued.count == 1 && abs(accrued[0].accrued - 12_000.0 * 123 / 365) < 1 && accrued[0].due == LocalTime.date(2027, 6, 1),
       "123 days of the year to 1 July 2027")
expect(Calc.accruedBonuses(s, at: now).isEmpty, "none without a bonus")

// the letter's fields in JSON, as the own workplace's
var letter = s
letter.studyFundPercent = 2.5
letter.severancePercent = 8.33
letter.travelMonthly = 600
let letterBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(letter))
expect(letterBack.studyFundPercent == 2.5 && letterBack.severancePercent == 8.33 && letterBack.place(nil).travelMonthly == 600
       && letterBack.place(nil).rules.studyFundPercent == 2.5 && Settings().travelMonthly == nil, "in JSON, as the own workplace's")

// seniority: the vacation days a year by the law, and recuperation pay
expect(Calc.legalVacationDays(year: 1, sixDays: false, extensionOrder: true) == 12
       && Calc.legalVacationDays(year: 6, sixDays: false, extensionOrder: true) == 17
       && Calc.legalVacationDays(year: 9, sixDays: false, extensionOrder: true) == 23, "the extension order's 12, 17 and 23")
expect(Calc.legalVacationDays(year: 6, sixDays: false, extensionOrder: false) == 14
       && Calc.legalVacationDays(year: 12, sixDays: false, extensionOrder: false) == 20
       && Calc.legalVacationDays(year: 13, sixDays: true, extensionOrder: true) == 24, "the law's, in a five-day week and a six-day one")
var senior = s
senior.startDate = LocalTime.date(2021, 2, 15) // 15 March 2021
let worked = Calc.seniority(from: LocalTime.date(2021, 2, 15), to: LocalTime.date(2026, 10, 1))
expect(worked.years == 5 && worked.months == 7, "5 years and 7 months on 1 November 2026")
expect(Calc.vacationDaysPerYear(senior, at: nil, on: LocalTime.date(2026, 10, 1)) == 17, "2026, the 6th calendar year: 17")
let july = Calc.period(around: LocalTime.date(2026, 6, 15), monthStartDay: 1)
expect(near(Calc.recuperation(senior, range: july), 7 * 451.5) && Calc.recuperation(senior, range: november) == 0,
       "July's: 5 years done, 7 days at 451.5; none in November")
expect(near(Calc.periodTotals([], senior, range: july).recuperation, 7 * 451.5), "in July's income")
expect(Calc.upcomingRecuperation(senior, at: LocalTime.date(2026, 10, 1)).first.map { $0.due == LocalTime.date(2027, 6, 1) && $0.days == 7 } == true,
       "the next, with July 2027's pay")
senior.extensionOrder = false
expect(Calc.vacationDaysPerYear(senior, at: nil, on: LocalTime.date(2026, 10, 1)) == 14, "without the extension order: 14")
senior.vacationDaysPerYear = 20
expect(Calc.vacationDaysPerYear(senior, at: nil, on: LocalTime.date(2026, 10, 1)) == 20, "more of the employer's")
expect(Calc.recuperationDays(year: 1) == 5 && Calc.recuperationDays(year: 3) == 6 && Calc.recuperationDays(year: 10) == 7
       && Calc.recuperationDays(year: 20) == 10, "recuperation days by the years of work")
senior.recuperationMonthly = true
expect(near(Calc.recuperation(senior, range: november), 7 * 451.5 / 12), "or a twelfth each month")
senior.standardByDay = [4, 4, 4, 4, 4, nil, nil]
expect(near(Calc.recuperation(senior, range: november), 7 * 451.5 * 20 / 42 / 12), "a part-time job's share: 20 hours of 42")
var fresh = s
fresh.startDate = LocalTime.date(2026, 8, 1)
expect(Calc.recuperation(fresh, range: july) == 0 && Calc.upcomingRecuperation(fresh, at: LocalTime.date(2026, 10, 1)).isEmpty,
       "none in the first year")
let seniorBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(senior))
expect(seniorBack.startDate == senior.startDate && !seniorBack.extensionOrder && seniorBack.recuperationMonthly
       && seniorBack.place(nil).startDate == senior.startDate && Settings().startDate == nil, "in JSON, as the own workplace's")

// a day of reserve duty, for the record: no hours or pay, nothing missing, and no day of work ahead in the projection
let withReserve = (shifts + [off(10, .reserve)]).sorted { $0.start > $1.start } // Tuesday 10 November
let reserveSummary = Calc.summary(withReserve, s, range: november, asOf: now.ms)
let reserveDay = reserveSummary.days["2026-10-10"]
expect(reserveDay?.dayOff == .reserve && reserveDay?.pay == 0 && reserveDay?.netHours == 0 && reserveDay?.short == false, "a day of reserve duty")
expect(near(reserveSummary.totals.total, summary.totals.total) && reserveSummary.totals.count == summary.totals.count
       && near(reserveSummary.shortfall.total, summary.shortfall.total), "it pays nothing and misses nothing")
let fifthEvening = LocalTime.date(2026, 10, 5, 20).ms
expect(Calc.projectedIncome(withReserve, s, range: november, asOf: fifthEvening)
       < Calc.projectedIncome(shifts, s, range: november, asOf: fifthEvening), "not a day of work in the projection")
expect(try! JSONDecoder().decode(Shift.self, from: try! JSONEncoder().encode(off(10, .reserve))).type == .reserve, "in JSON")

// the running shift's start dragged on the dial: the last time at the angle before now, by five minutes
let dragNow = LocalTime.date(2026, 10, 3, 12, 32)
let angle = { (h: Int, m: Int) in Calc.dialDegrees(LocalTime.date(2026, 10, 3, h, m)) }
expect(Format.clock(Calc.dialStart(angle(7, 2), now: dragNow)) == "07:00" && Format.clock(Calc.dialStart(angle(7, 3), now: dragNow)) == "07:05",
       "07:02's angle at 12:32: 07:00, and 07:03's 07:05")
expect(Calc.dialStart(angle(12, 31), now: dragNow) == Date(ms: dragNow.ms - 300_000), "five minutes before now at the latest")
expect(Format.clock(Calc.dialStart(angle(10, 0), now: dragNow, latest: LocalTime.date(2026, 10, 3, 9, 30))) == "09:30", "not after its first break")
expect(Format.clock(Calc.dialStart(angle(6, 0), now: dragNow, earliest: LocalTime.date(2026, 10, 3, 6, 30))) == "06:30",
       "not before the shift before it ended")

// the Hebrew date (Settings › תצוגה): in letters, and a period's Hebrew months
expect(Format.gematria(23) == "כ״ג" && Format.gematria(15) == "ט״ו" && Format.gematria(16) == "ט״ז" && Format.gematria(1) == "א׳"
       && Format.gematria(20) == "כ׳" && Format.gematria(5787) == "תשפ״ז", "numbers in Hebrew letters")
expect(Format.hebrewDate(LocalTime.date(2026, 10, 3, 9)) == "כ״ג בחשוון", "3 November 2026: 23 Heshvan")
expect(Format.hebrewDate(LocalTime.date(2027, 2, 10, 9)) == "א׳ באדר ב׳", "10 March 2027, a leap year: 1 Adar II")
expect(Format.hebrewDate(LocalTime.date(2026, 1, 20, 9)) == "ג׳ באדר", "20 February 2026, not a leap year: 3 Adar")
expect(Format.hebrewMonths(october) == "תשרי–חשוון תשפ״ז", "October 2026's Hebrew months")
expect(Format.hebrewMonths(Calc.period(around: LocalTime.date(2025, 8, 15), monthStartDay: 1)) == "אלול תשפ״ה–תשרי תשפ״ו",
       "September 2025, across Rosh Hashana")

print(failures == 0 ? "Period: all checks passed" : "Period: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
