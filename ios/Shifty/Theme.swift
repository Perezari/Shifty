import SwiftUI
import UIKit

extension Color {
    /// The screens' background, light and dark (Assets.xcassets): the web app's.
    static let appBackground = Color("Background")
    /// A vacation day's sky blue, and a day of reserve duty's olive (ShiftType.dayOffColor).
    static let vacation = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.23, green: 0.62, blue: 0.96, alpha: 1) : UIColor(red: 0.16, green: 0.58, blue: 0.95, alpha: 1)
    })
    static let reserveDuty = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.49, green: 0.56, blue: 0.27, alpha: 1) : UIColor(red: 0.42, green: 0.49, blue: 0.23, alpha: 1)
    })
    /// A card on the background: white, or a gray a little lighter than the dark background.
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1) : .white
    })
}

/// The cards' look, this device's (Settings › תצוגה): plain, as iOS's grouped cards, or of Liquid Glass as they
/// were. Glass over the content is heavy to draw, a layer of its own sampling what is under it; Apple keeps it
/// for the controls and the bars.
enum CardLook {
    static let key = "glassCards"
}

/// The side margin of every screen: their cards' edges stay in place from tab to tab.
enum ScreenMargin {
    static let side: CGFloat = 20
}

/// The Hebrew date beside the Gregorian, this device's (Settings › תצוגה): on the dial, in each day of the calendar
/// and over a day's shifts.
enum HebrewDates {
    static let key = "hebrewDate"
}

/// The dashed frame on a past day of work with nothing recorded, this device's (Settings › תצוגה): on by default, and
/// off for whoever does not work by a fixed week.
enum UnrecordedDays {
    static let key = "unrecordedDays"
}

extension EnvironmentValues {
    /// The cards are of glass (CardLook), set over the tabs.
    @Entry var glassCards = false
}

extension View {
    /// A rounded card over the background.
    func card(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// The surface of a card or a capsule: the cards' color, or a tint's; or glass, tinted if there is one.
    func surface<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        modifier(Surface(shape: shape, tint: tint))
    }
}

private struct Surface<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    @Environment(\.glassCards) private var glass

    @ViewBuilder
    func body(content: Content) -> some View {
        if glass {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            content
                .background(tint ?? Color.cardBackground, in: shape)
                .overlay {
                    shape.stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
        }
    }
}

#if DEBUG
/// The screens the build photographs in the simulator (ios/scripts/screenshots.sh): `-screenshot shifts`.
/// They show made-up shifts (Demo.swift). `now` is a shift running, `idle` none, `editor` a new shift, `menu` a shift
/// lifted by a long press with its menu, `day` the sheet of the last day worked on the calendar, and `report` the
/// hours report's sheet, to see its page.
enum Screenshot: String {
    case now, idle, editor, shifts, menu, calendar, day, settings, report

    static let current: Screenshot? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), index + 1 < arguments.count else { return nil }
        return Screenshot(rawValue: arguments[index + 1])
    }()

    var tab: AppTab {
        switch self {
        case .now, .idle, .editor: .now
        case .shifts, .menu, .report: .shifts
        case .calendar, .day: .calendar
        case .settings: .settings
        }
    }
}
#endif
