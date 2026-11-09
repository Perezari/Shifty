import Foundation

// Checks the store on the device (Shifty/Core/ShiftStore.swift) in a temporary folder: a shift's life,
// a day off, a deletion, the files read back, and a backup of the web app's.
// TZ=Asia/Jerusalem store-check

var failures = 0
func expect(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok {
        failures += 1
        print("FAILED (line \(line)): \(what)")
    }
}

let temporary = FileManager.default.temporaryDirectory
let folder = temporary.appendingPathComponent("shifty-store-\(UUID().uuidString)")
let other = temporary.appendingPathComponent("shifty-store-\(UUID().uuidString)")
let third = temporary.appendingPathComponent("shifty-store-\(UUID().uuidString)")

MainActor.assumeIsolated {
    let store = ShiftStore(folder: folder)
    expect(store.records.isEmpty && store.active == nil, "a new store is empty")
    expect(store.settings == Settings(), "a new store has the default settings")

    // a shift's life
    let start = LocalTime.date(2026, 9, 28, 7, 2)
    let shift = store.startShift(at: start)
    expect(store.active?.id == shift.id, "the shift started runs")
    expect(store.startShift(at: start.addingTimeInterval(60)).id == shift.id, "starting again keeps the shift running")
    store.startBreak(at: start.addingTimeInterval(3 * 3600))
    expect(store.active.flatMap { store.activeBreak(of: $0) } != nil, "on a break")
    store.startBreak(at: start.addingTimeInterval(3 * 3600 + 60))
    expect(store.active?.breaks.count == 1, "no second break during a break")
    store.endBreak(at: start.addingTimeInterval(3 * 3600 + 1800))
    store.startBreak(at: start.addingTimeInterval(6 * 3600))
    let ended = store.endShift(at: start.addingTimeInterval(9 * 3600))
    expect(store.active == nil, "nothing runs after the end")
    expect(ended?.breaks.count == 2 && ended?.breaks.allSatisfy { $0.end != nil } == true, "the end closes the open break")
    if let ended {
        expect(Calc.breakdown(ended, store.settings).netHours == 5.5, "nine hours less half an hour and three")
    }

    // a day off, and its deletion
    let vacation = store.addDayOff(LocalTime.date(2026, 9, 29, 18), type: .vacation)
    expect(LocalTime.parts(vacation.start).hour == 12 && vacation.end == vacation.start, "a day off sits at noon")
    expect(store.active == nil, "a day off never runs")
    expect(store.shifts.map(\.id) == [vacation.id, shift.id], "the newest first")
    store.delete(vacation.id)
    expect(store.shifts.count == 1 && store.records.count == 2, "a deletion leaves a tombstone")
    expect(store.deletion?.ids == [vacation.id], "the deletion kept for the strip")
    expect(store.recentlyDeleted().map(\.id) == [vacation.id], "a deleted shift among the recently deleted")
    let deletedAt = store.records.first { $0.id == vacation.id }?.updatedAt ?? .distantFuture
    Thread.sleep(forTimeInterval: 0.005)
    store.restore([vacation.id])
    expect(store.shifts.map(\.id) == [vacation.id, shift.id] && store.deletion == nil, "the undo brings it back")
    expect(store.recentlyDeleted().isEmpty, "a shift brought back is no longer among the deleted")
    expect(store.records.first { $0.id == vacation.id }?.updatedAt.map { $0 > deletedAt } == true,
           "a shift brought back is stamped anew, for the other devices")
    store.delete(vacation.id)
    let stamped = store.records.first { $0.id == vacation.id }?.updatedAt
    Thread.sleep(forTimeInterval: 0.005)
    store.delete(vacation.id)
    expect(store.records.first { $0.id == vacation.id }?.updatedAt == stamped, "deleting a deleted shift again changes nothing")

    store.updateSettings {
        $0.hourlyWage = 57.3
        $0.standardByDay[5] = 5
    }
    expect(store.settings.updatedAt != nil, "a change of the settings is stamped")

    // the files read back as they were written
    let again = ShiftStore(folder: folder)
    expect(again.records == store.records, "the shifts read back")
    expect(again.settings == store.settings, "the settings read back")

    // a backup of the web app (store.exportAll): a work shift without a type, the settings it changed
    let web = """
    {"settings":{"hourlyWage":61,"standardByDay":[9.1,9.1,9.1,9.1,8.1,null,null],"theme":"dark","updatedAt":"2026-06-24T10:00:00.000Z"},
     "shifts":[{"id":"smc1","start":"2026-10-27T05:00:00.000Z","end":"2026-10-27T14:30:00.000Z",
                "breaks":[{"start":"2026-10-27T09:00:00.000Z","end":"2026-10-27T09:30:00.000Z"}],
                "isHoliday":false,"note":"","updatedAt":"2026-10-27T14:30:00.000Z"},
               {"id":"smc2","start":"2026-10-26T09:00:00.000Z","end":"2026-10-26T09:00:00.000Z","breaks":[],
                "isHoliday":false,"note":"","type":"sick"}],
     "exportedAt":"2026-10-28T10:00:00.000Z"}
    """
    do {
        var changes = 0
        store.onChange = { changes += 1 }
        let before = ShiftStore.now()
        Thread.sleep(forTimeInterval: 0.005)
        try store.importBackup(Data(web.utf8))
        expect(store.settings.hourlyWage == 61 && store.settings.theme == "dark" && store.settings.vacationHours == 8.6,
               "a web backup's settings, the others by default")
        expect(store.shifts.map(\.type) == [.work, .sick] && store.shifts[0].breaks.count == 1, "a web backup's shifts")
        expect(ISODate.string(store.shifts[0].start) == "2026-10-27T05:00:00.000Z", "a time to the millisecond")
        // the backup replaces what is here on the other devices too
        expect(changes == 1, "a restore goes to iCloud")
        expect(store.settings.updatedAt.map { $0 > before } == true && store.shifts.allSatisfy { $0.updatedAt.map { $0 > before } == true },
               "what a restore brings is newer than iCloud's")
        expect(store.records.contains { $0.id == shift.id && $0.deleted && $0.updatedAt.map { $0 > before } == true },
               "a shift the backup lacks is deleted")
        expect(store.records.filter { $0.id == vacation.id }.count == 1 && store.records.contains { $0.id == vacation.id && $0.deleted },
               "a tombstone stays one")

        let restored = ShiftStore(folder: other)
        try restored.importBackup(try store.exportBackup())
        func plain(_ list: [Shift]) -> [Shift] {
            list.map { shift in
                var shift = shift
                shift.updatedAt = nil
                return shift
            }
        }
        var restoredSettings = restored.settings
        var storeSettings = store.settings
        restoredSettings.updatedAt = nil
        storeSettings.updatedAt = nil
        expect(plain(restored.shifts) == plain(store.shifts) && restoredSettings == storeSettings,
               "this app's backup restores what it holds")
    } catch {
        expect(false, "a backup: \(error)")
    }

    // a day's shifts deleted together, a running shift brought back, and the 30 days
    let day = ShiftStore(folder: third)
    let morning = day.startShift(at: LocalTime.date(2026, 10, 2, 7, 0))
    _ = day.endShift(at: LocalTime.date(2026, 10, 2, 11, 0))
    let evening = day.startShift(at: LocalTime.date(2026, 10, 2, 17, 0))
    _ = day.endShift(at: LocalTime.date(2026, 10, 2, 21, 0))
    var pushes = 0
    day.onChange = { pushes += 1 }
    day.delete([morning.id, evening.id, "none"])
    expect(day.shifts.isEmpty && day.deletion?.ids == [morning.id, evening.id] && pushes == 1,
           "a day's shifts deleted as one deletion, sent once")
    day.restore(day.deletion?.ids ?? [])
    expect(day.shifts.count == 2 && day.deletion == nil && pushes == 2, "and brought back together")
    let deletion = Deletion(ids: [morning.id], at: Date(timeIntervalSince1970: 0))
    day.delete(morning.id)
    day.forget(deletion)
    expect(day.deletion != nil, "only the strip's own deletion is forgotten")
    if let shown = day.deletion { day.forget(shown) }
    expect(day.deletion == nil && day.recentlyDeleted().map(\.id) == [morning.id],
           "a forgotten deletion stays among the recently deleted")

    let running = day.startShift(at: LocalTime.date(2026, 10, 3, 8, 0))
    day.startBreak(at: LocalTime.date(2026, 10, 3, 10, 0))
    day.delete(running.id)
    expect(day.active == nil, "a running shift deleted runs no more")
    day.restore([running.id])
    expect(day.active?.id == running.id && day.active?.breaks.first?.end == nil, "brought back, it runs again, on its break")
    day.delete(running.id)
    let goneAt = day.records.first { $0.id == running.id }?.updatedAt
    let next = day.startShift(at: LocalTime.date(2026, 10, 3, 12, 0))
    day.restore([running.id])
    let back = day.records.first { $0.id == running.id }
    expect(day.active?.id == next.id && back?.end == goneAt && back?.breaks.first?.end == goneAt,
           "with another running, it ends, with its break, when it was deleted")

    let now = ShiftStore.now()
    var old = Shift(id: "sold", start: LocalTime.date(2026, 9, 1, 8, 0), end: LocalTime.date(2026, 9, 1, 16, 0))
    old.deleted = true
    old.updatedAt = now.addingTimeInterval(-31 * 86_400)
    var recent = Shift(id: "srecent", start: LocalTime.date(2026, 9, 2, 8, 0), end: LocalTime.date(2026, 9, 2, 16, 0))
    recent.deleted = true
    recent.updatedAt = now.addingTimeInterval(-29 * 86_400)
    day.applyRemote([old, recent])
    expect(day.recentlyDeleted(asOf: now).map(\.id) == [morning.id, "srecent"],
           "the last 30 days, the last deleted first, a deletion of another device among them")
    // a new shift on Shabbat, marked by itself where overtime is counted as the law does; a sum once goes with the shifts
    let lawStore = ShiftStore(folder: third.appendingPathComponent("law"))
    let saturdayShift = lawStore.startShift(at: LocalTime.date(2026, 10, 7, 9))
    expect(!saturdayShift.isHoliday, "not marked with the law's count off")
    lawStore.endShift(at: LocalTime.date(2026, 10, 7, 10))
    lawStore.updateSettings { $0.lawOvertime = true }
    expect(lawStore.startShift(at: LocalTime.date(2026, 10, 14, 9)).isHoliday, "marked with it on")
    lawStore.endShift(at: LocalTime.date(2026, 10, 14, 10))
    expect(!lawStore.startShift(at: LocalTime.date(2026, 10, 15, 9)).isHoliday, "a Sunday is not")
    lawStore.endShift(at: LocalTime.date(2026, 10, 15, 10))
    let oneSum = lawStore.addAdjustment(LocalTime.date(2026, 10, 16, 20), amount: -50, title: "ארוחות", at: nil)
    expect(LocalTime.parts(oneSum.start).hour == 12 && oneSum.end == oneSum.start && oneSum.type == .adjustment && lawStore.active == nil, "a sum once sits at noon, and never runs")
    expect(lawStore.addedDayOff == nil, "a sum once is no day off")
    let marked = lawStore.addDayOff(LocalTime.date(2026, 10, 17), type: .vacation)
    expect(lawStore.addedDayOff?.id == marked.id && lawStore.addedDayOff?.type == .vacation, "a day off just added, for the strip")
    if let added = lawStore.addedDayOff { lawStore.forget(added) }
    expect(lawStore.addedDayOff == nil, "and forgotten")
    lawStore.delete(oneSum.id)
    expect(lawStore.deletion?.ids == [oneSum.id] && lawStore.recentlyDeleted(asOf: ShiftStore.now()).contains { $0.id == oneSum.id }, "deleted as a shift is")
    lawStore.restore([oneSum.id])
    expect(lawStore.shift(oneSum.id)?.amount == -50, "and comes back")
    let reread = ShiftStore(folder: third.appendingPathComponent("law"))
    expect(reread.shift(oneSum.id)?.amount == -50 && reread.settings.lawOvertime, "read back from the files")
}

try? FileManager.default.removeItem(at: folder)
try? FileManager.default.removeItem(at: other)
try? FileManager.default.removeItem(at: third)
print(failures == 0 ? "Store: all checks passed" : "Store: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
