import Foundation
import Observation

/// The shifts and the settings on this device, local-first like the web app's localStorage
/// (assets/js/store.js): two JSON files in the App Group's container, where the widgets read them too.
/// A shift's life: it starts, takes breaks, ends.
@MainActor @Observable
final class ShiftStore {
    nonisolated static let appGroup = "group.com.perezari.shifty"

    private(set) var settings: Settings
    /// Every record, a deleted one too: a deletion stays as a tombstone, for the sync, with all the shift held, so
    /// that it can be brought back (restore).
    private(set) var records: [Shift]
    /// The last deletion made here, while the strip under the screen offers to bring it back (UndoStrip).
    private(set) var deletion: Deletion?
    /// The last day off added here, while the strip under the screen tells what is left of its kind (UndoStrip).
    private(set) var addedDayOff: AddedDayOff?
    /// Called after a change made here (not after one applied from the cloud), for the sync to push it.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let folder: URL
    /// The workplace chosen for the next shift (nextWorkplace), this device's, as UserDefaults keeps it.
    private(set) var chosenWorkplace: String?
    nonisolated static let nextWorkplaceKey = "nextWorkplace"

    /// The app's store: its screens', and the one that Siri, the widgets' buttons and the Live Activity's
    /// change (Live/LiveShift.swift), so that a change from any of them is on screen at once.
    static let shared = ShiftStore()

    init(folder: URL = ShiftStore.defaultFolder) {
        self.folder = folder
        settings = Self.read(Settings.self, from: folder.appendingPathComponent("settings.json")) ?? Settings()
        records = Self.read([Shift].self, from: folder.appendingPathComponent("shifts.json")) ?? []
        chosenWorkplace = UserDefaults.standard.string(forKey: Self.nextWorkplaceKey)
    }

    /// The settings and the shifts on screen as the files hold them, without a store: for the widgets,
    /// which run apart from the app and only read.
    nonisolated static func snapshot(folder: URL = ShiftStore.defaultFolder) -> (settings: Settings, shifts: [Shift]) {
        let settings = read(Settings.self, from: folder.appendingPathComponent("settings.json")) ?? Settings()
        let records = read([Shift].self, from: folder.appendingPathComponent("shifts.json")) ?? []
        return (settings, onScreen(records))
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
        Self.onScreen(records)
    }

    nonisolated static func onScreen(_ records: [Shift]) -> [Shift] {
        records.enumerated()
            .filter { !$0.element.deleted }
            .sorted { $0.element.start != $1.element.start ? $0.element.start > $1.element.start : $0.offset < $1.offset }
            .map(\.element)
    }

    /// The shift running now, if any: a work shift with no end. Vacation and sick days never run.
    var active: Shift? {
        Self.running(in: shifts)
    }

    nonisolated static func running(in shifts: [Shift]) -> Shift? {
        shifts.first { $0.end == nil && $0.type == .work }
    }

    func shift(_ id: String) -> Shift? {
        shifts.first { $0.id == id }
    }

    func activeBreak(of shift: Shift) -> Break? {
        shift.breaks.first { $0.end == nil }
    }

    /// The workplace the next shift starts at, and a day off is taken at: the one chosen, while the settings
    /// have it and the work there goes on; nil for the settings' own, unless its work has ended and another's
    /// goes on.
    var nextWorkplace: String? {
        let now = Self.now()
        if let id = chosenWorkplace, let place = settings.workplaces.first(where: { $0.id == id }), !place.ended(by: now) {
            return id
        }
        if settings.place(nil).ended(by: now), let open = settings.workplaces.first(where: { !$0.ended(by: now) }) {
            return open.id
        }
        return nil
    }

    func chooseNextWorkplace(_ id: String?) {
        chosenWorkplace = id
        UserDefaults.standard.set(id, forKey: Self.nextWorkplaceKey)
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
        delete([id])
    }

    /// Deletes shifts together (a day's), as one deletion for the strip to bring back. Each stays a tombstone,
    /// stamped with the time it was deleted.
    func delete(_ ids: [String]) {
        let now = Self.now()
        var gone: [String] = []
        for id in ids {
            guard let index = records.firstIndex(where: { $0.id == id }), !records[index].deleted else { continue }
            records[index].deleted = true
            records[index].updatedAt = now
            gone.append(id)
        }
        guard !gone.isEmpty else { return }
        deletion = Deletion(ids: gone, at: now)
        saveShifts()
        onChange?()
    }

