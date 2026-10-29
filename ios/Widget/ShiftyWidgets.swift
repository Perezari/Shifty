import SwiftUI
import WidgetKit

/// Shifty outside the app: the shift's widget, on the home screen and the lock screen; the running shift's
/// Live Activity, on the Lock Screen and in the Dynamic Island; and the shift's switch, in the Control Center
/// and on the Action button. They read the app's files in the App Group (ShiftStore.snapshot), and change
/// the shifts only through the app's intents (Shifty/Live/ShiftIntents.swift), which the app performs.
@main
struct ShiftyWidgets: WidgetBundle {
    var body: some Widget {
        ShiftWidget()
        ShiftLiveActivity()
        ShiftControl()
    }
}

/// The app's colors, from the extension's own asset catalog (Widget/Assets.xcassets). A named color keeps
/// its light and its dark version in what the system draws of the extension; one worked out in code was
/// fixed when the Live Activity was drawn, and missed the iPhone's switch to dark.
enum WidgetStyle {
    static let accent = Color("Accent")
    /// The widgets' background, the app's.
    static let background = Color("Surface")
    /// The Live Activity's on the Lock Screen: white in light, dark in dark, and its text over it. The
    /// activity draws both itself, so that they always come out of the same drawing, in the same mode.
    static let activity = Color("ActivityBackground")
    static let activityText = Color("ActivityText")
}

/// A round button of a widget or of the Live Activity: its symbol in its color, on a lighter disc of it, as
/// the iPhone's own timers have.
struct RoundIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background {
                Circle().fill(color.opacity(0.18))
            }
    }
}
