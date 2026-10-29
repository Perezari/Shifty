import Foundation

// Checks the cloud mirror (Shifty/Core/CloudMirror.swift) on a cloud in memory: two devices in step, edits
// and deletions both ways, settings changed on both, a new install that must not wipe the cloud's
// settings, and no writing back and forth once the devices agree. Then the dates of the files and the
// cloud (ISODate, in Models.swift) against Foundation's calendar and formatter, which they replaced.
// TZ=Asia/Jerusalem sync-check

final class MemoryCloud: CloudStore {
    var values: [String: Data] = [:]
    var writes = 0

    func data(forKey key: String) -> Data? { values[key] }

    func set(_ data: Data, forKey key: String) {
        values[key] = data
        writes += 1
    }
}

var failures = 0
func expect(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok {
        failures += 1
        print("FAILED (line \(line)): \(what)")
    }
}

var folders: [URL] = []
func folder() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("shifty-sync-\(UUID().uuidString)")
    folders.append(url)
    return url
}
func defaults() -> UserDefaults { UserDefaults(suiteName: "shifty-sync-\(UUID().uuidString)")! }
/// A later millisecond, for the next change's stamp.
func later() { Thread.sleep(forTimeInterval: 0.005) }

/// Two devices hold the same records.
@MainActor func agree(_ a: ShiftStore, _ b: ShiftStore) -> Bool {
    a.records.sorted { $0.id < $1.id } == b.records.sorted { $0.id < $1.id }
}

MainActor.assumeIsolated {
    let cloud = MemoryCloud()
    let a = ShiftStore(folder: folder())
    let b = ShiftStore(folder: folder())
    let mirrorA = CloudMirror(cloud: cloud, store: a, defaults: defaults())
    let mirrorB = CloudMirror(cloud: cloud, store: b, defaults: defaults())

    // device A works, and sets its wage
    let start = LocalTime.date(2026, 9, 27, 7, 0)
    a.startShift(at: start)
    later()
    a.endShift(at: start.addingTimeInterval(9 * 3600))
    later()
    a.addDayOff(LocalTime.date(2026, 9, 26), type: .sick)
    later()
    a.updateSettings {
        $0.hourlyWage = 61
        $0.workplaceName = "המשרד"
    }
    mirrorA.sync()
    expect(cloud.values[CloudMirror.shiftsKey] != nil && cloud.values[CloudMirror.settingsKey] != nil, "A's shifts and settings go up")

    // device B, new, takes them
    expect(mirrorB.sync(), "B takes the cloud's")
    expect(agree(a, b), "B has A's shifts")
    expect(b.settings.hourlyWage == 61 && b.settings.workplaceName == "המשרד", "B has A's settings")

    // B edits A's shift while A deletes its sick day; they sync until they agree
    if var edited = b.shifts.first(where: { $0.type == .work }), let sick = a.shifts.first(where: { $0.type == .sick }) {
        edited.note = "ישיבה"
        later()
        b.upsert(edited)
        later()
        a.delete(sick.id)
        mirrorB.sync()
        mirrorA.sync()
        mirrorB.sync()
        expect(agree(a, b), "A and B agree")
        expect(a.shifts.first { $0.id == edited.id }?.note == "ישיבה", "B's edit reaches A")
        expect(!b.shifts.contains { $0.id == sick.id } && b.records.contains { $0.id == sick.id && $0.deleted }, "A's deletion reaches B")
    } else {
        expect(false, "B has a work shift, A a sick day")
    }

    // once they agree, nothing is written
    let writes = cloud.writes
    mirrorA.sync()
    mirrorB.sync()
    mirrorA.sync()
    expect(cloud.writes == writes, "agreeing devices write nothing")

    // settings changed on both: the newer change wins, the whole of it (as on the web)
    later()
    a.updateSettings { $0.hourlyWage = 62 }
    later()
    b.updateSettings { $0.travelPerDay = 20 }
    mirrorA.sync()
    mirrorB.sync()
    mirrorA.sync()
    expect(a.settings == b.settings && a.settings.travelPerDay == 20, "both keep the newer settings")

    // A new install changes its wage before iCloud's first download: its write is dropped (an empty cloud
    // here), and when the download comes, the cloud's settings stay, with its own change on top.
    let c = ShiftStore(folder: folder())
    let cDefaults = defaults()
    later()
    c.updateSettings { $0.hourlyWage = 70 }
    CloudMirror(cloud: MemoryCloud(), store: c, defaults: cDefaults).sync()
    expect(CloudMirror(cloud: cloud, store: c, defaults: cDefaults).sync(), "the download reaches the new install")
    expect(c.settings.hourlyWage == 70 && c.settings.travelPerDay == 20 && c.settings.workplaceName == "המשרד",
           "the cloud's settings stay, the new install's wage on top")
    expect(agree(a, c), "the new install has the shifts")
    mirrorA.sync()
    expect(a.settings.hourlyWage == 70 && a.settings.travelPerDay == 20, "its wage reaches A")

    // a new install that changed nothing takes the cloud's settings as they are
    let d = ShiftStore(folder: folder())
    CloudMirror(cloud: cloud, store: d, defaults: defaults()).sync()
    var cloudSettings = c.settings
    cloudSettings.updatedAt = nil
    var dSettings = d.settings
    dSettings.updatedAt = nil
    expect(dSettings == cloudSettings, "an untouched install takes the cloud's settings")
}

// the dates, written and read as Foundation wrote and read them before
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
func foundationString(_ date: Date) -> String {
    let ms = Int(date.ms)
    let seconds = Int((Double(ms) / 1000).rounded(.down))
    let c = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date(timeIntervalSince1970: Double(seconds)))
    return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!, ms - seconds * 1000)
}
func foundationParse(_ text: String) -> Date? {
    ((try? withFraction.parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text))).map { Date(ms: $0.ms) }
}
// every 11.45 hours or so, from 1970 to 2100, at all the milliseconds; the days around 1970; leap days
var moments = (0..<100_000).map { Double($0 * 41_234_567 + $0 % 1000) }
moments += [-86_400_001, -86_400_000, -1000, -1, 0, 1, 999, 86_399_999]
moments += [(2000, 1, 29), (2024, 1, 29), (2100, 1, 28), (2100, 2, 1), (2026, 9, 28)].map {
    LocalTime.date($0.0, $0.1, $0.2, 23, 59).ms + 59_999
}
var wrong = 0
for ms in moments {
    let date = Date(ms: ms)
    let text = ISODate.string(date)
    if text != foundationString(date) || ISODate.parse(text) != foundationParse(text) || ISODate.parse(text) != date {
        wrong += 1
        if wrong <= 3 { print("ISODate:", ms, text, foundationString(date)) }
    }
}
expect(wrong == 0, "dates written and read as Foundation does: \(wrong) of \(moments.count) differ")
for text in ["2026-02-29T07:00:00.000Z", "2024-02-29T07:00:00.000Z", "2026-10-28T24:00:00.000Z", "2026-10-28T07:60:00.000Z",
             "2026-10-28T07:00:00Z", "2026-10-28T07:00:00.5Z", "2026-10-28 07:00:00.000Z", "2026-1O-28T07:00:00.000Z", "", "x"] {
    expect(ISODate.parse(text) == foundationParse(text), "\(text) read as Foundation reads it")
}

for url in folders { try? FileManager.default.removeItem(at: url) }
print(failures == 0 ? "Sync: all checks passed" : "Sync: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
