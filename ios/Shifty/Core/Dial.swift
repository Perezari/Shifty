import Foundation

/// The shift on a twelve-hour dial, the Now screen's: an analog clock's face with the shift as an arc from its
/// start to the day's goal. Angles are degrees clockwise from 12; the pieces of the arc are counted from its
/// start. The goal's flag can be dragged to another time, a plan of when to leave.
struct DialLayout: Equatable {
    enum Kind: Hashable {
        /// Time worked, toward the goal and past it.
        case work, overtime
        /// A break.
        case pause
        /// To the goal still, at this pace.
        case ahead
        /// With a plan: short of the goal, or past it.
        case short, plannedOvertime
        /// A shift of today's, with none running.
        case today
    }

    struct Piece: Hashable {
        var from: Double
        var to: Double
        var kind: Kind
    }

    /// Where the arc starts on the dial.
    var startDeg: Double
    var pieces: [Piece]
    /// Now, the start's angle on (counted from `startDeg` like the pieces).
    var nowDeg: Double
    /// The goal and the leave time chosen, from the start; nil with none running.
    var goalDeg: Double?
    var leaveDeg: Double?
}

extension Calc {
    /// A date's angle on a twelve-hour dial, clockwise from 12.
    static func dialDegrees(_ date: Date) -> Double {
        let c = LocalTime.calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hours = Double((c.hour ?? 0) % 12) + Double(c.minute ?? 0) / 60
            + (Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1e9) / 3600
        return hours * 30
    }

    /// A span of time as degrees of the dial, up to its whole round of twelve hours.
    static func dialSpan(_ ms: Double) -> Double {
        min(360, max(0, ms / hour * 30))
    }

    /// When the running shift reaches the day's goal: its start, the goal's hours, and the breaks that apply
    /// (as NowStatus's finish, which is nil once it is reached).
    static func goalTime(_ shift: Shift, _ s: Settings, asOf now: Double) -> Date {
        let goal = standardHours(Date(ms: now), s)
        return Date(ms: shift.start.ms + goal * hour + max(breaksMs(shift, asOf: now), s.autoBreakMinutes * 60000))
    }

    /// The running shift on the dial at `now`, with a leave time chosen or none.
    static func dial(_ shift: Shift, _ s: Settings, at now: Date, leave: Date? = nil) -> DialLayout {
        let startMs = shift.start.ms
        let rel = { (date: Date) -> Double in dialSpan(date.ms - startMs) }
        let goal = rel(goalTime(shift, s, asOf: now.ms))
        let nowDeg = rel(now)
        var pieces: [DialLayout.Piece] = []
        // time worked, the part past the goal as overtime
        func work(_ a: Double, _ b: Double) {
            guard b > a else { return }
            if b <= goal {
                pieces.append(.init(from: a, to: b, kind: .work))
            } else if a >= goal {
                pieces.append(.init(from: a, to: b, kind: .overtime))
            } else {
                pieces.append(.init(from: a, to: goal, kind: .work))
                pieces.append(.init(from: goal, to: b, kind: .overtime))
            }
        }
        var cursor = shift.start
        for b in shift.breaks.sorted(by: { $0.start < $1.start }) where b.start < now {
            work(rel(cursor), rel(b.start))
            let end = min(b.end ?? now, now)
            if end > b.start { pieces.append(.init(from: rel(b.start), to: rel(end), kind: .pause)) }
            cursor = max(cursor, end)
        }
        work(rel(cursor), nowDeg)

        var leaveDeg: Double? = nil
        if let leave {
            let to = max(nowDeg, rel(leave))
            leaveDeg = to
            if to <= goal {
                if to > nowDeg { pieces.append(.init(from: nowDeg, to: to, kind: .ahead)) }
                if goal > to { pieces.append(.init(from: to, to: goal, kind: .short)) }
            } else {
                if goal > nowDeg { pieces.append(.init(from: nowDeg, to: goal, kind: .ahead)) }
                pieces.append(.init(from: max(nowDeg, goal), to: to, kind: .plannedOvertime))
            }
        } else if goal > nowDeg {
            pieces.append(.init(from: nowDeg, to: goal, kind: .ahead))
        }
        return DialLayout(startDeg: dialDegrees(shift.start), pieces: pieces, nowDeg: nowDeg, goalDeg: goal, leaveDeg: leaveDeg)
    }

    /// Today's shifts on the dial, with none running: from the first one's start.
    static func dial(today shifts: [Shift], at now: Date) -> DialLayout {
        let day = dayRange(now)
        let list = shifts.filter { $0.type == .work && inRange($0, day) && $0.end != nil }.sorted { $0.start < $1.start }
        guard let first = list.first else {
            return DialLayout(startDeg: dialDegrees(now), pieces: [], nowDeg: 0, goalDeg: nil, leaveDeg: nil)
        }
        let rel = { (date: Date) -> Double in dialSpan(date.ms - first.start.ms) }
        let pieces = list.compactMap { shift -> DialLayout.Piece? in
            guard let end = shift.end, end > shift.start else { return nil }
            return .init(from: rel(shift.start), to: rel(end), kind: .today)
        }
        return DialLayout(startDeg: dialDegrees(first.start), pieces: pieces, nowDeg: rel(now), goalDeg: nil, leaveDeg: nil)
    }

    /// The time of a point dragged on the dial, at `degrees` clockwise from 12: the first after the start, by five
    /// minutes, and never before now.
    static func dialTime(_ degrees: Double, start: Date, now: Date) -> Date {
        let after = ((degrees - dialDegrees(start)).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let ms = start.ms + after / 30 * hour
        let snapped = jsRound(ms / 300_000) * 300_000
        return Date(ms: max(now.ms, snapped))
    }

    /// The shift as it would be if it ended at `end`: an open break ended now, and the hours and the wage then.
    static func leaving(_ shift: Shift, at end: Date, _ s: Settings, now: Date, sickDates: Set<String>? = nil) -> Breakdown {
        var shift = shift
        for i in shift.breaks.indices where shift.breaks[i].end == nil {
            shift.breaks[i].end = now
        }
        shift.end = end
        return breakdown(shift, s, sickDates: sickDates)
    }
}
