import AppIntents
import Foundation

/// What the buttons outside the app do: Siri's and the Shortcuts app's, the Action button's, the Control
/// Center's, the widgets' and the Live Activity's.
enum ShiftAction {
    case start, end, startBreak, endBreak, toggleShift, toggleBreak
}

/// Runs an action on the app's store and answers in a sentence, for Siri. The intents are compiled into the
/// widget extension too, for its buttons; as Live Activity intents the system always performs them in the
/// app, which alone is built with SHIFTY_APP (project.yml).
@MainActor
enum ShiftIntents {
    static func run(_ action: ShiftAction) async -> String {
        #if SHIFTY_APP
        return await ShiftActions.run(action)
        #else
        return ""
        #endif
    }
}

struct StartShiftIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "התחלת משמרת"
    static let description = IntentDescription("מתחיל משמרת עכשיו.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.start)
        return .result(dialog: "\(message)")
    }
}

struct EndShiftIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "סיום משמרת"
    static let description = IntentDescription("מסיים את המשמרת שרצה, ואומר כמה שעות עבדת וכמה הרווחת.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.end)
        return .result(dialog: "\(message)")
    }
}

struct StartBreakIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "התחלת הפסקה"
    static let description = IntentDescription("עוצר את זמן העבודה של המשמרת שרצה.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.startBreak)
        return .result(dialog: "\(message)")
    }
}

struct EndBreakIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "סיום הפסקה"
    static let description = IntentDescription("ממשיך את זמן העבודה אחרי הפסקה.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.endBreak)
        return .result(dialog: "\(message)")
    }
}

/// One button for the shift: starts it, or ends the one running (the Action button's, through Shortcuts).
struct ToggleShiftIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "משמרת"
    static let description = IntentDescription("מתחיל משמרת, או מסיים את המשמרת שרצה.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.toggleShift)
        return .result(dialog: "\(message)")
    }
}

/// One button for the break: starts it, or ends the one running (the Live Activity's).
struct ToggleBreakIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "הפסקה"
    static let description = IntentDescription("מתחיל הפסקה, או מסיים את ההפסקה שרצה.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await ShiftIntents.run(.toggleBreak)
        return .result(dialog: "\(message)")
    }
}

/// The switch of the Control Center and of the Action button: on starts a shift, off ends it.
struct SetShiftIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "משמרת"
    static let description = IntentDescription("מתחיל או מסיים משמרת.")
    static let isDiscoverable = false

    @Parameter(title: "במשמרת")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await ShiftIntents.run(value ? .start : .end)
        return .result()
    }
}
