import SwiftUI
import UIKit

/// The running shift on a twelve-hour dial (Core/Dial.swift): an arc from its start to the day's goal, with the
/// time worked, its breaks and overtime, and now; in the middle the time worked and the wage. The goal's flag
/// is dragged to another time to see the wage of leaving then, the iPhone ticking at each quarter of an hour;
/// on reaching the goal it turns into a check, the ring glows and the iPhone taps. Under the dial: the start,
/// the goal and the wage at it, the buttons, then the week, the pay period and a holiday coming. With no shift
/// running, today's work and a button to start (app.js renderNow). A long press on a button makes its press
/// minutes back, or at another time, for a press made too late. Designed in ios/preview first. While a shift
/// runs and the screen is shown, the dial and its numbers are drawn again each second, the cards under them each
/// minute; out of sight, the dial waits.
struct NowView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.lifter) private var lifter
    @State private var adding = false
    @State private var adjusting = false
    @State private var dayOff: ShiftType?
    /// A press made too late, its time picked on the wheels.
    @State private var picking: Press?
    @State private var tapped = 0
    /// A leave time chosen by dragging the goal's flag; nil shows the shift as it is.
    @State private var plan: Date?
    @State private var glow = false
    @State private var celebrations = 0
    /// The screen on screen, for the dial's clock to count.
    @State private var shown = false
    @AppStorage(HebrewDates.key) private var hebrewDate = false
    /// The shift whose arrival's offer was taken or closed.
    @AppStorage(Place.arrivalTipKey) private var arrivalTipShift = ""
    /// The running shift's start being dragged along the dial, to correct it; let go, it is kept.
    @State private var draftStart: Date?
    /// The start just moved: the shift, its start before, and until when it can be undone.
    @State private var startUndo: (shift: String, start: Date, until: Date)?

    var body: some View {
        let running = store.active != nil
        ScrollView {
            VStack(spacing: 14) {
                // schedules that stay the same as the screen is drawn again, so that each draw does not restart
                // them; an hour's while another tab is shown
                TimelineView(.periodic(from: Self.anchor, by: !shown ? 3600 : running ? 1 : 30)) { context in
                    shift(at: context.date)
                }
                arrival()
                actions()
                TimelineView(.everyMinute) { context in
                    cards(at: context.date)
                }
            }
            .padding(.horizontal, ScreenMargin.side)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        // what is left of the days off, after one is added from here
        .safeAreaInset(edge: .bottom, spacing: 0) {
            UndoStrip()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .medium), trigger: tapped)
        .sensoryFeedback(.success, trigger: celebrations)
        .sensoryFeedback(.selection, trigger: planQuarter)
        .sensoryFeedback(.selection, trigger: draftStart)
        // the goal reached: a good moment to ask for a rating, now and then (Review.swift)
        .reviewRequest(on: celebrations)
        .sheet(isPresented: $adding) {
            ShiftEditor(shift: nil, day: nil)
                .environment(store)
        }
        .sheet(item: $dayOff) { type in
            DayOffSheet(type: type)
                .environment(store)
        }
        .sheet(isPresented: $adjusting) {
            AdjustmentSheet()
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
            draftStart = nil
            startUndo = nil
        }
        .onAppear {
            shown = true
            #if DEBUG
            if Screenshot.current == .editor { adding = true }
            #endif
        }
        .onDisappear { shown = false }
    }

    /// The clocks' schedules start here, a whole second as the app opened: the same each time a screen is drawn.
    static let anchor = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))

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
        // the running shift, its start where it is being dragged to
        let running = store.active.map { active -> Shift in
            var moved = active
            if let draftStart { moved.start = draftStart }
            return moved
        }
        let status = Calc.nowStatus(shifts, settings, active: running, at: date.ms)
        let reached = status.active != nil && status.remaining <= 0.001
        let period = Calc.period(around: date, monthStartDay: settings.monthStartDay)
        let periodTotals = Calc.periodTotals(shifts, settings, range: period, asOf: date.ms)
        // a global pay: the period's overtime under the time, instead of the wage; with a bonus at targets, the hours
        // left to the next
        let current = terms(settings, at: date)
        let overtime: MonthOvertime? = current.kind == .monthly
            ? MonthOvertime(hours: overtimeOfMonth(shifts, settings, at: date), terms: current) : nil
        return VStack(spacing: 14) {
            NowCapsule(status: status, place: placeName(settings), choices: placeChoices(settings), now: date,
                       dayOff: Self.offToday(in: shifts, on: date))
            dial(status, settings, shifts, at: date, reached: reached, overtime: overtime)
            NowFacts(cells: facts(status, settings, totals: periodTotals, global: overtime != nil, at: date))
        }
        .onChange(of: reached) { was, now in
            // not at the start of a shift with no regular hours left in its week
            if now && !was && draftStart == nil && status.goal > 0 { celebrate() }
        }
    }

    /// The week, the pay period, a holiday coming and, with Shifty Pro, the days off left at each workplace keeping
    /// them.
    private func cards(at date: Date) -> some View {
        Perf.drew("כרטיסים")
        let settings = store.settings
        let shifts = store.shifts
        let period = Calc.period(around: date, monthStartDay: settings.monthStartDay)
        let days = Calc.week(shifts, settings, around: date, asOf: date.ms)
        let today = LocalTime.startOfDay(date)
        let weekStart = days.first?.date ?? today
        let weekMissing = Calc.shortfall(shifts, settings, range: TimeRange(start: weekStart, end: today), asOf: date.ms).total
        let current = terms(settings, at: date)
        // the overtime held against a month's pay: of the workplaces whose pay month is the period
        let aligned = shifts.filter { settings.monthStartDay(of: settings.workplace(of: $0)?.id) == settings.monthStartDay }
        return VStack(spacing: 14) {
            WeekCard(days: days, missing: weekMissing, today: date)
            PeriodCard(range: period, totals: Calc.periodTotals(shifts, settings, range: period, asOf: date.ms),
                       projected: Calc.projectedIncome(shifts, settings, range: period, asOf: date.ms),
                       missing: Calc.shortfall(shifts, settings, range: period, asOf: date.ms).total,
                       net: Calc.periodNet(shifts, settings, range: period, asOf: date.ms, projected: true),
                       overtime: Calc.monthlyOvertime(aligned, settings, range: period, asOf: date.ms)
                           .map { (hours: $0.hours, target: $0.terms.target(after: $0.hours)) },
                       hourValue: current.kind == .monthly ? current.hourValue : nil,
                       settings: settings, now: date)
            if settings.holidaysEnabled, let coming = Calc.nextHoliday(after: date, within: 14) {
                HolidayBanner(date: coming.date, info: coming.info, settings: settings, today: date)
            }
            if pro.unlocked {
                ForEach(leaves(shifts, settings, at: date)) { leave in
                    LeaveCard(balance: leave.balance, since: leave.since, place: leave.place)
                }
                ForEach(Calc.accruedBonuses(settings, at: date)) { bonus in
                    BonusCard(bonus: bonus, named: !settings.workplaces.isEmpty, currency: settings.currency)
                }
                ForEach(Calc.upcomingRecuperation(settings, at: date)) { due in
                    RecuperationCard(due: due, named: !settings.workplaces.isEmpty, currency: settings.currency)
                }
            }
        }
    }

    /// The days off left at each workplace whose payslip's are kept, while the work there goes on; named with more
    /// than one workplace.
    private func leaves(_ shifts: [Shift], _ settings: Settings, at date: Date) -> [PlaceLeave] {
        let places: [String?] = [nil] + settings.workplaces.map { Optional($0.id) }
        return places.compactMap { id -> PlaceLeave? in
            let place = settings.place(id)
            guard !place.ended(by: date), let since = place.rules.balanceDate,
                  let balance = Calc.leave(shifts, settings, asOf: date, at: id) else { return nil }
            return PlaceLeave(id: id ?? "", balance: balance, since: since, place: settings.workplaces.isEmpty ? nil : place.name)
        }
    }

    /// The arrival at the running shift's workplace, as its place's reminder saw it (Shifty Pro), 5 minutes to 4 hours
    /// before the shift started and after any other shift's end: offered as the start, until taken or closed.
    @ViewBuilder
    private func arrival() -> some View {
        if pro.unlocked, let active = store.active, arrivalTipShift != active.id {
            let place = store.settings.workplace(of: active)?.id
            if Place.enabled(place), let arrived = Place.arrival(place),
               arrived <= active.start.addingTimeInterval(-5 * 60), arrived > active.start.addingTimeInterval(-4 * 3600),
               !store.shifts.contains(where: { $0.id != active.id && $0.type == .work && ($0.end ?? .distantPast) > arrived }) {
                ArrivalTip(arrived: arrived, start: active.start, place: placeName(store.settings) ?? "עבודה") {
                    var moved = active
                    moved.start = arrived
                    withAnimation { store.upsert(moved) }
                    arrivalTipShift = active.id
                } close: {
                    withAnimation { arrivalTipShift = active.id }
                }
            }
        }
    }

    // MARK: The workplace

    /// The workplace the screen is about: the running shift's, or the next one's; nil for the own.
    private func workplaceID(_ settings: Settings) -> String? {
        if let active = store.active { return settings.workplace(of: active)?.id }
        return store.nextWorkplace
    }

    /// The overtime of the workplace the screen is about, in its own pay month, of its shifts paid by a month's
    /// fixed pay: what a bonus's target is held against.
    private func overtimeOfMonth(_ shifts: [Shift], _ settings: Settings, at date: Date) -> Double {
        let place = workplaceID(settings)
        let month = Calc.period(around: date, monthStartDay: settings.monthStartDay(of: place))
        let there = shifts.filter { settings.workplace(of: $0)?.id == place }
        return Calc.monthlyOvertime(there, settings, range: month, asOf: date.ms)?.hours ?? 0
    }

    /// The pay the screen is about: the running shift's, or that of the workplace the next one starts at.
    private func terms(_ settings: Settings, at date: Date) -> PayTerms {
        if let active = store.active { return settings.terms(of: active) }
        var next = Shift(id: "", start: date)
        next.workplaceId = store.nextWorkplace
        return settings.terms(of: next)
    }

    /// The workplace on the capsule: the running shift's, or the next one's. The own one's default name is left out
    /// while it is the only one.
    private func placeName(_ settings: Settings) -> String? {
        let name = (store.active.map { settings.effective(for: $0).workplaceName } ?? settings.place(store.nextWorkplace).name)
            .trimmingCharacters(in: .whitespaces)
        if settings.workplaces.isEmpty && (name.isEmpty || name == Settings().workplaceName) { return nil }
        return name
    }

    /// The workplaces to choose the next shift's from, those whose work goes on, with more than one and none running.
    private func placeChoices(_ settings: Settings) -> [PlaceChoice] {
        guard !settings.workplaces.isEmpty, store.active == nil else { return [] }
        let now = Date()
        let all = [PlaceChoice(id: nil, name: settings.workplaceName)] + settings.workplaces.map { PlaceChoice(id: $0.id, name: $0.name) }
        let open = all.filter { !settings.place($0.id).ended(by: now) }
        return open.count > 1 ? open : []
    }

    // MARK: The dial

    @ViewBuilder
    private func dial(_ status: NowStatus, _ settings: Settings, _ shifts: [Shift], at date: Date, reached: Bool,
                      overtime: MonthOvertime?) -> some View {
        if let active = status.active {
            let layout = Calc.dial(active, settings, at: date, leave: plan,
                                   before: Calc.workedBefore(of: active, in: shifts, settings, asOf: date.ms))
            // the start dragged: its time over the clock, then that it changed, with an undo, for a few seconds
            let undo = startUndo.flatMap { $0.shift == active.id && date < $0.until ? $0 : nil }
            let note: (text: String, accent: Bool)? = draftStart != nil ? ("התחלה ב־" + Format.clock(active.start), false)
                : undo != nil ? ("ההתחלה עודכנה ל־" + Format.clock(active.start), true) : nil
            ShiftDial(layout: layout, reached: reached && plan == nil, planned: plan != nil, glow: glow,
                      knob: knobColor(status, reached: reached),
                      drag: { degrees in
                          plan = Calc.dialTime(degrees, start: active.start, now: Date())
                      },
                      moveStart: plan == nil ? moveStart(to:) : nil,
                      movingStart: draftStart != nil) {
                if let leave = plan {
                    planCenter(active, leave: leave, settings, at: date, global: overtime != nil)
                } else {
                    shiftCenter(hoursText: Format.timer(status.netMs), pay: status.pay, overtime: overtime, faint: false, settings, at: date,
                                note: note, undo: undo != nil ? undoStart : nil)
                }
            }
        } else if let off = Self.offToday(in: shifts, on: date) {
            ShiftDial(layout: Calc.dial(dayOff: off, at: date), reached: false, planned: false, glow: false,
                      knob: off.dayOffColor, drag: nil) {
                dayOffCenter(off, pay: status.pay, settings, at: date)
            }
        } else {
            ShiftDial(layout: Calc.dial(today: shifts, at: date), reached: false, planned: false, glow: false,
                      knob: Color.secondary, drag: nil) {
                shiftCenter(hoursText: Format.hoursToHM(status.netHours), pay: status.pay, overtime: overtime,
                            faint: status.netHours == 0, settings, at: date)
            }
        }
    }

    /// Today's day off, if any.
    private static func offToday(in shifts: [Shift], on date: Date) -> ShiftType? {
        let today = Calc.dayRange(date)
        return shifts.first { $0.isDayOff && Calc.inRange($0, today) }?.type
    }

    /// The day, its symbol, what kind of day off it is and what it pays.
    private func dayOffCenter(_ type: ShiftType, pay: Double, _ settings: Settings, at date: Date) -> some View {
        VStack(spacing: 6) {
            Text(dayLine(date, settings))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            DayOffSymbol(type: type, size: 54)
                .foregroundStyle(type.dayOffColor)
                .padding(.vertical, 4)
            Text(type.dayOffTitle)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // nothing on a day that pays nothing by itself: a first sick day, reserve duty, a month's fixed pay
            if pay > 0.005 {
                Text(Format.money(pay, settings.currency))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: 230)
    }

    private func knobColor(_ status: NowStatus, reached: Bool) -> Color {
        if status.activeBreak != nil { return .orange }
        return reached ? Color("Holiday") : .accentColor
    }

    /// The day, the time worked and the wage: the running shift's, or today's. A global pay's has the period's
    /// overtime instead of the wage, and with a bonus at targets, the hours left to the next.
    private func shiftCenter(hoursText: String, pay: Double, overtime: MonthOvertime?, faint: Bool, _ settings: Settings,
                             at date: Date, note: (text: String, accent: Bool)? = nil, undo: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            // the day, or the start dragged instead
            Text(note?.text ?? dayLine(date, settings))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(note?.accent == true ? Color.accentColor : Color.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(hoursText)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(faint ? Color.secondary : Color.primary)
            if let overtime {
                Text(Format.hoursToHM(overtime.hours) + " נוספות החודש")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color("Holiday"))
                if let bonus = overtime.bonusLine {
                    Text(bonus)
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .padding(.top, -4)
                }
            } else {
                Text(Format.money(pay, settings.currency))
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
            if let undo {
                Button("ביטול", action: undo)
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: 230)
    }

    /// The running shift's start dragged to `degrees` on the dial, never past its first break nor before the shift
    /// before it; let go (nil), it is kept when it moved, and can be undone for a few seconds.
    private func moveStart(to degrees: Double?) {
        guard let active = store.active else {
            draftStart = nil
            return
        }
        guard let degrees else {
            if let draft = draftStart, abs(draft.ms - active.start.ms) >= 60_000 {
                var moved = active
                moved.start = draft
                withAnimation { store.upsert(moved) }
                startUndo = (active.id, active.start, Date().addingTimeInterval(6))
            }
            draftStart = nil
            return
        }
        let before = store.shifts.filter { $0.id != active.id && $0.type == .work }.compactMap(\.end).filter { $0 <= active.start }.max()
        draftStart = Calc.dialStart(degrees, now: Date(), earliest: before, latest: active.breaks.map(\.start).min())
    }

    /// The start moved back to where it was.
    private func undoStart() {
        guard let undo = startUndo, var active = store.active, active.id == undo.shift else {
            startUndo = nil
            return
        }
        active.start = undo.start
        withAnimation { store.upsert(active) }
        startUndo = nil
    }

    /// Leaving at the time chosen: the wage then (a global pay's, the hours), and the overtime it adds or the hours
    /// it leaves short.
    private func planCenter(_ active: Shift, leave: Date, _ settings: Settings, at date: Date, global: Bool) -> some View {
        let before = Calc.workedBefore(of: active, in: store.shifts, settings, asOf: date.ms)
        let leaving = Calc.leaving(active, at: leave, settings, now: date, before: before)
        let atGoal = Calc.leaving(active, at: Calc.goalTime(active, settings, asOf: date.ms, before: before), settings, now: date, before: before)
        let extra = leaving.netHours - Calc.regularRoom(active.start.ms, leave.ms, settings.effective(for: active), before: before)
        return VStack(spacing: 8) {
            Text("אם תצא ב־" + Format.clock(leave))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(global ? Format.hoursToHM(leaving.netHours) : Format.money(leaving.pay, settings.currency))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.accentColor)
            Text(planDelta(extra, extraPay: global ? nil : leaving.pay - atGoal.pay, settings))
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

    private func planDelta(_ extra: Double, extraPay: Double?, _ settings: Settings) -> String {
        if extra > 0.001 {
            guard let extraPay else { return "+" + Format.hoursToHM(extra) + " נוספות" }
            return "+" + Format.hoursToHM(extra) + " נוספות · +" + Format.money(extraPay, settings.currency)
        }
        if extra < -0.001 {
            return "חסרות " + Format.hoursToHM(-extra) + " ליעד"
        }
        return "בדיוק ביעד"
    }

    /// "יום ה׳, 29 באוקטובר", after the day's holiday when there is one; the Hebrew date after it when it is on,
    /// "יום ג׳, 3 בנובמבר · כ״ג בחשוון".
    private func dayLine(_ date: Date, _ settings: Settings) -> String {
        var day = Format.weekday(date) + ", " + Format.dateLong(date)
        if hebrewDate { day += " · " + Format.hebrewDate(date) }
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

    /// A global pay's has the period's hours where the income is heading.
    private func facts(_ status: NowStatus, _ settings: Settings, totals: Totals, global: Bool, at date: Date) -> [FactCell] {
        let currency = settings.currency
        let hours = FactCell(title: "שעות בתקופה", value: Format.hoursToHM(totals.netHours))
        guard let active = status.active else {
            var cells = [
                FactCell(title: "משמרות בתקופה", value: String(totals.count)),
                global ? hours : FactCell(title: "הכנסה בתקופה", value: Format.moneyShort(totals.total, currency)),
            ]
            // a day off has no goal
            if Self.offToday(in: store.shifts, on: date) == nil {
                cells.append(FactCell(title: "יעד יומי", value: Format.hoursToHM(status.goal)))
            }
            return cells
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
        } else if global {
            cells.append(hours)
        } else if let projected = status.projected {
            cells.append(FactCell(title: "צפי ביעד", value: Format.moneyShort(projected, currency)))
        }
        return cells
    }

    /// Start, or add by hand; while working, a break (none where the workplace takes an automatic break) and the
    /// end; on a break, back to work and the end. Their corners are the cards' (Theme.swift), not a capsule's. A
    /// long press lifts one (Lift.swift) with its press made minutes back, the time each makes under it, for a
    /// press made too late; the end, held until it fills (HoldToEnd), is lifted by a tap; the plus, with a day off.
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
                    // an automatic break is taken off by itself: none is pressed
                    if store.settings.effective(for: active).autoBreakMinutes == 0 {
                        lifting(ShiftButton(title: "הפסקה", systemImage: "pause.fill", color: .orange, action: startBreak)) {
                            late("יצאתי להפסקה", .startBreak, minutes: [10, 20, 30])
                        }
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
                    [.adding(shift: { adding = true }, dayOff: { dayOff = $0 }, adjustment: { adjusting = true })]
                }
            }
            .controlSize(.large)
        }
    }

    /// The end, held until it fills; a tap lifts it with the end pressed too late, and a line on holding it.
    private func endButton() -> some View {
        HoldToEnd(menu: {
            [LiftSection(header: "לסיום עכשיו, להחזיק את הכפתור עד שיתמלא", items: [])]
                + late("סיימתי כבר", .end, minutes: [15, 30], other: true)
        }, end: {
            // with taps of its own as it fills, and when it is full (HoldToEnd)
            withAnimation { _ = store.endShift() }
        })
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

/// The arrival at work before the shift's start, offered as its start: a tip, as TipKit draws one, its action under a
/// line and a close in its corner.
private struct ArrivalTip: View {
    let arrived: Date
    let start: Date
    /// "סטודיו גל", or "עבודה".
    let place: String
    let take: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("הגעת ל" + place + " ב־" + Format.clock(arrived))
                        .font(.subheadline.weight(.semibold))
                    Text("המשמרת התחילה " + later + " אחר כך, ב־" + Format.clock(start) + ".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("סגירה")
            }
            .padding(.bottom, 10)
            Divider()
            Button(action: take) {
                Text("להתחיל מ־" + Format.clock(arrived))
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// "13 דקות", or "1:15 שעות".
    private var later: String {
        let minutes = Int(jsRound((start.ms - arrived.ms) / 60000))
        return minutes < 60 ? "\(minutes) דקות" : Format.hoursToHM(Double(minutes) / 60) + " שעות"
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

/// The shift's end, held a second and a half until it fills from its start, against a tap by mistake: let go
/// before, it empties (designed in ios/preview). Drawn at the size of a button of its row (a hidden one's), its
/// glass, the red fill and the words in one frame, so that the fill starts at the glass's very edge and its white
/// words lie over the red ones. A tap lifts it with its menu (Lift.swift), as a long press lifts the other buttons.
private struct HoldToEnd: View {
    let menu: () -> [LiftSection]
    let end: () -> Void
    @Environment(\.lifter) private var lifter
    /// How far the hold has come, from 0 to 1.
    @State private var filled = 0.0
    @State private var done = false
    /// When the press began; once let go, when and how long it was held: a tap is short, a hold let go is not.
    @State private var pressedAt: Date?
    @State private var lastPress: (at: Date, held: Double)?
    @State private var spot = LiftSpot()
    /// The taps as it fills.
    @State private var ticking: Task<Void, Never>?

    private static let seconds = 1.5
    /// The iPhone's taps: ten as it fills, each harder than the one before, and a success once it is full (UIKit's
    /// generators, readied as the finger presses).
    private static let charge = UIImpactFeedbackGenerator(style: .rigid)
    private static let full = UINotificationFeedbackGenerator()

    var body: some View {
        Self.look(filled: filled)
            .contentShape(Rectangle())
            .onTapGesture(perform: tap)
            .onLongPressGesture(minimumDuration: Self.seconds, maximumDistance: 30, perform: finish, onPressingChanged: press)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                spot.frame = frame
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("סיום משמרת")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { lift() }
            .accessibilityAction(named: "סיום עכשיו", end)
    }

    /// Red words on glass, the red filling it from its start as far as `filled`, the words white over it.
    private static func look(filled: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ShiftButton(title: "סיום משמרת", systemImage: "stop.fill", color: .red) {}
            .hidden()
            .overlay {
                ZStack {
                    words
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(.red)
                        .mask { HoldFill(share: filled) }
                    words
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mask { HoldFill(share: filled) }
                }
            }
    }

    private static var words: some View {
        Label("סיום משמרת", systemImage: "stop.fill")
    }

    private func press(_ pressing: Bool) {
        let now = Date()
        if pressing {
            done = false
            pressedAt = now
            withAnimation(.linear(duration: Self.seconds)) { filled = 1 }
            Self.charge.prepare()
            Self.full.prepare()
            ticking?.cancel()
            ticking = Task {
                for i in 0..<10 {
                    Self.charge.impactOccurred(intensity: 0.3 + 0.07 * CGFloat(i))
                    try? await Task.sleep(for: .seconds(Self.seconds / 10))
                    if Task.isCancelled { return }
                }
            }
        } else {
            ticking?.cancel()
            ticking = nil
            if let pressedAt { lastPress = (now, now.timeIntervalSince(pressedAt)) }
            pressedAt = nil
            guard !done else { return }
            withAnimation(.easeOut(duration: 0.25)) { filled = 0 }
        }
    }

    private func finish() {
        ticking?.cancel()
        ticking = nil
        Self.full.notificationOccurred(.success)
        done = true
        end()
    }

    /// A tap, and not a hold let go: lifted with its menu.
    private func tap() {
        let now = Date()
        let held = pressedAt.map { now.timeIntervalSince($0) }
            ?? lastPress.flatMap { now.timeIntervalSince($0.at) < 0.5 ? $0.held : nil } ?? 0
        guard !done, held < 0.4 else { return }
        lift()
    }

    private func lift() {
        let sections = menu()
        guard let lifter, !lifter.isShowing, !sections.isEmpty else { return }
        lifter.show(Lift(source: spot.frame, card: false, preview: AnyView(lifted), sections: sections))
    }

    /// As it looks lifted, over the blur.
    private var lifted: some View {
        Self.look(filled: 0)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 24))
    }
}

/// As far as a hold has come: a share of the width, from the start.
private struct HoldFill: View {
    let share: Double

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .frame(width: proxy.size.width * share)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A workplace to choose the next shift's from (NowCapsule).
private struct PlaceChoice: Identifiable, Hashable {
    /// nil for the settings' own workplace.
    let id: String?
    let name: String
}

/// The state on a capsule: "במשמרת · סטודיו גל", a break's time, or none running. With more than one workplace and
/// none running, a tap on it chooses the next shift's (designed in ios/preview).
private struct NowCapsule: View {
    let status: NowStatus
    /// The workplace's name, when it is shown.
    let place: String?
    let choices: [PlaceChoice]
    let now: Date
    /// Today's day off.
    var dayOff: ShiftType? = nil
    @Environment(ShiftStore.self) private var store

    var body: some View {
        if choices.isEmpty {
            capsule
        } else {
            Menu {
                Section("המשמרת הבאה") {
                    Picker("המשמרת הבאה", selection: next) {
                        ForEach(choices) { choice in
                            Text(choice.name).tag(choice.id)
                        }
                    }
                    .pickerStyle(.inline)
                }
            } label: {
                capsule
            }
            .buttonStyle(.plain)
        }
    }

    private var capsule: some View {
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
            if !choices.isEmpty {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .surface(in: Capsule())
    }

    private var next: Binding<String?> {
        Binding(get: { store.nextWorkplace }, set: { store.chooseNextWorkplace($0) })
    }

    private var title: String {
        guard status.active != nil else { return dayOff?.dayOffTitle ?? "לא במשמרת" }
        guard let pause = status.activeBreak else { return "במשמרת" }
        return "בהפסקה " + Format.timer(now.ms - pause.start.ms)
    }

    private var dot: Color {
        guard status.active != nil else { return dayOff?.dayOffColor ?? .secondary }
        return status.activeBreak == nil ? .green : .orange
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
    /// Called with the angle the start is dragged to, and with nil once it is let go.
    var moveStart: ((Double?) -> Void)? = nil
    /// The start being dragged: it has a halo, as the flag has.
    var movingStart = false
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
            // the start, dragged along the dial to correct it, in a finger's room
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .background(Circle().fill(Color.accentColor.opacity(movingStart ? 0.22 : 0)).frame(width: 40, height: 40))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .position(Self.point(layout.startDeg, r, c))
                .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("dial"))
                    .onChanged { value in
                        var degrees = atan2(value.location.x - c, -(value.location.y - c)) * 180 / .pi
                        if degrees < 0 { degrees += 360 }
                        moveStart?(degrees)
                    }
                    .onEnded { _ in moveStart?(nil) }, including: moveStart == nil ? [] : .all)
                .accessibilityLabel("גרירה לתיקון שעת ההתחלה")
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
        case .dayOff(let type): type.dayOffColor.opacity(0.85)
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
                // a day off fills its column in its color, as on the calendar
                if let off = day.dayOff {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(off.dayOffColor.gradient)
                    DayOffSymbol(type: off, size: 12)
                        .foregroundStyle(.white)
                        .frame(maxHeight: .infinity)
                }
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

/// A global pay's overtime this period, under the dial's time.
private struct MonthOvertime {
    let hours: Double
    /// The pay now.
    let terms: PayTerms

    /// With a bonus at targets: "עוד 13:30 לבונוס", or "הגעת לכל היעדים".
    var bonusLine: String? {
        guard terms.overtimeCover == .tiers, !terms.overtimeTiers.isEmpty else { return nil }
        guard let target = terms.target(after: hours) else { return "הגעת לכל היעדים" }
        return "עוד " + Format.hoursToHM(target - hours) + " לבונוס"
    }
}

/// A workplace's days off left, on its card.
private struct PlaceLeave: Identifiable {
    let id: String
    let balance: LeaveBalance
    let since: Date
    let place: String?
}

/// The pay period: its dates and the days left, its income so far and where it is heading, each over its name,
/// its shifts, overtime and hours missing, and the net pay it is heading to, which opens line by line; without
/// Shifty Pro, the net's line marked Pro opens Pro.
private struct PeriodCard: View {
    let range: TimeRange
    let totals: Totals
    let projected: Double
    let missing: Double
    let net: NetPay
    /// The overtime of the shifts paid by a month's fixed pay, and what it is held against: the hours the pay
    /// covers, or the next bonus's target (Calc.monthlyOvertime, PayTerms.target).
    let overtime: (hours: Double, target: Double?)?
    /// A global pay's hour, when the pay now is one.
    let hourValue: Double?
    let settings: Settings
    let now: Date
    @Environment(Pro.self) private var pro
    @State private var showsNet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Calc.periodTitle(range, year: false))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text(closes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            // the income and the aside on one line, each one's name under it, as the numbers under them
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.moneyShort(totals.total, settings.currency))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text(aside.value)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                HStack {
                    Text(global ? "שכר גלובלי" : "עד עכשיו")
                    Spacer()
                    Text(aside.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                mini(String(totals.count), "משמרות", totals.count > 0 ? .primary : .secondary)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 30)
                if let overtime, let target = overtime.target {
                    // a global pay's overtime against the hours it covers, or the next bonus's target
                    mini(Format.hoursToHM(overtime.hours), "נוספות", shown(overtime.hours, in: Color("Holiday")),
                         of: "מתוך " + (target == target.rounded() ? String(Int(target)) : Format.hoursToHM(target)))
                } else {
                    mini(Format.hoursToHM(totals.overtimeHours), "נוספות", shown(totals.overtimeHours, in: Color("Holiday")))
                }
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 30)
                mini(Format.hoursToHM(missing), "חוסר", shown(missing, in: .red))
            }
            if net.gross > 0 {
                Divider()
                Button {
                    if pro.unlocked { showsNet = true } else { pro.offer() }
                } label: {
                    HStack(spacing: 6) {
                        Text("נטו משוער")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if pro.unlocked {
                            Text(Format.moneyShort(net.net, settings.currency))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.accentColor)
                        } else {
                            ProBadge()
                        }
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
            NetSheet(title: Calc.periodTitle(range), year: Calc.taxYear(of: range), pay: net, settings: settings)
        }
    }

    private func mini(_ value: String, _ title: String, _ color: Color, of: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                if let of {
                    Text(of)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The income is a month's fixed pay: named so, with its hour beside it.
    private var global: Bool { hourValue != nil && totals.salary > 0 }

    /// Beside the income: a bonus in the period; a global pay's hour; or where the income is heading.
    private var aside: (title: String, value: String) {
        if totals.bonus > 0 {
            return ("כולל בונוס שנתי", Format.moneyShort(totals.bonus, settings.currency))
        }
        if global, let hourValue {
            return ("ערך שעה", Format.money(hourValue, settings.currency))
        }
        return ("צפי לסוף התקופה", Format.moneyShort(projected, settings.currency))
    }

    /// Hours in their color, or gray while they show as 0:00, so the eye goes to what is there.
    private func shown(_ hours: Double, in color: Color) -> Color {
        hours * 60 < 0.5 ? .secondary : color
    }

    /// "עוד 3 ימים", or "נסגרת מחר", or "נסגרת היום".
    private var closes: String {
        let days = Int(((range.end.ms - now.ms) / 86_400_000).rounded(.up))
        if days <= 1 { return "נסגרת היום" }
        if days == 2 { return "נסגרת מחר" }
        return "עוד \(days) ימים"
    }
}

/// The period's net pay, line by line: the gross it is heading to, what a payslip takes off of it, and
/// what is left (Net.swift); under it, what the employers save besides.
private struct NetSheet: View {
    let title: String
    /// The year the period's payslip counts in.
    let year: Int
    let pay: NetPay
    let settings: Settings

    var body: some View {
        ScrollView {
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
                    if pay.studyFund > 0 {
                        row("קרן השתלמות", pay.studyFund)
                    }
                    if pay.deductions > 0 {
                        row("ניכויים", pay.deductions)
                    }
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
                if pay.employer.total > 0 {
                    employer
                }
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// What the employers save besides, in a box under the net.
    private var employer: some View {
        VStack(spacing: 0) {
            HStack {
                Text("המעביד מפריש בשבילך")
                Spacer()
                Text(Format.moneyShort(pay.employer.total, settings.currency))
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.bottom, 4)
            share("פנסיה", pay.employer.pension)
            share("פיצויים", pay.employer.severance)
            if pay.employer.studyFund > 0 {
                share("קרן השתלמות", pay.employer.studyFund)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func share(_ title: String, _ amount: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Format.moneyShort(amount, settings.currency))
                .monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 3)
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
        // a year whose rates are not in the app yet says so (Calc.taxYears)
        let early = year > pay.ratesYear ? "השיעורים של \(year) עוד לא עודכנו באפליקציה. " : ""
        return early + "לפי מדרגות המס, ביטוח לאומי ומס בריאות של \(pay.ratesYear) ו־\(points) נקודות זיכוי. הפנסיה וקרן ההשתלמות מהשכר בלי שעות נוספות ונסיעות, כמו שנקבע בדף של כל מקום עבודה."
    }

    /// 6 as "6", 2.25 as "2.25".
    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// A yearly bonus accrued since it was last paid, toward its payment (Calc.accruedBonuses): how much of it, and
/// when it is paid.
private struct BonusCard: View {
    let bonus: AccruedBonus
    /// Its workplace's name shown, with more than one.
    let named: Bool
    let currency: String

    var body: some View {
        let due = LocalTime.parts(bonus.due)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(named ? "בונוס צבור · " + bonus.name : "בונוס צבור")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("ישולם ב" + Format.monthName(due.month0) + " " + String(due.year))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Format.moneyShort(bonus.accrued, currency))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text("מתוך " + Format.moneyShort(bonus.amount, currency))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: bonus.amount > 0 ? min(1, bonus.accrued / bonus.amount) : 0)
                .tint(Color.accentColor)
        }
        .card()
    }
}

/// A workplace's next recuperation pay (Calc.upcomingRecuperation): its sum, its days by the seniority, and when it
/// is paid, or each month's.
private struct RecuperationCard: View {
    let due: RecuperationDue
    /// Its workplace's name shown, with more than one.
    let named: Bool
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(named ? "דמי הבראה · " + due.name : "דמי הבראה")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(when)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Format.moneyShort(due.amount, currency))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text("\(Int(due.days)) ימים\(due.due == nil ? " בשנה" : "") · ותק של " + Format.seniority(years: due.years, months: 0))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    /// "ישולמו ביולי 2027", or "בכל חודש".
    private var when: String {
        guard let date = due.due else { return "בכל חודש" }
        let p = LocalTime.parts(date)
        return "ישולמו ב" + Format.monthName(p.month0) + " " + String(p.year)
    }
}

/// The vacation and sick days left at a workplace (Leave.swift): the last payslip's, and the months and days off
/// since.
private struct LeaveCard: View {
    let balance: LeaveBalance
    let since: Date
    /// The workplace's name, with more than one.
    let place: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.map { "חופשה ומחלה · " + $0 } ?? "חופשה ומחלה")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("מהתלוש של " + Format.dayMonth(since))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                column(.vacation, balance.vacation, "ימי חופשה")
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 36)
                column(.sick, balance.sick, "ימי מחלה")
            }
        }
        .card()
    }

    private func column(_ type: ShiftType, _ days: Double, _ title: String) -> some View {
        HStack(spacing: 10) {
            DayOffSymbol(type: type, size: 15)
                .foregroundStyle(type.dayOffColor)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(type.dayOffColor.opacity(0.16)))
            VStack(alignment: .leading, spacing: 1) {
                Text(Format.days(days))
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
