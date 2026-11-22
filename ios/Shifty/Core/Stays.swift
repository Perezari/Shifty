import Foundation

/// A crossing of a workplace's place (Live/Place.swift): the iPhone arrived there or left it. Kept on this iPhone
/// alone, as the places are, for a day's detail to show when it came and went beside the shifts recorded.
struct Crossing: Codable, Equatable {
    /// The workplace (Settings.workplaces' id); nil for the own one.
    var place: String?
    /// Arrived; else left.
    var arrived: Bool
    var at: Date
}

/// A stay at a workplace, from an arrival to the leaving after it. The leaving is missing while the iPhone is still
/// there, or where iOS missed it; the arrival, where the place was set during the stay.
struct Stay: Equatable {
    var place: String?
    var arrived: Date?
    var left: Date?

    /// When it began, as far as is known.
    var begun: Date { arrived ?? left ?? .distantPast }
}

enum Stays {
    /// How long the crossings are kept, in days.
    static let keptDays = 120
    /// A stay with no leaving is over after this: the next arrival is another stay, and it is no longer "still there".
    static let longest: TimeInterval = 20 * 3600

    /// Each place's stays from its crossings, by time. An arrival with no leaving since the last one is the same stay
    /// (iOS reports a crossing twice), unless that stay is over; a leaving with no arrival before it is a stay of
    /// its own.
    static func of(_ crossings: [Crossing]) -> [Stay] {
        var open: [String: Stay] = [:]
        var stays: [Stay] = []
        for crossing in crossings.sorted(by: { $0.at < $1.at }) {
            let key = crossing.place ?? ""
            if crossing.arrived {
                if let stay = open[key], let arrived = stay.arrived, crossing.at.timeIntervalSince(arrived) < longest {
                    continue
                }
                if let stay = open.removeValue(forKey: key) { stays.append(stay) }
                open[key] = Stay(place: crossing.place, arrived: crossing.at, left: nil)
            } else if var stay = open.removeValue(forKey: key) {
                stay.left = crossing.at
                stays.append(stay)
            } else {
                stays.append(Stay(place: crossing.place, arrived: nil, left: crossing.at))
            }
        }
        return (stays + open.values).sorted { $0.begun < $1.begun }
    }

    /// A day's arrival and leaving at each place (`key` as LocalTime.dayKey): the first arrival of the stays begun
    /// that day and the leaving of the last of them, none while still there and the next day's after a night. A day
    /// with no arrival has its leaving alone. In the order the places were first crossed that day.
    static func day(_ key: String, _ stays: [Stay]) -> [Stay] {
        var days: [Stay] = []
        for stay in stays where LocalTime.dayKey(stay.begun) == key {
            guard let index = days.firstIndex(where: { $0.place == stay.place }) else {
                days.append(stay)
                continue
            }
            if days[index].arrived == nil {
                // the morning's leaving alone ended the night before: a stay with an arrival takes its place
                if stay.arrived != nil { days[index] = stay } else { days[index].left = stay.left }
            } else if stay.arrived != nil {
                // back after a step out: the day's leaving is this stay's, none while still there
                days[index].left = stay.left
            } else if let left = stay.left {
                days[index].left = max(days[index].left ?? left, left)
            }
        }
        return days
    }
}
