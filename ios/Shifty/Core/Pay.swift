import Foundation

/// How a pay is paid: by the hours worked, or a fixed month's pay (שכר גלובלי).
enum PayKind: String {
    case hourly, monthly
}

/// What a month's fixed pay covers of the overtime: all of it, up to some hours a month, or none of it, each
/// hour of which is then paid on top of it.
enum OvertimeCover: String {
    case all, upTo, none
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
    /// A fixed bonus paid once a year, with the pay of `bonusMonth` (0 January); 0: none.
    var bonus = 0.0
    var bonusMonth = 0

    /// The worth of an hour: the hourly wage, or the month's pay over 182, as Israeli payslips count it.
    var hourValue: Double {
        kind == .monthly ? monthlySalary / 182 : hourlyWage
    }

    /// The date the first terms of a workplace are given: the start of the shifts' time.
    static let start = Date(ms: 0)
}

/// A workplace besides the settings' own (Shifty Pro): its name, its pay from each date, the standard hours of
/// each weekday and its travel. The settings' own workplace keeps them in the settings, as the web app does.
struct Workplace: Hashable, Identifiable {
    var id: String
    var name: String
    /// The oldest first.
    var pay: [PayTerms]
    var standardByDay: [Double?] = [8.6, 8.6, 8.6, 8.6, 8.6, nil, nil]
    var travelPerDay = 0.0
    var travelMonthlyCap = 0.0
}

extension Settings {
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

    /// The settings a shift is counted by: its workplace's name, standard hours and travel, and the wage of the
    /// pay in effect on its day (a month's pay's hour). The settings themselves with one workplace and one pay.
    func effective(for shift: Shift) -> Settings {
        guard !payTerms.isEmpty || !workplaces.isEmpty else { return self }
        var s = self
        if let place = workplace(of: shift) {
            s.workplaceName = place.name
            s.standardByDay = place.standardByDay
            s.travelPerDay = place.travelPerDay
            s.travelMonthlyCap = place.travelMonthlyCap
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
                         travelPerDay: travelPerDay, travelMonthlyCap: travelMonthlyCap)
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
    /// the period its terms cover, the overtime beyond what it covers at its hour's worth, and an annual bonus
    /// due in the period, on its month's first day.
    static func periodTotals(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> Totals {
        var totals = aggregate(shifts, s, range: range, asOf: asOf)
        let places = s.payPlaces
        guard places.contains(where: { place in place.pay.contains { $0.kind == .monthly || $0.bonus > 0 } }) else { return totals }
        let days = max(1, daysBetween(range.start, range.end))
        let years = LocalTime.parts(range.start).year...LocalTime.parts(range.end).year
        for place in places {
            let pay = place.pay
            for (i, t) in pay.enumerated() {
                // the part of the period these terms hold, from their date to the next terms'
                if t.kind == .monthly {
                    let from = max(t.from, range.start)
                    let to = min(i + 1 < pay.count ? pay[i + 1].from : range.end, range.end)
                    if to > from { totals.salary += t.monthlySalary * Double(daysBetween(from, to)) / Double(days) }
                }
                // the bonus, with the pay of its month, as long as these terms hold on its first day
                if t.bonus > 0 {
                    for year in years {
                        let due = LocalTime.date(year, t.bonusMonth, 1)
                        if due >= range.start && due < range.end && Settings.terms(pay, at: due)?.id == t.id { totals.bonus += t.bonus }
                    }
                }
            }
        }
        totals.extraOvertime = extraOvertime(shifts, s, range: range, asOf: asOf)
        totals.total = totals.pay + totals.travel + totals.salary + totals.extraOvertime + totals.bonus
        return totals
    }

    /// The overtime of the shifts paid by a month's fixed pay that the pay does not cover, worth its tiers at
    /// the pay's hour. With a cover of some hours, its share of the period's overtime past them.
    static func extraOvertime(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> Double {
        struct Overtime {
            var terms: PayTerms
            var hours = 0.0
            var worth = 0.0
        }
        var byTerms: [String: Overtime] = [:]
        for shift in shifts where shift.type == .work && !shift.deleted && inRange(shift, range) && s.isMonthly(shift) {
            let t = s.terms(of: shift)
            let b = breakdown(shift, s, asOf: asOf)
            guard b.overtimeHours > 0 else { continue }
            let key = (s.workplace(of: shift)?.id ?? "") + "/" + t.id
            var o = byTerms[key] ?? Overtime(terms: t)
            o.hours += b.overtimeHours
            o.worth += (b.ot1Hours * s.overtime1Mult + b.ot2Hours * s.overtime2Mult) * t.hourValue
            byTerms[key] = o
        }
        return byTerms.values.reduce(0) { sum, o in
            let extra: Double
            switch o.terms.overtimeCover {
            case .all: extra = 0
            case .none: extra = o.hours
            case .upTo: extra = max(0, o.hours - o.terms.overtimeHours)
            }
            return sum + o.worth * extra / o.hours
        }
    }

    /// The period's overtime against what a month's pay covers of it: the hours, and the cover's hours when
    /// the pay covers some (the Now screen's "6:30 מתוך 30"). Nil without shifts paid by the month.
    static func monthlyOvertime(_ shifts: [Shift], _ s: Settings, range: TimeRange, asOf: Double? = nil) -> (hours: Double, covered: Double?)? {
        var hours = 0.0
        var covered: Double? = nil
        var any = false
        for shift in shifts where shift.type == .work && !shift.deleted && inRange(shift, range) && s.isMonthly(shift) {
            any = true
            hours += breakdown(shift, s, asOf: asOf).overtimeHours
            let t = s.terms(of: shift)
            if t.overtimeCover == .upTo { covered = t.overtimeHours }
        }
        return any ? (hours, covered) : nil
    }

    /// The local days from one midnight to another, across a change of the clocks.
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        Int(jsRound((b.ms - a.ms) / 86_400_000))
    }
}

// MARK: JSON

extension PayTerms: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, from, kind, hourlyWage, monthlySalary, overtimeCover, overtimeHours, bonus, bonusMonth
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
        try c.encode(bonus, forKey: .bonus)
        try c.encode(bonusMonth, forKey: .bonusMonth)
    }
}

extension Workplace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, pay, standardByDay, travelPerDay, travelMonthlyCap
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
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(pay, forKey: .pay)
        try c.encode(standardByDay, forKey: .standardByDay)
        try c.encode(travelPerDay, forKey: .travelPerDay)
        try c.encode(travelMonthlyCap, forKey: .travelMonthlyCap)
    }
}
