import SwiftUI
import UIKit
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

/// The app's colors (its Assets.xcassets), which the extension does not have.
enum WidgetStyle {
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.106, green: 0.702, blue: 0.639, alpha: 1)
            : UIColor(red: 0.059, green: 0.616, blue: 0.561, alpha: 1)
    })
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.090, blue: 0.110, alpha: 1)
            : UIColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1)
    })
}

/// A button of a widget or of the Live Activity: a capsule, filled for the main action.
struct WidgetButtonLabel: View {
    let title: String
    let symbol: String
    var color: Color = WidgetStyle.accent
    var filled = false

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .foregroundStyle(filled ? Color.white : color)
            .background {
                Capsule().fill(filled ? color : color.opacity(0.15))
            }
    }
}
