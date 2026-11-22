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

        // the place's crossings (Place.demoCrossings): a few minutes before each shift and after it, and last
        // Friday at work with no shift recorded, for the day's detail
        var crossings: [Crossing] = []
        for shift in store.shifts where shift.type == .work {
            guard let end = shift.end else { continue }
            let early = Double(4 + Int(shift.start.timeIntervalSince1970 / 60) % 9) * 60
            crossings.append(Crossing(place: nil, arrived: true, at: shift.start.addingTimeInterval(-early)))
            crossings.append(Crossing(place: nil, arrived: false, at: end.addingTimeInterval(early / 2)))
        }
        if let friday = (1...7).map({ LocalTime.addingDays(-$0, to: today) }).first(where: { LocalTime.parts($0).weekday == 5 }) {
            let p = LocalTime.parts(friday)
            crossings.append(Crossing(place: nil, arrived: true, at: LocalTime.date(p.year, p.month0, p.day, 8, 2)))
            crossings.append(Crossing(place: nil, arrived: false, at: LocalTime.date(p.year, p.month0, p.day, 13, 15)))
        }

        if screen != .idle {
            // the shift running now, for 4:52 net after a break of 25 minutes
            let ran: TimeInterval = 5 * 3600 + 17 * 60 + 13
            let start = Date().addingTimeInterval(-ran)
            store.startShift(at: start)
            crossings.append(Crossing(place: nil, arrived: true, at: start.addingTimeInterval(-6 * 60)))
            store.startBreak(at: start.addingTimeInterval(2.5 * 3600))
            store.endBreak(at: start.addingTimeInterval(2.5 * 3600 + 25 * 60))
        }
        Place.demoCrossings = crossings
        return store
    }
}
#endif
