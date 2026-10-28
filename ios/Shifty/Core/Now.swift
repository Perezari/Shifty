import Foundation

/// What the Now screen shows (app.js updateNow): the running shift against the day's goal or, with none
/// running, today's work.
struct NowStatus {
    var active: Shift?
    var activeBreak: Break?
    /// The day's goal: its standard hours.
    var goal: Double
    var netMs: Double
    var netHours: Double
    var overtimeHours: Double
    /// The running shift's wage, or today's income, travel included.
    var pay: Double
    /// Toward the goal, from 0 to 1.
    var progress: Double
    /// The hours left to the goal: 0 or less once it is reached.
    var remaining: Double
    /// When the running shift reaches the goal: its start, the goal's hours, and the break that applies.
    var finishMs: Double?
    /// The wage at the goal at the pace so far; nil before anything is worked.
    var projected: Double?
    /// The pay period's income, when a monthly goal is set.
    var periodTotal: Double?
}

extension Calc {
    /// The Now screen at `now`. `shifts` are all of them, the newest first; `active` the running one.
    static func nowStatus(_ shifts: [Shift], _ s: Settings, active: Shift?, at now: Double) -> NowStatus {
        let goal = standardHours(Date(ms: now), s)
        var netMs: Double, netHours: Double, overtimeHours: Double, pay: Double
        var open: Break? = nil
        if let active {
            let b = breakdown(active, s, asOf: now)
            netMs = b.netMs
            netHours = b.netHours
            overtimeHours = b.overtimeHours
            pay = b.pay
            open = active.breaks.first { $0.end == nil }
        } else {
            let today = aggregate(shifts, s, range: dayRange(Date(ms: now)), asOf: now)
            netHours = today.netHours
            netMs = today.netHours * hour
            overtimeHours = today.overtimeHours
            pay = today.total
        }

        let remaining = goal - netHours
        var finishMs: Double? = nil
        if let active, remaining > 0.001 {
            var logged = 0.0
            for b in active.breaks {
                logged += max(0, (b.end?.ms ?? now) - b.start.ms)
            }
            finishMs = active.start.ms + goal * hour + max(logged, s.autoBreakMinutes * 60000)
        }

        var periodTotal: Double? = nil
        if s.monthlyIncomeGoal > 0 {
            let period = period(around: Date(ms: now), monthStartDay: s.monthStartDay)
            periodTotal = aggregate(shifts, s, range: period, asOf: now).total
        }

        return NowStatus(active: active, activeBreak: open, goal: goal, netMs: netMs, netHours: netHours,
                         overtimeHours: overtimeHours, pay: pay,
                         progress: max(0, min(1, goal > 0 ? netHours / goal : 0)), remaining: remaining,
                         finishMs: finishMs, projected: netHours > 0.001 ? pay * (goal / netHours) : nil,
                         periodTotal: periodTotal)
    }
}
