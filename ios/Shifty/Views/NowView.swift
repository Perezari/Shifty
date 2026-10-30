import SwiftUI

/// The running shift on a twelve-hour dial (Core/Dial.swift): an arc from its start to the day's goal, with the
/// time worked, its breaks and overtime, and now; in the middle the time worked and the wage. The goal's flag
/// is dragged to another time to see the wage of leaving then, the iPhone ticking at each quarter of an hour;
/// on reaching the goal it turns into a check, the ring glows and the iPhone taps. Under the dial: the start,
/// the goal and the wage at it, the buttons, then the week, the pay period and a holiday coming. With no shift
/// running, today's work and a button to start (app.js renderNow). A long press on a button makes its press
/// minutes back, or at another time, for a press made too late. Designed in ios/preview first. While a shift
/// runs the dial and its numbers are drawn again each second, the cards under them each minute.
struct NowView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.lifter) private var lifter
    @State private var adding = false
    @State private var dayOff: ShiftType?
    /// A press made too late, its time picked on the wheels.
    @State private var picking: Press?
    @State private var tapped = 0
    /// A leave time chosen by dragging the goal's flag; nil shows the shift as it is.
    @State private var plan: Date?
    @State private var glow = false
    @State private var celebrations = 0

    var body: some View {
        let running = store.active != nil
        ScrollView {
            VStack(spacing: 14) {
                TimelineView(.periodic(from: .now, by: running ? 1 : 30)) { context in
                    shift(at: context.date)
                }
                actions()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    cards(at: context.date)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: tapped)
        .sensoryFeedback(.success, trigger: celebrations)
        .sensoryFeedback(.selection, trigger: planQuarter)
        .sheet(isPresented: $adding) {
            ShiftEditor(shift: nil, day: nil)
                .environment(store)
        }
        .sheet(item: $dayOff) { type in
            DayOffSheet(type: type)
                .environment(store)
        }
        .sheet(item: $picking) { kind in
            let now = ShiftStore.now()
            MomentSheet(title: kind == .start ? "שעת כניסה" : "שעת יציאה",
                        range: min(earliest(now: now), now)...now) { moment in
                press(kind, at: moment)
            }
        }
        .onChange(of: store.active?.id) { _, _ in
            plan = nil
        }
        .onAppear {
            #if DEBUG
            if Screenshot.current == .editor { adding = true }
            #endif
        }
    }

    /// The plan's quarter of an hour: the iPhone ticks as the flag passes each.
    private var planQuarter: Int {
        guard let plan else { return 0 }
        return Int(plan.timeIntervalSince1970 / 900)
    }

    /// The state, the dial and its numbers.
    private func shift(at date: Date) -> some View {
        Perf.drew("עכשיו")
        let settings = store.settings
        let shifts = store.shifts
        let status = Calc.nowStatus(shifts, settings, active: store.active, at: date.ms)
        let reached = status.active != nil && status.remaining <= 0.001
        let period = Calc.period(around: date, monthStartDay: settings.monthStartDay)
        let periodTotals = Calc.aggregate(shifts, settings, range: period, asOf: date.ms)
        return VStack(spacing: 14) {
            NowCapsule(status: status, settings: settings, now: date)
            dial(status, settings, shifts, at: date, reached: reached)
            NowFacts(cells: facts(status, settings, totals: periodTotals, at: date))
        }
        .onChange(of: reached) { was, now in
            if now && !was { celebrate() }
        }
    }

    /// The week, the pay period, a holiday coming and the days off left.
    private func cards(at date: Date) -> some View {
        Perf.drew("כרטיסים")
        let settings = store.settings
        let shifts = store.shifts
        let period = Calc.period(around: date, monthStartDay: settings.monthStartDay)
        let days = Calc.week(shifts, settings, around: date, asOf: date.ms)
        let today = LocalTime.startOfDay(date)
        let weekStart = days.first?.date ?? today
        let weekMissing = Calc.shortfall(shifts, settings, range: TimeRange(start: weekStart, end: today), asOf: date.ms).total
        return VStack(spacing: 14) {
            WeekCard(days: days, missing: weekMissing, today: date)
            PeriodCard(range: period, totals: Calc.aggregate(shifts, settings, range: period, asOf: date.ms),
                       projected: Calc.projectedIncome(shifts, settings, range: period, asOf: date.ms),
                       missing: Calc.shortfall(shifts, settings, range: period, asOf: date.ms).total,
                       net: Calc.periodNet(shifts, settings, range: period, asOf: date.ms, projected: true),
                       settings: settings, now: date)
            if settings.holidaysEnabled, let coming = Calc.nextHoliday(after: date, within: 14) {
                HolidayBanner(date: coming.date, info: coming.info, settings: settings, today: date)
            }
            if let since = settings.balanceDate, let leave = Calc.leave(shifts, settings, asOf: date) {
                LeaveCard(balance: leave, since: since)
            }
        }
    }

    // MARK: The dial

    @ViewBuilder
    private func dial(_ status: NowStatus, _ settings: Settings, _ shifts: [Shift], at date: Date, reached: Bool) -> some View {
        if let active = status.active {
            let layout = Calc.dial(active, settings, at: date, leave: plan)
            ShiftDial(layout: layout, reached: reached && plan == nil, planned: plan != nil, glow: glow,
                      knob: knobColor(status, reached: reached),
                      drag: { degrees in
                          plan = Calc.dialTime(degrees, start: active.start, now: Date())
                      }) {
                if let leave = plan {
                    planCenter(active, leave: leave, settings, at: date)
                } else {
                    shiftCenter(hoursText: Format.timer(status.netMs), pay: status.pay, faint: false, settings, at: date)
                }
            }
        } else {
            ShiftDial(layout: Calc.dial(today: shifts, at: date), reached: false, planned: false, glow: false,
                      knob: Color.secondary, drag: nil) {
                shiftCenter(hoursText: Format.hoursToHM(status.netHours), pay: status.pay, faint: status.netHours == 0, settings, at: date)
            }
        }
    }

    private func knobColor(_ status: NowStatus, reached: Bool) -> Color {
        if status.activeBreak != nil { return .orange }
        return reached ? Color("Holiday") : .accentColor
    }

    /// The day, the time worked and the wage: the running shift's, or today's.
    private func shiftCenter(hoursText: String, pay: Double, faint: Bool, _ settings: Settings, at date: Date) -> some View {
        VStack(spacing: 8) {
            Text(dayLine(date, settings))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(hoursText)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(faint ? Color.secondary : Color.primary)
            Text(Format.money(pay, settings.currency))
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: 230)
    }

    /// Leaving at the time chosen: the wage then, and the overtime it adds or the hours it leaves short.
    private func planCenter(_ active: Shift, leave: Date, _ settings: Settings, at date: Date) -> some View {
        let leaving = Calc.leaving(active, at: leave, settings, now: date)
        let atGoal = Calc.leaving(active, at: Calc.goalTime(active, settings, asOf: date.ms), settings, now: date)
        let extra = leaving.netHours - Calc.standardHours(date, settings)
        return VStack(spacing: 8) {
            Text("אם תצא ב־" + Format.clock(leave))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(Format.money(leaving.pay, settings.currency))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.accentColor)
            Text(planDelta(extra, extraPay: leaving.pay - atGoal.pay, settings))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(extra >= -0.001 ? Color("Holiday") : Color.red)
            Button("חזרה") {
                withAnimation { plan = nil }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .frame(maxWidth: 230)
    }

    private func planDelta(_ extra: Double, extraPay: Double, _ settings: Settings) -> String {
        if extra > 0.001 {
            return "+" + Format.hoursToHM(extra) + " נוספות · +" + Format.money(extraPay, settings.currency)
        }
        if extra < -0.001 {
            return "חסרות " + Format.hoursToHM(-extra) + " ליעד"
        }
        return "בדיוק ביעד"
    }

    /// "יום ה׳, 29 באוקטובר", after the day's holiday when there is one.
    private func dayLine(_ date: Date, _ settings: Settings) -> String {
        let day = Format.weekday(date) + ", " + Format.dateLong(date)
        guard settings.holidaysEnabled, let name = Holidays.info(date).name else { return day }
        return name + " · " + day
    }

    /// The goal reached: the iPhone taps, and the ring glows a moment.
    private func celebrate() {
        celebrations += 1
        Task {
            withAnimation(.easeIn(duration: 0.3)) { glow = true }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 1.2)) { glow = false }
        }
    }

    // MARK: The numbers and the buttons

    private func facts(_ status: NowStatus, _ settings: Settings, totals: Totals, at date: Date) -> [FactCell] {
        let currency = settings.currency
        guard let active = status.active else {
            return [
                FactCell(title: "משמרות בתקופה", value: String(totals.count)),
                FactCell(title: "הכנסה בתקופה", value: Format.moneyShort(totals.total, currency)),
                FactCell(title: "יעד יומי", value: Format.hoursToHM(status.goal)),
            ]
        }
        var cells = [FactCell(title: "התחלה", value: Format.clock(active.start))]
        if let plan {
            let past = Calc.leaving(active, at: plan, settings, now: date).netHours >= status.goal - 0.001
            let color: Color = past ? Color("Holiday") : Color.red
            cells.append(FactCell(title: "יציאה מתוכננת", value: Format.clock(plan), color: color))
        } else if status.remaining <= 0.001 {
            cells.append(FactCell(title: "שעות נוספות", value: "+" + Format.hoursToHM(status.overtimeHours), color: Color("Holiday")))
        } else if let finish = status.finishMs {
            cells.append(FactCell(title: "יעד · עוד " + Format.hoursToHM(status.remaining), value: Format.clock(Date(ms: finish))))
        }
        if settings.monthlyIncomeGoal > 0 {
            cells.append(FactCell(title: "מתוך " + Format.moneyShort(settings.monthlyIncomeGoal, currency),
                                  value: Format.moneyShort(status.periodTotal ?? 0, currency)))
        } else if let projected = status.projected {
            cells.append(FactCell(title: "צפי ביעד", value: Format.moneyShort(projected, currency)))
        }
        return cells
    }

    /// Start, or add by hand; while working, a break and the end; on a break, back to work and the end. Their
    /// corners are the cards' (Theme.swift), not a capsule's. A long press lifts one (Lift.swift) with its press
    /// made minutes back, the time each makes under it, for a press made too late; the plus, with a day off.
    private func actions() -> some View {
        actionButtons()
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 24))
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        if let active = store.active {
            if store.activeBreak(of: active) != nil {
                HStack(spacing: 10) {
                    lifting(ShiftButton(title: "חזרה לעבודה", systemImage: "play.fill", prominent: true, action: endBreak)) {
                        late("חזרתי מההפסקה", .endBreak, minutes: [5, 10])
                    }
                    endButton()
                }
                .controlSize(.large)
            } else {
                HStack(spacing: 10) {
                    lifting(ShiftButton(title: "הפסקה", systemImage: "pause.fill", color: .orange, action: startBreak)) {
                        late("יצאתי להפסקה", .startBreak, minutes: [10, 20, 30])
                    }
                    endButton()
                }
                .controlSize(.large)
            }
        } else {
            HStack(spacing: 10) {
                lifting(ShiftButton(title: "התחל משמרת", systemImage: "play.fill", prominent: true, action: start)) {
                    late("התחלתי כבר", .start, minutes: [15, 30, 60], other: true)
                }
                Button {
                    if lifter?.isShowing != true { adding = true }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("הוספה ידנית")
                .liftable(card: false) {
                    Button {} label: {
                        Image(systemName: "plus")
                            .frame(width: 24)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle(radius: 24))
                } sections: {
                    [.adding(shift: { adding = true }, dayOff: { dayOff = $0 })]
                }
            }
            .controlSize(.large)
        }
    }

    private func endButton() -> some View {
        lifting(ShiftButton(title: "סיום משמרת", systemImage: "stop.fill", color: .red, action: end)) {
            late("סיימתי כבר", .end, minutes: [15, 30], other: true)
        }
    }

    /// A button of the shift that a long press lifts as it is, with its menu.
    private func lifting(_ button: ShiftButton, sections: @escaping () -> [LiftSection]) -> some View {
        button.liftable(card: false, preview: {
            button
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 24))
        }, sections: sections)
    }

    /// A press made too late: minutes back, each with the time it makes, and another time on the wheels. None
    /// before the shift's start or its last break, or for a new shift, the last one's end. Made when pressed.
    private func late(_ title: String, _ kind: Press, minutes: [Int], other: Bool = false) -> [LiftSection] {
        let now = ShiftStore.now()
        let after = earliest(now: now)
        let items = minutes.compactMap { m -> LiftItem? in
            let moment = now.addingTimeInterval(-Double(m) * 60)
            guard moment > after else { return nil }
            return LiftItem(title: m == 60 ? "לפני שעה" : "לפני \(m) דקות", subtitle: Format.clock(moment)) {
                press(kind, at: moment)
            }
        }
        var sections: [LiftSection] = []
        if !items.isEmpty {
            sections.append(LiftSection(header: title, items: items))
        }
        if other {
            sections.append(LiftSection(items: [LiftItem(title: "בשעה אחרת…", systemImage: "clock") { picking = kind }]))
        }
        return sections
    }

    /// A press of the buttons, at a moment of its own when it was made too late.
    private enum Press: Identifiable {
        case start, startBreak, endBreak, end
        var id: Self { self }
    }

    private func press(_ kind: Press, at moment: Date) {
        withAnimation {
            switch kind {
            case .start: _ = store.startShift(at: moment)
            case .startBreak: store.startBreak(at: moment)
            case .endBreak: store.endBreak(at: moment)
            case .end: _ = store.endShift(at: moment)
            }
        }
        tapped += 1
    }

    /// The earliest moment a press can be made for, within the last day: after the running shift's start and its
    /// breaks, or for a new shift, after the last one's end.
    private func earliest(now: Date) -> Date {
        let dayAgo = now.addingTimeInterval(-86_400)
        guard let active = store.active else {
            let lastEnd = store.shifts.filter { $0.type == .work }.compactMap(\.end).max()
            return max(lastEnd ?? dayAgo, dayAgo)
        }
        var moment = active.start
        for b in active.breaks {
            moment = max(moment, b.end ?? b.start)
        }
        return moment
    }

    // the buttons' taps; not the finger lifted after a long press

    private func start() {
        guard lifter?.isShowing != true else { return }
        withAnimation { _ = store.startShift() }
        tapped += 1
    }

    private func end() {
        guard lifter?.isShowing != true else { return }
        withAnimation { _ = store.endShift() }
        tapped += 1
    }

    private func startBreak() {
        guard lifter?.isShowing != true else { return }
        withAnimation { store.startBreak() }
        tapped += 1
    }

    private func endBreak() {
        guard lifter?.isShowing != true else { return }
        withAnimation { store.endBreak() }
        tapped += 1
    }
}

