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

// the end of the work (a workplace's page › סיום העבודה): the notice by the law, in calendar days
expect(Calc.noticeDays(months: 0, monthly: true) == 0 && Calc.noticeDays(months: 6, monthly: true) == 6
       && Calc.noticeDays(months: 8, monthly: true) == 11 && Calc.noticeDays(months: 11, monthly: true) == 18.5
       && Calc.noticeDays(months: 12, monthly: true) == nil, "by the month: a day a month to six, then 2.5, a month from a year")
expect(Calc.noticeDays(months: 11, monthly: false) == 11 && Calc.noticeDays(months: 12, monthly: false) == 14
       && Calc.noticeDays(months: 15, monthly: false) == 15 && Calc.noticeDays(months: 23, monthly: false) == 19
       && Calc.noticeDays(months: 24, monthly: false) == 21 && Calc.noticeDays(months: 35, monthly: false) == 26
       && Calc.noticeDays(months: 36, monthly: false) == nil, "by the hour: 14 and 21 days and one for each two months, a month from three years")
func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }
// a global salary from 1 March 2023, six percent to the fund's severance, recuperation with July's pay
var leaver = s
leaver.startDate = LocalTime.date(2023, 2, 1)
leaver.payTerms = [PayTerms(id: "global", from: PayTerms.start, kind: .monthly, monthlySalary: 12_000)]
leaver.balanceDate = LocalTime.date(2025, 11, 31)
leaver.vacationBalance = 10
let tookOff = Shift(id: "v", start: LocalTime.date(2026, 1, 10, 12), end: LocalTime.date(2026, 1, 10, 12), type: .vacation)
let threeYears = Calc.termination([tookOff], leaver, at: nil, lastDay: LocalTime.date(2026, 1, 28))! // to 28 February 2026
expect(threeYears.years == 3 && threeYears.months == 0 && close(threeYears.exactYears, 3), "three years to the end of the last day")
expect(close(threeYears.severance(.dismissal), 36_000) && close(threeYears.severance(.resignation), 36_000 * 0.72),
       "dismissed: a month's pay a year; resigning: the fund's 6% of 8.33")
expect(threeYears.noticeDays == nil && close(threeYears.noticePay, 12_000), "a month's notice, or its pay")
expect(close(threeYears.vacationDays ?? -1, 10) && close(threeYears.vacationPay, 10 * 12_000 / (5.0 * 52 / 12)),
       "the payslip's 10, a month's 1, less the day taken, each at the month over 21.67")
expect(close(threeYears.recuperationDays ?? -1, 6) && close(threeYears.recuperationPay, 6 * 451.5),
       "the third year's 6 recuperation days, not yet paid by July's")
expect(close(threeYears.total(.dismissal), 36_000 + threeYears.vacationPay + 6 * 451.5), "the total, the notice apart")
expect(Calc.termination([], leaver, at: nil, lastDay: LocalTime.date(2024, 1, 29))?.severance(.dismissal) == 12_000,
       "a year to the day: a month's pay")
expect(Calc.termination([], leaver, at: nil, lastDay: LocalTime.date(2023, 9, 31))?.noticeDays == 11, "eight months: 11 days")
expect(Calc.termination([], s, at: nil, lastDay: now) == nil && Calc.termination([], leaver, at: nil, lastDay: LocalTime.date(2023, 0, 1)) == nil,
       "none without the start, or before it")
leaver.severancePercent = 8.33
expect(Calc.termination([], leaver, at: nil, lastDay: LocalTime.date(2026, 1, 28))?.fund == 36_000, "8.33% stands for all of it")
// by the hour from 15 January 2025, 42 hours a week: a month of 182
var hourly = s
hourly.startDate = LocalTime.date(2025, 0, 15)
hourly.standardByDay = [8.4, 8.4, 8.4, 8.4, 8.4, nil, nil]
let byHour = Calc.termination([], hourly, at: nil, lastDay: LocalTime.date(2026, 8, 14))! // to 14 September 2026
expect(byHour.years == 1 && byHour.months == 8 && close(byHour.monthPay, 50 * 182) && close(byHour.severance(.dismissal), 50 * 182 * 20 / 12),
       "a year and eight months at 182 hours a month")
expect(byHour.noticeDays == 18 && close(byHour.noticePay, 50 * 182 * 18 / 30) && byHour.vacationDays == nil, "18 days; no balance kept")
expect(close(byHour.recuperationDays ?? -1, 4) && close(byHour.recuperationPay, 4 * 451.5),
       "the first year's 5 paid in July 2026, the second's two thirds of 6 not yet")
hourly.recuperationMonthly = true
expect(close(Calc.termination([], hourly, at: nil, lastDay: LocalTime.date(2026, 8, 14))?.recuperationDays ?? -1, 9 - 8 * 5.0 / 12),
       "paid by the month: eight twelfths of the first year's 5 so far")
hourly.startDate = LocalTime.date(2026, 0, 1)
let firstYear = Calc.termination([], hourly, at: nil, lastDay: LocalTime.date(2026, 7, 31))! // eight months
expect(!firstYear.severanceDue && close(firstYear.severance(.dismissal), 50 * 182 * 8 / 12 * 0.72) && firstYear.noticeDays == 8
       && firstYear.recuperationDays == 0, "before a year: the fund's money alone, 8 days' notice, no recuperation yet")

