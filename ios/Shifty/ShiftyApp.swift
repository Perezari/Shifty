import SwiftUI
import UserNotifications

@main
struct ShiftyApp: App {
    @State private var store: ShiftStore

    init() {
        #if DEBUG
        if let screen = Screenshot.current {
            _store = State(initialValue: ShiftStore.demo(screen))
            return
        }
        #endif
        _store = State(initialValue: ShiftStore.shared)
        // the notifications' buttons, and the workplace watched: here, as the app may be launched in the
        // background for them
        UNUserNotificationCenter.current().delegate = Notifications.shared
        Place.registerCategories()
        Place.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
        }
    }
}

/// The app's tabs.
enum AppTab: Hashable {
    case now, shifts, calendar, settings
}

/// The tabs: the running shift, the shifts by period, the period's calendar, and settings. Built with
/// the iOS 26 SDK, the tab bar is Liquid Glass and floats over the content.
struct RootView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var tab: AppTab = .now

    /// The look chosen in the settings: the iPhone's, light or dark.
    private var scheme: ColorScheme? {
        switch store.settings.theme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// iCloud and the Live Activity, but not for the screenshots' made-up shifts.
    private var syncs: Bool {
        #if DEBUG
        return Screenshot.current == nil
        #else
        return true
        #endif
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("עכשיו", systemImage: "timer", value: AppTab.now) {
                NowView()
            }
            Tab("משמרות", systemImage: "list.bullet", value: AppTab.shifts) {
                NavigationStack {
                    ShiftsView()
                }
            }
            Tab("לוח", systemImage: "calendar", value: AppTab.calendar) {
                NavigationStack {
                    CalendarView()
                }
            }
            Tab("הגדרות", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .preferredColorScheme(scheme)
        .modifier(LockGate())
        .task {
            guard syncs else { return }
            ICloud.start(store)
            LiveShift.refresh(store)
        }
        .onChange(of: phase) { _, now in
            // coming back may bring another device's changes; leaving sends this device's at once
            if syncs && now != .inactive { ICloud.syncNow() }
            // and the Lock Screen's activity is drawn again, in the iPhone's light or dark of now
            if syncs && now == .active { LiveShift.refresh(store) }
        }
        // each change, here, from iCloud or from a button outside the app, reaches the Lock Screen,
        // the Dynamic Island, the notifications and the widgets
        .onChange(of: store.records) { _, _ in
            if syncs { LiveShift.refresh(store) }
        }
        .onChange(of: store.settings) { _, _ in
            if syncs { LiveShift.refresh(store) }
        }
        // a widget or the Live Activity opens the app on the running shift
        .onOpenURL { _ in
            tab = .now
        }
        .onAppear {
            #if DEBUG
            if let screen = Screenshot.current { tab = screen.tab }
            #endif
        }
    }
}

enum AppInfo {
    /// "1.0 (263011530)": the version, and the build, which is the time it was built.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }
}
