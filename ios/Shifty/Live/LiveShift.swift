import ActivityKit
import Foundation
import UIKit
import UserNotifications
import WidgetKit

/// Does an action for Siri, the Shortcuts app, the Action button, the Control Center, the widgets and the
/// Live Activity on the app's store, and brings iCloud, the Live Activity, the notifications and the
/// widgets along before it answers: the app may have been woken in the background for it, and goes back
/// to sleep once it is done.
@MainActor
enum ShiftActions {
    static func run(_ action: ShiftAction) async -> String {
        let store = ShiftStore.shared
        let message = apply(action, to: store)
        ICloud.start(store)
        ICloud.syncNow()
        await LiveShift.apply(store)
        return message
    }

    private static func apply(_ action: ShiftAction, to store: ShiftStore) -> String {
        switch action {
        case .start:
            if let running = store.active {
                return "כבר במשמרת מ־" + Format.clock(running.start) + "."
            }
            let shift = store.startShift()
            return "המשמרת התחילה ב־" + Format.clock(shift.start) + "."
        case .end:
            guard let ended = store.endShift() else { return "אין משמרת פעילה." }
            let b = Calc.breakdown(ended, store.settings)
            return "המשמרת הסתיימה: " + Format.hoursToHM(b.netHours) + " שעות, " + Format.money(b.pay, store.settings.currency) + "."
        case .startBreak:
            guard let running = store.active else { return "אין משמרת פעילה." }
            if store.activeBreak(of: running) != nil { return "כבר בהפסקה." }
            store.startBreak()
            return "ההפסקה התחילה."
        case .endBreak:
            guard let running = store.active, store.activeBreak(of: running) != nil else { return "אין הפסקה פעילה." }
            store.endBreak()
            return "ההפסקה הסתיימה."
        case .toggleShift:
            let next: ShiftAction = store.active == nil ? .start : .end
            return apply(next, to: store)
        case .toggleBreak:
            guard let running = store.active else { return "אין משמרת פעילה." }
            let next: ShiftAction = store.activeBreak(of: running) == nil ? .startBreak : .endBreak
            return apply(next, to: store)
        }
    }
}

/// The running shift outside the app, in step with the store after each change, here or from iCloud: its
/// Live Activity on the Lock Screen and in the Dynamic Island, its notifications, the widgets and the
/// Control Center's switch.
@MainActor
enum LiveShift {
    private static var pending: Task<Void, Never>?
    private static var last: Task<Void, Never>?

    /// After a change on screen: a moment later, once for a run of changes (a wage being typed).
    static func refresh(_ store: ShiftStore) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await apply(store)
        }
    }

    /// At once, and one after another, so that two changes close together never start two activities.
    static func apply(_ store: ShiftStore) async {
        let previous = last
        let task = Task {
            await previous?.value
            await updateActivity(store)
            await Alerts.schedule(store)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
        }
        last = task
        await task.value
    }

    /// The running shift now, for its Live Activity.
    static func state(_ store: ShiftStore, _ shift: Shift, at now: Date = Date()) -> ShiftActivityAttributes.ContentState {
        let status = Calc.nowStatus(store.shifts, store.settings, active: shift, at: now.ms)
        var goalAt: Date? = nil
        if let finish = status.finishMs { goalAt = Date(ms: finish) }
        return ShiftActivityAttributes.ContentState(workingSince: Date(ms: now.ms - status.netMs), goalAt: goalAt,
                                                    breakSince: status.activeBreak?.start, worked: status.netMs / 1000,
                                                    goalHours: status.goal, start: shift.start,
                                                    workplace: store.settings.workplaceName, dark: dark(store.settings))
    }

    /// Whether the Lock Screen's activity is dark: as Shifty looks, by its setting or by the iPhone's. iOS
    /// draws it light or dark by the wallpaper, and a light one stayed light with the iPhone dark.
    static func dark(_ settings: Settings) -> Bool {
        switch settings.theme {
        case "dark": true
        case "light": false
        default: iPhoneDark
        }
    }

    /// The iPhone's appearance, from the app's screen; woken in the background without one, as it was last.
    private static var iPhoneDark: Bool {
        let key = "iPhoneDark"
        let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        guard let style = scene?.screen.traitCollection.userInterfaceStyle, style != .unspecified else {
            return UserDefaults.standard.bool(forKey: key)
        }
        UserDefaults.standard.set(style == .dark, forKey: key)
        return style == .dark
    }

    /// Starts the running shift's activity, updates it, or ends it; and ends any of a shift no longer running.
    private static func updateActivity(_ store: ShiftStore) async {
        let activities = Activity<ShiftActivityAttributes>.activities
        guard let shift = store.active else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let state = Self.state(store, shift)
        // past the goal the activity shows it reached, without a change
        let content = ActivityContent(state: state, staleDate: state.goalAt)
        if let current = activities.first(where: { $0.attributes.shiftID == shift.id }) {
            await current.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = ShiftActivityAttributes(shiftID: shift.id, start: shift.start, workplace: store.settings.workplaceName)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        for other in activities where other.attributes.shiftID != shift.id {
            await other.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// The running shift's notifications, on the device: the day's goal reached, the second tier of overtime,
/// and a shift still open after twelve hours. Planned again after each change; asked for at the first
/// shift.
@MainActor
enum Alerts {
    /// Whether they are on (Settings), on by default.
    static let key = "shiftAlerts"
    private static let ids = ["shifty.goal", "shifty.overtime", "shifty.open"]

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func schedule(_ store: ShiftStore) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled, let shift = store.active else { return }
        let planned = plan(store, shift, now: Date())
        guard !planned.isEmpty, await allowed() else { return }
        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, item.date.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    private struct Planned {
        let id: String
        let date: Date
        let title: String
        let body: String
    }

    private static func plan(_ store: ShiftStore, _ shift: Shift, now: Date) -> [Planned] {
        let s = store.settings
        let status = Calc.nowStatus(store.shifts, s, active: shift, at: now.ms)
        var planned: [Planned] = []
        // the goal and the overtime move with a break: they are planned again when it ends
        if status.activeBreak == nil, let finish = status.finishMs {
            let b = Calc.breakdown(shift, s, asOf: finish)
            planned.append(Planned(id: "shifty.goal", date: Date(ms: finish), title: "🎯 הגעת ליעד היומי",
                                   body: Format.hoursToHM(b.netHours) + " שעות · " + Format.money(b.pay, s.currency) + " · מעכשיו שעות נוספות"))
            if !shift.isHoliday && s.overtime1Hours > 0 && s.overtime2Mult != s.overtime1Mult {
                let percent = Int(jsRound(s.overtime2Mult * 100))
                planned.append(Planned(id: "shifty.overtime", date: Date(ms: finish + s.overtime1Hours * Calc.hour),
                                       title: "⏱️ " + Format.hoursToHM(s.overtime1Hours) + " שעות נוספות",
                                       body: "מעכשיו כל שעה ב־\(percent)%."))
            }
        }
        planned.append(Planned(id: "shifty.open", date: shift.start.addingTimeInterval(12 * 3600), title: "המשמרת עדיין פתוחה",
                               body: "התחלת ב־" + Format.clock(shift.start) + ". אם סיימת, אפשר לסיים אותה מהמסך הנעול או ב-Shifty."))
        return planned.filter { $0.date > now }
    }

    /// Asks once; the answer stands after.
    static func allowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}
