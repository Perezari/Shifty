import SwiftUI
import UserNotifications

@main
struct ShiftyApp: App {
    @State private var store: ShiftStore
    @State private var pro: Pro

    init() {
        #if DEBUG
        if let screen = Screenshot.current {
            _store = State(initialValue: ShiftStore.demo(screen))
            _pro = State(initialValue: Pro(screenshot: screen))
            return
        }
        #endif
        _store = State(initialValue: ShiftStore.shared)
        // the purchase followed from launch, also in the background, where the App Store tells of it
        _pro = State(initialValue: Pro.shared)
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
                .environment(pro)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
        }
    }
}

/// The app's tabs.
enum AppTab: Hashable {
    case now, shifts, calendar, settings

    /// Its name on the tab bar, and on the speed's strip.
    var name: String {
        switch self {
        case .now: "עכשיו"
        case .shifts: "משמרות"
        case .calendar: "לוח"
        case .settings: "הגדרות"
        }
    }
}

/// The tabs: the running shift, the shifts by period, the period's calendar, and settings. Built with
/// the iOS 26 SDK, the tab bar is Liquid Glass and floats over the content.
struct RootView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.scenePhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(CardLook.key) private var glassCards = false
    @AppStorage(Perf.key) private var measuring = false
    @State private var tab: AppTab = .now

    /// The look chosen in the settings: the iPhone's, light or dark.
    private var scheme: ColorScheme? {
        switch store.settings.theme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// iCloud and the Live Activity, but not for the screenshots' made-up shifts; each with Shifty Pro alone.
    private var syncs: Bool {
        #if DEBUG
        return Screenshot.current == nil
        #else
        return true
        #endif
    }

    /// The tab chosen, timed on the speed's strip from the tap to its first frame.
    private var selection: Binding<AppTab> {
        Binding {
            tab
        } set: { chosen in
            Perf.event(chosen.name)
            tab = chosen
        }
    }

    var body: some View {
        TabView(selection: selection) {
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
        // a long press lifts a shift, a day or a button over the tabs, the tab bar blurred too (Lift.swift)
        .liftHost()
        // Shifty Pro, from anything marked Pro
        .sheet(isPresented: Bindable(pro).offering) {
            ProSheet()
                .environment(pro)
        }
        .environment(\.glassCards, glassCards)
        .overlay(alignment: .top) {
            if measuring {
                PerfStrip()
            }
        }
        .onChange(of: measuring, initial: true) { _, on in
            Perf.shared.run(on)
        }
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
        // the iPhone turned light or dark: the Lock Screen's activity with it
        .onChange(of: colorScheme) { _, _ in
            if syncs { LiveShift.refresh(store) }
        }
        // Shifty Pro bought, or given back: iCloud, the Live Activity, the widgets and the place with it
        .onChange(of: pro.unlocked) { _, unlocked in
            guard syncs else { return }
            if unlocked { ICloud.start(store) } else { ICloud.stop() }
            LiveShift.refresh(store)
            Place.shared.start()
        }
        // a widget or the Live Activity opens the app on the running shift; a widget without Pro, on Pro
        .onOpenURL { url in
            if url.host == "pro" {
                pro.offer()
            } else {
                tab = .now
            }
        }
        .onAppear {
            #if DEBUG
            if let screen = Screenshot.current {
                tab = screen.tab
                if screen == .pro { pro.offer() }
            }
            #endif
        }
    }
}

enum AppInfo {
    /// The app's pages on the web (the repository shifty-app, on GitHub Pages), which App Store Connect asks
    /// for and the settings link to.
    static let support = URL(string: "https://perezari.github.io/shifty-app/")!
    static let privacy = URL(string: "https://perezari.github.io/shifty-app/privacy.html")!

    /// "1.0 (263011530)": the version, and the build, which is the time it was built.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }
}
