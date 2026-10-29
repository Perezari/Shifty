import SwiftUI

/// The running shift: its time worked on the ring toward the day's goal, then one card with its wage, when
/// the goal is reached and what it brings, and the buttons for a break and the end. With no shift running,
/// today's work and a button to start (app.js renderNow). The ring's clock reads as the Lock Screen's.
struct NowView: View {
    @Environment(ShiftStore.self) private var store
    @State private var adding = false
    @State private var tapped = 0

    var body: some View {
        let running = store.active != nil
        TimelineView(.periodic(from: .now, by: running ? 1 : 30)) { context in
            screen(at: context.date)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: tapped)
        .sheet(isPresented: $adding) {
            ShiftEditor(shift: nil, day: nil)
                .environment(store)
        }
        .onAppear {
            #if DEBUG
            if Screenshot.current == .editor { adding = true }
            #endif
        }
    }

    private func screen(at date: Date) -> some View {
        let settings = store.settings
        let status = Calc.nowStatus(store.shifts, settings, active: store.active, at: date.ms)
        var periodTotal: Double? = nil
        if status.active == nil {
            let period = Calc.period(around: date, monthStartDay: settings.monthStartDay)
            periodTotal = Calc.aggregate(store.shifts, settings, range: period, asOf: date.ms).total
        }
        return ScrollView {
            VStack(spacing: 28) {
                NowHeader(status: status, date: date, settings: settings)
                NowRing(status: status, now: date)
                NowStats(status: status, settings: settings, periodTotal: periodTotal)
                actions(status)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// Start, or add by hand; while working, a break and the end; on a break, back to work and the end.
    @ViewBuilder
    private func actions(_ status: NowStatus) -> some View {
        if status.active == nil {
            HStack(spacing: 10) {
                Button(action: start) {
                    Label("התחל משמרת", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("הוספה ידנית")
            }
            .controlSize(.large)
        } else if status.activeBreak != nil {
            HStack(spacing: 10) {
                Button(action: endBreak) {
                    Label("חזרה לעבודה", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button(action: end) {
                    Label("סיום משמרת", systemImage: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        } else {
            HStack(spacing: 10) {
                Button(action: startBreak) {
                    Label("הפסקה", systemImage: "pause.fill")
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button(action: end) {
                    Label("סיום משמרת", systemImage: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
    }

    private func start() {
        withAnimation { _ = store.startShift() }
        tapped += 1
    }

    private func end() {
        withAnimation { _ = store.endShift() }
        tapped += 1
    }

    private func startBreak() {
        withAnimation { store.startBreak() }
        tapped += 1
    }

    private func endBreak() {
        withAnimation { store.endBreak() }
        tapped += 1
    }
}

/// The day, and whether a shift runs.
private struct NowHeader: View {
    let status: NowStatus
    let date: Date
    let settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(title)
                    .font(.largeTitle.bold())
                if status.active != nil {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(dot)
                        .symbolEffect(.pulse)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        guard status.active != nil else { return "מוכן להתחיל" }
        return status.activeBreak == nil ? "במשמרת" : "בהפסקה"
    }

    private var dot: Color {
        status.activeBreak == nil ? .green : .orange
    }

    /// "יום ד׳, 28 באוקטובר 2026", with the day's holiday, and Shabbat for a shift marked so.
    private var subtitle: String {
        var parts = [Format.dateFull(date)]
        if settings.holidaysEnabled, let name = Holidays.info(date).name {
            parts.append(name)
        }
        if status.active?.isHoliday == true {
            parts.append("שבת/חג")
        }
        return parts.joined(separator: " · ")
    }
}

/// The ring: the time worked filling toward the day's goal, and past the goal the overtime as a second lap
/// in amber. It starts at the top and runs clockwise, as a clock's hand, in Hebrew too.
private struct NowRing: View {
    let status: NowStatus
    let now: Date

    var body: some View {
        ZStack {
            rings
            VStack(spacing: 6) {
                Text(Format.timer(status.netMs))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(idle ? Color.secondary : Color.primary)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(status.activeBreak == nil ? Color.secondary : Color.orange)
                if let started = status.active?.start {
                    Text("התחלה " + Format.clock(started))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 272, height: 272)
        .animation(.easeInOut(duration: 0.6), value: status.progress)
    }

    private var rings: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 18)
            if status.progress > 0 {
                Circle()
                    .trim(from: 0, to: status.progress)
                    .stroke(fill, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .opacity(status.activeBreak == nil ? 1 : 0.45)
            }
            if overtime > 0 {
                Circle()
                    .trim(from: 0, to: overtime)
                    .stroke(Color("Holiday"), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
        // right to left, SwiftUI turns the ring the other way, from the bottom
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Nothing worked today and nothing running: the time is faint.
    private var idle: Bool {
        status.active == nil && status.netHours == 0
    }

    /// The overtime's share of a lap, its length the day's goal.
    private var overtime: Double {
        guard status.goal > 0 else { return 0 }
        return max(0, min(1, status.overtimeHours / status.goal))
    }

    private var fill: AngularGradient {
        AngularGradient(colors: [Color.accentColor.opacity(0.55), Color.accentColor], center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(360 * status.progress))
    }

    private var label: String {
        if let pause = status.activeBreak {
            return "הפסקה " + Format.timer(now.ms - pause.start.ms)
        }
        if status.active != nil { return "זמן עבודה" }
        return status.netHours > 0 ? "עבדת היום" : "לא במשמרת"
    }
}

/// The numbers under the ring, in one card. While working: the wage so far; when the goal is reached, or the
/// overtime past it; and the wage at the goal, or the period's income against the monthly goal. With none
/// running: today's wage, the period's income and the day's goal.
private struct NowStats: View {
    let status: NowStatus
    let settings: Settings
    /// The pay period's income, with none running.
    let periodTotal: Double?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1, height: 36)
                }
                VStack(spacing: 4) {
                    Text(cells[index].value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(cells[index].title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .card(padding: 0)
    }

    private var cells: [SummaryCell] {
        let currency = settings.currency
        guard status.active != nil else {
            return [
                SummaryCell(title: "שכר היום", value: Format.money(status.pay, currency)),
                SummaryCell(title: "בתקופה", value: Format.moneyShort(periodTotal ?? 0, currency)),
                SummaryCell(title: "יעד יומי", value: Format.hoursToHM(status.goal)),
            ]
        }
        var cells = [SummaryCell(title: "שכר עד עכשיו", value: Format.money(status.pay, currency))]
        if status.remaining <= 0.001 {
            cells.append(SummaryCell(title: "שעות נוספות", value: "+" + Format.hoursToHM(status.overtimeHours)))
        } else if let finish = status.finishMs {
            cells.append(SummaryCell(title: "יעד · עוד " + Format.hoursToHM(status.remaining),
                                     value: Format.clock(Date(ms: finish))))
        }
        if settings.monthlyIncomeGoal > 0 {
            cells.append(SummaryCell(title: "מתוך " + Format.moneyShort(settings.monthlyIncomeGoal, currency),
                                     value: Format.moneyShort(status.periodTotal ?? 0, currency)))
        } else if let projected = status.projected {
            cells.append(SummaryCell(title: "צפי ביעד", value: Format.moneyShort(projected, currency)))
        }
        return cells
    }
}