/// A button of the shift: its icon and word in its color on glass, or on the accent; the size and the corners
/// are its row's (NowView.actions).
private struct ShiftButton: View {
    let title: String
    let systemImage: String
    var color: Color? = nil
    var prominent = false
    let action: () -> Void

    var body: some View {
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
        } else {
            Button(action: action) { label }
                .buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let color {
            Label(title, systemImage: systemImage)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
        } else {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}

/// The state on a capsule: "במשמרת · סטודיו גל", a break's time, or none running.
private struct NowCapsule: View {
    let status: NowStatus
    let settings: Settings
    let now: Date

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(dot)
                .symbolEffect(.pulse, isActive: status.active != nil)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(status.activeBreak == nil ? Color.primary : Color.orange)
            if let place {
                Text("· " + place)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .surface(in: Capsule())
    }

    private var title: String {
        guard status.active != nil else { return "לא במשמרת" }
        guard let pause = status.activeBreak else { return "במשמרת" }
        return "בהפסקה " + Format.timer(now.ms - pause.start.ms)
    }

    private var dot: Color {
        guard status.active != nil else { return .secondary }
        return status.activeBreak == nil ? .green : .orange
    }

    /// The workplace, unless it is the default.
    private var place: String? {
        let name = settings.workplaceName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == Settings().workplaceName ? nil : name
    }
}

/// The twelve-hour dial: its track with the minutes' ticks and four hours, the arc's pieces, the start, now
/// and the goal's flag, and the middle. Drawn left to right, as clocks are in Hebrew too: right to left,
/// SwiftUI would turn the arcs the other way.
private struct ShiftDial<Center: View>: View {
    let layout: DialLayout
    /// The goal reached, with no plan: the flag is a check.
    let reached: Bool
    let planned: Bool
    let glow: Bool
    let knob: Color
    /// Called with the angle, clockwise from 12, the flag is dragged to.
    let drag: ((Double) -> Void)?
    @ViewBuilder var center: Center

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                face(size)
                    .environment(\.layoutDirection, .leftToRight)
                center
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 350)
    }

