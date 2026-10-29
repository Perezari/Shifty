import CoreLocation
import Foundation
import UserNotifications

/// The workplace as a place on the map: on arriving there the iPhone asks whether to start a shift, and on
/// leaving it whether to end the one running, in notifications whose buttons do it without opening the app.
/// iOS watches the place and wakes the app when it is crossed, also when the app is closed, once the location
/// is allowed "always". The place is this iPhone's (UserDefaults), as the lock is.
final class Place: NSObject, CLLocationManagerDelegate {
    static let shared = Place()
    static let enabledKey = "placeEnabled"
    static let latitudeKey = "placeLatitude"
    static let longitudeKey = "placeLongitude"
    static let radiusKey = "placeRadius"
    private static let region = "shifty.work"

    private let manager = CLLocationManager()
    /// Waiting for the location now, to set the place there.
    private var settingHere: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// The place set, if any.
    static var coordinate: CLLocationCoordinate2D? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: latitudeKey) != nil else { return nil }
        return CLLocationCoordinate2D(latitude: defaults.double(forKey: latitudeKey), longitude: defaults.double(forKey: longitudeKey))
    }

    static var radius: Double {
        let value = UserDefaults.standard.double(forKey: radiusKey)
        return value > 0 ? value : 150
    }

    /// Whether iOS lets the place be watched with the app closed.
    var always: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    /// On launch, also in the background for a crossing: the place watched as the settings say, or not at all.
    func start() {
        for region in manager.monitoredRegions where region.identifier == Self.region {
            manager.stopMonitoring(for: region)
        }
        guard Self.enabled, let center = Self.coordinate,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(center: center, radius: Self.radius, identifier: Self.region)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    /// Asks for the location "always": first while using the app, then, iOS asking again, always.
    func askAlways() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestAlwaysAuthorization()
    }

    /// The place set where the iPhone is now; false when the location is not allowed or not found.
    func setHere(_ done: @escaping (Bool) -> Void) {
        settingHere = done
        askAlways()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let done = settingHere, let location = locations.last else { return }
        settingHere = nil
        UserDefaults.standard.set(location.coordinate.latitude, forKey: Self.latitudeKey)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: Self.longitudeKey)
        start()
        done(true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let done = settingHere else { return }
        settingHere = nil
        done(false)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.region else { return }
        Task { @MainActor in await Self.arrived() }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.region else { return }
        Task { @MainActor in await Self.left() }
    }

    // MARK: The questions

    static let arriveCategory = "shifty.arrive"
    static let leaveCategory = "shifty.leave"
    /// Alerts' reminder of a break.
    static let breakCategory = "shifty.break"

    /// The notifications' buttons (Notifications handles them): start or not now; end or still at work; and
    /// a break, after six hours on end (Alerts).
    static func registerCategories() {
        let start = UNNotificationAction(identifier: "start", title: "התחל משמרת", options: [])
        let later = UNNotificationAction(identifier: "later", title: "לא עכשיו", options: [])
        let end = UNNotificationAction(identifier: "end", title: "סיים משמרת", options: [.destructive])
        let stay = UNNotificationAction(identifier: "stay", title: "אני עדיין בעבודה", options: [])
        let pause = UNNotificationAction(identifier: "break", title: "התחל הפסקה", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: arriveCategory, actions: [start, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: leaveCategory, actions: [end, stay], intentIdentifiers: []),
            UNNotificationCategory(identifier: breakCategory, actions: [pause], intentIdentifiers: []),
        ])
    }

    /// Arrived at work: whether to start, unless a shift runs.
    @MainActor
    static func arrived() async {
        guard ShiftStore.shared.active == nil else { return }
        await ask(arriveCategory, title: "הגעת ל" + placeName, body: "להתחיל משמרת עכשיו?")
    }

    /// Left work: whether to end the shift running, if one runs.
    @MainActor
    static func left() async {
        guard let active = ShiftStore.shared.active else { return }
        await ask(leaveCategory, title: "יצאת מ" + placeName, body: "המשמרת פתוחה מ־" + Format.clock(active.start) + ". לסיים אותה?")
    }

    /// The workplace's name, or "העבודה" while it has the default.
    @MainActor
    private static var placeName: String {
        let name = ShiftStore.shared.settings.workplaceName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == Settings().workplaceName ? "העבודה" : name
    }

    @MainActor
    private static func ask(_ category: String, title: String, body: String) async {
        guard await Alerts.allowed() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: category, content: content, trigger: nil))
    }
}

/// The app's notifications: shown also while the app is open, and their buttons done in the background.
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifications()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        Task { @MainActor in
            switch action {
            case "start": _ = await ShiftActions.run(.start)
            case "end": _ = await ShiftActions.run(.end)
            case "break": _ = await ShiftActions.run(.startBreak)
            default: break
            }
            completionHandler()
        }
    }
}