    /// Brings deleted shifts back, stamped now, so that the other devices take them back too. A shift deleted while
    /// it ran runs again, unless another runs now: then it ends, with an open break, when it was deleted.
    func restore(_ ids: [String]) {
        let now = Self.now()
        var changed = false
        for id in ids {
            guard let index = records.firstIndex(where: { $0.id == id }), records[index].deleted else { continue }
            var shift = records[index]
            if shift.type == .work, shift.end == nil, active != nil {
                let end = max(shift.start, shift.updatedAt ?? now)
                for b in shift.breaks.indices where shift.breaks[b].end == nil {
                    shift.breaks[b].end = max(shift.breaks[b].start, end)
                }
                shift.end = end
            }
            shift.deleted = false
            shift.updatedAt = now
            records[index] = shift
            changed = true
        }
        if let deletion, deletion.ids.contains(where: ids.contains) {
            self.deletion = nil
        }
        guard changed else { return }
        saveShifts()
        onChange?()
    }

    /// The strip's time is over: the deletion is no longer offered there, and stays among the recently deleted.
    func forget(_ deletion: Deletion) {
        if self.deletion == deletion { self.deletion = nil }
    }

    /// The days a deleted shift is offered back (Settings › נמחקו לאחרונה); its tombstone stays after them, for
    /// the sync.
    nonisolated static let keptDays = 30

    /// The shifts deleted in the last 30 days, here or on another device, the last deleted first.
    func recentlyDeleted(asOf date: Date = ShiftStore.now()) -> [Shift] {
        let since = date.addingTimeInterval(-Double(Self.keptDays) * 86_400)
        return records
            .filter { $0.deleted && ($0.updatedAt ?? .distantPast) >= since }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    @discardableResult
    func startShift(at date: Date = ShiftStore.now()) -> Shift {
        if let active { return active }
        var shift = Shift(id: Self.newID(), start: date)
        shift.workplaceId = nextWorkplace
        // Shabbat or a holiday marked by itself, where overtime is counted as the law does
        if settings.effective(for: shift).lawOvertime { shift.isHoliday = Calc.isRestDay(date, settings) }
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
        var shift = Shift(id: Self.newID(), start: noon, end: noon, type: type)
        shift.workplaceId = nextWorkplace
        upsert(shift)
        addedDayOff = AddedDayOff(id: shift.id, type: type, at: Self.now())
        return shift
    }

    /// The strip's time is over.
    func forget(_ added: AddedDayOff) {
        if addedDayOff == added { addedDayOff = nil }
    }

    /// A sum once on a day, added or, below zero, taken off, anchored at noon as a day off is. It goes with the shifts:
    /// to iCloud, the backup, the strip that brings a deletion back and the recently deleted.
    @discardableResult
    func addAdjustment(_ date: Date, amount: Double, title: String, at place: String?) -> Shift {
        let p = LocalTime.parts(date)
        let noon = LocalTime.date(p.year, p.month0, p.day, 12)
        let shift = Shift(id: Self.newID(), start: noon, end: noon, note: title, type: .adjustment, workplaceId: place, amount: amount)
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

    /// Restores a backup of the web app or of this app (store.importAll): it replaces what is here, on the
    /// other devices too. What it restores is stamped now, so that it wins over iCloud's copy, and a shift
    /// here that the backup lacks is deleted, as a tombstone, so that iCloud does not bring it back.
    func importBackup(_ data: Data) throws {
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        let stamp = Self.now()
        if var restored = backup.settings {
            restored.updatedAt = stamp
            settings = restored
            saveSettings()
        }
        if let restored = backup.shifts {
            let kept = Set(restored.map(\.id))
            var list = restored.map { shift -> Shift in
                var shift = shift
                shift.updatedAt = stamp
                return shift
            }
            for record in records where !kept.contains(record.id) {
                var gone = record
                if !gone.deleted {
                    gone.deleted = true
                    gone.updatedAt = stamp
                }
                list.append(gone)
            }
            records = list
            saveShifts()
        }
        onChange?()
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

    nonisolated private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
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

/// A day off just added.
struct AddedDayOff: Equatable {
    let id: String
    let type: ShiftType
    let at: Date
}

/// Shifts deleted together, by a swipe, a menu, the editor or a day's menu: what the strip brings back at once.
struct Deletion: Equatable {
    let ids: [String]
    /// When, as the tombstones are stamped.
    let at: Date
}
