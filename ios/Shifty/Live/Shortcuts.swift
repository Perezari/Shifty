import AppIntents

/// What Siri, the Shortcuts app and the Action button know the app does, without setting anything up, by its name
/// under the icon: "התחל משמרת במר משמרת", "מר משמרת הפסקה", "סיים משמרת במר משמרת", and the questions of
/// Questions.swift, "כמה הרווחתי היום במר משמרת".
struct ShiftyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartShiftIntent(),
                    phrases: ["התחל משמרת ב\(.applicationName)", "\(.applicationName) התחל משמרת", "התחלת משמרת ב\(.applicationName)"],
                    shortTitle: "התחלת משמרת", systemImageName: "play.fill")
        AppShortcut(intent: EndShiftIntent(),
                    phrases: ["סיים משמרת ב\(.applicationName)", "\(.applicationName) סיים משמרת", "סיום משמרת ב\(.applicationName)"],
                    shortTitle: "סיום משמרת", systemImageName: "stop.fill")
        AppShortcut(intent: StartBreakIntent(),
                    phrases: ["התחל הפסקה ב\(.applicationName)", "\(.applicationName) הפסקה"],
                    shortTitle: "התחלת הפסקה", systemImageName: "pause.fill")
        AppShortcut(intent: EndBreakIntent(),
                    phrases: ["סיים הפסקה ב\(.applicationName)", "\(.applicationName) סוף הפסקה"],
                    shortTitle: "סיום הפסקה", systemImageName: "play.fill")
        AppShortcut(intent: ToggleShiftIntent(),
                    phrases: ["\(.applicationName) משמרת", "משמרת ב\(.applicationName)"],
                    shortTitle: "משמרת", systemImageName: "timer")
        AppShortcut(intent: TodayQuestion(),
                    phrases: ["כמה הרווחתי היום ב\(.applicationName)", "\(.applicationName) כמה הרווחתי היום", "כמה עבדתי היום ב\(.applicationName)"],
                    shortTitle: "כמה הרווחתי היום", systemImageName: "banknote")
        AppShortcut(intent: GoalQuestion(),
                    phrases: ["כמה נשאר ליעד ב\(.applicationName)", "\(.applicationName) כמה נשאר ליעד", "מתי היעד ב\(.applicationName)"],
                    shortTitle: "כמה נשאר ליעד", systemImageName: "flag.checkered")
        AppShortcut(intent: PeriodQuestion(),
                    phrases: ["כמה עבדתי החודש ב\(.applicationName)", "\(.applicationName) כמה עבדתי החודש", "\(.applicationName) סיכום החודש"],
                    shortTitle: "כמה עבדתי החודש", systemImageName: "calendar")
    }
}