    private func face(_ size: CGFloat) -> some View {
        let c = size / 2
        let r = size * 160 / 350
        let w = size * 22 / 350
        return ZStack {
            DialFace(size: size)
            ZStack {
                ForEach(layout.pieces, id: \.self) { piece in
                    Circle()
                        .trim(from: piece.from / 360, to: piece.to / 360)
                        .stroke(Self.color(piece.kind), style: StrokeStyle(lineWidth: w, lineCap: .butt))
                        .frame(width: r * 2, height: r * 2)
                        .rotationEffect(.degrees(layout.startDeg - 90))
                }
            }
            .shadow(color: Color.accentColor.opacity(glow ? 0.6 : 0), radius: glow ? 18 : 0)
            marks(c, r)
        }
        .frame(width: size, height: size)
        .coordinateSpace(.named("dial"))
    }

    @ViewBuilder
    private func marks(_ c: CGFloat, _ r: CGFloat) -> some View {
        if let goal = layout.goalDeg {
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .position(Self.point(layout.startDeg, r, c))
            if planned {
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2.5))
                    .position(Self.point(layout.startDeg + goal, r, c))
            }
            knobView
                .position(Self.point(layout.startDeg + layout.nowDeg, r, c))
            flag
                .position(Self.point(layout.startDeg + (layout.leaveDeg ?? goal), r, c))
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("dial"))
                    .onChanged { value in
                        var degrees = atan2(value.location.x - c, -(value.location.y - c)) * 180 / .pi
                        if degrees < 0 { degrees += 360 }
                        drag?(degrees)
                    }, including: drag == nil ? [] : .all)
                .accessibilityLabel("גרירה לבחירת שעת יציאה")
        } else {
            knobView
                .position(Self.point(layout.startDeg + layout.nowDeg, r, c))
        }
    }

    /// Now: a white knob ringed in the state's color.
    private var knobView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(knob, lineWidth: 3.5))
            .overlay(Circle().fill(knob).frame(width: 9, height: 9))
            .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
    }

    /// The goal's flag, in a halo that asks to be dragged; a check once the goal is reached.
    private var flag: some View {
        ZStack {
            Circle()
                .fill(flagColor.opacity(0.18))
                .frame(width: 42, height: 42)
            Circle()
                .fill(reached ? Color.accentColor : Color.white)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            Image(systemName: reached ? "checkmark" : "flag.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(reached ? Color.white : flagColor)
        }
    }

    private var flagColor: Color {
        guard planned, let goal = layout.goalDeg, let leave = layout.leaveDeg else { return .accentColor }
        return leave >= goal ? Color("Holiday") : .red
    }

    static func point(_ degrees: Double, _ radius: CGFloat, _ c: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: c + radius * CGFloat(sin(radians)), y: c - radius * CGFloat(cos(radians)))
    }

    static func color(_ kind: DialLayout.Kind) -> Color {
        switch kind {
        case .work: Color.accentColor
        case .overtime: Color("Holiday")
        case .pause: Color.orange
        case .ahead: Color.accentColor.opacity(0.18)
        case .short: Color.red.opacity(0.22)
        case .plannedOvertime: Color("Holiday").opacity(0.4)
        case .today: Color.accentColor.opacity(0.45)
        }
    }
}

