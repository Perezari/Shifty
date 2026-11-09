import SwiftUI
import UIKit

/// The pay period as a month of days (app.js renderCalendar), a heat map of the work: each day worked filled
/// by its hours against its standard, red when it fell short, a day off and a holiday marked, and today
/// ringed. A day opens with its shifts, to add one or a day off; a long press lifts it with its menu. Drawn
/// again each minute while it is on screen.
struct CalendarView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.lifter) private var lifter
    @State private var offset = 0
    @State private var picking = false
    @State private var opened: DayRef?
    @State private var adding: DayRef?
    @State private var adjusting: DayRef?
    @State private var copying: Shift?
    /// The minute the month shows, again each minute while it is on screen.
    @State private var now = Date()
    @AppStorage(HebrewDates.key) private var hebrewDate = false

    var body: some View {
        let range = Calc.period(around: now, monthStartDay: store.settings.monthStartDay, offset: offset)
        month(range, at: now)
            // a day's shifts just deleted, offered back for a few seconds
            .safeAreaInset(edge: .bottom, spacing: 0) {
                UndoStrip()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("לוח")
            .minutes($now)
            .sheet(item: $opened) { day in
                // its own place to lift a shift over, as a sheet is drawn over the tabs
                DayDetail(date: day.date)
                    .environment(store)
                    .liftHost()
            }
            .sheet(item: $adding) { day in
                ShiftEditor(shift: nil, day: day.date)
                    .environment(store)
            }
            .sheet(item: $adjusting) { day in
                AdjustmentSheet(day: day.date)
                    .environment(store)
            }
            .sheet(item: $copying) { shift in
                ShiftEditor(shift: nil, day: Date(), from: shift)
                    .environment(store)
            }
            .sheet(isPresented: $picking) {
                PeriodPicker(current: Calc.periodMonth(range)) { year, month in
                    offset = Calc.periodOffset(year: year, month0: month, monthStartDay: store.settings.monthStartDay, now: Date())
                }
            }
            #if DEBUG
            .task {
                if Screenshot.current == .day {
                    // after the tab has appeared: a sheet asked for during the switch is dropped
                    try? await Task.sleep(for: .seconds(1.5))
                    // the last day worked before today, not a Saturday's empty sheet
                    let today = LocalTime.startOfDay(Date())
                    let last = store.shifts.filter { $0.type == .work && $0.end != nil && $0.start < today }.map(\.start).max()
                    opened = DayRef(date: LocalTime.startOfDay(last ?? LocalTime.addingDays(-1, to: today)))
                }
            }
            #endif
    }

    private func month(_ range: TimeRange, at date: Date) -> some View {
        Perf.drew("לוח")
        let settings = store.settings
        let summary = Calc.summary(store.shifts, settings, range: range, asOf: date.ms)
        let days = Calc.gridDays(range)
        let today = LocalTime.dayKey(date)
        // each day's shifts or day off, for its menu and its lifted card
        let records = Dictionary(grouping: store.shifts.filter { $0.start >= range.start && $0.start < range.end },
                                 by: { LocalTime.dayKey($0.start) })
        let sick = Calc.sickDates(of: store.shifts)
        let before = Calc.workedBefore(store.shifts, settings, range: range, asOf: date.ms)
        let cells = [
            SummaryCell(title: "ימי עבודה", value: String(summary.totals.workedDays)),
            SummaryCell(title: "שעות", value: Format.hoursToHM(summary.totals.netHours)),
            SummaryCell(title: "שעות חוסר", value: Format.hoursToHM(summary.shortfall.total)),
            SummaryCell(title: "סה״כ", value: Format.moneyShort(summary.totals.total, settings.currency)),
        ]
        return ScrollView {
            VStack(spacing: 12) {
                PeriodBar(range: range, offset: $offset, hebrew: hebrewDate) { picking = true }
                VStack(spacing: 8) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                        ForEach(Format.weekdays, id: \.self) { name in
                            Text(name.replacingOccurrences(of: "׳", with: ""))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(days, id: \.self) { day in
                            let key = LocalTime.dayKey(day)
                            let inPeriod = day >= range.start && day < range.end
                            let cell = DayCell(date: day, inPeriod: inPeriod, today: key == today,
                                               sum: inPeriod ? summary.days[key] : nil, settings: settings, hebrew: hebrewDate)
                            if inPeriod {
                                let onDay = (records[key] ?? []).sorted { $0.start < $1.start }
                                Button {
                                    // not the finger lifted after a long press
                                    if lifter?.isShowing != true { opened = DayRef(date: day) }
                                } label: {
                                    cell
                                }
                                .buttonStyle(.plain)
                                .liftable(card: true) {
                                    DayPreview(date: day, shifts: onDay, settings: settings, sickDates: sick, before: before,
                                               holidayPays: summary.holidayPays.filter { LocalTime.dayKey($0.date) == key })
                                } sections: {
                                    daySections(day, onDay)
                                }
                            } else {
                                cell
                            }
                        }
                    }
                }
                .card(padding: 12)
                SummaryCard(cells: cells)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// A day's menu: an empty day takes a shift or a day off; a day with any opens, is copied to today, or is
    /// emptied.
    private func daySections(_ day: Date, _ onDay: [Shift]) -> [LiftSection] {
        if onDay.isEmpty {
            return [.adding(shift: { adding = DayRef(date: day) }, dayOff: { type in
                withAnimation { _ = store.addDayOff(day, type: type) }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }, adjustment: { adjusting = DayRef(date: day) })]
        }
        var items = [LiftItem(title: "פתיחת היום", systemImage: "calendar") { opened = DayRef(date: day) }]
        if onDay.count == 1, let only = onDay.first, store.canCopyToToday(only) {
            items.append(LiftItem(title: "שכפול להיום", systemImage: "plus.square.on.square") { copying = only })
        }
        let delete = LiftItem(title: onDay.count > 1 ? "מחיקת המשמרות" : "מחיקה", systemImage: "trash", destructive: true) {
            // as one deletion, which the strip brings back at once
            withAnimation { store.delete(onDay.map(\.id)) }
        }
        return [LiftSection(items: items), LiftSection(items: [delete])]
    }
}

/// A day to open in a sheet.
struct DayRef: Identifiable {
    let date: Date
    var id: String { LocalTime.dayKey(date) }
}

/// A day of the calendar: its number, and the hours worked, the kind of day off or the holiday's name; the Hebrew
/// day in its corner when the Hebrew date is on.
private struct DayCell: View {
    let date: Date
    let inPeriod: Bool
    let today: Bool
    let sum: DaySum?
    let settings: Settings
    let hebrew: Bool

    var body: some View {
        let _ = Perf.drew("יום")
        let holiday = holidayInfo
        VStack(spacing: 2) {
            Text(verbatim: String(LocalTime.parts(date).day))
                .font(.system(size: 15, weight: numberWeight))
                .monospacedDigit()
                .foregroundStyle(numberColor(holiday))
            if let sum, sum.count > 0 {
                Text(Format.hoursToHM(sum.netHours))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(sum.short ? Color.red : Color.secondary)
            } else if let off = sum?.dayOff {
                Text(Self.name(off))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if let sum, sum.adjustment != 0 {
                Text(Format.signedMoney(sum.adjustment, settings.currency))
                    .font(.system(size: 8, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if let name = holiday?.name {
                Text(name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color("Holiday"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill(holiday))
        }
        .overlay {
            if today {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 1.6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if hebrew && inPeriod {
                Text(Holidays.hebrewDate(date).day)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.trailing, 5)
            }
        }
        .opacity(inPeriod ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private static func name(_ dayOff: ShiftType) -> String {
        switch dayOff {
        case .vacation: "חופש"
        case .sick: "מחלה"
        case .reserve: "מילואים"
        case .work, .adjustment: ""
        }
    }

    /// The day's holiday, when the holidays are on.
    private var holidayInfo: Holidays.Info? {
        guard inPeriod, settings.holidaysEnabled else { return nil }
        let info = Holidays.info(date)
        return info.kind == nil ? nil : info
    }

    private var worked: Bool {
        (sum?.count ?? 0) > 0
    }

    private var numberWeight: Font.Weight {
        if today { return .heavy }
        return worked ? .bold : .medium
    }

    private func numberColor(_ holiday: Holidays.Info?) -> Color {
        if let sum, sum.short { return .red }
        if worked { return .accentColor }
        if holiday != nil { return Color("Holiday") }
        return today ? .accentColor : .primary
    }

    /// Accent by the share of the standard worked; red when short; grey for a day off; the holiday's color
    /// for a holiday, lighter for a shortened day.
    private func fill(_ holiday: Holidays.Info?) -> Color {
        if let sum, sum.count > 0 {
            if sum.short { return Color.red.opacity(0.13) }
            let standard = Calc.standardHours(date, settings)
            let share = max(0, min(1, standard > 0 ? sum.netHours / standard : 0))
            return Color.accentColor.opacity(0.09 + share * 0.17)
        }
        if sum?.dayOff != nil { return Color.secondary.opacity(0.12) }
        if let holiday {
            return Color("Holiday").opacity(holiday.kind == .chag ? 0.14 : 0.07)
        }
        return inPeriod ? Color.primary.opacity(0.04) : Color.clear
    }
}

/// A day's shifts and adding to them (app.js openDayDetail): a day is either work, one shift or more, or one
/// paid day off, never both. The days around it are pages: a swipe, or an arrow beside the date, moves to the day
/// before or after, the day before on the right. A shift goes from its long press's menu, as a swipe is the pages'.
struct DayDetail: View {
    let date: Date
    @AppStorage(HebrewDates.key) private var hebrewDate = false
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifter) private var lifter
    /// The day shown, in days from `date`.
    @State private var page: Int? = 0
    @State private var adding = false
    @State private var adjusting = false
    @State private var editing: Shift?
    @State private var copying: Shift?

    /// The days a swipe reaches, each way: two months.
    private static let reach = 62

    /// The day shown.
    private var day: Date {
        LocalTime.addingDays(page ?? 0, to: LocalTime.startOfDay(date))
    }

    var body: some View {
        let settings = store.settings
        let all = store.shifts
        let sick = Calc.sickDates(of: all)
        let before = Calc.workedBefore(all, settings, asOf: Date().ms)
        // each day's shifts, once for all the pages
        let byDay = Dictionary(grouping: all) { LocalTime.dayKey($0.start) }
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(-Self.reach...Self.reach, id: \.self) { offset in
                        let day = LocalTime.addingDays(offset, to: LocalTime.startOfDay(date))
                        dayPage(day, (byDay[LocalTime.dayKey(day)] ?? []).sorted { $0.start < $1.start }, settings, sick, before, all)
                            .containerRelativeFrame(.horizontal)
                            .id(offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            // the day opened, in the middle of the days each way
            .defaultScrollAnchor(.center)
            .scrollIndicators(.hidden)
            // a shift just deleted here, offered back at the sheet's bottom, as the tabs' is under it
            .safeAreaInset(edge: .bottom, spacing: 0) {
                UndoStrip()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(Format.dateFull(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        step(-1)
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled((page ?? 0) <= -Self.reach)
                    .accessibilityLabel("היום הקודם")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(Format.dateFull(day))
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if hebrewDate || holidayLine(day, settings) != nil {
                            dateLine(day, settings)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        step(1)
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled((page ?? 0) >= Self.reach)
                    .accessibilityLabel("היום הבא")
                }
            }
            .sensoryFeedback(.selection, trigger: page)
            .sheet(isPresented: $adding) {
                ShiftEditor(shift: nil, day: day)
                    .environment(store)
            }
            .sheet(isPresented: $adjusting) {
                AdjustmentSheet(day: day)
                    .environment(store)
            }
            .sheet(item: $editing) { shift in
                ShiftEditor(shift: shift, day: nil)
                    .environment(store)
            }
            .sheet(item: $copying) { shift in
                ShiftEditor(shift: nil, day: Date(), from: shift)
                    .environment(store)
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// A day's page: its shifts or day off, each opening, and lifted by a long press with its menu; and adding to it.
    private func dayPage(_ day: Date, _ shifts: [Shift], _ settings: Settings, _ sick: Set<String>,
                         _ before: [String: WorkedBefore], _ all: [Shift]) -> some View {
        let hasDayOff = shifts.contains { $0.isDayOff }
        let hasWork = shifts.contains { $0.type == .work }
        let holidayPays = Calc.holidayPays(all, settings, range: Calc.dayRange(day), asOf: Date().ms)
        return ScrollView {
            VStack(spacing: 10) {
                if shifts.isEmpty && holidayPays.isEmpty {
                    Text("אין משמרת ביום זה")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                ForEach(shifts) { shift in
                    let breakdown = Calc.breakdown(shift, settings, asOf: Date().ms, sickDates: sick, before: before[shift.id])
                    Button {
                        // not the finger lifted after a long press
                        if lifter?.isShowing != true { editing = shift }
                    } label: {
                        ShiftRow(shift: shift, breakdown: breakdown, currency: settings.currency, showsDate: false,
                                 byHours: settings.isMonthly(shift), place: settings.placeName(of: shift))
                    }
                    .buttonStyle(.plain)
                    .shiftMenu(shift, breakdown, settings, edit: { editing = shift }, copy: { copying = shift })
                }
                ForEach(holidayPays) { pay in
                    HolidayPayRow(day: pay, currency: settings.currency,
                                  place: settings.workplaces.isEmpty ? nil : settings.place(pay.place.isEmpty ? nil : pay.place).name,
                                  showsDate: false)
                }
                if !hasDayOff {
                    VStack(spacing: 10) {
                        Button {
                            adding = true
                        } label: {
                            Label("הוספת משמרת ליום זה", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        if !hasWork {
                            HStack(spacing: 10) {
                                Button {
                                    addDayOff(.vacation, on: day)
                                } label: {
                                    Text("יום חופש")
                                        .frame(maxWidth: .infinity)
                                }
                                Button {
                                    addDayOff(.sick, on: day)
                                } label: {
                                    Text("יום מחלה")
                                        .frame(maxWidth: .infinity)
                                }
                                Button {
                                    addDayOff(.reserve, on: day)
                                } label: {
                                    Text("מילואים")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .buttonStyle(.glass)
                        }
                    }
                    .controlSize(.large)
                    .padding(.top, 6)
                }
                Button {
                    adjusting = true
                } label: {
                    Label("תוספת או ניכוי", systemImage: "plusminus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// The day before (-1) or after (1), sliding in.
    private func step(_ by: Int) {
        let next = min(Self.reach, max(-Self.reach, (page ?? 0) + by))
        withAnimation { page = next }
    }

    /// "ערב פסח · יום מקוצר", or the holiday's name.
    private func holidayLine(_ day: Date, _ settings: Settings) -> String? {
        guard settings.holidaysEnabled else { return nil }
        let info = Holidays.info(day)
        guard let kind = info.kind, let name = info.name else { return nil }
        return kind == .short ? name + " · יום מקוצר" : name
    }

    /// The Hebrew date when it is on, "כ״ג בחשוון תשפ״ז", then the holiday's line in its color.
    private func dateLine(_ day: Date, _ settings: Settings) -> Text {
        let holiday = holidayLine(day, settings).map { Text($0).foregroundStyle(Color("Holiday")) }
        guard hebrewDate else { return holiday ?? Text(verbatim: "") }
        let hebrew = Text(Format.hebrewDate(day) + " " + Holidays.hebrewDate(day).year).foregroundStyle(.secondary)
        guard let holiday else { return hebrew }
        return hebrew + Text(verbatim: " · ").foregroundStyle(.secondary) + holiday
    }

    private func addDayOff(_ type: ShiftType, on day: Date) {
        store.addDayOff(day, type: type)
        dismiss()
    }
}
