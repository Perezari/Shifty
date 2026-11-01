import StoreKit
import SwiftUI

/// Asks for a rating on the App Store at a good moment, the day's goal reached: after a week of shifts and ten of
/// them, once a version, never in the screenshots. iOS shows Apple's dialog only when it chooses, at most three
/// times a year.
struct ReviewRequest: ViewModifier {
    /// Grows each time the day's goal is reached (NowView).
    let trigger: Int
    @Environment(\.requestReview) private var requestReview
    @Environment(ShiftStore.self) private var store

    /// The version last asked in.
    private static let key = "reviewRequestedVersion"

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, _ in
            guard due else { return }
            UserDefaults.standard.set(version, forKey: Self.key)
            Task {
                // after the goal's own celebration
                try? await Task.sleep(for: .seconds(2))
                requestReview()
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// A week since the first shift, ten shifts of work, and not asked in this version.
    private var due: Bool {
        #if DEBUG
        if Screenshot.current != nil { return false }
        #endif
        let work = store.shifts.filter { $0.type == .work }
        guard work.count >= 10, let first = work.map(\.start).min(),
              Date().timeIntervalSince(first) >= 7 * 86_400 else { return false }
        return UserDefaults.standard.string(forKey: Self.key) != version
    }
}

extension View {
    /// The App Store's rating asked for when `trigger` grows, if it is time (ReviewRequest).
    func reviewRequest(on trigger: Int) -> some View {
        modifier(ReviewRequest(trigger: trigger))
    }
}