// the work's span (a workplace's page › תקופת העבודה): its month's pay, bonus and recuperation pay in it alone
var spanned = s
spanned.payTerms = [PayTerms(id: "global", from: PayTerms.start, kind: .monthly, monthlySalary: 12_000, bonus: 6_000, bonusMonth: 6)]
spanned.startDate = LocalTime.date(2026, 10, 16) // 16 November 2026
expect(Calc.periodTotals([], spanned, range: october).salary == 0, "no month's pay before the start")
expect(near(Calc.periodTotals([], spanned, range: november).salary, 12_000 * 15 / 30), "November from the 16th: 15 days of 30")
spanned.startDate = LocalTime.date(2025, 0, 1)
spanned.endDate = LocalTime.date(2026, 10, 10) // the last day, 10 November 2026
expect(near(Calc.periodTotals([], spanned, range: november).salary, 12_000 * 10 / 30) && Calc.periodTotals([], spanned, range: december).salary == 0,
       "to the end of the 10th, and none after")
let july2027 = Calc.period(around: LocalTime.date(2027, 6, 15), monthStartDay: 1)
expect(Calc.periodTotals([], spanned, range: july).bonus == 6_000 && Calc.periodTotals([], spanned, range: july2027).bonus == 0
       && Calc.accruedBonuses(spanned, at: LocalTime.date(2027, 0, 1)).isEmpty, "the bonus while working there alone")
expect(near(Calc.periodTotals([], spanned, range: july).recuperation, 5 * 451.5) && Calc.periodTotals([], spanned, range: july2027).recuperation == 0
       && Calc.upcomingRecuperation(spanned, at: LocalTime.date(2026, 11, 1)).isEmpty, "recuperation pay too")
spanned.balanceDate = LocalTime.date(2026, 0, 31)
let atEnd = Calc.leave([], spanned, asOf: LocalTime.date(2026, 10, 10))!
let later = Calc.leave([], spanned, asOf: LocalTime.date(2027, 2, 1))!
expect(atEnd.months > 0 && later.months == atEnd.months && later.vacation == atEnd.vacation, "no vacation days added after the last day")
let spannedPlace = spanned.place(nil)
expect(spannedPlace.employs(LocalTime.date(2026, 10, 10, 23)) && spannedPlace.ended(by: LocalTime.date(2026, 10, 11))
       && !spannedPlace.employs(LocalTime.date(2024, 11, 31)) && !Settings().place(nil).ended(by: now), "the last day in it, the next not")
spanned.nightShift = true
spanned.workplaces = [Workplace(id: "w", name: "w", pay: [PayTerms(id: "w-pay", from: PayTerms.start)], endDate: LocalTime.date(2026, 5, 30))]
spanned.workplaces[0].rules.nightShift = true
let spannedBack = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(spanned))
expect(spannedBack.endDate == spanned.endDate && spannedBack.nightShift && spannedBack.workplaces[0].endDate == LocalTime.date(2026, 5, 30)
       && spannedBack.workplaces[0].rules.nightShift && Settings().endDate == nil && !Settings().nightShift, "in JSON")

// a night shift, two hours or more between 22:00 and 06:00, where it is set: a day of 7 hours, then overtime
var nightRules = s
let overnight = Shift(id: "n", start: LocalTime.date(2026, 10, 1, 22), end: LocalTime.date(2026, 10, 2, 7)) // Sunday to Monday
expect(near(Calc.breakdown(overnight, nightRules).regularHours, 9) && Calc.breakdown(overnight, nightRules).overtimeHours == 0,
       "without it: 9 hours of Sunday's 9:36")
nightRules.nightShift = true
expect(near(Calc.breakdown(overnight, nightRules).regularHours, 7) && near(Calc.breakdown(overnight, nightRules).ot1Hours, 2),
       "with it: 7 hours, then 2 at 125%")
let evening = Shift(id: "e", start: LocalTime.date(2026, 10, 2, 16), end: LocalTime.date(2026, 10, 2, 23, 30))
expect(near(Calc.breakdown(evening, nightRules).regularHours, 7.5) && Calc.breakdown(evening, nightRules).overtimeHours == 0,
       "an hour and a half of night is no night shift")
let sevenNight = Shift(id: "n7", start: LocalTime.date(2026, 10, 8, 23), end: LocalTime.date(2026, 10, 9, 6))
expect(Calc.shortfall([sevenNight], nightRules, range: november).total == 0, "7 hours of a night shift miss nothing")
let lateShift = Shift(id: "late", start: LocalTime.date(2026, 10, 1, 21))
let morningShift = Shift(id: "morning", start: LocalTime.date(2026, 10, 1, 8))
expect(Calc.goalHours(lateShift, nightRules, asOf: LocalTime.date(2026, 10, 1, 22).ms) == 7
       && Calc.goalHours(morningShift, nightRules, asOf: LocalTime.date(2026, 10, 1, 9).ms) == 9.6, "the dial's goal: 7 into the night, else the day's")
nightRules.nightShift = false
expect(near(Calc.shortfall([sevenNight], nightRules, range: november).total, 9.6 - 7)
       && Calc.goalHours(lateShift, nightRules, asOf: LocalTime.date(2026, 10, 1, 22).ms) == 9.6, "without it, Sunday's standard")

