import Foundation

/// A pay period's hours at one workplace, for its report (Views/ReportSheet.swift, Shifty Pro): each day's, and what they
/// come to, line by line as a payslip has them.
struct HoursReport {
    /// A shift or a day off.
    struct Row: Hashable, Identifiable {
        let id: String
        let date: Date
        /// "08:00" and "17:00"; empty on a day off, the end while it runs.
        let start: String
        let end: String
        let breakMinutes: Int
        let net: Double
        /// Its hours by rate; those of Shabbat or a holiday in `holiday` alone.
        let regular: Double
        let first: Double
        let second: Double
        let holiday: Double
        /// Its wage; nil paid by a month's fixed pay, or on a day of reserve duty.
        let pay: Double?
        /// The kind of day off, and its note.
        let note: String
    }

    /// A line of the sum: what it is, its hours or days when it has them, and its amount when it is paid by itself.
    struct Line: Hashable {
        let title: String
        let detail: String
        let amount: Double?
    }

    let range: TimeRange
    let workplace: String
    /// The oldest first.
    let rows: [Row]
    let lines: [Line]
    let netHours: Double
    let overtimeHours: Double
    let workedDays: Int
    let total: Double
    /// The hourly wage, when one holds over the whole period.
    let hourlyWage: Double?
    /// The overtime tiers' rates: "125%" and "150%".
    let firstTier: String
    let secondTier: String
    let currency: String

    /// The period's name.
    var title: String { Calc.periodTitle(range) }
}

extension Settings {
    /// These settings with one workplace alone, as their own: all that is counted of them is then that workplace's.
    func alone(_ id: String?) -> Settings {
        var one = self
        one.workplaces = []
        if let id { one.setPlace(nil, place(id)) }
        return one
    }
}

