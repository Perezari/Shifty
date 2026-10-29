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

/// The app's colors, from the extension's own asset catalog (Widget/Assets.xcassets), each with its light
/// and its dark version.
enum WidgetStyle {
    static let accent = Color("Accent")
    /// The widgets' background, the app's.
    static let background = Color("Surface")

    /// The Live Activity's background on the Lock Screen, white or dark, and its text over it: plain
    /// colors, as the app says (ContentState.dark). iOS draws the Lock Screen's activities light or dark by
    /// the wallpaper, not by the iPhone's appearance, and named ones stayed light with the iPhone dark.
    static func activity(dark: Bool) -> Color {
        dark ? rgb(0x1C1C1E).opacity(0.88) : Color.white.opacity(0.88)
    }

    static func activityText(dark: Bool) -> Color {
        dark ? rgb(0xF5F7F8) : rgb(0x0B0F12)
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
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
