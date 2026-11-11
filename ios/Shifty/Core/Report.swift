import Foundation

/// A pay period's hours at one workplace, for its report (Views/ReportSheet.swift): each day's, and what they
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
        /// Its kind, for the calendar's card to mark it.
        enum Mark: Hashable {
            case regular, overtime, rest, night, dayOff(ShiftType), holidayPay, money
        }

        let title: String
        let detail: String
        let amount: Double?
        var mark: Mark = .money
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

/// A year's pay periods at one workplace, on one page (Views/ReportSheet.swift): to check against the
/// employer's Form 106. The year of a period is the one its net counts in, its last day's (Calc.taxYear).
struct YearReport {
    struct Row: Hashable, Identifiable {
        let id: String
        let title: String
        var workedDays = 0
        var netHours = 0.0
        var overtimeHours = 0.0
        var vacationDays = 0
        var sickDays = 0
        var gross = 0.0
        var incomeTax = 0.0
        /// National Insurance and health tax.
        var insurance = 0.0
        /// The employee's pension and study fund.
        var saved = 0.0
        var net = 0.0
    }

    let year: Int
    let workplace: String
    /// From the period of the first record, or the year's first, to the period of now.
    let rows: [Row]
    let currency: String

    /// The rows added up.
    var total: Row {
        rows.reduce(into: Row(id: "total", title: "סה״כ")) { sum, row in
            sum.workedDays += row.workedDays
            sum.netHours += row.netHours
            sum.overtimeHours += row.overtimeHours
            sum.vacationDays += row.vacationDays
            sum.sickDays += row.sickDays
            sum.gross += row.gross
            sum.incomeTax += row.incomeTax
            sum.insurance += row.insurance
            sum.saved += row.saved
            sum.net += row.net
        }
    }
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
        let there = shiftsAlone(shifts, s, place: id)
        let range = period(around: date, monthStartDay: one.monthStartDay)
        let sum = Calc.summary(there, one, range: range, asOf: now)

        var rows: [HoursReport.Row] = []
        var wages = Set<Double>()
        for shift in sum.shifts.sorted(by: { $0.start < $1.start }) where shift.type != .adjustment {
            guard let b = sum.breakdowns[shift.id] else { continue }
            let paid = !one.isMonthly(shift)
            let work = shift.type == .work
            let rest = work && shift.isHoliday
            if work && paid { wages.insert(one.effective(for: shift).hourlyWage) }
            rows.append(.init(id: shift.id, date: shift.start,
                              start: work ? Format.clock(shift.start) : "", end: work ? shift.end.map { Format.clock($0) } ?? "" : "",
                              breakMinutes: Int(jsRound(b.breakMs / 60000)), net: work ? b.netHours : 0,
                              regular: work && !rest ? b.regularHours : 0, first: work && !rest ? b.ot1Hours : 0,
                              second: work && !rest ? b.ot2Hours : 0, holiday: rest ? b.netHours : 0,
                              pay: paid && shift.type != .reserve ? b.pay : nil,
                              note: [work ? "" : shift.type.reportTitle, shift.note].filter { !$0.isEmpty }.joined(separator: " · ")))
        }
        let totals = sum.totals
        return HoursReport(range: range, workplace: one.workplaceName, rows: rows, lines: lines(sum, one), netHours: totals.netHours,
                           overtimeHours: totals.overtimeHours, workedDays: totals.workedDays, total: totals.total,
                           hourlyWage: wages.count == 1 ? wages.first : nil, firstTier: Format.percent(one.overtime1Mult),
                           secondTier: Format.percent(one.overtime2Mult), currency: one.currency)
    }

    /// How a period comes to its income, line by line as a payslip has them: its hours by rate, each workplace's rates
    /// its own, what its days off pay, its travel and the rest. The report's sum, and the calendar's first card. Their
    /// amounts add up to the income; hours paid by a month's fixed pay have none.
    static func lines(_ sum: PeriodSummary, _ s: Settings) -> [HoursReport.Line] {
        struct Tally {
            let title: String
            let mark: HoursReport.Line.Mark
            /// Its place among the hours': regular, overtime, Shabbat and holidays, night; by rate within them.
            let order: Double
            var hours = 0.0
            var pay = 0.0
            var paid = false
        }
        var tallies: [Tally] = []
        func add(_ title: String, _ mark: HoursReport.Line.Mark, order: Double, hours: Double, pay: Double, paid: Bool) {
            guard hours > 0 else { return }
            let i = tallies.firstIndex { $0.title == title } ?? {
                tallies.append(Tally(title: title, mark: mark, order: order))
                return tallies.count - 1
            }()
            tallies[i].hours += hours
            if paid {
                tallies[i].pay += pay
                tallies[i].paid = true
            }
        }
        var vacation = (days: 0, pay: 0.0, paid: false)
        var sick = (days: 0, pay: 0.0, paid: false)
        var reserveDays = 0
        var once: [HoursReport.Line] = []
        for shift in sum.shifts.sorted(by: { $0.start < $1.start }) {
            guard let b = sum.breakdowns[shift.id] else { continue }
            let own = s.effective(for: shift)
            let paid = !s.isMonthly(shift)
            let wage = own.hourlyWage
            switch shift.type {
            case .adjustment:
                let amount = shift.amount ?? 0
                once.append(.init(title: shift.note.isEmpty ? (amount < 0 ? "ניכוי" : "תוספת") : shift.note, detail: "", amount: amount))
            case .vacation:
                vacation.days += 1
                if paid {
                    vacation.pay += b.pay
                    vacation.paid = true
                }
            case .sick:
                sick.days += 1
                if paid {
                    sick.pay += b.pay
                    sick.paid = true
                }
            case .reserve:
                reserveDays += 1
            case .work:
                if !shift.isHoliday {
                    add("שעות רגילות", .regular, order: 0, hours: b.regularHours, pay: b.basePay, paid: paid)
                    add("נוספות " + Format.percent(own.overtime1Mult), .overtime, order: 1 + own.overtime1Mult, hours: b.ot1Hours,
                        pay: b.ot1Hours * own.overtime1Mult * wage, paid: paid)
                    add("נוספות " + Format.percent(own.overtime2Mult), .overtime, order: 1 + own.overtime2Mult, hours: b.ot2Hours,
                        pay: b.ot2Hours * own.overtime2Mult * wage, paid: paid)
                    if b.nightPremium > 0.005 { add("תוספת לילה", .night, order: 100, hours: b.nightHours, pay: b.nightPremium, paid: paid) }
                } else if own.lawOvertime {
                    let first = own.holidayMult + own.overtime1Mult - 1
                    let second = own.holidayMult + own.overtime2Mult - 1
                    add("שבת וחג " + Format.percent(own.holidayMult), .rest, order: 10 + own.holidayMult, hours: b.regularHours, pay: b.basePay, paid: paid)
                    add("שבת וחג " + Format.percent(first), .rest, order: 10 + first, hours: b.ot1Hours, pay: b.ot1Hours * first * wage, paid: paid)
                    add("שבת וחג " + Format.percent(second), .rest, order: 10 + second, hours: b.ot2Hours, pay: b.ot2Hours * second * wage, paid: paid)
                } else {
                    add("שבת וחג " + Format.percent(own.holidayMult), .rest, order: 10 + own.holidayMult, hours: b.netHours, pay: b.basePay, paid: paid)
                }
            }
        }

        var lines: [HoursReport.Line] = tallies
            .filter { $0.hours > 0.001 }
            .sorted { $0.order < $1.order }
            .map { .init(title: $0.title, detail: Format.hoursShort($0.hours), amount: $0.paid ? $0.pay : nil, mark: $0.mark) }
        func days(_ title: String, _ count: Int, _ amount: Double?, _ mark: HoursReport.Line.Mark) {
            guard count > 0 else { return }
            lines.append(.init(title: title, detail: count == 1 ? "יום אחד" : count == 2 ? "יומיים" : "\(count) ימים", amount: amount, mark: mark))
        }
        func money(_ title: String, _ amount: Double) {
            if abs(amount) > 0.005 { lines.append(.init(title: title, detail: "", amount: amount)) }
        }
        let totals = sum.totals
        days("חופשה", vacation.days, vacation.paid ? vacation.pay : nil, .dayOff(.vacation))
        days("מחלה", sick.days, sick.paid ? sick.pay : nil, .dayOff(.sick))
        days("מילואים", reserveDays, nil, .dayOff(.reserve))
        days("דמי חג", sum.holidayPays.count, totals.holidayPay, .holidayPay)
        money("נסיעות", totals.travel)
        money("שכר חודשי", totals.salary)
        money("שעות נוספות מעבר לכלולות", totals.extraOvertime)
        money("בונוס שנתי", totals.bonus)
        money("דמי הבראה", totals.recuperation)
        return lines + once
    }
}

