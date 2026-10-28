import Foundation
import Observation

/// The shifts and the settings on this device, local-first like the web app's localStorage
/// (assets/js/store.js): two JSON files in the App Group's container, where the widgets read them too.
/// A shift's life: it starts, takes breaks, ends.
@MainActor @Observable
final class ShiftStore {
    nonisolated static let appGroup = "group.com.perezari.shifty"

    private(set) var settings: Settings
    /// Every record, a deleted one too: a deletion stays as a tombstone, for the sync.
    private(set) var records: [Shift]
    /// Called after a change made here (not after one applied from the cloud), for the sync to push it.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let folder: URL

    init(folder: URL = ShiftStore.defaultFolder) {
        self.folder = folder
        settings = Self.read(Settings.self, from: folder.appendingPathComponent("settings.json")) ?? Settings()
        records = Self.read([Shift].self, from: folder.appendingPathComponent("shifts.json")) ?? []
    }

    /// The App Group's container, shared with the widgets; Application Support where there is none
    /// (an unsigned simulator build).
    nonisolated static var defaultFolder: URL {
        #if os(iOS)
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return group
        }
        #endif
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Shifty", isDirectory: true)
    }

    // MARK: Reading

    /// The shifts on screen: those not deleted, the newest first (two at the same moment in the order
    /// they were added, as the web app's sort keeps them).
    var shifts: [Shift] {
        records.enumerated()
            .filter { !$0.element.deleted }
            .sorted { $0.element.start != $1.element.start ? $0.element.start > $1.element.start : $0.offset < $1.offset }
            .map(\.element)
    }

    /// The shift running now, if any: a work shift with no end. Vacation and sick days never run.
    var active: Shift? {
        shifts.first { $0.end == nil && $0.type == .work }
    }

    func shift(_ id: String) -> Shift? {
        shifts.first { $0.id == id }
    }

    func activeBreak(of shift: Shift) -> Break? {
        shift.breaks.first { $0.end == nil }
    }

    // MARK: Changes

    func updateSettings(_ change: (inout Settings) -> Void) {
        change(&settings)
        settings.updatedAt = Self.now()
        saveSettings()
        onChange?()
    }

    func upsert(_ shift: Shift) {
        var shift = shift
        shift.updatedAt = Self.now()
        if let index = records.firstIndex(where: { $0.id == shift.id }) {
            records[index] = shift
        } else {
            records.append(shift)
        }
        saveShifts()
        onChange?()
    }

    /// Deletes a shift, keeping a tombstone so that the deletion reaches the other devices.
    func delete(_ id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].deleted = true
        records[index].updatedAt = Self.now()
        saveShifts()
        onChange?()
    }

    @discardableResult
    func startShift(at date: Date = ShiftStore.now()) -> Shift {
        if let active { return active }
        let shift = Shift(id: Self.newID(), start: date)
        upsert(shift)
        return shift
    }

    /// Ends the running shift, and its open break with it.
    @discardableResult
    func endShift(at date: Date = ShiftStore.now()) -> Shift? {
        guard var shift = active else { return nil }
        if let open = shift.breaks.firstIndex(where: { $0.end == nil }) {
            shift.breaks[open].end = date
        }
        shift.end = date
        upsert(shift)
        return shift
    }

    func startBreak(at date: Date = ShiftStore.now()) {
        guard var shift = active, activeBreak(of: shift) == nil else { return }
        shift.breaks.append(Break(start: date))
        upsert(shift)
    }

    func endBreak(at date: Date = ShiftStore.now()) {
        guard var shift = active else { return }
        if let open = shift.breaks.firstIndex(where: { $0.end == nil }) {
            shift.breaks[open].end = date
        }
        upsert(shift)
    }

    /// A paid vacation or sick day, anchored at noon so that it sits inside its day.
    @discardableResult
    func addDayOff(_ date: Date, type: ShiftType) -> Shift {
        let p = LocalTime.parts(date)
        let noon = LocalTime.date(p.year, p.month0, p.day, 12)
        let shift = Shift(id: Self.newID(), start: noon, end: noon, type: type)
        upsert(shift)
        return shift
    }

    // MARK: From the cloud

    /// Records from the cloud that win over these (store.applyRemoteShifts): kept as they came, without a
    /// new stamp or a call to onChange.
    func applyRemote(_ list: [Shift]) {
        var index = Dictionary(records.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        for record in list {
            if let i = index[record.id] {
                records[i] = record
            } else {
                index[record.id] = records.count
                records.append(record)
            }
        }
        saveShifts()
    }

    /// The cloud's settings, their time kept (store.applyRemoteSettings).
    func applyRemote(settings: Settings) {
        self.settings = settings
        saveSettings()
    }

    // MARK: Backup

    /// The web app's backup file (store.exportAll): the settings, the shifts on screen and the time.
    private struct Backup: Codable {
        var settings: Settings?
        var shifts: [Shift]?
        var exportedAt: String?
    }

    func exportBackup() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(Backup(settings: settings, shifts: shifts, exportedAt: ISODate.string(Self.now())))
    }

    /// Restores a backup of the web app or of this app (store.importAll): it replaces what is here.
    func importBackup(_ data: Data) throws {
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        if let restored = backup.settings {
            settings = restored
            saveSettings()
        }
        if let restored = backup.shifts {
            records = restored
            saveShifts()
        }
    }

    // MARK: Files

    /// Now, to the millisecond: what the files keep, so that a time reads back as it was written.
    nonisolated static func now() -> Date {
        Date(ms: Date().ms)
    }

    /// "s" and the time in base 36, as the web app's ids: "smhb2k1x7f".
    nonisolated static func newID() -> String {
        "s" + String(Int64(Date().ms), radix: 36) + String(Int.random(in: 0..<1296), radix: 36)
    }

    private func saveSettings() {
        Self.write(settings, to: folder.appendingPathComponent("settings.json"))
    }

    private func saveShifts() {
        Self.write(records, to: folder.appendingPathComponent("shifts.json"))
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            // Kept in memory; the next change writes the file again.
        }
    }
}
