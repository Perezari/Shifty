import SwiftUI

/// The pay period as a month of days (app.js renderCalendar), a heat map of the work: each day worked filled
/// by its hours against its standard, red when it fell short, a day off and a holiday marked, and today
/// ringed. A day opens with its shifts, to add one or a day off.
struct CalendarView: View {
    @Environment(ShiftStore.self) private var store
    @State private var offset = 0
    @State private var picking = false
    @State private var opened: DayRef?

    var body: some View {
        let range = Calc.period(around: Date(), monthStartDay: store.settings.monthStartDay, offset: offset)
        TimelineView(.periodic(from: .now, by: 60)) { context in
            month(range, at: context.date)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("לוח")
        .sheet(item: $opened) { day in
            DayDetail(date: day.date)
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
                opened = DayRef(date: LocalTime.addingDays(-1, to: LocalTime.startOfDay(Date())))
            }
        }
        #endif
    }

    private func month(_ range: TimeRange, at date: Date) -> some View {
        let settings = store.settings
        let summary = Calc.summary(store.shifts, settings, range: range, asOf: date.ms)
        let days = Calc.gridDays(range)
        let today = LocalTime.dayKey(date)
        let cells = [
            SummaryCell(title: "ימי עבודה", value: String(summary.totals.workedDays)),
            SummaryCell(title: "שעות", value: Format.hoursToHM(summary.totals.netHours)),
            SummaryCell(title: "שעות חוסר", value: Format.hoursToHM(summary.shortfall.total)),
            SummaryCell(title: "סה״כ", value: Format.moneyShort(summary.totals.total, settings.currency)),
        ]
        return ScrollView {
            VStack(spacing: 12) {
                PeriodBar(range: range, offset: $offset) { picking = true }
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
                            DayCell(date: day, inPeriod: inPeriod, today: key == today,
                                    sum: inPeriod ? summary.days[key] : nil, settings: settings)
                                .onTapGesture {
                                    if inPeriod { opened = DayRef(date: day) }
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
}

/// A day to open in a sheet.
struct DayRef: Identifiable {
    let date: Date
    var id: String { LocalTime.dayKey(date) }
}

/// A day of the calendar: its number, and the hours worked, the kind of day off or the holiday's name.
private struct DayCell: View {
    let date: Date
    let inPeriod: Bool
    let today: Bool
    let sum: DaySum?
    let settings: Settings

    var body: some View {
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
        .opacity(inPeriod ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private static func name(_ dayOff: ShiftType) -> String {
        dayOff == .vacation ? "חופש" : "מחלה"
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
/// paid day off, never both.
struct DayDetail: View {
    let date: Date
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var editing: Shift?

    var body: some View {
        let settings = store.settings
        let all = store.shifts
        let sick = Calc.sickDates(of: all)
        let key = LocalTime.dayKey(date)
        let shifts = all.filter { LocalTime.dayKey($0.start) == key }.sorted { $0.start < $1.start }
        let hasDayOff = shifts.contains { $0.type != .work }
        let hasWork = shifts.contains { $0.type == .work }
        NavigationStack {
            // a list, for a shift to be swiped away as on the Shifts tab
            List {
                if let line = holidayLine(settings) {
                    Text(line)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("Holiday"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardRow()
                }
                if shifts.isEmpty {
                    Text("אין משמרת ביום זה")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .cardRow()
                }
                ForEach(shifts) { shift in
                    Button {
                        editing = shift
                    } label: {
                        ShiftRow(shift: shift, breakdown: Calc.breakdown(shift, settings, asOf: Date().ms, sickDates: sick),
                                 currency: settings.currency, showsDate: false)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { store.delete(shift.id) }
                        } label: {
                            Label("מחיקה", systemImage: "trash")
                        }
                    }
                    .cardRow()
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
                                    addDayOff(.vacation)
                                } label: {
                                    Text("יום חופש")
                                        .frame(maxWidth: .infinity)
                                }
                                Button {
                                    addDayOff(.sick)
                                } label: {
                                    Text("יום מחלה")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .controlSize(.large)
                    .padding(.top, 6)
                    .cardRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(Format.dateFull(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("סגירה")
                }
            }
            .sheet(isPresented: $adding) {
                ShiftEditor(shift: nil, day: date)
                    .environment(store)
            }
            .sheet(item: $editing) { shift in
                ShiftEditor(shift: shift, day: nil)
                    .environment(store)
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// "ערב פסח · יום מקוצר", or the holiday's name.
    private func holidayLine(_ settings: Settings) -> String? {
        guard settings.holidaysEnabled else { return nil }
        let info = Holidays.info(date)
        guard let kind = info.kind, let name = info.name else { return nil }
        return kind == .short ? name + " · יום מקוצר" : name
    }

    private func addDayOff(_ type: ShiftType) {
        store.addDayOff(date, type: type)
        dismiss()
    }
}