extension Calc {
    /// The report of a workplace's pay period around `date`, at `now`: nil for the settings' own workplace. `shifts` are
    /// all of them.
    static func report(_ shifts: [Shift], _ s: Settings, place id: String?, around date: Date, asOf now: Double) -> HoursReport {
        let one = s.alone(id)
        let there = shifts
            .filter { id == nil ? s.workplace(of: $0) == nil : $0.workplaceId == id }
            .map { shift -> Shift in
                var shift = shift
                shift.workplaceId = nil
                return shift
            }
        let range = period(around: date, monthStartDay: one.monthStartDay)
        let sum = Calc.summary(there, one, range: range, asOf: now)

        struct Tally {
            var hours = 0.0
            var pay = 0.0
            var paid = false

            mutating func add(_ hours: Double, _ pay: Double, paid: Bool) {
                self.hours += hours
                if paid {
                    self.pay += pay
                    self.paid = true
                }
            }
        }
        var regular = Tally(), first = Tally(), second = Tally(), night = Tally()
        var restBase = Tally(), restFirst = Tally(), restSecond = Tally()
        var vacation = Tally(), sick = Tally()
        var reserveDays = 0
        var once: [HoursReport.Line] = []
        var rows: [HoursReport.Row] = []
        var wages = Set<Double>()

        for shift in sum.shifts.sorted(by: { $0.start < $1.start }) {
            guard let b = sum.breakdowns[shift.id] else { continue }
            let own = one.effective(for: shift)
            let paid = !one.isMonthly(shift)
            let wage = own.hourlyWage
            switch shift.type {
            case .adjustment:
                let amount = shift.amount ?? 0
                once.append(.init(title: shift.note.isEmpty ? (amount < 0 ? "ניכוי" : "תוספת") : shift.note, detail: "", amount: amount))
                continue
            case .vacation:
                vacation.add(1, b.pay, paid: paid)
            case .sick:
                sick.add(1, b.pay, paid: paid)
            case .reserve:
                reserveDays += 1
            case .work:
                if paid { wages.insert(wage) }
                if !shift.isHoliday {
                    regular.add(b.regularHours, b.basePay, paid: paid)
                    first.add(b.ot1Hours, b.ot1Hours * own.overtime1Mult * wage, paid: paid)
                    second.add(b.ot2Hours, b.ot2Hours * own.overtime2Mult * wage, paid: paid)
                    if b.nightPremium > 0.005 { night.add(b.nightHours, b.nightPremium, paid: paid) }
                } else if own.lawOvertime {
                    restBase.add(b.regularHours, b.basePay, paid: paid)
                    restFirst.add(b.ot1Hours, b.ot1Hours * (own.holidayMult + own.overtime1Mult - 1) * wage, paid: paid)
                    restSecond.add(b.ot2Hours, b.ot2Hours * (own.holidayMult + own.overtime2Mult - 1) * wage, paid: paid)
                } else {
                    restBase.add(b.netHours, b.basePay, paid: paid)
                }
            }
            let work = shift.type == .work
            let rest = work && shift.isHoliday
            rows.append(.init(id: shift.id, date: shift.start,
                              start: work ? Format.clock(shift.start) : "", end: work ? shift.end.map { Format.clock($0) } ?? "" : "",
                              breakMinutes: Int(jsRound(b.breakMs / 60000)), net: work ? b.netHours : 0,
                              regular: work && !rest ? b.regularHours : 0, first: work && !rest ? b.ot1Hours : 0,
                              second: work && !rest ? b.ot2Hours : 0, holiday: rest ? b.netHours : 0,
                              pay: paid && shift.type != .reserve ? b.pay : nil,
                              note: [work ? "" : shift.type.reportTitle, shift.note].filter { !$0.isEmpty }.joined(separator: " · ")))
        }

        var lines: [HoursReport.Line] = []
        func hours(_ title: String, _ tally: Tally) {
            if tally.hours > 0.001 { lines.append(.init(title: title, detail: Format.hoursShort(tally.hours), amount: tally.paid ? tally.pay : nil)) }
        }
        func days(_ title: String, _ count: Int, _ amount: Double?) {
            if count > 0 { lines.append(.init(title: title, detail: count == 1 ? "יום אחד" : count == 2 ? "יומיים" : "\(count) ימים", amount: amount)) }
        }
        func money(_ title: String, _ amount: Double) {
            if abs(amount) > 0.005 { lines.append(.init(title: title, detail: "", amount: amount)) }
        }
        let totals = sum.totals
        hours("שעות רגילות", regular)
        hours("נוספות " + Format.percent(one.overtime1Mult), first)
        hours("נוספות " + Format.percent(one.overtime2Mult), second)
        hours("שבת וחג " + Format.percent(one.holidayMult), restBase)
        hours("שבת וחג " + Format.percent(one.holidayMult + one.overtime1Mult - 1), restFirst)
        hours("שבת וחג " + Format.percent(one.holidayMult + one.overtime2Mult - 1), restSecond)
        hours("תוספת לילה", night)
        days("חופשה", Int(vacation.hours), vacation.paid ? vacation.pay : nil)
        days("מחלה", Int(sick.hours), sick.paid ? sick.pay : nil)
        days("מילואים", reserveDays, nil)
        days("דמי חג", sum.holidayPays.count, totals.holidayPay)
        money("נסיעות", totals.travel)
        money("שכר חודשי", totals.salary)
        money("שעות נוספות מעבר לכלולות", totals.extraOvertime)
        money("בונוס שנתי", totals.bonus)
        money("דמי הבראה", totals.recuperation)
        lines += once

        return HoursReport(range: range, workplace: one.workplaceName, rows: rows, lines: lines, netHours: totals.netHours,
                           overtimeHours: totals.overtimeHours, workedDays: totals.workedDays, total: totals.total,
                           hourlyWage: wages.count == 1 ? wages.first : nil, firstTier: Format.percent(one.overtime1Mult),
                           secondTier: Format.percent(one.overtime2Mult), currency: one.currency)
    }
}

private extension ShiftType {
    /// A day off's word in a report's row.
    var reportTitle: String {
        switch self {
        case .vacation: "חופשה"
        case .sick: "מחלה"
        case .reserve: "מילואים"
        case .work, .adjustment: ""
        }
    }
}