/// The dial's track, its minutes' ticks and its four hours: the same for its size, so drawn once and not with
/// each second of the shift.
private struct DialFace: View {
    let size: CGFloat

    var body: some View {
        let c = size / 2
        let r = size * 160 / 350
        let w = size * 22 / 350
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: w)
                .frame(width: r * 2, height: r * 2)
            ForEach(0..<60, id: \.self) { i in
                Capsule()
                    .fill(i % 5 == 0 ? Color.secondary : Color.secondary.opacity(0.45))
                    .frame(width: i % 5 == 0 ? 2 : 1.5, height: i % 5 == 0 ? 9 : 4)
                    .offset(y: -(r - w / 2 - (i % 5 == 0 ? 11.5 : 9)))
                    .rotationEffect(.degrees(Double(i) * 6))
            }
            ForEach([12, 3, 6, 9], id: \.self) { hour in
                Text(verbatim: String(hour))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .position(ShiftDial<EmptyView>.point(Double(hour % 12) * 30, size * 120 / 350, c))
            }
        }
        .frame(width: size, height: size)
    }
}

/// A number of the card under the dial, in a color of its own if it has one.
private struct FactCell: Hashable {
    let title: String
    let value: String
    var color: Color? = nil
}

/// The numbers under the dial, on one card.
private struct NowFacts: View {
    let cells: [FactCell]

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
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(cells[index].color ?? Color.primary)
                    Text(cells[index].title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .card(padding: 0)
    }
}

