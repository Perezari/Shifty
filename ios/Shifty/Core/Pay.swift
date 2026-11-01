import Foundation

/// How a pay is paid: by the hours worked, or a fixed month's pay (שכר גלובלי).
enum PayKind: String {
    case hourly, monthly
}

/// What a month's fixed pay does with the overtime: covers all of it, up to some hours a month, or none of it (each
/// hour then paid on top at its worth); or pays a bonus at each target of hours a month, the hours short of the first
/// not paid.
enum OvertimeCover: String {
    case all, upTo, none, tiers
}

/// A bonus at a target of overtime hours a month (OvertimeCover.tiers): each one reached adds its amount.
struct OvertimeTier: Hashable {
    var hours: Double
    var amount: Double
}

/// A workplace's pay from a date on: by the hour, or a month's (global), with an annual bonus. Shifts before
/// the date keep the pay before it.
struct PayTerms: Hashable, Identifiable {
    var id: String
    /// Its first day, at midnight; the first terms of a workplace hold from the start, whatever their date.
    var from: Date
    var kind: PayKind = .hourly
    var hourlyWage = 50.0
    var monthlySalary = 0.0
    var overtimeCover: OvertimeCover = .upTo
    /// The overtime hours a month that the month's pay covers (overtimeCover upTo).
    var overtimeHours = 0.0
    /// The bonuses at targets of overtime hours (overtimeCover tiers), the lowest first.
    var overtimeTiers: [OvertimeTier] = []
    /// A fixed bonus paid once a year, with the pay of `bonusMonth` (0 January); 0: none.
    var bonus = 0.0
    var bonusMonth = 0

    /// The worth of an hour: the hourly wage, or the month's pay over 182, as Israeli payslips count it.
    var hourValue: Double {
        kind == .monthly ? monthlySalary / 182 : hourlyWage
    }

    /// What a month's overtime is held against: the hours the pay covers, or the next bonus's target not reached at
    /// `hours`; nil without one, or once every target is reached.
    func target(after hours: Double) -> Double? {
        switch overtimeCover {
        case .upTo: overtimeHours
        case .tiers: overtimeTiers.first { hours < $0.hours - 1e-9 }?.hours
        case .all, .none: nil
        }
    }

    /// The date the first terms of a workplace are given: the start of the shifts' time.
    static let start = Date(ms: 0)
}

/// What an employer sets, besides the pay and the standard hours: overtime, breaks, Shabbat and night, a holiday's eve,
/// vacation and sick days and the days left of them, and the pension. The settings' own workplace keeps them in the
/// settings themselves, as the web app does (Settings.rules); another workplace, its own.
struct EmployerRules: Hashable {
    var overtime1Hours = 2.0
    var overtime1Mult = 1.25
    var overtime2Mult = 1.5
    var autoBreakMinutes = 0.0
    var autoBreakAfterHours = 6.0
    var holidayMult = 1.5
    var nightEnabled = false
    var nightStart = 22.0
    var nightEnd = 6.0
    var nightMult = 1.0
    var holidayEveHours = 4.1
    var vacationHours = 8.6
    var sickDay1Pct = 0.0
    var sickDay2Pct = 50.0
    var sickDay3Pct = 50.0
    var sickDay4Pct = 100.0
    var pensionPercent = 6.0
    var vacationBalance = 0.0
    var sickBalance = 0.0
    var balanceDate: Date?
    var vacationDaysPerYear = 12.0
    /// What the employer saves besides (the law's least: 6.5% and 6%), and the study fund's shares.
    var pensionEmployerPercent = 6.5
    var severancePercent = 6.0
    var studyFundPercent = 0.0
    var studyFundEmployerPercent = 0.0
}

