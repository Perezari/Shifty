import Foundation

/// What reaches the bank of a month's pay, as a payslip takes off of it at 2026's rates: income tax by its
/// brackets, less the credit points and the credit for the pension saved; National Insurance and health
/// tax; and the employee's shares of the pension and of the study fund. And what the employers save besides,
/// which reaches no bank this month. An estimate: a payslip may differ a little.
struct NetPay: Equatable {
    var gross: Double
    var incomeTax: Double
    var nationalInsurance: Double
    var health: Double
    var pension: Double
    var studyFund = 0.0
    var employer = EmployerSaving()

    var net: Double { gross - incomeTax - nationalInsurance - health - pension - studyFund }
}

/// What employers save for the worker besides the wage: for the pension, for severance and for the study fund.
struct EmployerSaving: Equatable {
    var pension = 0.0
    var severance = 0.0
    var studyFund = 0.0

    var total: Double { pension + severance + studyFund }
}

extension Calc {
    /// The income tax's monthly brackets in 2026 (the yearly ones over twelve): the top of each and its rate.
    /// The last has no top, and its 50% has the 3% surtax in it.
    static let taxBrackets: [(top: Double, rate: Double)] = [
        (7_010, 0.10), (10_060, 0.14), (19_000, 0.20), (25_100, 0.31), (46_690, 0.35), (60_130, 0.47), (.infinity, 0.50),
    ]
    /// A credit point's worth, a month.
    static let creditPointValue = 242.0
    /// National Insurance and health tax take their reduced rates up to 60% of the average wage, and their
    /// full ones above it, up to the most they are taken on.
    static let reducedRateUpTo = 7_703.0
    static let insuredUpTo = 51_910.0
    /// The credit for the pension: 35% of what the employee saves, on up to 7% of a wage up to 9,700.
    static let pensionCredit = 0.35
    static let pensionCreditWage = 9_700.0

    /// The study fund is saved from a wage of up to this a month, free of tax: 2026's ceiling.
    static let studyFundWage = 15_712.0

    /// A month's pay of `gross`, of which `pensionable` is saved for the pension from (the wages without the
    /// overtime, the night's addition and the travel), by the own workplace's rules.
    static func netPay(gross: Double, pensionable: Double, _ s: Settings) -> NetPay {
        netPay(gross: gross, saved: [(pensionable, s.rules)], creditPoints: s.creditPoints)
    }

    /// A month's pay of `gross`, each employer saving of its part of it (`base`) by its own rules: the pension's
    /// shares of all of it, the study fund's of up to its ceiling.
    static func netPay(gross: Double, saved: [(base: Double, rules: EmployerRules)], creditPoints: Double) -> NetPay {
        let gross = max(0, gross)
        let whole = saved.reduce(0) { $0 + max(0, $1.base) }
        // no more saved of than is paid
        let scale = whole > gross ? gross / whole : 1
        var pensionable = 0.0
        var pension = 0.0
        var studyFund = 0.0
        var employer = EmployerSaving()
        for (base, rules) in saved {
            let base = max(0, base) * scale
            let studyBase = min(base, studyFundWage)
            pensionable += base
            pension += base * rules.pensionPercent / 100
            studyFund += studyBase * rules.studyFundPercent / 100
            employer.pension += base * rules.pensionEmployerPercent / 100
            employer.severance += base * rules.severancePercent / 100
            employer.studyFund += studyBase * rules.studyFundEmployerPercent / 100
        }
        var tax = 0.0
        var floor = 0.0
        for bracket in taxBrackets {
            if gross > floor { tax += (min(gross, bracket.top) - floor) * bracket.rate }
            floor = bracket.top
        }
        let credit = creditPoints * creditPointValue
            + pensionCredit * min(pension, 0.07 * min(pensionable, pensionCreditWage))
        let insured = min(gross, insuredUpTo)
        let reduced = min(insured, reducedRateUpTo)
        let full = insured - reduced
        return NetPay(gross: gross, incomeTax: max(0, tax - credit),
                      nationalInsurance: reduced * 0.0104 + full * 0.07,
                      health: reduced * 0.0323 + full * 0.0517,
                      pension: pension, studyFund: studyFund, employer: employer)
    }

    /// The period `range` as its payslip would give it: as it is at `now`, or, `projected`, as it is heading
    /// to its end, at the pace of the days worked so far.
    static func periodNet(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf now: Double, projected: Bool) -> NetPay {
        let summary = Calc.summary(shifts, s, range: range, asOf: now)
        let totals = summary.totals
        let gross = totals.total
        // a holiday's whole shift is in its base pay, at the holiday's multiplier; a month's fixed pay is, but
        // not its overtime or a bonus. Each employer saves of its own wages and month's pay, by its own rules.
        var wages: [String: Double] = [:]
        for shift in summary.shifts where !s.isMonthly(shift) {
            wages[s.workplace(of: shift)?.id ?? "", default: 0] += summary.breakdowns[shift.id]?.basePay ?? 0
        }
        var salaries: [String: Double] = [:]
        for place in s.payPlaces {
            salaries[place.id ?? "", default: 0] += Calc.salary(place.pay, range: range)
        }
        func saved(_ pace: Double) -> [(base: Double, rules: EmployerRules)] {
            Set(wages.keys).union(salaries.keys).sorted().map { id in
                ((wages[id] ?? 0) * pace + (salaries[id] ?? 0), s.place(id.isEmpty ? nil : id).rules)
            }
        }
        guard projected, gross > 0 else { return netPay(gross: gross, saved: saved(1), creditPoints: s.creditPoints) }
        // the wages head on with the rest of the income that is not fixed
        let ahead = projectedIncome(shifts, s, range: range, asOf: now)
        let fixed = totals.salary + totals.bonus + monthlyTravel(shifts, s, range: range)
        let pace = gross - fixed > 0 ? (ahead - fixed) / (gross - fixed) : 1
        return netPay(gross: ahead, saved: saved(pace), creditPoints: s.creditPoints)
    }
}