/// The week, its first day on the right: each day's hours against its standard, a day short in red, today's
/// as it grows.
private struct WeekCard: View {
    let days: [WeekDay]
    /// The hours missing on the days before today.
    let missing: Double
    let today: Date

    var body: some View {
        let total = days.reduce(0) { $0 + $1.hours }
        let todayKey = LocalTime.dayKey(today)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("השבוע")
                    .font(.headline)
                Spacer()
                Text(Format.hoursToHM(total) + " שעות")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if missing > 0.01 {
                    Text("· חסרות " + Format.hoursToHM(missing))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days, id: \.date) { day in
                    WeekColumn(day: day, isToday: LocalTime.dayKey(day.date) == todayKey, past: day.date < LocalTime.startOfDay(today))
                }
            }
        }
        .card()
    }
}

private struct WeekColumn: View {
    let day: WeekDay
    let isToday: Bool
    let past: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(day.hours > 0.001 ? Format.hoursToHM(day.hours) : " ")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(day.standard == nil ? Color.clear : Color.primary.opacity(0.06))
                    .overlay {
                        if day.standard == nil {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .frame(height: 66 * share)
            }
            .frame(width: 24, height: 66)
            Text(Format.weekdayShort(day.date).replacingOccurrences(of: "׳", with: ""))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var share: CGFloat {
        let goal = max(day.standard ?? 8, 0.1)
        return CGFloat(min(1, day.hours / goal))
    }

    private var color: Color {
        if isToday { return Color.accentColor.opacity(0.85) }
        if past, let standard = day.standard, day.hours > 0.001, day.hours < standard - 0.001 { return .red }
        return .accentColor
    }
}

/// The pay period: its income so far, where it is heading, its shifts, overtime and hours missing, and the
/// net pay it is heading to, which opens line by line.
private struct PeriodCard: View {
    let range: TimeRange
    let totals: Totals
    let projected: Double
    let missing: Double
    let net: NetPay
    let settings: Settings
    let now: Date
    @State private var showsNet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Calc.periodTitle(range))
                    .font(.headline)
                Spacer()
                Text(closes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Format.moneyShort(totals.total, settings.currency))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("צפי לסוף התקופה")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Format.moneyShort(projected, settings.currency))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
            HStack(spacing: 0) {
                mini(String(totals.count), "משמרות", .primary)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 30)
                mini(Format.hoursToHM(totals.overtimeHours), "נוספות", Color("Holiday"))
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 30)
                mini(Format.hoursToHM(missing), "חוסר", missing > 0.01 ? .red : .primary)
            }
            if net.gross > 0 {
                Divider()
                Button {
                    showsNet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("נטו משוער לסוף התקופה")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Format.moneyShort(net.net, settings.currency))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .sheet(isPresented: $showsNet) {
            NetSheet(title: Calc.periodTitle(range), pay: net, settings: settings)
        }
    }

    private func mini(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// "נסגרת בעוד 3 ימים", or tomorrow, or today.
    private var closes: String {
        let days = Int(((range.end.ms - now.ms) / 86_400_000).rounded(.up))
        if days <= 1 { return "נסגרת היום" }
        if days == 2 { return "נסגרת מחר" }
        return "נסגרת בעוד \(days) ימים"
    }
}