/// A workplace besides the settings' own (Shifty Pro): its name, its pay from each date, the standard hours of
/// each weekday, its travel, its employer's rules and the day its pay month starts. The settings' own workplace
/// keeps them in the settings, as the web app does.
struct Workplace: Hashable, Identifiable {
    var id: String
    var name: String
    /// The oldest first.
    var pay: [PayTerms]
    var standardByDay: [Double?] = [8.6, 8.6, 8.6, 8.6, 8.6, nil, nil]
    var travelPerDay = 0.0
    var travelMonthlyCap = 0.0
    var rules = EmployerRules()
    /// The day its payslip's month starts; nil as the own workplace's. The own one's is the app's pay period.
    var monthStartDay: Int?
    /// Travel as a fixed sum a month instead of each day's, for a period worked in; nil: by the day.
    var travelMonthly: Double?
}

/// A yearly bonus accrued since it was last paid, toward its next payment.
struct AccruedBonus: Identifiable {
    /// The workplace's id; "" for the own.
    let id: String
    let name: String
    let accrued: Double
    let amount: Double
    /// The first of the month it is paid with.
    let due: Date
}

extension Settings {
    /// The own workplace's employer's rules, the settings' own fields.
    var rules: EmployerRules {
        get {
            EmployerRules(overtime1Hours: overtime1Hours, overtime1Mult: overtime1Mult, overtime2Mult: overtime2Mult,
                          autoBreakMinutes: autoBreakMinutes, autoBreakAfterHours: autoBreakAfterHours, holidayMult: holidayMult,
                          nightEnabled: nightEnabled, nightStart: nightStart, nightEnd: nightEnd, nightMult: nightMult,
                          holidayEveHours: holidayEveHours, vacationHours: vacationHours, sickDay1Pct: sickDay1Pct,
                          sickDay2Pct: sickDay2Pct, sickDay3Pct: sickDay3Pct, sickDay4Pct: sickDay4Pct,
                          pensionPercent: pensionPercent, vacationBalance: vacationBalance, sickBalance: sickBalance,
                          balanceDate: balanceDate, vacationDaysPerYear: vacationDaysPerYear,
                          pensionEmployerPercent: pensionEmployerPercent, severancePercent: severancePercent,
                          studyFundPercent: studyFundPercent, studyFundEmployerPercent: studyFundEmployerPercent)
        }
        set {
            overtime1Hours = newValue.overtime1Hours
            overtime1Mult = newValue.overtime1Mult
            overtime2Mult = newValue.overtime2Mult
            autoBreakMinutes = newValue.autoBreakMinutes
            autoBreakAfterHours = newValue.autoBreakAfterHours
            holidayMult = newValue.holidayMult
            nightEnabled = newValue.nightEnabled
            nightStart = newValue.nightStart
            nightEnd = newValue.nightEnd
            nightMult = newValue.nightMult
            holidayEveHours = newValue.holidayEveHours
            vacationHours = newValue.vacationHours
            sickDay1Pct = newValue.sickDay1Pct
            sickDay2Pct = newValue.sickDay2Pct
            sickDay3Pct = newValue.sickDay3Pct
            sickDay4Pct = newValue.sickDay4Pct
            pensionPercent = newValue.pensionPercent
            vacationBalance = newValue.vacationBalance
            sickBalance = newValue.sickBalance
            balanceDate = newValue.balanceDate
            vacationDaysPerYear = newValue.vacationDaysPerYear
            pensionEmployerPercent = newValue.pensionEmployerPercent
            severancePercent = newValue.severancePercent
            studyFundPercent = newValue.studyFundPercent
            studyFundEmployerPercent = newValue.studyFundEmployerPercent
        }
    }

    /// The rules another workplace starts with: the own one's, without its payslip's days off.
    var startingRules: EmployerRules {
        var rules = rules
        rules.balanceDate = nil
        rules.vacationBalance = 0
        rules.sickBalance = 0
        return rules
    }

    /// The settings' own workplace's pay: its terms from each date, or by the hour at `hourlyWage` from the
    /// start.
    var ownPay: [PayTerms] {
        payTerms.isEmpty ? [PayTerms(id: "own", from: PayTerms.start, kind: .hourly, hourlyWage: hourlyWage)] : payTerms
    }

