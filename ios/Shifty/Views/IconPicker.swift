import SwiftUI
import UIKit

/// The app's icon on the Home Screen: its own, or one of the alternates in Assets.xcassets (project.yml's
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES, drawn from AppIcon-teal.svg, AppIcon-dark.svg and
/// AppIcon-mono.svg), each with its picture for the picker (IconChoice-…). An alternate keeps its look in the
/// iPhone's dark look; the app's own turns dark with it. Until 1.5 the app's own was teal and an alternate,
/// "AppIcon-White", white: that one is still in the app for whoever picked it, now the app's own kept white in the
/// dark look, and the picker rings the app's own for it.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard, teal, dark, mono

    var id: String { rawValue }

    /// The alternate icon's name; nil for the app's own.
    var iconName: String? {
        switch self {
        case .standard: nil
        case .teal: "AppIcon-Teal"
        case .dark: "AppIcon-Dark"
        case .mono: "AppIcon-Mono"
        }
    }

    var title: String {
        switch self {
        case .standard: "רגיל"
        case .teal: "טורקיז"
        case .dark: "כהה"
        case .mono: "שחור־לבן"
        }
    }

    /// Its picture in the picker: the icon in the light look.
    var picture: String {
        switch self {
        case .standard: "IconChoice-Standard"
        case .teal: "IconChoice-Teal"
        case .dark: "IconChoice-Dark"
        case .mono: "IconChoice-Mono"
        }
    }

    /// The icon on the Home Screen now.
    @MainActor static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standard
    }
}

/// The icons side by side in Settings › אייקון, the one on the Home Screen ringed in the accent; a tap
/// sets another, and iOS says that the icon has changed.
struct IconPicker: View {
    @State private var chosen = AppIconChoice.standard
    private static let size: CGFloat = 54

    var body: some View {
        HStack(spacing: 0) {
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

    /// Another icon on the Home Screen; the ring goes back if iOS refuses it. By the icon iOS has, not by the ring: the
    /// white one of before 1.5 is ringed as the app's own, and a tap on the app's own sets it.
    private func choose(_ choice: AppIconChoice) {
        guard UIApplication.shared.alternateIconName != choice.iconName, UIApplication.shared.supportsAlternateIcons else { return }
        let before = chosen
        withAnimation(.snappy(duration: 0.2)) { chosen = choice }
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(choice.iconName)
            } catch {
                withAnimation(.snappy(duration: 0.2)) { chosen = before }
            }
        }
    }
}