/// The period's net pay, line by line: the gross it is heading to, what a payslip takes off of it, and
/// what is left (Net.swift).
private struct NetSheet: View {
    let title: String
    let pay: NetPay
    let settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("נטו משוער")
                    .font(.title3.weight(.bold))
                Spacer()
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                row("ברוטו צפוי", pay.gross, primary: true)
                row("מס הכנסה", pay.incomeTax)
                row("ביטוח לאומי", pay.nationalInsurance)
                row("מס בריאות", pay.health)
                row("פנסיה", pay.pension)
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("נטו")
                    .font(.headline)
                Spacer()
                Text(Format.moneyShort(pay.net, settings.currency))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: String, _ amount: Double, primary: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Format.moneyShort(amount, settings.currency))
                .monospacedDigit()
                .foregroundStyle(primary ? .primary : .secondary)
        }
        .padding(.vertical, 8)
    }

    private var note: String {
        let points = Self.number(settings.creditPoints)
        let pension = Self.number(settings.pensionPercent)
        return "לפי מדרגות המס, ביטוח לאומי ומס בריאות של 2026, \(points) נקודות זיכוי ו־\(pension)% לפנסיה מהשכר בלי שעות נוספות ונסיעות. אפשר לשנות בהגדרות."
    }

    /// 6 as "6", 2.25 as "2.25".
    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// The vacation and sick days left (Leave.swift): the last payslip's, and the months and days off since.