    /// The workplace a shift is at: one of `workplaces`, or nil for the settings' own (also when the shift's
    /// is gone).
    func workplace(of shift: Shift) -> Workplace? {
        guard let id = shift.workplaceId else { return nil }
        return workplaces.first { $0.id == id }
    }

    /// The pay of the workplace a shift is at, in effect on its day.
    func terms(of shift: Shift) -> PayTerms {
        Self.terms(workplace(of: shift)?.pay ?? ownPay, at: shift.start) ?? ownPay[0]
    }

    /// A shift paid by a month's fixed pay, not by its hours.
    func isMonthly(_ shift: Shift) -> Bool {
        (!payTerms.isEmpty || !workplaces.isEmpty) && terms(of: shift).kind == .monthly
    }

    /// The settings a shift is counted by: its workplace's name, standard hours, travel and employer's rules, and the
    /// wage of the pay in effect on its day (a month's pay's hour). The settings themselves with one workplace and one
    /// pay.
    func effective(for shift: Shift) -> Settings {
        guard !payTerms.isEmpty || !workplaces.isEmpty else { return self }
        var s = self
        if let place = workplace(of: shift) {
            s.workplaceName = place.name
            s.standardByDay = place.standardByDay
            s.travelPerDay = place.travelPerDay
            s.travelMonthlyCap = place.travelMonthlyCap
            s.rules = place.rules
        }
        s.hourlyWage = terms(of: shift).hourValue
        return s
    }

    /// The terms in effect on `date`: the last to start by its day; the first, before them all. `list` is the
    /// oldest first.
    static func terms(_ list: [PayTerms], at date: Date) -> PayTerms? {
        list.last { $0.from <= date } ?? list.first
    }

    /// A workplace as the settings page shows it, the settings' own (nil) or another, to read and change alike.
    func place(_ id: String?) -> Workplace {
        if let id, let place = workplaces.first(where: { $0.id == id }) { return place }
        return Workplace(id: "", name: workplaceName, pay: ownPay, standardByDay: standardByDay,
                         travelPerDay: travelPerDay, travelMonthlyCap: travelMonthlyCap, rules: rules,
                         monthStartDay: monthStartDay, travelMonthly: travelMonthly)
    }

    /// The day a workplace's pay month starts: its own, or the own workplace's, which is the app's pay period.
    func monthStartDay(of id: String?) -> Int {
        id.flatMap { id in workplaces.first { $0.id == id }?.monthStartDay } ?? monthStartDay
    }

    /// A workplace changed on its page. The own one's pay is kept as `hourlyWage` alone while it is one wage from
    /// the start without a bonus, as the web app keeps it, and as terms once it is more; `hourlyWage` is then
    /// its last hourly wage.
    mutating func setPlace(_ id: String?, _ place: Workplace) {
        let pay = place.pay.sorted { $0.from < $1.from }
        if let id {
            guard let i = workplaces.firstIndex(where: { $0.id == id }) else { return }
            workplaces[i] = place
            workplaces[i].pay = pay
            return
        }
        workplaceName = place.name
        standardByDay = place.standardByDay
        travelPerDay = place.travelPerDay
        travelMonthlyCap = place.travelMonthlyCap
        rules = place.rules
        if let day = place.monthStartDay { monthStartDay = day }
        travelMonthly = place.travelMonthly
        if pay.count == 1 && pay[0].kind == .hourly && pay[0].bonus == 0 {
            payTerms = []
            hourlyWage = pay[0].hourlyWage
        } else {
            payTerms = pay
            if let last = pay.last(where: { $0.kind == .hourly }) { hourlyWage = last.hourlyWage }
        }
    }

    /// The name of a shift's workplace, with more than one; nil with the settings' own alone.
    func placeName(of shift: Shift) -> String? {
        guard !workplaces.isEmpty else { return nil }
        return workplace(of: shift)?.name ?? workplaceName
    }

