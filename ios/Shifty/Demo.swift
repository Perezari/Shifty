#if DEBUG
import Foundation

extension ShiftStore {
    /// Made-up shifts for the screenshots (ios/scripts/screenshots.sh), in a folder of their own: the
    /// repository is public, and its builds show no one's real hours or wages.
    static func demo(_ screen: Screenshot) -> ShiftStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shifty-demo", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        let store = ShiftStore(folder: folder)
        let today = LocalTime.startOfDay(Date())
        store.updateSettings {
            $0.workplaceName = "סטודיו גל"
            $0.hourlyWage = 54
            $0.standardByDay = [9.1, 9.1, 9.1, 9.1, 8.1, nil, nil]
            $0.autoBreakMinutes = 30
            $0.travelPerDay = 22.6
            // the pay period well along on any day the screenshots are taken: the calendar month from its
            // middle, and before it the period from the 15th
            $0.monthStartDay = LocalTime.parts(today).day >= 15 ? 1 : 15
        }

        // Sunday to Thursday of the last five weeks, all of the period, a little over or under the day's
        // standard, with a day of vacation and one sick
        for back in 1...35 {
            let day = LocalTime.addingDays(-back, to: today)
            let p = LocalTime.parts(day)
            guard p.weekday <= 4 else { continue }
            if back == 9 || back == 17 {
                store.addDayOff(day, type: back == 9 ? .vacation : .sick)
                continue
            }
            let start = LocalTime.date(p.year, p.month0, p.day, 7 + back % 2, (back * 13) % 60)
            let hours = 8.4 + Double(back % 5) * 0.35
            let shift = Shift(id: "demo\(back)", start: start, end: start.addingTimeInterval(hours * 3600))
            store.upsert(shift)
        }

        if screen != .idle {
            // the shift running now, for 4:52 net after a break of 25 minutes
            let start = Date().addingTimeInterval(-(5 * 3600 + 17 * 60 + 13))
            store.startShift(at: start)
            store.startBreak(at: start.addingTimeInterval(2.5 * 3600))
            store.endBreak(at: start.addingTimeInterval(2.5 * 3600 + 25 * 60))
        }
        return store
    }
}
#endif