// the Hebrew date (Settings › תצוגה): in letters, and a period's Hebrew months
expect(Format.gematria(23) == "כ״ג" && Format.gematria(15) == "ט״ו" && Format.gematria(16) == "ט״ז" && Format.gematria(1) == "א׳"
       && Format.gematria(20) == "כ׳" && Format.gematria(5787) == "תשפ״ז", "numbers in Hebrew letters")
expect(Format.hebrewDate(LocalTime.date(2026, 10, 3, 9)) == "כ״ג בחשוון", "3 November 2026: 23 Heshvan")
expect(Format.hebrewDate(LocalTime.date(2027, 2, 10, 9)) == "א׳ באדר ב׳", "10 March 2027, a leap year: 1 Adar II")
expect(Format.hebrewDate(LocalTime.date(2026, 1, 20, 9)) == "ג׳ באדר", "20 February 2026, not a leap year: 3 Adar")
expect(Format.hebrewMonths(october) == "תשרי–חשוון תשפ״ז", "October 2026's Hebrew months")
expect(Format.hebrewMonths(Calc.period(around: LocalTime.date(2025, 8, 15), monthStartDay: 1)) == "אלול תשפ״ה–תשרי תשפ״ו",
       "September 2025, across Rosh Hashana")

// overtime as the law counts it (Settings.lawOvertime), kolzchut.org.il's examples: a week of November 2026, Sunday the 1st
func lawChecks() {
    /// A shift of that month, to the minute.
    func span(_ day: Int, _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, holiday: Bool = false) -> Shift {
        Shift(id: "span\(day)-\(h1)", start: LocalTime.date(2026, 10, day, h1, m1), end: LocalTime.date(2026, 10, day, h2, m2), isHoliday: holiday)
    }
    func counted(_ list: [Shift], _ settings: Settings) -> [String: Breakdown] {
        let before = Calc.workedBefore(list, settings)
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, Calc.breakdown($0, settings, before: before[$0.id])) })
    }
    var six = Settings()
    six.lawOvertime = true
    six.standardByDay = [8, 8, 8, 8, 8, 7, nil]
    six.regularDailyHours = 8

    // off, as it was: each shift alone against the day's standard
    var off = six
    off.lawOvertime = false
    let splitOff = counted([span(1, 8, 0, 13, 0), span(1, 17, 0, 22, 0)], off)
    expect(Calc.workedBefore([span(1, 8, 0, 13, 0)], off).isEmpty, "nothing to walk through with the law's count off")
    expect(splitOff.values.allSatisfy { $0.overtimeHours == 0 && $0.before == nil }, "off: two shifts of five hours, no overtime")

    // example 1: a day's overtime leaves 42 regular hours, so no week's overtime
    let one = counted([span(1, 8, 0, 17, 0), span(2, 8, 0, 15, 0), span(3, 8, 0, 15, 0), span(4, 8, 0, 15, 0), span(5, 8, 0, 15, 0), span(6, 8, 0, 14, 0)], six)
    expect(near(one["span1-8"]!.ot1Hours, 1) && near(one["span6-8"]!.regularHours, 6) && one["span6-8"]!.overtimeHours == 0,
           "Sunday's ninth hour at 125%, none on Friday")
    // example 2: 45 hours, none of them past a day's standard but Friday's
    let two = counted([span(1, 8, 0, 16, 0), span(2, 8, 0, 16, 0), span(3, 8, 0, 16, 0), span(4, 8, 0, 16, 0), span(5, 8, 0, 16, 0), span(6, 8, 0, 13, 0)], six)
    expect(near(two["span6-8"]!.regularHours, 2) && near(two["span6-8"]!.ot1Hours, 2) && near(two["span6-8"]!.ot2Hours, 1),
           "Friday: two regular, two at 125%, one at 150%")
    expect(near(two["span6-8"]!.pay, (2 + 2 * 1.25 + 1.5) * 50), "and what they pay")
    // example 3: a day's overtime does not use up the last day's first tier
    let three = counted([span(1, 8, 0, 17, 0), span(2, 8, 0, 16, 0), span(3, 8, 0, 16, 0), span(4, 8, 0, 16, 0), span(5, 8, 0, 16, 0), span(6, 8, 0, 13, 0)], six)
    expect(near(three["span1-8"]!.ot1Hours, 1) && near(three["span6-8"]!.regularHours, 2) && near(three["span6-8"]!.ot1Hours, 2)
           && near(three["span6-8"]!.ot2Hours, 1), "46 hours: the same Friday")
    // example 4: 8:36 a day and a short day of 7:36, all worked at 8:36: its last hour at 125%, then Friday's
    var five = six
    five.standardByDay = [8.6, 8.6, 8.6, 8.6, 7.6, nil, nil]
    let four = counted([span(1, 8, 0, 16, 36), span(2, 8, 0, 16, 36), span(3, 8, 0, 16, 36), span(4, 8, 0, 16, 36), span(5, 8, 0, 16, 36), span(6, 8, 0, 11, 0)], five)
    expect(near(four["span5-8"]!.ot1Hours, 1) && abs(four["span6-8"]!.regularHours) < 1e-9 && near(four["span6-8"]!.ot1Hours, 2)
           && near(four["span6-8"]!.ot2Hours, 1), "46 hours in a five-day week")
    // example 5: a paid day off counts as a day worked in full
    var vacation = Shift(id: "off5", start: LocalTime.date(2026, 10, 5, 12), end: LocalTime.date(2026, 10, 5, 12))
    vacation.type = .vacation
    let fifth = counted([span(1, 8, 0, 16, 36), span(2, 8, 0, 16, 36), span(3, 8, 0, 16, 36), span(4, 8, 0, 16, 36), vacation, span(6, 8, 0, 12, 0)], five)
    expect(abs(fifth["span6-8"]!.regularHours) < 1e-9 && near(fifth["span6-8"]!.ot1Hours, 2) && near(fifth["span6-8"]!.ot2Hours, 2),
           "Friday's four hours at 125% and 150%")
    // and so does a holiday not worked on a day of work: Yom Ha'atzmaut 2026, Wednesday 22 April
    var april = five
    april.holidayEveHours = 0
    april.standardByDay = [8.6, 8.6, 8.6, 8.6, 7.6, nil, nil]
    func spanApril(_ day: Int, _ h2: Int, _ m2: Int) -> Shift {
        Shift(id: "april\(day)", start: LocalTime.date(2026, 3, day, 8), end: LocalTime.date(2026, 3, day, h2, m2))
    }
    let holidayWeek = counted([spanApril(19, 16, 36), spanApril(20, 16, 36), spanApril(21, 16, 36), spanApril(23, 15, 36), spanApril(24, 10, 0)], april)
    expect(abs(holidayWeek["april24"]!.regularHours) < 1e-9 && near(holidayWeek["april24"]!.ot1Hours, 2), "the holiday among the week's 42")

    // two shifts of a day count together, and the first tier is the day's
    var day = six
    day.standardByDay = [8.6, 8.6, 8.6, 8.6, 8.6, nil, nil]
    let split = counted([span(1, 8, 0, 13, 0), span(1, 17, 0, 22, 0)], day)
    expect(near(split["span1-8"]!.regularHours, 5) && near(split["span1-17"]!.regularHours, 3.6) && near(split["span1-17"]!.ot1Hours, 1.4),
           "five and five hours: 1:24 of overtime")
    let long = counted([span(1, 6, 0, 16, 36), span(1, 17, 0, 20, 0)], day)
    expect(near(long["span1-6"]!.ot1Hours, 2) && long["span1-17"]!.ot1Hours == 0 && near(long["span1-17"]!.ot2Hours, 3), "the day's first two hours, then 150%")
    expect(split["span1-17"]!.before?.dayRegular == 5, "what it was counted after")

    // the shifts of two employers do not add up
    var two2 = day
    let otherPlace = Workplace(id: "other", name: "אחר", pay: [PayTerms(id: "p", from: PayTerms.start)], standardByDay: day.standardByDay, rules: day.rules)
    two2.workplaces = [otherPlace]
    var atOther = span(1, 17, 0, 22, 0)
    atOther.workplaceId = "other"
    let apart = counted([span(1, 8, 0, 13, 0), atOther], two2)
    expect(apart.values.allSatisfy { $0.overtimeHours == 0 }, "five hours at each: no overtime")

    // Shabbat: 150% for the regular hours, then 175% and 200%; from the first hour after a full week
    var week = six
    week.standardByDay = [8.4, 8.4, 8.4, 8.4, 8.4, nil, nil]
    let saturday = span(7, 8, 0, 16, 0, holiday: true)
    let fullWeek = counted([span(1, 8, 0, 16, 24), span(2, 8, 0, 16, 24), span(3, 8, 0, 16, 24), span(4, 8, 0, 16, 24), span(5, 8, 0, 16, 24), saturday], week)
    expect(abs(fullWeek[saturday.id]!.pay - 775) < 1e-6, "eight hours of Shabbat after a full week: ₪775")
    expect(near(Calc.breakdown(saturday, off).pay, 600), "off: ₪600")
    let twelve = span(7, 6, 0, 18, 0, holiday: true)
    expect(abs(Calc.breakdown(twelve, six).pay - 975) < 1e-9 && near(Calc.breakdown(twelve, off).pay, 900), "twelve hours of Shabbat: ₪975, off ₪900")
    expect(near(Calc.breakdown(twelve, six).basePay, 600) && near(Calc.breakdown(twelve, six).otPay, 375), "its base and its overtime")

    // a global pay's overtime is counted so too
    var global = day
    global.payTerms = [PayTerms(id: "g", from: PayTerms.start, kind: .monthly, monthlySalary: 18_200, overtimeCover: .none)]
    let novemberRange = Calc.period(around: LocalTime.date(2026, 10, 15), monthStartDay: 1)
    let globalShifts = [span(1, 8, 0, 13, 0), span(1, 17, 0, 22, 0)]
    expect(abs(Calc.extraOvertime(globalShifts, global, range: novemberRange, asOf: LocalTime.date(2026, 10, 15).ms) - 1.4 * 1.25 * 100) < 1e-9,
           "1:24 of overtime at the hour's worth")
    expect(near(Calc.monthlyOvertime(globalShifts, global, range: novemberRange)?.hours ?? 0, 1.4), "and in its month's count")

    // the running shift: what its day and week leave of the goal
    var evening = span(1, 17, 0, 22, 0)
    evening.end = nil
    let eveningNow = LocalTime.date(2026, 10, 1, 21, 0)
    let status = Calc.nowStatus([evening, span(1, 8, 0, 13, 0)], day, active: evening, at: eveningNow.ms)
    expect(near(status.goal, 3.6) && near(status.overtimeHours, 0.4) && status.remaining < 0, "the morning's five hours off the goal")
    let dial = Calc.dial(evening, day, at: eveningNow, before: WorkedBefore(dayRegular: 5, dayOvertime: 0, weekRegular: 5))
    expect(near(dial.goalDeg ?? 0, 3.6 * 30), "the dial's flag with it")
    let leaving = Calc.leaving(evening, at: eveningNow, day, now: eveningNow, before: WorkedBefore(dayRegular: 5, dayOvertime: 0, weekRegular: 5))
    expect(near(leaving.overtimeHours, 0.4), "and leaving then")
    let quota = Calc.goalHours(evening, day, asOf: eveningNow.ms, before: WorkedBefore(dayRegular: 0, dayOvertime: 0, weekRegular: 42))
    expect(quota == 0, "the week's hours done: no goal left")

    // a new shift's mark, by the clock
    expect(Calc.isRestDay(LocalTime.date(2026, 10, 7, 10), day) && !Calc.isRestDay(LocalTime.date(2026, 10, 7, 19), day), "Shabbat's day, and its evening")
    expect(Calc.isRestDay(LocalTime.date(2026, 10, 6, 20), day) && !Calc.isRestDay(LocalTime.date(2026, 10, 6, 10), day), "Friday evening, and its morning")
    expect(Calc.isRestDay(LocalTime.date(2026, 8, 21, 10), day) && Calc.isRestDay(LocalTime.date(2026, 8, 20, 19), day)
           && !Calc.isRestDay(LocalTime.date(2026, 8, 20, 10), day), "Yom Kippur, its eve's evening, and its eve's morning")
    var noHolidays = day
    noHolidays.holidaysEnabled = false
    expect(!Calc.isRestDay(LocalTime.date(2026, 8, 21, 10), noHolidays), "without the holidays, a Monday")

    // in JSON, and through the cloud's merge
    var kept = Settings()
    kept.lawOvertime = true
    kept.weeklyHours = 40
    kept.holidayPay = true
    kept.workplaces = [otherPlace]
    kept.workplaces[0].rules.lawOvertime = true
    kept.workplaces[0].rules.weeklyHours = 40
    kept.workplaces[0].rules.holidayPay = true
    let back = try! JSONDecoder().decode(Settings.self, from: try! JSONEncoder().encode(kept))
    expect(back.lawOvertime && back.weeklyHours == 40 && back.holidayPay && back.workplaces[0].rules.lawOvertime
           && back.workplaces[0].rules.weeklyHours == 40 && back.workplaces[0].rules.holidayPay, "the rules in JSON")
    expect(!Settings().lawOvertime && !Settings().holidayPay && Settings().weeklyHours == 42, "off by default")
    let oldRules = try! JSONDecoder().decode(EmployerRules.self, from: Data("{}".utf8))
    expect(!oldRules.lawOvertime && !oldRules.holidayPay && oldRules.weeklyHours == 42, "off in what was saved before them")
    let merged = Settings.merged(cloud: Settings(), local: kept)
    expect(merged.lawOvertime && merged.weeklyHours == 40 && merged.holidayPay, "through the cloud's merge")
    expect(kept.rules.lawOvertime && kept.rules.weeklyHours == 40 && kept.place(nil).rules.holidayPay, "as the own workplace's rules")
}
lawChecks()

