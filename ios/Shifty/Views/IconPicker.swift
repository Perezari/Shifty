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
/// the ring moving to it with a light tap of the iPhone, without iOS's own alert (IconChangeAlert).
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
        IconChangeAlert.skipNext()
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(choice.iconName)
            } catch {
                withAnimation(.snappy(duration: 0.2)) { chosen = before }
            }
        }
    }
}

/// iOS's own alert after an icon change ("שינית את האייקון של…") comes out wrong in Hebrew: its text to the left, away
/// from the icon, under it an empty band. The picker's ring says the same, so it is let go: for ten seconds after the
/// picker asks for a change (iOS takes a moment to change it), the first alert with one button is not shown. Two ways,
/// as iOS may bring it up either: a screen about to present it does not; and should it be presented all the same, it is
/// hidden as it appears and taken away when it is in. Every other alert and screen goes on as always.
@MainActor
enum IconChangeAlert {
    private static var until = Date.distantPast
    private static var installed = false

    static func skipNext() {
        install()
        until = Date().addingTimeInterval(10)
    }

    fileprivate static func skips(_ controller: UIViewController) -> Bool {
        guard Date() < until, let alert = controller as? UIAlertController, alert.actions.count <= 1 else { return false }
        until = .distantPast
        return true
    }

    /// From the first change on, UIKit's present goes by way of `iconChangePresent`, and an alert's viewWillAppear by
    /// way of `iconChangeWillAppear`: the alert's own, added to it first if it has none, for no other screen to change.
    private static func install() {
        guard !installed else { return }
        installed = true
        if let original = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.present(_:animated:completion:))),
           let replacement = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.iconChangePresent(_:animated:completion:))) {
            method_exchangeImplementations(original, replacement)
        }
        let alert = UIAlertController.self
        let appear = #selector(UIViewController.viewWillAppear(_:))
        let ours = #selector(UIAlertController.iconChangeWillAppear(_:))
        guard let original = class_getInstanceMethod(alert, appear), let replacement = class_getInstanceMethod(alert, ours) else { return }
        if class_addMethod(alert, appear, method_getImplementation(replacement), method_getTypeEncoding(replacement)) {
            class_replaceMethod(alert, ours, method_getImplementation(original), method_getTypeEncoding(original))
        } else {
            method_exchangeImplementations(original, replacement)
        }
    }
}

extension UIViewController {
    /// UIKit's present, exchanged with it by IconChangeAlert: under this name, after the exchange, is the original.
    /// Dynamic, for the call below to go by the exchange and not straight to this.
    @objc dynamic fileprivate func iconChangePresent(_ controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if IconChangeAlert.skips(controller) {
            completion?()
            return
        }
        iconChangePresent(controller, animated: animated, completion: completion)
    }
}

extension UIAlertController {
    /// An alert's viewWillAppear, exchanged with it by IconChangeAlert: the icon's alert, if it got this far, unseen and
    /// gone once its coming in is over.
    @objc dynamic fileprivate func iconChangeWillAppear(_ animated: Bool) {
        iconChangeWillAppear(animated)
        guard IconChangeAlert.skips(self) else { return }
        view.alpha = 0
        presentationController?.containerView?.alpha = 0
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.dismiss(animated: false) }
        } else {
            DispatchQueue.main.async { [weak self] in self?.dismiss(animated: false) }
        }
    }
}
