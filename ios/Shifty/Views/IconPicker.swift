import SwiftUI
import UIKit

/// The app's icon on the Home Screen: its own, white, or one of the alternates in Assets.xcassets (project.yml's
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES), all made from the logo by scripts/icons.py, each with its picture
/// for the picker (IconChoice-…) and its own dark and tinted looks. The shekel's icons of before 1.6 are gone: whoever
/// had picked one has the app's own again, and the picker rings it.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard, yellow, navy, purple, teal, plain

    var id: String { rawValue }

    /// The alternate icon's name; nil for the app's own.
    var iconName: String? {
        switch self {
        case .standard: nil
        case .yellow: "AppIcon-Yellow"
        case .navy: "AppIcon-Navy"
        case .purple: "AppIcon-Purple"
        case .teal: "AppIcon-Teal"
        case .plain: "AppIcon-Plain"
        }
    }

    var title: String {
        switch self {
        case .standard: "לבן"
        case .yellow: "צהוב"
        case .navy: "כחול כהה"
        case .purple: "סגול"
        case .teal: "טורקיז"
        case .plain: "בלי שנתות"
        }
    }

    /// Its picture in the picker: the icon in the light look.
    var picture: String {
        switch self {
        case .standard: "IconChoice-Standard"
        case .yellow: "IconChoice-Yellow"
        case .navy: "IconChoice-Navy"
        case .purple: "IconChoice-Purple"
        case .teal: "IconChoice-Teal"
        case .plain: "IconChoice-Plain"
        }
    }

    /// The icon on the Home Screen now: the app's own also for a name this version no longer has.
    @MainActor static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standard
    }
}

/// The icons in Settings › אייקון, three to a row, the one on the Home Screen ringed in the accent; a tap sets another,
/// the ring moving to it with a light tap of the iPhone, and iOS says that the icon has changed. (Its alert comes out
/// wrong in Hebrew, but iOS 26 shows it beyond the app's reach: 1.6's TestFlight builds tried to hold it back from the
/// app's side, before it is presented and as it appears, and it showed all the same.)
struct IconPicker: View {
    @State private var chosen = AppIconChoice.standard
    private static let size: CGFloat = 54
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 16) {
            ForEach(AppIconChoice.allCases) { choice in
                Button {
                    choose(choice)
                } label: {
                    VStack(spacing: 7) {
                        icon(choice)
                        Text(choice.title)
                            .font(.footnote)
                            .foregroundStyle(choice == chosen ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.title)
                .accessibilityAddTraits(choice == chosen ? .isSelected : [])
            }
        }
        .padding(.vertical, 14)
        .onAppear { chosen = .current }
    }

    private func icon(_ choice: AppIconChoice) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.size * 0.2237, style: .continuous)
        let ring = RoundedRectangle(cornerRadius: (Self.size + 10) * 0.2237, style: .continuous)
        return Image(choice.picture)
            .resizable()
            .frame(width: Self.size, height: Self.size)
            .clipShape(shape)
            // the white one's edge, on a light card
            .overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            .padding(5)
            .overlay(ring.strokeBorder(Color.accentColor, lineWidth: 2.5).opacity(choice == chosen ? 1 : 0))
            .accessibilityHidden(true)
    }

    /// Another icon on the Home Screen; the ring goes back if iOS refuses it. By the icon iOS has, not by the ring: with
    /// an icon of before 1.6 the app's own is ringed, and a tap on it sets it.
    private func choose(_ choice: AppIconChoice) {
        guard UIApplication.shared.alternateIconName != choice.iconName, UIApplication.shared.supportsAlternateIcons else { return }
        let before = chosen
        withAnimation(.snappy(duration: 0.2)) { chosen = choice }
        UISelectionFeedbackGenerator().selectionChanged()
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(choice.iconName)
            } catch {
                withAnimation(.snappy(duration: 0.2)) { chosen = before }
            }
        }
    }
}
