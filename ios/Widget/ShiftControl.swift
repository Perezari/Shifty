import AppIntents
import SwiftUI
import WidgetKit

/// The shift as a switch: in the Control Center, among the Lock Screen's controls, and on the Action button
/// (Settings, Action Button, Controls). On starts a shift, off ends the one running.
struct ShiftControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.perezari.shifty.shift", provider: ShiftControlValue()) { running in
            ControlWidgetToggle("משמרת", isOn: running, action: SetShiftIntent()) { on in
                Label(Self.title(on), systemImage: Self.symbol(on))
            }
            .tint(WidgetStyle.accent)
        }
        .displayName("משמרת")
        .description("מתחיל משמרת, או מסיים את המשמרת שרצה.")
    }

    private static func title(_ on: Bool) -> String {
        on ? "במשמרת" : "לא במשמרת"
    }

    private static func symbol(_ on: Bool) -> String {
        on ? "timer" : "play.fill"
    }
}

/// Whether a shift runs, from the app's files.
struct ShiftControlValue: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        ShiftStore.running(in: ShiftStore.snapshot().shifts) != nil
    }
}
