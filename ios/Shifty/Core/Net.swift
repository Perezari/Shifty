import Foundation

/// What reaches the bank of a month's pay, as a payslip takes off of it at 2026's rates: income tax by its
/// brackets, less the credit points and the credit for the pension saved; National Insurance and health
/// tax; and the employee's share of the pension. An estimate: a payslip may differ a little.
struct NetPay: Equatable {
    var gross: Double
    var incomeTax: Double
    var nationalInsurance: Double
    var health: Double
    var pension: Double

    var net: Double { gross - incomeTax - nationalInsurance - health - pension }
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

    /// A month's pay of `gross`, of which `pensionable` is saved for the pension from: the wages without
    /// the overtime, the night's addition and the travel.
    static func netPay(gross: Double, pensionable: Double, _ s: Settings) -> NetPay {
        let gross = max(0, gross)
        let pensionable = min(max(0, pensionable), gross)
        let pension = pensionable * s.pensionPercent / 100
        var tax = 0.0
        var floor = 0.0
        for bracket in taxBrackets {
            if gross > floor { tax += (min(gross, bracket.top) - floor) * bracket.rate }
            floor = bracket.top
        }
        let credit = s.creditPoints * creditPointValue
            + pensionCredit * min(pension, 0.07 * min(pensionable, pensionCreditWage))
        let insured = min(gross, insuredUpTo)
        let reduced = min(insured, reducedRateUpTo)
        let full = insured - reduced
        return NetPay(gross: gross, incomeTax: max(0, tax - credit),
                      nationalInsurance: reduced * 0.0104 + full * 0.07,
                      health: reduced * 0.0323 + full * 0.0517,
                      pension: pension)
    }

    /// The period `range` as its payslip would give it: as it is at `now`, or, `projected`, as it is heading
    /// to its end, at the pace of the days worked so far.
    static func periodNet(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf now: Double, projected: Bool) -> NetPay {
        let summary = Calc.summary(shifts, s, range: range, asOf: now)
        let gross = summary.totals.total
        // a holiday's whole shift is in its base pay, at the holiday's multiplier
        let pensionable = summary.breakdowns.values.reduce(0) { $0 + $1.basePay }
        guard projected, gross > 0 else { return netPay(gross: gross, pensionable: pensionable, s) }
        let ahead = projectedIncome(shifts, s, range: range, asOf: now)
        return netPay(gross: ahead, pensionable: pensionable * ahead / gross, s)
    }
}
