import SwiftUI
import LocalAuthentication

/// The web app's lock (lock.js) the iPhone's way: Face ID, with the iPhone's passcode when it fails, instead
/// of a code of four digits. On launch and after a minute away; this device's alone, as on the web.
enum AppLock {
    /// Whether the lock is on (UserDefaults, not iCloud).
    static let key = "lockEnabled"
    /// Away this long, the app locks again.
    static let grace: TimeInterval = 60

    /// The iPhone has a passcode, so that Face ID or the passcode can tell its owner.
    static var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// "Face ID", or "Touch ID" on an iPhone with the button.
    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }

    /// Asks for Face ID, or the passcode; true when the owner is there.
    static func authenticate(_ reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Covers the app while it is locked and, with the lock on, while it is away, so that the app switcher
/// shows no hours or wages; asks for Face ID when it comes back locked.
struct LockGate: ViewModifier {
    @AppStorage(AppLock.key) private var enabled = false
    @Environment(\.scenePhase) private var phase
    @State private var locked = UserDefaults.standard.bool(forKey: AppLock.key)
    @State private var leftAt: Date?
    @State private var asking = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && (locked || phase != .active) {
                    LockScreen(locked: locked, unlock: unlock)
                        .transition(.opacity)
                }
            }
            .onChange(of: phase) { _, now in
                if now == .background {
                    leftAt = Date()
                } else if now == .active {
                    if let leftAt, Date().timeIntervalSince(leftAt) > AppLock.grace {
                        locked = true
                    }
                    leftAt = nil
                    if locked { unlock() }
                }
            }
            .onChange(of: enabled) { _, on in
                if !on { locked = false }
            }
            .task {
                // launched in front; otherwise coming to the front asks
                if locked && phase == .active { unlock() }
            }
    }

    private func unlock() {
        guard enabled else {
            locked = false
            return
        }
        guard locked, !asking else { return }
        asking = true
        Task {
            let ok = await AppLock.authenticate("פתיחת Shifty")
            asking = false
            if ok {
                withAnimation(.easeOut(duration: 0.25)) { locked = false }
            }
        }
    }
}

/// The cover: the app's name, and a button to ask again for Face ID when it was turned down.
private struct LockScreen: View {
    let locked: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Shifty")
                    .font(.title.bold())
                if locked {
                    Button(action: unlock) {
                        Label("פתיחה", systemImage: symbol)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
                }
            }
        }
    }

    private var symbol: String {
        AppLock.biometryName == "Touch ID" ? "touchid" : "faceid"
    }
}
