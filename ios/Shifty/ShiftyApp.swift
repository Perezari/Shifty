import SwiftUI

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
        _store = State(initialValue: ShiftStore())
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

    /// iCloud, but not for the screenshots' made-up shifts.
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
                    Placeholder(title: "משמרות", symbol: "list.bullet",
                                note: "כאן יהיו המשמרות לפי תקופה, עם הסיכומים, הוספה ועריכה.")
                }
            }
            Tab("לוח", systemImage: "calendar", value: AppTab.calendar) {
                NavigationStack {
                    Placeholder(title: "לוח", symbol: "calendar",
                                note: "כאן יהיה הלוח של התקופה, עם פרטי כל יום ושעות החוסר.")
                }
            }
            Tab("הגדרות", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    Placeholder(title: "הגדרות", symbol: "gearshape",
                                note: "כאן יהיו השכר, שעות התקן, השעות הנוספות, החגים, הלילה, הנסיעות והנעילה.",
                                footer: "Shifty · גרסה \(AppInfo.version)")
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            if syncs { ICloud.start(store) }
        }
        .onChange(of: phase) { _, now in
            // coming back may bring another device's changes; leaving sends this device's at once
            if syncs && now != .inactive { ICloud.syncNow() }
        }
        .onAppear {
            #if DEBUG
            if let screen = Screenshot.current { tab = screen.tab }
            #endif
        }
    }
}

/// A tab still to come: its title, and a card saying what it will hold.
struct Placeholder: View {
    let title: String
    let symbol: String
    let note: String
    var footer: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text(note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .card()
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(title)
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
