import AppIntents
import SwiftUI
import WidgetKit

/// The shift on the home screen and the lock screen, in the Live Activity's look: the running shift's clock
/// in the app's color (a break's in orange), its way toward the day's goal, and round buttons for a break
/// and the end; with none running, today's hours and a button to start.
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
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            clock
                .font(.system(size: 34, weight: .semibold, design: .rounded))
            bar
                .padding(.top, 8)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                buttons(size: 36)
                Spacer(minLength: 0)
                Text(wayEnd)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 4)
                clock
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                Spacer(minLength: 8)
                bar
                HStack {
                    Text(wayStart)
                    Spacer(minLength: 6)
                    Text(wayEnd)
                }
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 6)
            }
            VStack(spacing: 10) {
                buttons(size: 48)
            }
        }
    }

    /// While a shift runs, a break (or back from it) and the end; else, the start.
    @ViewBuilder
    private func buttons(size: CGFloat) -> some View {
        Group {
            if entry.running {
                Button(intent: ToggleBreakIntent()) {
                    RoundIcon(symbol: breakSymbol, color: breakColor, size: size)
                }
                Button(intent: EndShiftIntent()) {
                    RoundIcon(symbol: "stop.fill", color: .red, size: size)
                }
            } else {
                Button(intent: StartShiftIntent()) {
                    RoundIcon(symbol: "play.fill", color: WidgetStyle.accent, size: size)
                }
            }
        }
        .buttonStyle(.plain)
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
            Label(title + " · " + wayEnd, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .widgetAccentable()
            clock
                .font(.system(size: 24, weight: .semibold, design: .rounded))
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
                    Image(systemName: symbol)
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
        if entry.running {
            Label {
                if let since = entry.breakSince {
                    Text(since, style: .timer)
                } else {
                    Text(entry.workingSince, style: .timer)
                }
            } icon: {
                Image(systemName: symbol)
            }
        } else {
            Text(title + " " + Format.hoursToHM(entry.worked / 3600))
        }
    }

    // MARK: Parts

    /// The time worked, running; a break's; or today's hours.
    private var clock: some View {
        Group {
            if let since = entry.breakSince {
                Text(since, style: .timer)
            } else if entry.running {
                Text(entry.workingSince, style: .timer)
            } else {
                Text(Format.hoursToHM(entry.worked / 3600))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.leading)
        .foregroundStyle(clockColor)
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

    private var symbol: String {
        entry.onBreak ? "pause.fill" : "timer"
    }

    private var dot: Color {
        guard entry.running else { return .secondary }
        return entry.onBreak ? .orange : .green
    }

    private var clockColor: Color {
        guard entry.running else { return .primary }
        return entry.onBreak ? .orange : WidgetStyle.accent
    }

    /// Under the bar's right end: the start, or today's pay.
    private var wayStart: String {
        guard let start = entry.start else { return Format.money(entry.pay, entry.currency) }
        return "התחלה " + Format.clock(start)
    }

    /// Under its left end: the goal's time, reached, or the day's goal.
    private var wayEnd: String {
        guard entry.running else { return "יעד " + Format.hoursToHM(entry.goalHours) }
        guard let goal = entry.goalAt, goal > entry.date else { return "הגעת ליעד ✓" }
        return "יעד " + Format.clock(goal)
    }

    private var breakSymbol: String {
        entry.onBreak ? "play.fill" : "pause.fill"
    }

    private var breakColor: Color {
        entry.onBreak ? WidgetStyle.accent : Color.orange
    }
}
