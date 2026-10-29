import AppIntents
import Foundation

/// Questions for Siri and the Shortcuts app, answered aloud without opening the app (Shortcuts.swift has
/// their phrases): today's hours and wage, the time left to the day's goal, and the pay period so far and
/// where it is heading, gross and net.
struct TodayQuestion: AppIntent {
    static let title: LocalizedStringResource = "כמה הרווחתי היום"
    static let description = IntentDescription("השעות והשכר של היום.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(Answers.today(ShiftStore.shared))")
    }
}

struct GoalQuestion: AppIntent {
    static let title: LocalizedStringResource = "כמה נשאר ליעד"
    static let description = IntentDescription("כמה זמן עבודה נשאר עד היעד של היום, ומתי מגיעים אליו.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(Answers.goal(ShiftStore.shared))")
    }
}

struct PeriodQuestion: AppIntent {
    static let title: LocalizedStringResource = "כמה עבדתי החודש"
    static let description = IntentDescription("השעות וההכנסה של התקופה עד עכשיו, והצפי לסופה, ברוטו ונטו.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(Answers.period(ShiftStore.shared))")
    }
}

/// The answers, a sentence or two each, with the times as Siri says them.
@MainActor
enum Answers {
    static func today(_ store: ShiftStore, at now: Date = Date()) -> String {
        let s = store.settings
        let day = LocalTime.startOfDay(now)
        let totals = Calc.aggregate(store.shifts, s, range: TimeRange(start: day, end: LocalTime.addingDays(1, to: day)), asOf: now.ms)
        guard totals.total > 0 || totals.netHours > 0 else { return "היום עוד לא עבדת." }
        let text = "היום עבדת \(spoken(totals.netHours)) והרווחת \(Format.moneyShort(totals.total, s.currency))."
        return store.active == nil ? text : text + " המשמרת עדיין פתוחה."
    }

    static func goal(_ store: ShiftStore, at now: Date = Date()) -> String {
        guard let shift = store.active else { return "אין משמרת פתוחה עכשיו." }
        let status = Calc.nowStatus(store.shifts, store.settings, active: shift, at: now.ms)
        guard status.remaining > 0.001 else { return "הגעת ליעד של היום. מעכשיו שעות נוספות." }
        let left = "נשארו \(spoken(status.remaining)) עד היעד"
        // during a break the goal moves with it
        if status.activeBreak != nil { return "בהפסקה עכשיו. \(left)." }
        guard let finish = status.finishMs else { return left + "." }
        return "\(left), ב־\(Format.clock(Date(ms: finish)))."
    }

    static func period(_ store: ShiftStore, at now: Date = Date()) -> String {
        let s = store.settings
        let range = Calc.period(around: now, monthStartDay: s.monthStartDay)
        let totals = Calc.aggregate(store.shifts, s, range: range, asOf: now.ms)
        guard totals.total > 0 || totals.netHours > 0 else { return "בתקופה הזו עוד לא עבדת." }
        let ahead = Calc.periodNet(store.shifts, s, range: range, asOf: now.ms, projected: true)
        let earned = Format.moneyShort(totals.total, s.currency)
        let gross = Format.moneyShort(ahead.gross, s.currency)
        let net = Format.moneyShort(ahead.net, s.currency)
        return "בתקופה הזו עבדת \(spoken(totals.netHours)) והרווחת \(earned). הצפי לסוף התקופה: \(gross) ברוטו, בערך \(net) נטו."
    }

    /// "6 שעות ו־42 דקות", "שעתיים", "שעה ו־5 דקות", "40 דקות".
    static func spoken(_ hours: Double) -> String {
        let minutes = max(0, Int((hours * 60).rounded()))
        let h = minutes / 60
        let m = minutes % 60
        let hourText = h == 1 ? "שעה" : h == 2 ? "שעתיים" : "\(h) שעות"
        let minuteText = m == 1 ? "דקה" : "\(m) דקות"
        if h == 0 { return minuteText }
        return m == 0 ? hourText : hourText + " ו־" + minuteText
    }
}
