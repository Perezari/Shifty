import Foundation

// Runs the Swift engine (Shifty/Core) on the cases of calc-cases.mjs and writes its results, for
// compare.mjs to hold against the web app's. Run in Jerusalem time, as the cases were made:
// TZ=Asia/Jerusalem calc-check cases.json actual.json

struct Cases: Decodable {
    let settings: [Settings]
    let sets: [[Shift]]
    let checks: [Check]
}

/// One check; which fields it has depends on its kind (calc-cases.mjs).
struct Check: Decodable {
    let kind: String
    let s: Int?
    let set: Int?
    let i: Int?
    let asOf: Double?
    let date: Double?
    let start: Double?
    let end: Double?
    let msd: Int?
    let offset: Int?
    let wso: Int?
    let a: Double?
    let b: Double?
    let fn: String?
    let x: Double?
}

enum Value: Encodable {
    case number(Double), text(String), flag(Bool), none

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let v): try c.encode(v)
        case .text(let v): try c.encode(v)
        case .flag(let v): try c.encode(v)
        case .none: try c.encodeNil()
        }
    }
}

func number(_ v: Double?) -> Value { v.map(Value.number) ?? .none }
func number(_ v: Int?) -> Value { v.map { Value.number(Double($0)) } ?? .none }
func text(_ v: String?) -> Value { v.map(Value.text) ?? .none }
func range(_ r: TimeRange) -> [String: Value] { ["start": .number(r.start.ms), "end": .number(r.end.ms)] }

let arguments = CommandLine.arguments
let cases = try JSONDecoder().decode(Cases.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
let sickSets = cases.sets.map { Calc.sickDates(of: $0) }

func output(_ c: Check) -> [String: Value] {
    let s = c.s.map { cases.settings[$0] } ?? Settings()
    let span = c.start.flatMap { start in c.end.map { TimeRange(start: Date(ms: start), end: Date(ms: $0)) } }
    switch c.kind {
    case "breakdown":
        let b = Calc.breakdown(cases.sets[c.set!][c.i!], s, asOf: c.asOf, sickDates: sickSets[c.set!])
        return [
            "id": .text(b.id), "type": .text(b.type.rawValue), "startMs": .number(b.startMs), "endMs": .number(b.endMs),
            "ongoing": .flag(b.ongoing), "grossMs": .number(b.grossMs), "breakMs": .number(b.breakMs),
            "netMs": .number(b.netMs), "netHours": .number(b.netHours), "regularHours": .number(b.regularHours),
            "ot1Hours": .number(b.ot1Hours), "ot2Hours": .number(b.ot2Hours), "overtimeHours": .number(b.overtimeHours),
            "nightHours": .number(b.nightHours), "isHoliday": .flag(b.isHoliday), "basePay": .number(b.basePay),
            "otPay": .number(b.otPay), "nightPremium": .number(b.nightPremium), "pay": .number(b.pay),
            "sickTier": number(b.sickTier), "sickPct": number(b.sickPct),
        ]
    case "aggregate":
        let t = Calc.aggregate(cases.sets[c.set!], s, range: span, asOf: c.asOf)
        return [
            "count": number(t.count), "netHours": .number(t.netHours), "overtimeHours": .number(t.overtimeHours),
            "nightHours": .number(t.nightHours), "holidayHours": .number(t.holidayHours), "pay": .number(t.pay),
            "travel": .number(t.travel), "total": .number(t.total), "workedDays": number(t.workedDays),
            "avgShiftHours": .number(t.avgShiftHours),
        ]
    case "shortfall":
        let f = Calc.shortfall(cases.sets[c.set!], s, range: span!, asOf: c.asOf)
        return ["total": .number(f.total), "days": number(f.byDay.count)]
    case "now":
        let set = cases.sets[c.set!]
        let active = set.first { !$0.deleted && $0.end == nil && $0.type == .work }
        let n = Calc.nowStatus(set, s, active: active, at: c.asOf!)
        return [
            "active": text(n.active?.id), "onBreak": .flag(n.activeBreak != nil), "goal": .number(n.goal),
            "netMs": .number(n.netMs), "netHours": .number(n.netHours), "overtimeHours": .number(n.overtimeHours),
            "pay": .number(n.pay), "progress": .number(n.progress), "remaining": .number(n.remaining),
            "finishMs": number(n.finishMs), "projected": number(n.projected), "periodTotal": number(n.periodTotal),
        ]
    case "holiday":
        let h = Holidays.info(Date(ms: c.date!))
        return ["kind": text(h.kind?.rawValue), "name": text(h.name)]
    case "standard":
        return ["value": .number(Calc.standardHours(Date(ms: c.date!), s))]
    case "expected":
        return ["value": number(Calc.expectedStandard(Date(ms: c.date!), s))]
    case "period":
        return range(Calc.period(around: Date(ms: c.date!), monthStartDay: c.msd!, offset: c.offset!))
    case "dayRange":
        return range(Calc.dayRange(Date(ms: c.date!)))
    case "weekRange":
        return range(Calc.weekRange(Date(ms: c.date!), weekStartsOn: c.wso!))
    case "night":
        return ["value": .number(Calc.nightMs(c.start!, c.end!, c.a!, c.b!))]
    case "sickTier":
        return ["value": number(Calc.sickTier(c.date!, sickSets[c.set!], s))]
    case "format":
        let x = c.x!
        switch c.fn! {
        case "hoursToHM": return ["text": .text(Format.hoursToHM(x))]
        case "hms": return ["text": .text(Format.hms(x))]
        case "money": return ["text": .text(Format.money(x))]
        case "moneyShort": return ["text": .text(Format.moneyShort(x))]
        case "clock": return ["text": .text(Format.clock(Date(ms: x)))]
        case "dayMonth": return ["text": .text(Format.dayMonth(Date(ms: x)))]
        case "dateLong": return ["text": .text(Format.dateLong(Date(ms: x)))]
        case "dateFull": return ["text": .text(Format.dateFull(Date(ms: x)))]
        default: return ["error": .text("no format \(c.fn!)")]
        }
    default:
        return ["error": .text("no check \(c.kind)")]
    }
}

let results = cases.checks.map(output)
try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: arguments[2]))
print("Swift: \(results.count) results")
