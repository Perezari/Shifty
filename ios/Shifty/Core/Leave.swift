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

    /// The balance at `now`, once the payslip's date is set (Settings.balanceDate). `shifts` are all of them.
    static func leave(_ shifts: [Shift], _ s: Settings, asOf now: Date) -> LeaveBalance? {
        guard let since = s.balanceDate else { return nil }
        // the days off after the payslip's day, up to today's
        let from = LocalTime.addingDays(1, to: LocalTime.startOfDay(since))
        let to = LocalTime.addingDays(1, to: LocalTime.startOfDay(now))
        var vacation = Set<String>()
        var sick = Set<String>()
        for shift in shifts where !shift.deleted && shift.start >= from && shift.start < to {
            switch shift.type {
            case .vacation: vacation.insert(LocalTime.dayKey(shift.start))
            case .sick: sick.insert(LocalTime.dayKey(shift.start))
            case .work: break
            }
        }
        let months = monthsBetween(since, now)
        return LeaveBalance(vacation: s.vacationBalance + s.vacationDaysPerYear / 12 * Double(months) - Double(vacation.count),
                            sick: min(sickDaysMost, s.sickBalance + sickDaysPerMonth * Double(months)) - Double(sick.count),
                            months: months, vacationTaken: vacation.count, sickTaken: sick.count)
    }

    /// The whole months from `start` to `end`: from 30 September, one on 30 October.
    static func monthsBetween(_ start: Date, _ end: Date) -> Int {
        var months = 0
        while months < 1200 && LocalTime.addingMonths(months + 1, to: start) <= end { months += 1 }
        return months
    }
}