private struct LeaveCard: View {
    let balance: LeaveBalance
    let since: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("חופשה ומחלה")
                    .font(.headline)
                Spacer()
                Text("מהתלוש של " + Format.dayMonth(since))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                column("sun.max.fill", balance.vacation, "ימי חופשה", Color("Holiday"))
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 36)
                column("cross.case.fill", balance.sick, "ימי מחלה", .pink)
            }
        }
        .card()
    }

    private func column(_ symbol: String, _ days: Double, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.16)))
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.days(days))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(days < 0 ? Color.red : Color.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
    }

    /// 12, 7.5, 8.7: to a tenth of a day.
    private static func days(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        return tenths == tenths.rounded() ? String(Int(tenths)) : String(tenths)
    }
}

/// A shortened day or a holiday within two weeks, from the Hebrew calendar: its standard.
private struct HolidayBanner: View {
    let date: Date
    let info: Holidays.Info
    let settings: Settings
    let today: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color("Holiday"))
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color("Holiday").opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    private var when: String {
        let days = Int(jsRound((LocalTime.startOfDay(date).ms - LocalTime.startOfDay(today).ms) / 86_400_000))
        return days <= 1 ? "מחר" : "בעוד \(days) ימים"
    }

    private var title: String {
        info.kind == .short ? "יום מקוצר " + when : (info.name ?? "חג") + " " + when
    }

    private var detail: String {
        let day = Format.weekday(date) + ", " + Format.dateLong(date)
        guard info.kind == .short else { return day }
        return (info.name ?? "") + " · " + day + " · תקן " + Format.hoursToHM(settings.holidayEveHours)
    }
}
