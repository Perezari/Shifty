import Foundation

/// What reaches the bank of a month's pay, as a payslip takes off of it at its year's rates: income tax by its
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
    /// The sums taken off on the period's days (Shift.amount): off what reaches the bank, not off what is taxed.
    var deductions = 0.0
    /// The year whose rates these are.
    var ratesYear = 2026

    var net: Double { gross - incomeTax - nationalInsurance - health - pension - studyFund - deductions }
}

/// What employers save for the worker besides the wage: for the pension, for severance and for the study fund.
struct EmployerSaving: Equatable {
    var pension = 0.0
    var severance = 0.0
    var studyFund = 0.0

    var total: Double { pension + severance + studyFund }
}

/// A tax year's numbers, a month's: they change every January.
struct TaxRates {
    let year: Int
    /// The income tax's monthly brackets (the yearly ones over twelve): the top of each and its rate. The last has no
    /// top, and its 50% has the 3% surtax in it.
    let brackets: [(top: Double, rate: Double)]
    /// A credit point's worth.
    let creditPoint: Double
    /// National Insurance and health tax take their reduced rates up to 60% of the average wage, and their full ones
    /// above it, up to the most they are taken on.
    let reducedRateUpTo: Double
    let insuredUpTo: Double
    let insuranceReduced: Double
    let insuranceFull: Double
    let healthReduced: Double
    let healthFull: Double
    /// The credit for the pension: its share of what the employee saves, on up to 7% of a wage up to this.
    let pensionCredit: Double
    let pensionCreditWage: Double
    /// The study fund is saved from a wage of up to this, free of tax.
    let studyFundWage: Double
}

extension Calc {
    /// Each year's rates, the oldest first. Each January its year is added here, from kolzchut.org.il and btl.gov.il,
    /// and a version submitted: periods of the years before keep theirs, and until then the new year's say whose they are.
    static let taxYears = [
        TaxRates(year: 2026,
                 brackets: [(7_010, 0.10), (10_060, 0.14), (19_000, 0.20), (25_100, 0.31), (46_690, 0.35), (60_130, 0.47), (.infinity, 0.50)],
                 creditPoint: 242, reducedRateUpTo: 7_703, insuredUpTo: 51_910,
                 insuranceReduced: 0.0104, insuranceFull: 0.07, healthReduced: 0.0323, healthFull: 0.0517,
                 pensionCredit: 0.35, pensionCreditWage: 9_700, studyFundWage: 15_712),
    ]

    /// The rates of `year`: its own, or the last before it until its own are added; the first's before them all.
    static func taxRates(year: Int) -> TaxRates {
        taxYears.last { $0.year <= year } ?? taxYears[0]
    }

    /// The year a period's payslip counts in: its last day's.
    static func taxYear(of range: TimeRange) -> Int {
        LocalTime.parts(Date(ms: range.end.ms - 1)).year
    }

    /// A month's pay of `gross`, of which `pensionable` is saved for the pension from (the wages without the
    /// overtime, the night's addition and the travel), by the own workplace's rules.
    static func netPay(gross: Double, pensionable: Double, _ s: Settings, rates: TaxRates = Calc.taxRates(year: 2026)) -> NetPay {
        netPay(gross: gross, saved: [(pensionable, s.rules)], creditPoints: s.creditPoints, rates: rates)
    }

    /// A month's pay of `gross`, each employer saving of its part of it (`base`) by its own rules: the pension's
    /// shares of all of it, the study fund's of up to its ceiling.
    static func netPay(gross: Double, saved: [(base: Double, rules: EmployerRules)], creditPoints: Double,
                       rates: TaxRates = Calc.taxRates(year: 2026)) -> NetPay {
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
            let studyBase = min(base, rates.studyFundWage)
            pensionable += base
            pension += base * rules.pensionPercent / 100
            studyFund += studyBase * rules.studyFundPercent / 100
            employer.pension += base * rules.pensionEmployerPercent / 100
            employer.severance += base * rules.severancePercent / 100
            employer.studyFund += studyBase * rules.studyFundEmployerPercent / 100
        }
        var tax = 0.0
        var floor = 0.0
        for bracket in rates.brackets {
            if gross > floor { tax += (min(gross, bracket.top) - floor) * bracket.rate }
            floor = bracket.top
        }
        let credit = creditPoints * rates.creditPoint
            + rates.pensionCredit * min(pension, 0.07 * min(pensionable, rates.pensionCreditWage))
        let insured = min(gross, rates.insuredUpTo)
        let reduced = min(insured, rates.reducedRateUpTo)
        let full = insured - reduced
        return NetPay(gross: gross, incomeTax: max(0, tax - credit),
                      nationalInsurance: reduced * rates.insuranceReduced + full * rates.insuranceFull,
                      health: reduced * rates.healthReduced + full * rates.healthFull,
                      pension: pension, studyFund: studyFund, employer: employer, ratesYear: rates.year)
    }

    /// The period `range` as its payslip would give it, at its year's rates: as it is at `now`, or, `projected`, as it is
    /// heading to its end, at the pace of the days worked so far. Sums added are taxed and saved of by no one; sums
    /// taken off come off the net alone.
    static func periodNet(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf now: Double, projected: Bool) -> NetPay {
        let summary = Calc.summary(shifts, s, range: range, asOf: now)
        let totals = summary.totals
        let rates = taxRates(year: taxYear(of: range))
        let gross = totals.total + totals.deductions
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
        // holiday pay is saved of as a wage, and stays as it is
        for day in summary.holidayPays {
            salaries[day.place, default: 0] += day.amount
        }
        func saved(_ pace: Double) -> [(base: Double, rules: EmployerRules)] {
            Set(wages.keys).union(salaries.keys).sorted().map { id in
                ((wages[id] ?? 0) * pace + (salaries[id] ?? 0), s.place(id.isEmpty ? nil : id).rules)
            }
        }
        func pay(_ gross: Double, _ pace: Double) -> NetPay {
            var pay = netPay(gross: gross, saved: saved(pace), creditPoints: s.creditPoints, rates: rates)
            pay.deductions = totals.deductions
            return pay
        }
        guard projected, gross > 0 else { return pay(gross, 1) }
        // the wages head on with the rest of the income that is not fixed
        let ahead = projectedIncome(shifts, s, range: range, asOf: now) + totals.deductions
        let fixed = totals.salary + totals.bonus + totals.recuperation + totals.holidayPay + totals.additions
            + monthlyTravel(shifts, s, range: range)
        let pace = gross - fixed > 0 ? (ahead - fixed) / (gross - fixed) : 1
        return pay(ahead, pace)
    }
}