// holiday pay (Calc.holidayPays), kolzchut.org.il's example: 7.5 hours a day at ₪40; Yom Kippur 2026, Monday 21 September
func holidayPayChecks() {
    var worker = Settings()
    worker.hourlyWage = 40
    worker.holidayPay = true
    worker.holidayEveHours = 0
    worker.standardByDay = [8.6, 8.6, 8.6, 8.6, 8.6, nil, nil]
    worker.startDate = LocalTime.date(2025, 0, 1)
    // 7:30 on each day of work of the three months before, and the day after
    var list: [Shift] = []
    var cursor = LocalTime.date(2026, 5, 21)
    while cursor <= LocalTime.date(2026, 8, 22) {
        let weekday = LocalTime.parts(cursor).weekday
        if weekday <= 4 && Holidays.info(cursor).kind != .chag {
            let p = LocalTime.parts(cursor)
            list.append(Shift(id: LocalTime.dayKey(cursor), start: LocalTime.date(p.year, p.month0, p.day, 8), end: LocalTime.date(p.year, p.month0, p.day, 15, 30)))
        }
        cursor = LocalTime.addingDays(1, to: cursor)
    }
    let september = TimeRange(start: LocalTime.date(2026, 8, 20), end: LocalTime.date(2026, 8, 24))
    let later = LocalTime.date(2026, 8, 30).ms
    let paid = Calc.holidayPays(list, worker, range: september, asOf: later)
    expect(paid.count == 1 && paid[0].name == "יום כיפור" && near(paid[0].hours, 7.5) && near(paid[0].amount, 300), "₪300, as the example")
    let totals = Calc.periodTotals(list, worker, range: september, asOf: later)
    expect(near(totals.holidayPay, 300) && near(totals.total, totals.pay + 300), "in the period's income")
    expect(Calc.summary(list, worker, range: september, asOf: later).holidayPays == paid, "and on its screens")

    // a holiday still ahead, or going on with the day after it ahead
    expect(Calc.holidayPays(list, worker, range: september, asOf: LocalTime.date(2026, 8, 20, 10).ms).isEmpty, "not before it comes")
    expect(Calc.holidayPays(list, worker, range: september, asOf: LocalTime.date(2026, 8, 21, 10).ms).count == 1, "on its day, the day after is not held against it")

    // the days around it
    let noEve = list.filter { $0.id != LocalTime.dayKey(LocalTime.date(2026, 8, 20)) }
    expect(Calc.holidayPays(noEve, worker, range: september, asOf: later).isEmpty, "nothing on the day of work before it: an absence")
    var vacationDay = Shift(id: "v", start: LocalTime.date(2026, 8, 20, 12), end: LocalTime.date(2026, 8, 20, 12))
    vacationDay.type = .vacation
    expect(Calc.holidayPays(noEve + [vacationDay], worker, range: september, asOf: later).count == 1, "a day off instead is no absence")
    var oneSum = vacationDay
    oneSum.type = .adjustment
    oneSum.amount = 10
    expect(Calc.holidayPays(noEve + [oneSum], worker, range: september, asOf: later).isEmpty, "a sum once is no day of work")
    let fromThen = list.filter { $0.start > LocalTime.date(2026, 8, 21) }
    let fresh = Calc.holidayPays(fromThen, worker, range: september, asOf: later)
    expect(fresh.count == 1 && near(fresh[0].hours, 8.6), "from before anything was recorded: not held against it, its weekday's standard")

    // who is paid
    var new = worker
    new.startDate = LocalTime.date(2026, 7, 1)
    expect(Calc.holidayPays(list, new, range: september, asOf: later).isEmpty, "under three months")
    new.startDate = LocalTime.date(2026, 5, 21)
    expect(Calc.holidayPays(list, new, range: september, asOf: later).count == 1, "three months")
    new.startDate = nil
    expect(Calc.holidayPays(list, new, range: september, asOf: later).isEmpty, "without a start date")
    var offWorker = worker
    offWorker.holidayPay = false
    expect(Calc.holidayPays(list, offWorker, range: september, asOf: later).isEmpty, "off")
    var monthly = worker
    monthly.payTerms = [PayTerms(id: "m", from: PayTerms.start, kind: .monthly, monthlySalary: 10_000)]
    expect(Calc.holidayPays(list, monthly, range: september, asOf: later).isEmpty, "a month's pay has it in it")
    var noHolidays = worker
    noHolidays.holidaysEnabled = false
    expect(Calc.holidayPays(list, noHolidays, range: september, asOf: later).isEmpty, "the holidays off")
    var ended = worker
    ended.endDate = LocalTime.date(2026, 8, 1)
    expect(Calc.holidayPays(list, ended, range: september, asOf: later).isEmpty, "after the last day")

    // Shavuot 2026, Friday 22 May: not in a week of Sunday to Thursday; in a week with Friday
    let may = TimeRange(start: LocalTime.date(2026, 4, 20), end: LocalTime.date(2026, 4, 25))
    let thursday = Shift(id: "thu", start: LocalTime.date(2026, 4, 21, 8), end: LocalTime.date(2026, 4, 21, 16))
    expect(Calc.holidayPays([thursday], worker, range: may, asOf: LocalTime.date(2026, 4, 30).ms).isEmpty, "on a Friday, a day off there")
    var sixDays = worker
    sixDays.standardByDay = [8, 8, 8, 8, 8, 7, nil]
    expect(Calc.holidayPays([thursday], sixDays, range: may, asOf: LocalTime.date(2026, 4, 30).ms).count == 1, "on a Friday, a day of work there")

    // another workplace's, at its wage, and in the net's base
    var two = Settings()
    two.holidayEveHours = 0
    two.workplaces = [Workplace(id: "x", name: "שני", pay: [PayTerms(id: "p", from: PayTerms.start, hourlyWage: 60)], startDate: LocalTime.date(2025, 0, 1))]
    two.workplaces[0].rules.holidayPay = true
    let atX = Calc.holidayPays([], two, range: september, asOf: later)
    expect(atX.count == 1 && atX[0].place == "x" && near(atX[0].amount, 8.6 * 60), "another workplace's, at its wage")
    let net = Calc.periodNet([], two, range: september, asOf: later, projected: false)
    expect(near(net.gross, 8.6 * 60) && near(net.pension, 8.6 * 60 * 0.06), "saved of as a wage")
}
holidayPayChecks()

