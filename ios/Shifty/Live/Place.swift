import CoreLocation
import Foundation
import UserNotifications

/// Each workplace as a place on the map: on arriving there the iPhone asks whether to start a shift (there), and on
/// leaving it whether to end the one running there, in notifications whose buttons do it without opening the app.
/// iOS watches the places and wakes the app when one is crossed, also when the app is closed, once the location is
/// allowed "always". The places are this iPhone's (UserDefaults), as the lock is: the own workplace's under the
/// keys below, another's under them and its id. With Shifty Pro alone.
final class Place: NSObject, CLLocationManagerDelegate {
    static let shared = Place()
    static let enabledKey = "placeEnabled"
    static let latitudeKey = "placeLatitude"
    static let longitudeKey = "placeLongitude"
    static let radiusKey = "placeRadius"
    /// When the iPhone last arrived at the place (seconds since 1970), for the Now screen to offer it as the start of
    /// a shift started later; and the shift whose offer was taken or closed.
    static let arrivedKey = "placeArrived"
    static let arrivalTipKey = "placeArrivalTip"
    /// The own workplace's region; another's is this and its id.
    private static let region = "shifty.work"

    private let manager = CLLocationManager()
    /// Waiting for the location now, to set a workplace's place there.
    private var settingHere: (place: String?, done: (Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// A key of a workplace's place: the own one's (nil) as it was, another's with its id.
    static func key(_ base: String, _ place: String?) -> String {
        place.map { base + "." + $0 } ?? base
    }

    static func enabled(_ place: String?) -> Bool {
        UserDefaults.standard.bool(forKey: key(enabledKey, place))
    }

    /// The place set, if any.
    static func coordinate(_ place: String?) -> CLLocationCoordinate2D? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key(latitudeKey, place)) != nil else { return nil }
        return CLLocationCoordinate2D(latitude: defaults.double(forKey: key(latitudeKey, place)),
                                      longitude: defaults.double(forKey: key(longitudeKey, place)))
    }

    static func radius(_ place: String?) -> Double {
        let value = UserDefaults.standard.double(forKey: key(radiusKey, place))
        return value > 0 ? value : 150
    }

    /// When the iPhone last arrived at the place, if it has.
    static func arrival(_ place: String?) -> Date? {
        let seconds = UserDefaults.standard.double(forKey: key(arrivedKey, place))
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// The workplace a region is watched for: nil for the own one; not one of these, none.
    private static func place(of region: CLRegion) -> String?? {
        if region.identifier == Self.region { return .some(nil) }
        guard region.identifier.hasPrefix(Self.region + ".") else { return nil }
        return .some(String(region.identifier.dropFirst(Self.region.count + 1)))
    }

    /// Whether iOS lets the place be watched with the app closed.
    var always: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    /// On launch, also in the background for a crossing: each workplace's place watched as the settings say, or none.
    func start() {
        for region in manager.monitoredRegions where Self.place(of: region) != nil {
            manager.stopMonitoring(for: region)
        }
        guard ProFlag.on, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        // the workplaces from the files, as the app may be woken in the background for this
        let places: [String?] = [nil] + ShiftStore.snapshot().settings.workplaces.map { Optional($0.id) }
        for place in places where Self.enabled(place) {
            guard let center = Self.coordinate(place) else { continue }
            let region = CLCircularRegion(center: center, radius: Self.radius(place),
                                          identifier: place.map { Self.region + "." + $0 } ?? Self.region)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
    }

    /// Asks for the location "always": first while using the app, then, iOS asking again, always.
    func askAlways() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestAlwaysAuthorization()
    }

    /// A workplace's place set where the iPhone is now; false when the location is not allowed or not found.
    func setHere(_ place: String?, _ done: @escaping (Bool) -> Void) {
        settingHere = (place, done)
        askAlways()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let setting = settingHere, let location = locations.last else { return }
        settingHere = nil
        UserDefaults.standard.set(location.coordinate.latitude, forKey: Self.key(Self.latitudeKey, setting.place))
        UserDefaults.standard.set(location.coordinate.longitude, forKey: Self.key(Self.longitudeKey, setting.place))
        start()
        setting.done(true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let setting = settingHere else { return }
        settingHere = nil
        setting.done(false)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let place = Self.place(of: region) else { return }
        Task { @MainActor in await Self.arrived(at: place) }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let place = Self.place(of: region) else { return }
        Task { @MainActor in await Self.left(place) }
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

    /// Arrived at a workplace: the time kept, and whether to start, unless a shift runs; the shift to start is there.
    @MainActor
    static func arrived(at place: String?) async {
        let store = ShiftStore.shared
        guard ProFlag.on else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(arrivedKey, place))
        guard store.active == nil else { return }
        store.chooseNextWorkplace(place)
        await ask(arriveCategory, title: "הגעת ל" + name(place), body: "להתחיל משמרת עכשיו?")
    }

    /// Left a workplace: whether to end the shift running there, if one runs.
    @MainActor
    static func left(_ place: String?) async {
        let store = ShiftStore.shared
        guard ProFlag.on, let active = store.active, store.settings.workplace(of: active)?.id == place else { return }
        await ask(leaveCategory, title: "יצאת מ" + name(place), body: "המשמרת פתוחה מ־" + Format.clock(active.start) + ". לסיים אותה?")
    }

    /// A workplace's name, or "העבודה" while the own one has the default.
    @MainActor
    private static func name(_ place: String?) -> String {
        let name = ShiftStore.shared.settings.place(place).name.trimmingCharacters(in: .whitespaces)
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
