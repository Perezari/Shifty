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
        try store.importBackup(Data(web.utf8))
        expect(store.settings.hourlyWage == 61 && store.settings.theme == "dark" && store.settings.vacationHours == 8.6,
               "a web backup's settings, the others by default")
        expect(store.shifts.map(\.type) == [.work, .sick] && store.shifts[0].breaks.count == 1, "a web backup's shifts")
        expect(ISODate.string(store.shifts[0].start) == "2026-10-27T05:00:00.000Z", "a time to the millisecond")

        let restored = ShiftStore(folder: other)
        try restored.importBackup(try store.exportBackup())
        expect(restored.shifts == store.shifts && restored.settings == store.settings, "this app's backup restores what it holds")
    } catch {
        expect(false, "a backup: \(error)")
    }
}

try? FileManager.default.removeItem(at: folder)
try? FileManager.default.removeItem(at: other)
print(failures == 0 ? "Store: all checks passed" : "Store: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
