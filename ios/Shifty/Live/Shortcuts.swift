import AppIntents

/// What Siri, the Shortcuts app and the Action button know Shifty does, without setting anything up:
/// "התחל משמרת בShifty", "Shifty הפסקה", "סיים משמרת בShifty".
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
    }
}
