import Foundation

/// Whether Shifty Pro is bought, as the app last learned it from the App Store (Pro.swift), kept in the App
/// Group's defaults: the widgets and the Control Center's switch read it there, and so does the app when it is
/// woken in the background, for Siri or for a place crossed, before StoreKit has answered. Pro opens the net
/// pay, the days off left, the Live Activity and the widgets, Siri and the Control Center, iCloud and the
/// place's reminder; everything else is free.
enum ProFlag {
    private static let key = "pro"

    static var on: Bool {
        UserDefaults(suiteName: ShiftStore.appGroup)?.bool(forKey: key) ?? false
    }

    static func set(_ on: Bool) {
        UserDefaults(suiteName: ShiftStore.appGroup)?.set(on, forKey: key)
    }

    /// Siri's answer, and the Shortcuts app's, to what needs Pro.
    static let lockedAnswer = "זה זמין ב-Shifty Pro. אפשר לשדרג בהגדרות של Shifty."
}
