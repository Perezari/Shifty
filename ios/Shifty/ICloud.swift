import Foundation

/// iCloud's key-value store as the mirror's cloud (Core/CloudMirror.swift). The shifts go up deflated:
/// a key holds up to a megabyte, as the whole store does, and deflated that is years of shifts.
final class ICloudStore: CloudStore {
    private let store = NSUbiquitousKeyValueStore.default

    func data(forKey key: String) -> Data? {
        guard let packed = store.data(forKey: key) else { return nil }
        return try? (packed as NSData).decompressed(using: .zlib) as Data
    }

    func set(_ data: Data, forKey key: String) {
        guard let packed = try? (data as NSData).compressed(using: .zlib) as Data, packed.count < 1_000_000 else { return }
        store.set(packed, forKey: key)
        store.synchronize()
    }
}

/// Keeps the shifts and the settings in iCloud, with the other devices of the same Apple account and
/// for a new iPhone or a new install: on launch, on coming back to the app and on leaving it, when another
/// device changes iCloud's copy, and a moment after each change here, so that a run of changes goes up
/// once. Without iCloud everything stays on the device, as before. iCloud drops writes made before a new
/// install's first download, and then tells of the download, which merges them in again.
@MainActor
enum ICloud {
    private static var mirror: CloudMirror?
    private static var observer: NSObjectProtocol?
    private static var pending: Task<Void, Never>?

    static func start(_ store: ShiftStore) {
        guard mirror == nil else { return }
        mirror = CloudMirror(cloud: ICloudStore(), store: store)
        store.onChange = { schedule() }
        observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                          object: NSUbiquitousKeyValueStore.default, queue: .main) { _ in
            MainActor.assumeIsolated { syncNow() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        syncNow()
    }

    static func syncNow() {
        pending?.cancel()
        pending = nil
        mirror?.sync()
    }

    private static func schedule() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            syncNow()
        }
    }
}