// the sums once (Shift.amount): in the period's income, out of its hours and days
func adjustmentChecks() {
    let settings = Settings()
    let range = Calc.period(around: LocalTime.date(2026, 10, 15), monthStartDay: 1)
    let asOf = LocalTime.date(2026, 10, 10, 9).ms
    let base = [work(1, 8, 17), work(2, 8, 17)].sorted { $0.start > $1.start }
    func sum(_ id: String, _ day: Int, _ amount: Double, _ title: String) -> Shift {
        let noon = LocalTime.date(2026, 10, day, 12)
        return Shift(id: id, start: noon, end: noon, note: title, type: .adjustment, amount: amount)
    }
    let list = (base + [sum("a", 2, 500, "מענק"), sum("b", 3, -200, "מקדמה")]).sorted { $0.start > $1.start }
    let without = Calc.periodTotals(base, settings, range: range, asOf: asOf)
    let with = Calc.periodTotals(list, settings, range: range, asOf: asOf)
    expect(with.additions == 500 && with.deductions == 200 && near(with.total, without.total + 300), "added and taken off")
    expect(with.count == without.count && near(with.netHours, without.netHours) && with.workedDays == without.workedDays, "no hours, no days worked")
    let summary = Calc.summary(list, settings, range: range, asOf: asOf)
    expect(summary.days["2026-10-3"]?.adjustment == -200 && summary.days["2026-10-3"]?.dayOff == nil && summary.days["2026-10-3"]?.count == 0, "on its day, no day off")
    expect(summary.days["2026-10-2"]?.adjustment == 500 && summary.days["2026-10-2"]?.count == 1, "beside a shift")
    expect(summary.shortfall.byDay["2026-10-3"] == nil, "nothing missing on its day")
    let ahead = Calc.projectedIncome(list, settings, range: range, asOf: asOf)
    expect(near(ahead, Calc.projectedIncome(base, settings, range: range, asOf: asOf) + 300), "stays as it is in where the income is heading")
    // taxed when added, not when taken off
    let netBase = Calc.periodNet(base, settings, range: range, asOf: asOf, projected: false)
    let netOff = Calc.periodNet((base + [sum("b", 3, -200, "מקדמה")]).sorted { $0.start > $1.start }, settings, range: range, asOf: asOf, projected: false)
    expect(near(netOff.gross, netBase.gross) && near(netOff.incomeTax, netBase.incomeTax) && near(netOff.net, netBase.net - 200), "taken off the net alone")
    let netAdded = Calc.periodNet((base + [sum("a", 2, 500, "מענק")]).sorted { $0.start > $1.start }, settings, range: range, asOf: asOf, projected: false)
    expect(near(netAdded.gross, netBase.gross + 500) && near(netAdded.pension, netBase.pension), "taxed when added, not saved of")
    let aheadOff = Calc.periodNet((base + [sum("b", 3, -200, "מקדמה")]).sorted { $0.start > $1.start }, settings, range: range, asOf: asOf, projected: true)
    let aheadBase = Calc.periodNet(base, settings, range: range, asOf: asOf, projected: true)
    expect(near(aheadOff.gross, aheadBase.gross) && near(aheadOff.net, aheadBase.net - 200), "and where it is heading")
    // a month's pay has them too
    var global = settings
    global.payTerms = [PayTerms(id: "g", from: PayTerms.start, kind: .monthly, monthlySalary: 10_000)]
    let globalTotals = Calc.periodTotals(list, global, range: range, asOf: asOf)
    expect(near(globalTotals.total, globalTotals.salary + 300), "on a month's pay")
    // in JSON; deleted, gone
    let back = try! JSONDecoder().decode(Shift.self, from: try! JSONEncoder().encode(sum("a", 2, -12.5, "ארוחות")))
    expect(back.type == .adjustment && back.amount == -12.5 && back.note == "ארוחות", "in JSON")
    expect(try! JSONDecoder().decode(Shift.self, from: try! JSONEncoder().encode(work(1, 8, 9))).amount == nil, "none on a shift")
    var gone = sum("c", 4, 1000, "")
    gone.deleted = true
    expect(Calc.periodTotals(base + [gone], settings, range: range, asOf: asOf).additions == 0, "a deleted one is not counted")
    expect(Calc.breakdown(sum("a", 2, 500, ""), settings).pay == 0, "no wage of its own")
    expect(sum("a", 2, 500, "").isDayOff == false && off(3, .sick).isDayOff && !work(1, 8, 9).isDayOff, "no day off")
    let week = Calc.week(list + [off(4, .vacation)], settings, around: LocalTime.date(2026, 10, 4), asOf: asOf)
    expect(week[3].dayOff == .vacation && week[2].dayOff == nil && week[0].dayOff == nil, "the week's day off, not its sums once")
    expect(Format.signedMoney(500) == "\u{200E}+₪ 500.00" && Format.signedMoney(-12.5) == "\u{200E}−₪ 12.50", "with its sign")
}
adjustmentChecks()