    /// Each workplace's id (nil for the settings' own) and pay.
    var payPlaces: [(id: String?, pay: [PayTerms])] {
        var places: [(id: String?, pay: [PayTerms])] = [(nil, ownPay)]
        for place in workplaces { places.append((place.id, place.pay)) }
        return places
    }
}

extension Calc {
    /// A pay period's income (the Now, Shifts and Calendar screens', the net's and the summaries'): its shifts'
    /// wages and travel (aggregate), and for each workplace paid by the month, its month's pay for the part of
    /// the period its terms cover, the overtime it does not cover (at its hour's worth, or as the bonuses of the
    /// targets reached), and an annual bonus due in the period, on its month's first day.
    static func periodTotals(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> Totals {
        var totals = aggregate(shifts, s, range: range, asOf: asOf)
        let monthly = monthlyTravel(shifts, s, range: range)
        totals.travel += monthly
        totals.total += monthly
        let places = s.payPlaces
        guard places.contains(where: { place in place.pay.contains { $0.kind == .monthly || $0.bonus > 0 } }) else { return totals }
        let years = LocalTime.parts(range.start).year...LocalTime.parts(range.end).year
        for place in places {
            let pay = place.pay
            totals.salary += salary(pay, range: range)
            // the bonus, with the pay of its month, as long as its terms hold on its first day
            for t in pay where t.bonus > 0 {
                for year in years {
                    let due = LocalTime.date(year, t.bonusMonth, 1)
                    if due >= range.start && due < range.end && Settings.terms(pay, at: due)?.id == t.id { totals.bonus += t.bonus }
                }
            }
        }
        totals.extraOvertime = extraOvertime(shifts, s, range: range, asOf: asOf)
        totals.total = totals.pay + totals.travel + totals.salary + totals.extraOvertime + totals.bonus
        return totals
    }

    /// The travel paid as a fixed sum a month (Workplace.travelMonthly): each such workplace's, in a period with a
    /// day's work there.
    static func monthlyTravel(_ shifts: [Shift], _ s: Settings, range: TimeRange) -> Double {
        let places: [String?] = [nil] + s.workplaces.map { Optional($0.id) }
        var travel = 0.0
        for id in places {
            guard let monthly = s.place(id).travelMonthly, monthly > 0 else { continue }
            let worked = shifts.contains { $0.type == .work && !$0.deleted && inRange($0, range) && s.workplace(of: $0)?.id == id }
            if worked { travel += monthly }
        }
        return travel
    }

    /// Each workplace's yearly bonus in its pay at `date`, accrued since its month's first last came, as a share
    /// of the year to the next (NowView's card).
    static func accruedBonuses(_ s: Settings, at date: Date) -> [AccruedBonus] {
        let places: [String?] = [nil] + s.workplaces.map { Optional($0.id) }
        return places.compactMap { id -> AccruedBonus? in
            let place = s.place(id)
            guard let terms = Settings.terms(place.pay, at: date), terms.bonus > 0 else { return nil }
            let year = LocalTime.parts(date).year
            var last = LocalTime.date(year, terms.bonusMonth, 1)
            if last > date { last = LocalTime.date(year - 1, terms.bonusMonth, 1) }
            let due = LocalTime.date(LocalTime.parts(last).year + 1, terms.bonusMonth, 1)
            // by whole days, across a change of the clocks
            let share = max(0, min(1, Double(daysBetween(last, LocalTime.startOfDay(date))) / Double(max(1, daysBetween(last, due)))))
            return AccruedBonus(id: id ?? "", name: place.name, accrued: terms.bonus * share, amount: terms.bonus, due: due)
        }
    }

    /// A workplace's month's fixed pay in a period: each month's pay for the part of the period its terms hold, from
    /// their date to the next terms'.
    static func salary(_ pay: [PayTerms], range: TimeRange) -> Double {
        let days = max(1, daysBetween(range.start, range.end))
        var salary = 0.0
        for (i, t) in pay.enumerated() where t.kind == .monthly {
            let from = max(t.from, range.start)
            let to = min(i + 1 < pay.count ? pay[i + 1].from : range.end, range.end)
            if to > from { salary += t.monthlySalary * Double(daysBetween(from, to)) / Double(days) }
        }
        return salary
    }

    /// The overtime of the shifts paid by a month's fixed pay that the pay does not cover: worth its tiers at the
    /// pay's hour, all of it or past the hours covered (its share of the month's overtime past them); or the bonuses
    /// of the targets reached. Each workplace's by its own pay months: a month the period holds in part counts for
    /// its share of the days, as its pay does.
    static func extraOvertime(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> Double {
        var places: [String?] = []
        for shift in shifts where shift.type == .work && !shift.deleted && inRange(shift, range) && s.isMonthly(shift) {
            let place = s.workplace(of: shift)?.id
            if !places.contains(place) { places.append(place) }
        }
        var extra = 0.0
        for place in places {
            let day = s.monthStartDay(of: place)
            let there = shifts.filter { s.workplace(of: $0)?.id == place }
            var month = period(around: range.start, monthStartDay: day)
            while month.start < range.end {
                let from = max(month.start, range.start)
                let to = min(month.end, range.end)
                if to > from {
                    let share = Double(daysBetween(from, to)) / Double(max(1, daysBetween(month.start, month.end)))
                    extra += share * monthExtra(there, s, range: month, asOf: asOf)
                }
                month = period(around: month.end, monthStartDay: day)
            }
        }
        return extra
    }

    /// A pay month's overtime that its pay does not cover, of the shifts given.
    private static func monthExtra(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double?) -> Double {
        struct Overtime {
            var terms: PayTerms
            var hours = 0.0
            var worth = 0.0
        }
        var byTerms: [String: Overtime] = [:]
        for shift in shifts where shift.type == .work && !shift.deleted && inRange(shift, range) && s.isMonthly(shift) {
            let t = s.terms(of: shift)
            let rules = s.effective(for: shift)
            let b = breakdown(shift, s, asOf: asOf)
            guard b.overtimeHours > 0 else { continue }
            let key = (s.workplace(of: shift)?.id ?? "") + "/" + t.id
            var o = byTerms[key] ?? Overtime(terms: t)
            o.hours += b.overtimeHours
            o.worth += (b.ot1Hours * rules.overtime1Mult + b.ot2Hours * rules.overtime2Mult) * t.hourValue
            byTerms[key] = o
        }
        return byTerms.values.reduce(0) { sum, o in
            switch o.terms.overtimeCover {
            case .all: sum
            case .none: sum + o.worth
            case .upTo: sum + o.worth * max(0, o.hours - o.terms.overtimeHours) / o.hours
            case .tiers: sum + o.terms.overtimeTiers.filter { o.hours >= $0.hours - 1e-9 }.reduce(0) { $0 + $1.amount }
            }
        }
    }

    /// The period's overtime of the shifts paid by a month's fixed pay, and that pay's terms (the newest shift's), for
    /// the Now screen's "6:30 מתוך 20". Nil without such shifts.
    static func monthlyOvertime(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> (hours: Double, terms: PayTerms)? {
        var hours = 0.0
        var terms: PayTerms?
        for shift in shifts where shift.type == .work && !shift.deleted && inRange(shift, range) && s.isMonthly(shift) {
            hours += breakdown(shift, s, asOf: asOf).overtimeHours
            if terms == nil { terms = s.terms(of: shift) }
        }
        return terms.map { (hours, $0) }
    }

    /// The local days from one midnight to another, across a change of the clocks.
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        Int(jsRound((b.ms - a.ms) / 86_400_000))
    }
}

// MARK: JSON

extension OvertimeTier: Codable {}

extension PayTerms: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, from, kind, hourlyWage, monthlySalary, overtimeCover, overtimeHours, overtimeTiers, bonus, bonusMonth
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PayTerms(id: "", from: PayTerms.start)
        id = try c.decode(String.self, forKey: .id)
        from = ISODate.decodeIfPresent(c, .from) ?? PayTerms.start
        kind = ((try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil).flatMap(PayKind.init(rawValue:)) ?? d.kind
        hourlyWage = (try? c.decodeIfPresent(Double.self, forKey: .hourlyWage)) ?? d.hourlyWage
        monthlySalary = (try? c.decodeIfPresent(Double.self, forKey: .monthlySalary)) ?? d.monthlySalary
        overtimeCover = ((try? c.decodeIfPresent(String.self, forKey: .overtimeCover)) ?? nil).flatMap(OvertimeCover.init(rawValue:)) ?? d.overtimeCover
        overtimeHours = (try? c.decodeIfPresent(Double.self, forKey: .overtimeHours)) ?? d.overtimeHours
        overtimeTiers = (try? c.decodeIfPresent([OvertimeTier].self, forKey: .overtimeTiers)) ?? d.overtimeTiers
        bonus = (try? c.decodeIfPresent(Double.self, forKey: .bonus)) ?? d.bonus
        bonusMonth = (try? c.decodeIfPresent(Int.self, forKey: .bonusMonth)) ?? d.bonusMonth
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ISODate.string(from), forKey: .from)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(hourlyWage, forKey: .hourlyWage)
        try c.encode(monthlySalary, forKey: .monthlySalary)
        try c.encode(overtimeCover.rawValue, forKey: .overtimeCover)
        try c.encode(overtimeHours, forKey: .overtimeHours)
        if !overtimeTiers.isEmpty { try c.encode(overtimeTiers, forKey: .overtimeTiers) }
        try c.encode(bonus, forKey: .bonus)
        try c.encode(bonusMonth, forKey: .bonusMonth)
    }
}