extension Calc {
    /// A workplace's shifts, as the settings with it alone (Settings.alone) count them.
    private static func shiftsAlone(_ shifts: [Shift], _ s: Settings, place id: String?) -> [Shift] {
        shifts
            .filter { id == nil ? s.workplace(of: $0) == nil : $0.workplaceId == id }
            .map { shift -> Shift in
                var shift = shift
                shift.workplaceId = nil
                return shift
            }
    }

    /// The years with a record at a workplace, the last first.
    static func reportYears(_ shifts: [Shift], _ s: Settings, place id: String?) -> [Int] {
        let day = s.alone(id).monthStartDay
        let years = shiftsAlone(shifts, s, place: id).filter { !$0.deleted }.map { taxYear(of: period(around: $0.start, monthStartDay: day)) }
        return Array(Set(years)).sorted(by: >)
    }

    /// A workplace's year, period by period, as of `now`: its income, what the net estimates are taken off of it, and
    /// its hours and days. `shifts` are all of them.
    static func yearReport(_ shifts: [Shift], _ s: Settings, place id: String?, year: Int, asOf now: Double) -> YearReport {
        let one = s.alone(id)
        let there = shiftsAlone(shifts, s, place: id)
        let first = there.filter { !$0.deleted && $0.type != .adjustment }.map(\.start).min()
        var rows: [YearReport.Row] = []
        // from a period that surely comes before the year's first
        var range = period(around: LocalTime.date(year - 1, 10, 20), monthStartDay: one.monthStartDay)
        for _ in 0..<16 {
            defer { range = period(around: range.end, monthStartDay: one.monthStartDay) }
            guard taxYear(of: range) == year, range.start.ms <= now, let first, range.end > first else { continue }
            let sum = Calc.summary(there, one, range: range, asOf: now)
            let pay = periodNet(there, one, range: range, asOf: now, projected: false)
            rows.append(.init(id: LocalTime.dayKey(range.start), title: periodTitle(range, year: false), workedDays: sum.totals.workedDays,
                              netHours: sum.totals.netHours, overtimeHours: sum.totals.overtimeHours,
                              vacationDays: sum.shifts.filter { $0.type == .vacation }.count,
                              sickDays: sum.shifts.filter { $0.type == .sick }.count, gross: pay.gross, incomeTax: pay.incomeTax,
                              insurance: pay.nationalInsurance + pay.health, saved: pay.pension + pay.studyFund, net: pay.net))
        }
        return YearReport(year: year, workplace: one.workplaceName, rows: rows, currency: one.currency)
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