// each year's rates
func yearChecks() {
    expect(Calc.taxRates(year: 2026).year == 2026 && Calc.taxRates(year: 2026).creditPoint == 242, "2026's")
    expect(Calc.taxRates(year: 2099).year == Calc.taxYears.last?.year, "a year not added yet: the last")
    expect(Calc.taxRates(year: 2020).year == Calc.taxYears[0].year, "before them all: the first")
    let december = Calc.period(around: LocalTime.date(2026, 11, 15), monthStartDay: 1)
    let across = Calc.period(around: LocalTime.date(2027, 0, 10), monthStartDay: 25)
    expect(Calc.taxYear(of: december) == 2026 && Calc.taxYear(of: across) == 2027, "by a period's last day")
    let net = Calc.periodNet([work(1, 8, 17)], Settings(), range: december, asOf: LocalTime.date(2026, 11, 15).ms, projected: false)
    expect(net.ratesYear == 2026, "the net says whose rates it has")
    let rates = TaxRates(year: 2030, brackets: [(.infinity, 0.5)], creditPoint: 0, reducedRateUpTo: 0, insuredUpTo: 0, insuranceReduced: 0,
                         insuranceFull: 0, healthReduced: 0, healthFull: 0, pensionCredit: 0, pensionCreditWage: 0, studyFundWage: 0)
    let at2030 = Calc.netPay(gross: 1000, pensionable: 0, Settings(), rates: rates)
    expect(at2030.incomeTax == 500 && at2030.ratesYear == 2030, "counted by the rates given")
}
yearChecks()

