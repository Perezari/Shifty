import Foundation

/// The vacation and sick days left, kept as a payslip keeps them: the balance on the last payslip, then each
/// month a twelfth of the year's vacation days and a day and a half of sick leave (up to 90), less the days
/// off taken since.
struct LeaveBalance: Equatable {
    var vacation: Double
    var sick: Double
    /// Since the payslip: the months that added days, and the days taken.
    var months: Int
    var vacationTaken: Int
    var sickTaken: Int
}

extension Calc {
    static let sickDaysPerMonth = 1.5
    static let sickDaysMost = 90.0

    /// The balance at `now` of a workplace (nil for the settings' own), once its payslip's date is set
    /// (EmployerRules.balanceDate): its days off alone, its days added up to its last day. `shifts` are all of them.
    static func leave(_ shifts: [Shift], _ s: Settings, asOf now: Date, at place: String? = nil) -> LeaveBalance? {
        let work = s.place(place)
        let rules = work.rules
        guard let since = rules.balanceDate else { return nil }
        // no days added after the work there ends
        let accrued = work.endDate.map { min(now, $0) } ?? now
        // the days off after the payslip's day, up to today's
        let from = LocalTime.addingDays(1, to: LocalTime.startOfDay(since))
        let to = LocalTime.addingDays(1, to: LocalTime.startOfDay(now))
        var vacation = Set<String>()
        var sick = Set<String>()
        for shift in shifts where !shift.deleted && shift.start >= from && shift.start < to && s.workplace(of: shift)?.id == place {
            switch shift.type {
            case .vacation: vacation.insert(LocalTime.dayKey(shift.start))
            case .sick: sick.insert(LocalTime.dayKey(shift.start))
            case .work, .reserve: break
            }
        }
        let months = monthsBetween(since, accrued)
        return LeaveBalance(vacation: rules.vacationBalance + vacationDaysPerYear(s, at: place, on: accrued) / 12 * Double(months) - Double(vacation.count),
                            sick: min(sickDaysMost, rules.sickBalance + sickDaysPerMonth * Double(months)) - Double(sick.count),
                            months: months, vacationTaken: vacation.count, sickTaken: sick.count)
    }

    /// The whole months from `start` to `end`: from 30 September, one on 30 October.
    static func monthsBetween(_ start: Date, _ end: Date) -> Int {
        var months = 0
        while months < 1200 && LocalTime.addingMonths(months + 1, to: start) <= end { months += 1 }
        return months
    }
}
