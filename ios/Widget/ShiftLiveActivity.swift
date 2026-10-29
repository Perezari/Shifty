import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running shift on the Lock Screen and in the Dynamic Island: its clock large in the app's color, the
/// state and the workplace over it, round buttons for a break and the end beside it, and under them the
/// shift's way from its start to the day's goal. During a break the clock is the break's, in orange. The app
/// keeps it in step (Shifty/Live/LiveShift.swift); between changes its clocks and bar run on their own.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            // The background is the activity's own, drawn with its text: set as the system's tint, it turned
            // dark with the iPhone while the text stayed as last drawn, dark on dark.
            LockScreenActivity(state: context.state, attributes: context.attributes, stale: context.isStale)
                .environment(\.layoutDirection, .rightToLeft)
                .activityBackgroundTint(Color.clear)
                .widgetURL(URL(string: "shifty://now"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityHeadline(state: context.state, attributes: context.attributes, short: true)
                        .padding(.horizontal, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityClock(state: context.state)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(ActivityLook.color(context.state))
                        .padding(.horizontal, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 14) {
                        ActivityWay(state: context.state, attributes: context.attributes, stale: context.isStale)
                        ActivityButtons(state: context.state, size: 42)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                    .environment(\.layoutDirection, .rightToLeft)
                }
            } compactLeading: {
                Image(systemName: ActivityLook.symbol(context.state))
                    .foregroundStyle(ActivityLook.color(context.state))
            } compactTrailing: {
                // wide enough for "8:88:88": narrower, the clock was cut to "1:27:…"
                ActivityClock(state: context.state, alignment: .center)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(ActivityLook.color(context.state))
                    .minimumScaleFactor(0.7)
                    .frame(width: 64)
            } minimal: {
                Image(systemName: ActivityLook.symbol(context.state))
                    .foregroundStyle(ActivityLook.color(context.state))
            }
            .widgetURL(URL(string: "shifty://now"))
            .keylineTint(WidgetStyle.accent)
        }
    }
}

/// The Lock Screen's activity: the headline and the clock with the buttons beside them, and the way to the
/// goal under them.
private struct LockScreenActivity: View {
    let state: ShiftActivityAttributes.ContentState
    let attributes: ShiftActivityAttributes
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    ActivityHeadline(state: state, attributes: attributes, short: false)
                    ActivityClock(state: state)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(ActivityLook.color(state))
                }
                ActivityButtons(state: state, size: 50)
            }
            ActivityWay(state: state, attributes: attributes, stale: stale)
        }
        .foregroundStyle(WidgetStyle.activityText)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(WidgetStyle.activity)
    }
}

/// The colors and symbols of working and of a break.
private enum ActivityLook {
    static func symbol(_ state: ShiftActivityAttributes.ContentState) -> String {
        state.breakSince == nil ? "timer" : "pause.fill"
    }

    static func color(_ state: ShiftActivityAttributes.ContentState) -> Color {
        state.breakSince == nil ? WidgetStyle.accent : Color.orange
    }
}

/// "במשמרת · אביבי מטבחים", or during a break "בהפסקה · עבדת 57:24", after a dot of its color; the
/// Dynamic Island's has the state alone.
private struct ActivityHeadline: View {
    let state: ShiftActivityAttributes.ContentState
    let attributes: ShiftActivityAttributes
    let short: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ActivityLook.color(state))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }

    private var title: String {
        state.breakSince == nil ? "במשמרת" : "בהפסקה"
    }

    /// The workplace, unless it is the default; during a break, the time worked.
    private var detail: String? {
        guard !short else { return nil }
        if state.breakSince != nil {
            return "· עבדת " + Format.timer(state.worked * 1000)
        }
        let place = state.workplace ?? attributes.workplace
        guard !place.isEmpty, place != Settings().workplaceName else { return nil }
        return "· " + place
    }
}

/// The time worked, running; during a break, the break's.
private struct ActivityClock: View {
    let state: ShiftActivityAttributes.ContentState
    var alignment: TextAlignment = .leading

    var body: some View {
        Group {
            if let since = state.breakSince {
                Text(since, style: .timer)
            } else {
                Text(state.workingSince, style: .timer)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .multilineTextAlignment(alignment)
    }
}

/// The shift's way from its start to the goal: the bar, the start under its right end and the goal under its
/// left.
private struct ActivityWay: View {
    let state: ShiftActivityAttributes.ContentState
    let attributes: ShiftActivityAttributes
    let stale: Bool

    var body: some View {
        VStack(spacing: 6) {
            ActivityBar(state: state)
            HStack {
                Text("התחלה " + Format.clock(state.start ?? attributes.start))
                Spacer(minLength: 8)
                Text(goal)
            }
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var goal: String {
        guard let at = state.goalAt, !stale else { return "הגעת ליעד ✓" }
        return "יעד " + Format.clock(at)
    }
}

/// The bar toward the goal: filling by itself while working, standing during a break.
private struct ActivityBar: View {
    let state: ShiftActivityAttributes.ContentState

    var body: some View {
        if state.breakSince == nil, let goal = state.goalAt, goal > state.workingSince {
            ProgressView(timerInterval: state.workingSince...goal, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(WidgetStyle.accent)
        } else {
            ProgressView(value: share)
                .tint(ActivityLook.color(state))
        }
    }

    private var share: Double {
        if state.breakSince == nil && state.goalAt == nil { return 1 }
        return state.goalHours > 0 ? min(1, state.worked / (state.goalHours * 3600)) : 0
    }
}

/// A break, or back from it, and the end, as round buttons.
private struct ActivityButtons: View {
    let state: ShiftActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: ToggleBreakIntent()) {
                RoundIcon(symbol: breakSymbol, color: breakColor, size: size)
            }
            .accessibilityLabel(breakLabel)
            Button(intent: EndShiftIntent()) {
                RoundIcon(symbol: "stop.fill", color: .red, size: size)
            }
            .accessibilityLabel("סיום משמרת")
        }
        .buttonStyle(.plain)
    }

    private var breakSymbol: String {
        state.breakSince == nil ? "pause.fill" : "play.fill"
    }

    private var breakColor: Color {
        state.breakSince == nil ? Color.orange : WidgetStyle.accent
    }

    private var breakLabel: String {
        state.breakSince == nil ? "הפסקה" : "סיום הפסקה"
    }
}
