import Foundation

/// A key-value store in the cloud: iCloud's (ICloud.swift, in the app), or one in memory for the checks.
protocol CloudStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
}

/// The shifts and the settings mirrored in a cloud key-value store, in step with the other devices of the
/// same account. A shift merges by its `updatedAt`, the newest winning, and a deletion is a tombstone, so
/// nothing a device holds is lost; the settings merge as the web app's cloud.js merges them, so that a new
/// install's defaults never wipe the cloud's. The files on the device stay the source of truth: the
/// mirror only adds to them, and writes to the cloud only what it lacks, so that two devices do not answer
/// each other forever.
@MainActor
final class CloudMirror {
    static let shiftsKey = "shifts.v1"
    static let settingsKey = "settings.v1"
    /// The settings' `updatedAt` last confirmed in the cloud (cloud.js settingsSyncedAt): local settings
    /// differ from it only when changed here since.
    private static let syncedKey = "shifty.settingsSyncedAt"

    private let cloud: CloudStore
    private let store: ShiftStore
    private let defaults: UserDefaults

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    init(cloud: CloudStore, store: ShiftStore, defaults: UserDefaults = .standard) {
        self.cloud = cloud
        self.store = store
        self.defaults = defaults
    }

    /// Takes what the cloud has that is newer, then writes what it lacks. True when the store changed.
    @discardableResult
    func sync() -> Bool {
        let shifts = syncShifts()
        let settings = syncSettings()
        return shifts || settings
    }

    // MARK: Shifts

    private func syncShifts() -> Bool {
        let remote = cloud.data(forKey: Self.shiftsKey).flatMap { try? JSONDecoder().decode([Shift].self, from: $0) } ?? []
        let theirs = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // the cloud's records newer than this device's, or new to it
        let mine = Dictionary(store.records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newer = theirs.values.filter { record in
            guard let local = mine[record.id] else { return true }
            return Self.isNewer(record, than: local)
        }
        if !newer.isEmpty { store.applyRemote(newer) }

        // this device's records the cloud lacks, or holds older: then the whole list goes up
        let lacking = store.records.contains { record in
            guard let remote = theirs[record.id] else { return true }
            return Self.isNewer(record, than: remote)
        }
        if lacking, let data = try? Self.encoder.encode(store.records.sorted { $0.id < $1.id }) {
            cloud.set(data, forKey: Self.shiftsKey)
        }
        return !newer.isEmpty
    }

    private static func isNewer(_ a: Shift, than b: Shift) -> Bool {
        (a.updatedAt?.ms ?? 0) > (b.updatedAt?.ms ?? 0)
    }

    // MARK: Settings (cloud.js syncNow)

    private func syncSettings() -> Bool {
        let local = store.settings
        let syncedAt = defaults.object(forKey: Self.syncedKey) as? Double
        guard let data = cloud.data(forKey: Self.settingsKey),
              let remote = try? JSONDecoder().decode(Settings.self, from: data),
              let remoteAt = remote.updatedAt else {
            // Nothing in the cloud yet: settings changed here go up; untouched defaults need not. Not
            // marked as confirmed: before iCloud's first download on a new install, the write is dropped,
            // and the download then meets this device as a first contact.
            if let localAt = local.updatedAt { write(local, at: localAt, confirm: false) }
            return false
        }
        let localAt = local.updatedAt?.ms ?? 0
        let localEdited = local.updatedAt != nil && local.updatedAt?.ms != syncedAt

        if syncedAt == nil {
            // first contact on this install: the cloud's settings, with this device's own changes on top
            let merged = Settings.merged(cloud: remote, local: local)
            var cloudOnly = remote
            cloudOnly.updatedAt = nil
            if merged == cloudOnly {
                store.applyRemote(settings: remote)
                confirm(remoteAt)
            } else {
                let now = ShiftStore.now()
                var applied = merged
                applied.updatedAt = now
                write(applied, at: now, confirm: true)
                store.applyRemote(settings: applied)
            }
            return true
        }
        if !localEdited {
            // nothing changed here since: the cloud's are the settings
            confirm(remoteAt)
            guard remoteAt.ms != localAt else { return false }
            store.applyRemote(settings: remote)
            return true
        }
        if remoteAt.ms > localAt {
            // a newer change from another device wins
            store.applyRemote(settings: remote)
            confirm(remoteAt)
            return true
        }
        // this device holds the newest change
        write(local, at: local.updatedAt ?? remoteAt, confirm: true)
        return false
    }

    private func write(_ settings: Settings, at time: Date, confirm confirmed: Bool) {
        var copy = settings
        copy.updatedAt = time
        guard let data = try? Self.encoder.encode(copy) else { return }
        if cloud.data(forKey: Self.settingsKey) != data { cloud.set(data, forKey: Self.settingsKey) }
        if confirmed { confirm(time) }
    }

    private func confirm(_ time: Date) {
        defaults.set(time.ms, forKey: Self.syncedKey)
    }
}

extension Settings {
    /// The cloud's settings with this device's own changes on top: each field this device holds at other
    /// than its default (cloud.js mergeSettings). A field added to the settings is added here too.
    static func merged(cloud: Settings, local: Settings) -> Settings {
        let defaults = Settings()
        var out = cloud
        func take<T: Equatable>(_ field: WritableKeyPath<Settings, T>) {
            if local[keyPath: field] != defaults[keyPath: field] { out[keyPath: field] = local[keyPath: field] }
        }
        take(\.appName)
        take(\.workplaceName)
        take(\.currency)
        take(\.theme)
        take(\.hourlyWage)
        take(\.regularDailyHours)
        take(\.standardByDay)
        take(\.overtime1Hours)
        take(\.overtime1Mult)
        take(\.overtime2Mult)
        take(\.nightEnabled)
        take(\.nightStart)
        take(\.nightEnd)
        take(\.nightMult)
        take(\.holidayMult)
        take(\.holidaysEnabled)
        take(\.holidayEveHours)
        take(\.vacationHours)
        take(\.sickDay1Pct)
        take(\.sickDay2Pct)
        take(\.sickDay3Pct)
        take(\.sickDay4Pct)
        take(\.autoBreakMinutes)
        take(\.autoBreakAfterHours)
        take(\.travelPerDay)
        take(\.travelMonthlyCap)
        take(\.monthlyIncomeGoal)
        take(\.monthStartDay)
        take(\.weekStartsOn)
        out.updatedAt = nil
        return out
    }
}