extension EmployerRules: Codable {
    private enum CodingKeys: String, CodingKey {
        case overtime1Hours, overtime1Mult, overtime2Mult, autoBreakMinutes, autoBreakAfterHours, holidayMult,
             nightEnabled, nightStart, nightEnd, nightMult, holidayEveHours, vacationHours,
             sickDay1Pct, sickDay2Pct, sickDay3Pct, sickDay4Pct, pensionPercent,
             vacationBalance, sickBalance, balanceDate, vacationDaysPerYear,
             pensionEmployerPercent, severancePercent, studyFundPercent, studyFundEmployerPercent
    }

    /// A missing key takes the default, as the settings' do.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = EmployerRules()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        overtime1Hours = value(.overtime1Hours, d.overtime1Hours)
        overtime1Mult = value(.overtime1Mult, d.overtime1Mult)
        overtime2Mult = value(.overtime2Mult, d.overtime2Mult)
        autoBreakMinutes = value(.autoBreakMinutes, d.autoBreakMinutes)
        autoBreakAfterHours = value(.autoBreakAfterHours, d.autoBreakAfterHours)
        holidayMult = value(.holidayMult, d.holidayMult)
        nightEnabled = value(.nightEnabled, d.nightEnabled)
        nightStart = value(.nightStart, d.nightStart)
        nightEnd = value(.nightEnd, d.nightEnd)
        nightMult = value(.nightMult, d.nightMult)
        holidayEveHours = value(.holidayEveHours, d.holidayEveHours)
        vacationHours = value(.vacationHours, d.vacationHours)
        sickDay1Pct = value(.sickDay1Pct, d.sickDay1Pct)
        sickDay2Pct = value(.sickDay2Pct, d.sickDay2Pct)
        sickDay3Pct = value(.sickDay3Pct, d.sickDay3Pct)
        sickDay4Pct = value(.sickDay4Pct, d.sickDay4Pct)
        pensionPercent = value(.pensionPercent, d.pensionPercent)
        vacationBalance = value(.vacationBalance, d.vacationBalance)
        sickBalance = value(.sickBalance, d.sickBalance)
        balanceDate = ISODate.decodeIfPresent(c, .balanceDate)
        vacationDaysPerYear = value(.vacationDaysPerYear, d.vacationDaysPerYear)
        pensionEmployerPercent = value(.pensionEmployerPercent, d.pensionEmployerPercent)
        severancePercent = value(.severancePercent, d.severancePercent)
        studyFundPercent = value(.studyFundPercent, d.studyFundPercent)
        studyFundEmployerPercent = value(.studyFundEmployerPercent, d.studyFundEmployerPercent)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(overtime1Hours, forKey: .overtime1Hours)
        try c.encode(overtime1Mult, forKey: .overtime1Mult)
        try c.encode(overtime2Mult, forKey: .overtime2Mult)
        try c.encode(autoBreakMinutes, forKey: .autoBreakMinutes)
        try c.encode(autoBreakAfterHours, forKey: .autoBreakAfterHours)
        try c.encode(holidayMult, forKey: .holidayMult)
        try c.encode(nightEnabled, forKey: .nightEnabled)
        try c.encode(nightStart, forKey: .nightStart)
        try c.encode(nightEnd, forKey: .nightEnd)
        try c.encode(nightMult, forKey: .nightMult)
        try c.encode(holidayEveHours, forKey: .holidayEveHours)
        try c.encode(vacationHours, forKey: .vacationHours)
        try c.encode(sickDay1Pct, forKey: .sickDay1Pct)
        try c.encode(sickDay2Pct, forKey: .sickDay2Pct)
        try c.encode(sickDay3Pct, forKey: .sickDay3Pct)
        try c.encode(sickDay4Pct, forKey: .sickDay4Pct)
        try c.encode(pensionPercent, forKey: .pensionPercent)
        try c.encode(vacationBalance, forKey: .vacationBalance)
        try c.encode(sickBalance, forKey: .sickBalance)
        try c.encodeIfPresent(balanceDate.map(ISODate.string), forKey: .balanceDate)
        try c.encode(vacationDaysPerYear, forKey: .vacationDaysPerYear)
        try c.encode(pensionEmployerPercent, forKey: .pensionEmployerPercent)
        try c.encode(severancePercent, forKey: .severancePercent)
        try c.encode(studyFundPercent, forKey: .studyFundPercent)
        try c.encode(studyFundEmployerPercent, forKey: .studyFundEmployerPercent)
    }
}

