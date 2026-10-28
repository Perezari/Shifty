import SwiftUI

/// The running shift: its net time on the ring toward the day's goal, its wage so far, and starting and
/// ending it and its breaks. With no shift running, today's work (app.js renderNow).
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
        let hoursTitle = status.active == nil ? "שעות היום" : "שעות נטו"
        let payTitle = status.active == nil ? "שכר היום" : "שכר במשמרת"
        return ScrollView {
            VStack(spacing: 22) {
                NowHeader(status: status, date: date, settings: settings)
                NowRing(status: status, now: date)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        StatCard(title: hoursTitle, value: Format.hoursToHM(status.netHours), symbol: "clock")
                        StatCard(title: payTitle, value: Format.money(status.pay, settings.currency), symbol: "shekelsign.circle")
                    }
                }
                actions(status)
                GoalCard(status: status, settings: settings)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// The screen's one prominent button: start the shift, end it, or end its break.
    @ViewBuilder
    private func actions(_ status: NowStatus) -> some View {
        if status.active == nil {
            VStack(spacing: 10) {
                Button(action: start) {
                    Label("התחל משמרת", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button {
                    adding = true
                } label: {
                    Label("הוספה ידנית", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        } else if status.activeBreak != nil {
            VStack(spacing: 10) {
                Button(action: endBreak) {
                    Label("סיים הפסקה", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button(action: end) {
                    Label("סיים משמרת", systemImage: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        } else {
            HStack(spacing: 10) {
                Button(action: startBreak) {
                    Label("התחל הפסקה", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button(action: end) {
                    Label("סיים משמרת", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
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

/// The ring: the net time worked, filling toward the day's goal.
private struct NowRing: View {
    let status: NowStatus
    let now: Date

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 18)
            if status.progress > 0 {
                Circle()
                    .trim(from: 0, to: status.progress)
                    .stroke(fill, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 6) {
                Text(Format.hms(status.netMs))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(idle ? Color.secondary : Color.primary)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if let started = status.active?.start {
                    Text("התחלה " + Format.clock(started))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 260, height: 260)
        .animation(.easeInOut(duration: 0.6), value: status.progress)
    }

    /// Nothing worked today and nothing running: the time is faint.
    private var idle: Bool {
        status.active == nil && status.netHours == 0
    }

    private var fill: AngularGradient {
        AngularGradient(colors: [Color.accentColor.opacity(0.55), Color.accentColor], center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(360 * status.progress))
    }

    private var label: String {
        if let pause = status.activeBreak {
            return "בהפסקה · " + Format.hms(now.ms - pause.start.ms)
        }
        if status.active != nil { return "זמן עבודה" }
        return status.netHours > 0 ? "עבדת היום" : "לא במשמרת"
    }
}

/// A number and its name, on glass.
private struct StatCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card(padding: 14)
    }
}

/// The day's goal: how far, how much is left and when it is reached, and the wage it brings, or the
/// pay period's income against the monthly goal.
private struct GoalCard: View {
    let status: NowStatus
    let settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("היעד היומי")
                    .font(.headline)
                Spacer()
                Text(Format.hoursToHM(status.netHours) + " / " + Format.hoursToHM(status.goal) + " ש׳")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: status.progress)
            Text(remaining)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(reached ? Color.green : Color.secondary)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(projectionTitle)
                    .font(.subheadline)
                Spacer()
                Text(projection)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .card()
    }

    private var reached: Bool {
        status.remaining <= 0.001
    }

    /// "נותרו 4:14 ליעד · סיום ב־16:38", or "הגעת ליעד ✓" and the overtime.
    private var remaining: String {
        if reached {
            let overtime = status.overtimeHours > 0.001 ? " · שעות נוספות +" + Format.hoursToHM(status.overtimeHours) : ""
            return "הגעת ליעד ✓" + overtime
        }
        var text = "נותרו " + Format.hoursToHM(status.remaining) + " ליעד"
        if let finish = status.finishMs {
            text += " · סיום ב־" + Format.clock(Date(ms: finish))
        }
        return text
    }

    private var projectionTitle: String {
        settings.monthlyIncomeGoal > 0 ? "יעד חודשי" : "צפי שכר בסיום היעד"
    }

    private var projection: String {
        if settings.monthlyIncomeGoal > 0 {
            let total = Format.moneyShort(status.periodTotal ?? 0, settings.currency)
            return total + " מתוך " + Format.moneyShort(settings.monthlyIncomeGoal, settings.currency)
        }
        guard let projected = status.projected else { return "—" }
        return Format.money(projected, settings.currency)
    }
}
