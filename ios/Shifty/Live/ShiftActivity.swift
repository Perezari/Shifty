import ActivityKit
import Foundation

/// The running shift as a Live Activity, on the Lock Screen and in the Dynamic Island. The app starts it,
/// keeps it in step and ends it (LiveShift.swift); the widget extension draws it (Widget/ShiftLiveActivity).
/// Between changes it runs on its own: its clocks count from dates, and its bar fills toward the goal.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The time worked counts from here: the moment of the last change less the net time worked then,
        /// so that it grows only while working.
        var workingSince: Date
        /// When the day's goal is reached, as the Now screen gives it; nil once it is reached.
        var goalAt: Date?
        /// The break running, from when.
        var breakSince: Date?
        /// The net time worked at the last change, in seconds: what the clock shows while it stands.
        var worked: Double
        /// The day's goal, in hours.
        var goalHours: Double
    }

    /// The shift's id, to tell it from a shift that ran before.
    var shiftID: String
    var start: Date
    var workplace: String
}