extension Workplace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, pay, standardByDay, travelPerDay, travelMonthlyCap, rules, monthStartDay, travelMonthly
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Workplace(id: "", name: "", pay: [])
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        pay = (try? c.decodeIfPresent([PayTerms].self, forKey: .pay)) ?? []
        if pay.isEmpty { pay = [PayTerms(id: id + "-pay", from: PayTerms.start)] }
        standardByDay = (try? c.decodeIfPresent([Double?].self, forKey: .standardByDay)) ?? d.standardByDay
        travelPerDay = (try? c.decodeIfPresent(Double.self, forKey: .travelPerDay)) ?? d.travelPerDay
        travelMonthlyCap = (try? c.decodeIfPresent(Double.self, forKey: .travelMonthlyCap)) ?? d.travelMonthlyCap
        rules = (try? c.decodeIfPresent(EmployerRules.self, forKey: .rules)) ?? d.rules
        monthStartDay = (try? c.decodeIfPresent(Int.self, forKey: .monthStartDay)) ?? nil
        travelMonthly = (try? c.decodeIfPresent(Double.self, forKey: .travelMonthly)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(pay, forKey: .pay)
        try c.encode(standardByDay, forKey: .standardByDay)
        try c.encode(travelPerDay, forKey: .travelPerDay)
        try c.encode(travelMonthlyCap, forKey: .travelMonthlyCap)
        try c.encode(rules, forKey: .rules)
        try c.encodeIfPresent(monthStartDay, forKey: .monthStartDay)
        try c.encodeIfPresent(travelMonthly, forKey: .travelMonthly)
    }
}
