import Foundation

// Checks a day's arrival and leaving by the location (Shifty/Core/Stays.swift).
// TZ=Asia/Jerusalem stays-check

var failures = 0
func expect(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok {
        failures += 1
        print("FAILED (line \(line)): \(what)")
    }
}

/// A moment of November 2026.
func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date { LocalTime.date(2026, 10, day, hour, minute) }
func key(_ day: Int) -> String { LocalTime.dayKey(at(day, 12, 0)) }
func arrive(_ date: Date, _ place: String? = nil) -> Crossing { Crossing(place: place, arrived: true, at: date) }
func leave(_ date: Date, _ place: String? = nil) -> Crossing { Crossing(place: place, arrived: false, at: date) }
func one(_ day: Int, _ crossings: [Crossing]) -> Stay? {
    let days = Stays.day(key(day), Stays.of(crossings))
    return days.count == 1 ? days[0] : nil
}

// a plain day
var day = one(2, [arrive(at(2, 7, 52)), leave(at(2, 17, 10))])
expect(day?.arrived == at(2, 7, 52) && day?.left == at(2, 17, 10), "arrived 7:52, left 17:10")

// out for lunch and back: the first arrival and the last leaving
day = one(3, [arrive(at(3, 7, 40)), leave(at(3, 12, 30)), arrive(at(3, 13, 5)), leave(at(3, 16, 55))])
expect(day?.arrived == at(3, 7, 40) && day?.left == at(3, 16, 55), "lunch out: 7:40 to 16:55")

// out for lunch and back, still there: no leaving
day = one(3, [arrive(at(3, 7, 40)), leave(at(3, 12, 30)), arrive(at(3, 13, 5))])
expect(day?.arrived == at(3, 7, 40) && day?.left == nil, "back from lunch and still there")

// an arrival reported twice is one stay
day = one(4, [arrive(at(4, 7, 50)), arrive(at(4, 7, 55)), leave(at(4, 17, 0))])
expect(day?.arrived == at(4, 7, 50) && day?.left == at(4, 17, 0), "the first of two arrivals")

// a night: the stay is its arrival's day's, the leaving the next morning
let night = [arrive(at(5, 22, 0)), leave(at(6, 6, 10))]
day = one(5, night)
expect(day?.arrived == at(5, 22, 0) && day?.left == at(6, 6, 10), "a night: 22:00 to 6:10 the next day")
expect(Stays.day(key(6), Stays.of(night)).isEmpty, "the night's morning has nothing of its own")

// a leaving missed: the next day's arrival is another stay
let missed = [arrive(at(9, 8, 0)), arrive(at(10, 8, 5)), leave(at(10, 17, 0))]
day = one(9, missed)
expect(day?.arrived == at(9, 8, 0) && day?.left == nil, "a day whose leaving was missed")
day = one(10, missed)
expect(day?.arrived == at(10, 8, 5) && day?.left == at(10, 17, 0), "the next day on its own")

// the place set during the day: a leaving alone
day = one(11, [leave(at(11, 17, 20))])
expect(day?.arrived == nil && day?.left == at(11, 17, 20), "a leaving with no arrival")

// a night's end alone, then the day's stay: the day's
day = one(12, [leave(at(12, 6, 0)), arrive(at(12, 8, 0)), leave(at(12, 16, 0))])
expect(day?.arrived == at(12, 8, 0) && day?.left == at(12, 16, 0), "the day's stay, not the night's end")

// two workplaces in a day: each its own, in order
let two = Stays.day(key(16), Stays.of([arrive(at(16, 13, 0), "b"), leave(at(16, 18, 0), "b"),
                                       arrive(at(16, 8, 0)), leave(at(16, 12, 0))]))
expect(two.count == 2 && two[0].place == nil && two[0].arrived == at(16, 8, 0) && two[0].left == at(16, 12, 0)
       && two[1].place == "b" && two[1].arrived == at(16, 13, 0) && two[1].left == at(16, 18, 0),
       "the own workplace 8:00 to 12:00, then b's 13:00 to 18:00")

// a day with no crossing
expect(Stays.day(key(17), Stays.of([arrive(at(16, 8, 0)), leave(at(16, 12, 0))])).isEmpty, "another day's nothing")

print(failures == 0 ? "Stays: all checks passed" : "Stays: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
