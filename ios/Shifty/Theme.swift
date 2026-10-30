import SwiftUI

extension Color {
    /// The screens' background, light and dark (Assets.xcassets): the web app's.
    static let appBackground = Color("Background")
}

extension View {
    /// A rounded card of Liquid Glass over the background, as Sogia's cards are.
    func card(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#if DEBUG
/// The screens the build photographs in the simulator (ios/scripts/screenshots.sh): `-screenshot shifts`.
/// They show made-up shifts (Demo.swift). `now` is a shift running, `idle` none, `editor` a new shift, `day`
/// yesterday's sheet on the calendar.
enum Screenshot: String {
    case now, idle, editor, shifts, calendar, day, settings

    static let current: Screenshot? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), index + 1 < arguments.count else { return nil }
        return Screenshot(rawValue: arguments[index + 1])
    }()

    var tab: AppTab {
        switch self {
        case .now, .idle, .editor: .now
        case .shifts: .shifts
        case .calendar, .day: .calendar
        case .settings: .settings
        }
    }
}
#endif