// the hours report (Report.swift): its rows, and its lines adding up to the period's income
func reportChecks() {
    var settings = Settings()
    settings.hourlyWage = 50
    settings.lawOvertime = true
    settings.standardByDay = [8, 8, 8, 8, 8, nil, nil]
    settings.regularDailyHours = 8
    settings.travelPerDay = 20
    let asOf = LocalTime.date(2026, 10, 20, 9).ms
    var saturday = Shift(id: "sat", start: LocalTime.date(2026, 10, 7, 8), end: LocalTime.date(2026, 10, 7, 20), isHoliday: true)
    saturday.note = "כיסוי"
    let noon = LocalTime.date(2026, 10, 10, 12)
    let list = [work(1, 8, 18), work(2, 8, 16), off(3, .sick), off(4, .vacation), off(5, .reserve), saturday,
                Shift(id: "plus", start: noon, end: noon, note: "מענק", type: .adjustment, amount: 500),
                Shift(id: "minus", start: noon, end: noon, note: "", type: .adjustment, amount: -100)].sorted { $0.start > $1.start }
    let report = Calc.report(list, settings, place: nil, around: LocalTime.date(2026, 10, 15), asOf: asOf)
    expect(report.title == "נובמבר 2026" && report.rows.count == 6, "its rows, without the sums once")
    expect(report.rows.map(\.date) == report.rows.map(\.date).sorted(), "the oldest first")
    let totals = Calc.periodTotals(list, settings, range: report.range, asOf: asOf)
    expect(abs(report.total - totals.total) < 1e-9 && near(report.netHours, totals.netHours), "the period's")
    let added = report.lines.compactMap(\.amount).reduce(0, +)
    expect(abs(added - report.total) < 1e-6, "the lines add up to it: \(added) and \(report.total)")
    let titles = report.lines.map(\.title)
    expect(titles.contains("שעות רגילות") && titles.contains("נוספות 125%") && titles.contains("שבת וחג 150%") && titles.contains("שבת וחג 175%")
           && titles.contains("שבת וחג 200%") && titles.contains("חופשה") && titles.contains("מחלה") && titles.contains("מילואים")
           && titles.contains("נסיעות") && titles.contains("מענק") && titles.contains("ניכוי"), "its lines: \(titles)")
    let row = report.rows.first { $0.id == "sat" }
    expect(row?.holiday == 12 && row?.regular == 0 && row?.note == "כיסוי" && row?.start == "08:00" && row?.end == "20:00", "Shabbat's row")
    let sick = report.rows.first { $0.date == LocalTime.date(2026, 10, 3, 12) }
    expect(sick?.note == "מחלה" && sick?.start == "" && sick?.net == 0, "a day off's row")
    expect(report.rows.first { $0.date == LocalTime.date(2026, 10, 5, 12) }?.pay == nil, "no pay on a day of reserve duty")
    expect(report.hourlyWage == 50 && report.firstTier == "125%" && report.secondTier == "150%", "the wage and the tiers")

    // one workplace of two
    var two = settings
    let place = Workplace(id: "x", name: "שני", pay: [PayTerms(id: "p", from: PayTerms.start, hourlyWage: 60)], standardByDay: settings.standardByDay,
                          rules: settings.rules, monthStartDay: 10)
    two.workplaces = [place]
    var elsewhere = Shift(id: "there", start: LocalTime.date(2026, 10, 12, 8), end: LocalTime.date(2026, 10, 12, 16))
    elsewhere.workplaceId = "x"
    let both = (list + [elsewhere]).sorted { $0.start > $1.start }
    let own = Calc.report(both, two, place: nil, around: LocalTime.date(2026, 10, 15), asOf: asOf)
    expect(own.rows.count == 6 && abs(own.total - report.total) < 1e-9 && own.workplace == two.workplaceName, "the own one's alone")
    let there = Calc.report(both, two, place: "x", around: LocalTime.date(2026, 10, 15), asOf: asOf)
    expect(there.rows.map(\.id) == ["there"] && near(there.total, 8 * 60 + 20 * 0) && there.workplace == "שני" && there.hourlyWage == 60, "the other's alone")
    expect(LocalTime.parts(there.range.start).day == 10, "by its own pay month")

    // a month's pay: hours, and the month's pay as its line
    var global = settings
    global.payTerms = [PayTerms(id: "g", from: PayTerms.start, kind: .monthly, monthlySalary: 10_000)]
    let monthly = Calc.report(list, global, place: nil, around: LocalTime.date(2026, 10, 15), asOf: asOf)
    expect(monthly.hourlyWage == nil && monthly.rows.first?.pay == nil, "no wage of its own")
    expect(monthly.lines.first { $0.title == "שעות רגילות" }?.amount == nil && monthly.lines.contains { $0.title == "שכר חודשי" }, "the month's pay as its line")
    expect(abs(monthly.lines.compactMap(\.amount).reduce(0, +) - monthly.total) < 1e-6, "and they add up to it")
}
reportChecks()

print(failures == 0 ? "Period: all checks passed" : "Period: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
