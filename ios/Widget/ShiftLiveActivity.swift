import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running shift on the Lock Screen and in the Dynamic Island: its clock, its bar toward the day's goal,
/// when the goal is reached, and buttons for a break and the end. The app keeps it in step
/// (Shifty/Live/LiveShift.swift); between changes its clocks and bar run on their own.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            ActivityLockScreen(context: context)
                .environment(\.layoutDirection, .rightToLeft)
                .activityBackgroundTint(WidgetStyle.background)
                .widgetURL(URL(string: "shifty://now"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityStatus(state: context.state, workplace: context.attributes.workplace)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityClock(state: context.state)
                        .font(.title2.weight(.semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        ActivityBar(state: context.state)
                        HStack(spacing: 8) {
                            ActivityGoal(state: context.state, stale: context.isStale)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            ActivityButtons(state: context.state)
                                .frame(width: 190)
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                }
            } compactLeading: {
                Image(systemName: ActivityStatus.symbol(context.state))
                    .foregroundStyle(ActivityStatus.color(context.state))
            } compactTrailing: {
                ActivityClock(state: context.state)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 58)
            } minimal: {
                Image(systemName: ActivityStatus.symbol(context.state))
                    .foregroundStyle(ActivityStatus.color(context.state))
            }
            .widgetURL(URL(string: "shifty://now"))
            .keylineTint(WidgetStyle.accent)
        }
    }
}

/// The Lock Screen's activity: the state and the start, the clock and when the goal is reached, the bar,
/// and the buttons.
private struct ActivityLockScreen: View {
    let context: ActivityViewContext<ShiftActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                ActivityStatus(state: context.state, workplace: context.attributes.workplace)
                Spacer(minLength: 8)
                Text("התחלה " + Format.clock(context.attributes.start))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline) {
                ActivityClock(state: context.state)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                Spacer(minLength: 8)
                ActivityGoal(state: context.state, stale: context.isStale)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            ActivityBar(state: context.state)
            ActivityButtons(state: context.state)
        }
        .padding(16)
    }
}

/// "במשמרת" or "בהפסקה", with the workplace.
private struct ActivityStatus: View {
    let state: ShiftActivityAttributes.ContentState
    let workplace: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: Self.symbol(state))
                .foregroundStyle(Self.color(state))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(workplace)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var title: String {
        state.breakSince == nil ? "במשמרת" : "בהפסקה"
    }

    static func symbol(_ state: ShiftActivityAttributes.ContentState) -> String {
        state.breakSince == nil ? "timer" : "pause.fill"
    }

    static func color(_ state: ShiftActivityAttributes.ContentState) -> Color {
        state.breakSince == nil ? WidgetStyle.accent : Color.orange
    }
}

/// The time worked: running while working, standing during a break.
private struct ActivityClock: View {
    let state: ShiftActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.breakSince == nil {
                Text(state.workingSince, style: .timer)
            } else {
                Text(Format.hms(state.worked * 1000))
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.center)
    }
}

/// When the goal is reached; during a break, how long the break runs.
private struct ActivityGoal: View {
    let state: ShiftActivityAttributes.ContentState
    /// Past the goal's time.
    let stale: Bool

    var body: some View {
        if let since = state.breakSince {
            HStack(spacing: 4) {
                Text("הפסקה")
                Text(since, style: .timer)
                    .monospacedDigit()
            }
        } else if let goal = state.goalAt, !stale {
            Text("יעד ב־" + Format.clock(goal))
                .monospacedDigit()
        } else {
            Text("הגעת ליעד ✓")
        }
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
                .tint(ActivityStatus.color(state))
        }
    }

    private var share: Double {
        if state.breakSince == nil && state.goalAt == nil { return 1 }
        return state.goalHours > 0 ? min(1, state.worked / (state.goalHours * 3600)) : 0
    }
}

/// A break, or back from it, and the end.
private struct ActivityButtons: View {
    let state: ShiftActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleBreakIntent()) {
                WidgetButtonLabel(title: breakTitle, symbol: breakSymbol, color: .orange)
            }
            Button(intent: EndShiftIntent()) {
                WidgetButtonLabel(title: "סיום", symbol: "stop.fill", color: .red, filled: true)
            }
        }
        .buttonStyle(.plain)
    }

    private var breakTitle: String {
        state.breakSince == nil ? "הפסקה" : "המשך"
    }

    private var breakSymbol: String {
        state.breakSince == nil ? "pause.fill" : "play.fill"
    }
}
