import Foundation

/// How work at a workplace ends: by the employer (a dismissal) or by the worker (a resignation).
enum Leaving: String {
    case dismissal, resignation
}

/// What ending the work at a workplace on a last day comes to by the law, at the pay of that day (TerminationPage,
/// Shifty Pro): the severance, the notice, the vacation days left paid out and the recuperation pay not yet paid. An
/// estimate: a contract or a collective agreement can give more.
struct Termination: Equatable {
    /// The whole years and months of work to the end of the last day.
    let years: Int
    let months: Int
    /// The years of work as a number: the whole months' twelfths, and the days after them.
    let exactYears: Double
    /// Paid by the month (a global salary), not by the hour.
    let monthly: Bool
    /// The month's pay the severance and the notice go by: the month's salary, or the hour's wage for a month of the
    /// standard week's hours.
    let monthPay: Double
    /// The share of the severance the employer's severance payments to the pension fund stand for (section 14): its
    /// percentage of the 8.33 that is a month's pay a year.
    let fundShare: Double
    /// The notice's calendar days; nil for a month.
    let noticeDays: Double?
    /// The pay for the notice, when the employer does without the work in it.
    let noticePay: Double
    /// The vacation days left on the last day, and a day's worth; nil while the payslip's balance is not kept
    /// (EmployerRules.balanceDate).
    let vacationDays: Double?
    let vacationDayPay: Double
    /// The recuperation days earned and not yet paid by then, and their worth; nil where the workplace pays none.
    let recuperationDays: Double?
    let recuperationPay: Double

    /// A month's pay for each year of work, a year begun counted for its share.
    var severanceBase: Double { monthPay * exactYears }
    /// The severance is due on a dismissal after a year of work.
    var severanceDue: Bool { years >= 1 }
    /// The severance money in the pension fund, by the pay of the last day and without its returns.
    var fund: Double { severanceBase * fundShare }
    var vacationPay: Double { (vacationDays ?? 0) * vacationDayPay }

    /// The severance on a dismissal after a year; else the pension fund's severance money, the worker's either way.
    func severance(_ leaving: Leaving) -> Double {
        leaving == .dismissal && severanceDue ? severanceBase : fund
    }

    /// The severance (or the fund's), the vacation days left and the recuperation pay due; the notice's pay apart.
    func total(_ leaving: Leaving) -> Double {
        severance(leaving) + vacationPay + recuperationPay
    }
}

extension Calc {
    /// A workplace's ending on `lastDay`: nil without its start date (Workplace.startDate), or before it. `shifts` are
    /// all of them, for the vacation days taken.
    static func termination(_ shifts: [Shift], _ s: Settings, at id: String?, lastDay: Date) -> Termination? {
        let place = s.place(id)
        guard let startDate = place.startDate else { return nil }
        let start = LocalTime.startOfDay(startDate)
        // the work ends with its last day
        let until = LocalTime.addingDays(1, to: LocalTime.startOfDay(lastDay))
        guard until > start else { return nil }
        let worked = seniority(from: start, to: until)
        let months = worked.years * 12 + worked.months
        let days = max(0, daysBetween(LocalTime.addingMonths(months, to: start), until))
        let exact = Double(months) / 12 + Double(days) / 365.25

        let terms = Settings.terms(place.pay, at: lastDay) ?? place.pay[0]
        let monthly = terms.kind == .monthly
        let monthPay = monthly ? terms.monthlySalary : terms.hourlyWage * monthHours(place)
        let severance = place.rules.severancePercent
        let notice = noticeDays(months: months, monthly: monthly)

        // a vacation day's worth: a month's salary over its work days (21.67 in a five-day week, 25 in a six-day one),
        // or by the hour, the vacation day's hours, as the app pays one
        let workDays = place.standardByDay.compactMap { $0 }.count
        let dayPay = monthly ? terms.monthlySalary / (workDays >= 6 ? 25 : Double(max(1, workDays)) * 52 / 12)
            : place.rules.vacationHours * terms.hourlyWage
        let vacation = leave(shifts, s, asOf: lastDay, at: id).map { max(0, $0.vacation) }
        let recuperation = place.rules.recuperationOn
            ? recuperationOwed(place, start: start, until: until, months: months, years: exact) : nil

        return Termination(years: worked.years, months: worked.months, exactYears: exact, monthly: monthly, monthPay: monthPay,
                           fundShare: severance >= 8.33 ? 1 : max(0, severance * 12 / 100),
                           noticeDays: notice, noticePay: monthPay * (notice.map { $0 / 30 } ?? 1),
                           vacationDays: vacation, vacationDayPay: dayPay,
                           recuperationDays: recuperation,
                           recuperationPay: (recuperation ?? 0) * place.rules.recuperationRate * jobShare(place))
    }

    /// A month of a workplace's standard week: its hours, 52 weeks over 12 months (182 for 42 hours a week).
    static func monthHours(_ place: Workplace) -> Double {
        place.standardByDay.compactMap { $0 }.reduce(0, +) * 52 / 12
    }

    /// The notice's calendar days by the law (חוק הודעה מוקדמת, 2001) after `months` whole months of work; nil for a
    /// month. Paid by the month: a day for each of the first six months, then two and a half for each, a month from
    /// the second year. Paid by the hour: a day for each month of the first year; 14 days and one for each two months
    /// of the second; 21 and one for each two of the third; a month from the fourth.
    static func noticeDays(months: Int, monthly: Bool) -> Double? {
        if monthly {
            switch months {
            case ..<7: return Double(max(0, months))
            case ..<12: return 6 + 2.5 * Double(months - 6)
            default: return nil
            }
        }
        switch months {
        case ..<12: return Double(max(0, months))
        case ..<24: return 14 + Double((months - 12) / 2)
        case ..<36: return 21 + Double((months - 24) / 2)
        default: return nil
        }
    }

    /// The recuperation days earned by `until` and not paid by then: each year of work's days, the year begun for its
    /// share, once the first is done; less those its payments gave (Calc.recuperation's: a year's in its month, or a
    /// twelfth of it each month, from the second year).
    static func recuperationOwed(_ place: Workplace, start: Date, until: Date, months: Int, years exact: Double) -> Double {
        let done = months / 12
        guard done >= 1 else { return 0 }
        var earned = 0.0
        for year in 1...done { earned += recuperationDays(year: year) }
        earned += recuperationDays(year: done + 1) * min(1, max(0, exact - Double(done)))
        var paid = 0.0
        if place.rules.recuperationMonthly {
            for month in 12..<months { paid += recuperationDays(year: month / 12) / 12 }
        } else {
            for year in LocalTime.parts(start).year...LocalTime.parts(until).year {
                let due = LocalTime.date(year, place.rules.recuperationMonth, 1)
                guard due >= start && due < until else { continue }
                paid += recuperationDays(year: seniority(from: start, to: due).years)
            }
        }
        return max(0, earned - paid)
    }
}
