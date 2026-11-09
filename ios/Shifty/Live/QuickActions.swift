import SwiftUI
import UIKit

/// The quick actions of the home screen's icon, pressed long: by the shift's state, to start it or end it, to take
/// a break or come back from one, and to add a shift or a vacation day. Set again after each change of the shift; an
/// action is done in the app, the shift's at once as the notifications' buttons do it (ShiftActions), adding on a
/// sheet over the tabs (RootView). Free, as the app's own buttons are.
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()

    /// What an action asked to add, for the tabs to show.
    var adding: Adding?
    /// Counts the shift's actions done, for the tabs to show the Now screen after each.
    var shiftActions = 0

    enum Adding: String, Identifiable {
        case shift, vacation
        var id: String { rawValue }
    }

    /// The icon's actions for the store as it is now: ending a shift says since when, a break too; with more than one
    /// workplace, starting says where.
    static func update(_ store: ShiftStore) {
        let settings = store.settings
        func item(_ type: String, _ title: String, _ symbol: String, _ subtitle: String? = nil) -> UIApplicationShortcutItem {
            UIApplicationShortcutItem(type: type, localizedTitle: title, localizedSubtitle: subtitle,
                                      icon: UIApplicationShortcutIcon(systemImageName: symbol), userInfo: nil)
        }
        var items: [UIApplicationShortcutItem] = []
        if let running = store.active {
            let since = "מ־" + Format.clock(running.start)
            if let open = store.activeBreak(of: running) {
                items.append(item("back", "חזרה לעבודה", "play.fill", "בהפסקה מ־" + Format.clock(open.start)))
                items.append(item("end", "סיום משמרת", "stop.fill", since))
            } else {
                // no break where it is taken by itself
                if settings.effective(for: running).autoBreakMinutes == 0 {
                    items.append(item("break", "הפסקה", "pause.fill"))
                }
                items.append(item("end", "סיום משמרת", "stop.fill", since))
                items.append(item("add", "הוספת משמרת", "plus"))
            }
        } else {
            let place = settings.workplaces.isEmpty ? nil : settings.place(store.nextWorkplace).name
            items.append(item("start", "התחלת משמרת", "play.fill", place))
            items.append(item("add", "הוספת משמרת", "plus"))
            items.append(item("vacation", "יום חופש", "beach.umbrella"))
        }
        UIApplication.shared.shortcutItems = items
    }

    /// An action of the icon, done: the shift's on the Now screen.
    func perform(_ type: String) {
        let actions: [String: ShiftAction] = ["start": .start, "end": .end, "break": .startBreak, "back": .endBreak]
        if let action = actions[type] {
            shiftActions += 1
            Task { _ = await ShiftActions.run(action) }
        } else if type == "add" {
            adding = .shift
        } else if type == "vacation" {
            adding = .vacation
        }
    }
}

/// The app's delegate, for its scene's: the icon's quick actions reach the app through them.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // launched by a quick action: done as the app comes up
        if let type = options.shortcutItem?.type {
            Task { @MainActor in QuickActions.shared.perform(type) }
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// The window's scene: a quick action while the app runs, or brought back by it.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let type = shortcutItem.type
        Task { @MainActor in
            QuickActions.shared.perform(type)
            completionHandler(true)
        }
    }
}
