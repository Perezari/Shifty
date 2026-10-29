import AppIntents
import SwiftUI
import WidgetKit

/// The shift on the home screen and the lock screen: the running shift's clock and its bar toward the day's
/// goal, with buttons for a break and the end; with none running, today's hours and a button to start.
struct ShiftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "shift", provider: ShiftTimeline()) { entry in
            ShiftWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetStyle.background }
                .widgetURL(URL(string: "shifty://now"))
                .environment(\.layoutDirection, .rightToLeft)
        }
        .configurationDisplayName("משמרת")
        .description("המשמרת שרצה, או השעות של היום, עם כפתורים להתחלה, להפסקה ולסיום.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// The shift at a moment, as the app's files hold it.
struct ShiftEntry: TimelineEntry {
    let date: Date
    /// The running shift's start; nil with none running.
    let start: Date?
    let breakSince: Date?
    /// The clock of the time worked counts from here (as the Live Activity's, ShiftActivityAttributes).
    let workingSince: Date
    /// The net time worked at `date`, in seconds: the running shift's, or today's.
    let worked: Double
    /// When the day's goal is reached; nil once it is, or with none running.
    let goalAt: Date?
    let goalHours: Double
    /// Today's income, with none running.
    let pay: Double
    let currency: String

    static func now(_ date: Date = Date()) -> ShiftEntry {
        let files = ShiftStore.snapshot()
        let active = ShiftStore.running(in: files.shifts)
        let status = Calc.nowStatus(files.shifts, files.settings, active: active, at: date.ms)
        var goalAt: Date? = nil
        if let finish = status.finishMs { goalAt = Date(ms: finish) }
        return ShiftEntry(date: date, start: active?.start, breakSince: status.activeBreak?.start,
                          workingSince: Date(ms: date.ms - status.netMs), worked: status.netMs / 1000,
                          goalAt: goalAt, goalHours: status.goal, pay: status.pay, currency: files.settings.currency)
    }

    var running: Bool { start != nil }
    var onBreak: Bool { breakSince != nil }

    /// Toward the goal as it stands at `date`: full once reached.
    var progress: Double {
        if running && goalAt == nil { return 1 }
        return goalHours > 0 ? min(1, worked / (goalHours * 3600)) : 0
    }
}

/// An entry now, and the next when the goal is reached or at midnight; the app reloads it after each change.
struct ShiftTimeline: TimelineProvider {
    func placeholder(in context: Context) -> ShiftEntry {
        ShiftEntry.now()
    }

    func getSnapshot(in context: Context, completion: @escaping (ShiftEntry) -> Void) {
        completion(ShiftEntry.now())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftEntry>) -> Void) {
        let entry = ShiftEntry.now()
        var next = LocalTime.addingDays(1, to: LocalTime.startOfDay(entry.date))
        if let goal = entry.goalAt, goal > entry.date, goal < next {
            next = goal
        }
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ShiftWidgetView: View {
    let entry: ShiftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            clock
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            bar
            Spacer(minLength: 0)
            Group {
                if entry.running {
                    Button(intent: EndShiftIntent()) {
                        WidgetButtonLabel(title: "סיום", symbol: "stop.fill", color: .red, filled: true)
                    }
                } else {
                    Button(intent: StartShiftIntent()) {
                        WidgetButtonLabel(title: "התחלה", symbol: "play.fill", filled: true)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                clock
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                bar
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            VStack(spacing: 8) {
                if entry.running {
                    Button(intent: ToggleBreakIntent()) {
                        WidgetButtonLabel(title: breakTitle, symbol: breakSymbol, color: .orange)
                    }
                    Button(intent: EndShiftIntent()) {
                        WidgetButtonLabel(title: "סיום", symbol: "stop.fill", color: .red, filled: true)
                    }
                } else {
                    Button(intent: StartShiftIntent()) {
                        WidgetButtonLabel(title: "התחלה", symbol: "play.fill", filled: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 112)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title + " · " + detail)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .widgetAccentable()
            clock
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            bar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var circular: some View {
        if entry.running {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: entry.onBreak ? "pause.fill" : "timer")
                        .font(.system(size: 13, weight: .semibold))
                    clock
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                }
            }
        } else {
            Gauge(value: entry.progress) {
                Image(systemName: "timer")
            } currentValueLabel: {
                Text(Format.hoursToHM(entry.worked / 3600))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if entry.running && !entry.onBreak {
            Label {
                Text(entry.workingSince, style: .timer)
            } icon: {
                Image(systemName: "timer")
            }
        } else {
            Text(title + " " + Format.hoursToHM(entry.worked / 3600))
        }
    }

    // MARK: Parts

    /// The time worked: running from `workingSince`, standing during a break, or today's hours.
    @ViewBuilder
    private var clock: some View {
        Group {
            if entry.running && !entry.onBreak {
                Text(entry.workingSince, style: .timer)
            } else if entry.running {
                Text(Format.hms(entry.worked * 1000))
            } else {
                Text(Format.hoursToHM(entry.worked / 3600))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// The bar toward the goal, filling by itself while working.
    @ViewBuilder
    private var bar: some View {
        if entry.running && !entry.onBreak, let goal = entry.goalAt, goal > entry.workingSince {
            ProgressView(timerInterval: entry.workingSince...goal, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(WidgetStyle.accent)
        } else {
            ProgressView(value: entry.progress)
                .tint(entry.onBreak ? Color.orange : WidgetStyle.accent)
        }
    }

    private var title: String {
        guard entry.running else { return "היום" }
        return entry.onBreak ? "בהפסקה" : "במשמרת"
    }

    private var dot: Color {
        guard entry.running else { return .secondary }
        return entry.onBreak ? .orange : .green
    }

    /// "יעד ב־16:38", "הגעת ליעד ✓", "מ־12:30" on a break, or today's pay.
    private var detail: String {
        guard entry.running else { return Format.money(entry.pay, entry.currency) }
        if let since = entry.breakSince { return "מ־" + Format.clock(since) }
        guard let goal = entry.goalAt, goal > entry.date else { return "הגעת ליעד ✓" }
        return "יעד ב־" + Format.clock(goal)
    }

    private var breakTitle: String {
        entry.onBreak ? "המשך" : "הפסקה"
    }

    private var breakSymbol: String {
        entry.onBreak ? "play.fill" : "pause.fill"
    }
}
