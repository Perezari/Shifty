import SwiftUI
import UIKit

// The pieces the Shifts, Calendar and Settings screens share.

extension View {
    /// `now`, set again at each minute while the view is on screen, and at once when it comes back: instead of a
    /// TimelineView around a List or in its rows, which made the Shifts tab stall with a shift running, and which
    /// kept drawing a tab not shown.
    func minutes(_ now: Binding<Date>) -> some View {
        modifier(MinuteClock(now: now))
    }
}

private struct MinuteClock: ViewModifier {
    @Binding var now: Date

    func body(content: Content) -> some View {
        content.task {
            await tick()
        }
    }

    private func tick() async {
        now = Date()
        while !Task.isCancelled {
            let wait = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            now = Date()
        }
    }
}

/// The pay period on screen, between the earlier one and the later (app.js .period-bar): right to left, the
/// earlier on the right. Its name opens the period picker; on the calendar, with the Hebrew date on, its Hebrew
/// months are under it.
struct PeriodBar: View {
    let range: TimeRange
    @Binding var offset: Int
    var hebrew = false
    let pick: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                offset -= 1
            } label: {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("התקופה הקודמת")
            Button(action: pick) {
                VStack(spacing: 1) {
                    HStack(spacing: 4) {
                        Text(Calc.periodTitle(range))
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    if hebrew {
                        Text(Format.hebrewMonths(range))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(.primary)
            Button {
                offset += 1
            } label: {
                Image(systemName: "chevron.forward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("התקופה הבאה")
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: offset)
    }
}

/// Any month of any year, for its pay period (app.js openPeriodPicker), each with what it came to (Calc.monthIncomes).
struct PeriodPicker: View {
    /// The month shown now.
    let current: (year: Int, month0: Int)
    let pick: (Int, Int) -> Void
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int

    init(current: (year: Int, month0: Int), pick: @escaping (Int, Int) -> Void) {
        self.current = current
        self.pick = pick
        _year = State(initialValue: current.year)
    }

    /// What each month of the year came to, as its button says it.
    private func monthIncomes() -> [String?] {
        let currency = store.settings.currency
        return Calc.monthIncomes(store.shifts, store.settings, year: year, asOf: Date().ms).map { income in
            income.map { Format.moneyShort($0, currency) }
        }
    }

    var body: some View {
        let incomes = monthIncomes()
        NavigationStack {
            VStack(spacing: 18) {
                HStack {
                    Button {
                        year -= 1
                    } label: {
                        Image(systemName: "chevron.backward")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("השנה הקודמת")
                    Spacer()
                    Text(verbatim: String(year))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Button {
                        year += 1
                    } label: {
                        Image(systemName: "chevron.forward")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("השנה הבאה")
                }
                .font(.body.weight(.semibold))
                .buttonStyle(.plain)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(0..<12, id: \.self) { month in
                        MonthButton(name: Format.monthName(month), income: incomes[month],
                                    on: year == current.year && month == current.month0) {
                            pick(year, month)
                            dismiss()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("מעבר לתקופה")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("היום") {
                        let today = LocalTime.parts(Date())
                        pick(today.year, today.month0)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(400)])
    }
}

private struct MonthButton: View {
    let name: String
    /// What it came to, when anything is recorded in it.
    let income: String?
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(name)
                    .font(.body.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? Color.white : Color.primary)
                if let income {
                    Text(income)
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(on ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? Color.accentColor : Color.primary.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
    }
}

/// A number of the summary card.
struct SummaryCell: Hashable {
    let title: String
    let value: String
}

/// The period's numbers on the accent (app.js .summary-card).
struct SummaryCard: View {
    let cells: [SummaryCell]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 1, height: 30)
                }
                VStack(spacing: 4) {
                    Text(cells[index].title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .opacity(0.85)
                    Text(cells[index].value)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .surface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), tint: .accentColor)
    }
}

/// A shift in a list (app.js shiftRow): its day, its hours or the kind of day off, its pay, and how its hours
/// add up. A shift paid by a month's fixed pay has its hours where its pay would be; with more than one workplace,
/// its workplace leads the line under it.
struct ShiftRow: View {
    let shift: Shift
    let breakdown: Breakdown
    let currency: String
    /// The day fell short of its standard.
    var short = false
    /// The day's date on the side; a day's own list has none.
    var showsDate = true
    /// The settings to count a running shift's pay by, each second, while its list is on screen; nil shows it
    /// as of the list's minute.
    var live: Settings? = nil
    /// Paid by a month's fixed pay (Settings.isMonthly): its hours instead of a pay.
    var byHours = false
    /// Its workplace's name, with more than one (Settings.placeName).
    var place: String? = nil

    var body: some View {
        let _ = Perf.drew("שורה")
        HStack(spacing: 14) {
            if showsDate {
                DateBadge(date: shift.start, short: short, dayOff: shift.type != .work, filled: shift.isDayOff ? shift.type : nil)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    time
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    if shift.type == .work && shift.end == nil {
                        RunningTag(onBreak: shift.breaks.contains { $0.end == nil })
                    }
                    Spacer(minLength: 0)
                    pay
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                Text(meta)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                // a sum once has its name as its title
                if !shift.note.isEmpty && shift.type != .adjustment {
                    Text(shift.note)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .card(padding: 14)
        .contentShape(Rectangle())
    }

    /// The pay; a running shift's going up each second when `live`. Only this number is drawn again, by a clock
    /// whose seconds stay the same as the list is drawn (NowView.anchor): the row and the list are not.
    @ViewBuilder
    private var pay: some View {
        if shift.type == .adjustment {
            Text(Format.signedMoney(shift.amount ?? 0, currency))
        } else if shift.type == .reserve {
            // a day of reserve duty has no pay counted
            EmptyView()
        } else if byHours {
            Text(Format.hoursToHM(breakdown.netHours))
        } else if let live, shift.type == .work, shift.end == nil {
            TimelineView(.periodic(from: NowView.anchor, by: 1)) { context in
                Text(Format.money(Calc.breakdown(shift, live, asOf: context.date.ms, before: breakdown.before).pay, currency))
            }
        } else {
            Text(Format.money(breakdown.pay, currency))
        }
    }

    /// "07:12 – 16:40", "התחלה 07:12" while it runs, or the kind of day off (app.js entryLabel). The mark
    /// makes the line right to left, so that the start is on the right.
    private var time: Text {
        switch shift.type {
        case .vacation:
            return Text("חופשה בתשלום")
        case .sick:
            return Text("יום מחלה")
        case .reserve:
            return Text("יום מילואים")
        case .adjustment:
            return Text(shift.dayTitle)
        case .work:
            guard let end = shift.end else {
                return Text("התחלה " + Format.clock(shift.start))
            }
            return Text("\u{200F}" + Format.clock(shift.start) + " – " + Format.clock(end))
        }
    }

    /// "8:41 שע׳ · הפסקה 30׳ · נ.ש 0:35 · שבת/חג" (app.js shiftMetaHtml), or what a day off pays; after the workplace,
    /// with more than one.
    private var meta: String {
        let b = breakdown
        var parts = place.map { [$0] } ?? []
        switch shift.type {
        case .vacation:
            parts.append(Format.hoursToHM(b.netHours) + " שע׳ בתשלום")
        case .sick:
            let tier = b.sickTier ?? 1
            let plus = tier >= 4 ? "+" : ""
            let pct = Int(jsRound(b.sickPct ?? 0))
            parts.append("יום \(tier)\(plus) · \(pct)% מהתקן")
        case .reserve:
            // its pay is Bituach Leumi's, not counted here; a month's fixed pay goes on
            parts.append(byHours ? "המשכורת ממשיכה" : "התגמול לא נכלל בחישוב")
        case .adjustment:
            parts.append(shift.note.isEmpty ? "סכום חד־פעמי" : shift.adjustmentTitle)
        case .work:
            if !byHours { parts.append(Format.hoursToHM(b.netHours) + " שע׳") }
            if b.breakMs > 0 { parts.append("הפסקה \(Int(jsRound(b.breakMs / 60000)))׳") }
            if b.overtimeHours > 0.01 { parts.append("נ.ש " + Format.hoursToHM(b.overtimeHours)) }
            if b.isHoliday { parts.append("שבת/חג") }
        }
        return parts.joined(separator: " · ")
    }
}

/// A holiday paid by itself (Calc.holidayPays), among a period's shifts or on its day.
struct HolidayPayRow: View {
    let day: HolidayPayDay
    let currency: String
    /// Its workplace's name, with more than one.
    var place: String? = nil
    var showsDate = true

    var body: some View {
        HStack(spacing: 14) {
            if showsDate {
                DateBadge(date: day.date, short: false, dayOff: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("דמי חג")
                    Spacer(minLength: 0)
                    Text(Format.money(day.amount, currency))
                        .monospacedDigit()
                }
                .font(.body.weight(.semibold))
                Text(([place, day.name, Format.hoursShort(day.hours)] as [String?]).compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 14)
    }
}

/// The running shift's mark beside its start: "פעילה", or "בהפסקה" during a break.
private struct RunningTag: View {
    let onBreak: Bool

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(color.opacity(0.14))
            }
    }

    private var label: String {
        onBreak ? "בהפסקה" : "פעילה"
    }

    private var color: Color {
        onBreak ? .orange : .accentColor
    }
}

extension View {
    /// A card as a row of a list: no separator or background of the list's, the card's own spacing.
    func cardRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: ScreenMargin.side, bottom: 5, trailing: ScreenMargin.side))
    }
}

/// A shift's day in a list: the day of the month over its weekday, red when the day fell short of its
/// standard, faint for a sum once or a holiday's pay, and a day off in its color, as on the calendar.
private struct DateBadge: View {
    let date: Date
    let short: Bool
    let dayOff: Bool
    var filled: ShiftType? = nil

    var body: some View {
        let p = LocalTime.parts(date)
        VStack(spacing: 1) {
            Text(verbatim: String(p.day))
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()
            Text(Format.weekdayShort(date))
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .frame(width: 44, height: 46)
        .background {
            if let filled {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled.dayOffColor.gradient)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
            }
        }
    }

    private var color: Color {
        if filled != nil { return .white }
        if short { return .red }
        return dayOff ? .secondary : .primary
    }

    private var fill: Color {
        short ? Color.red.opacity(0.12) : Color.primary.opacity(0.06)
    }
}

/// A section of the settings: a small title over a glass card of rows, and a note under it (Sogia's).
struct SettingsSection<Content: View>: View {
    let title: String?
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .card(padding: 0)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }
}

/// The app's icon, light or dark with the iPhone (Assets.xcassets' Icon, from AppIcon), in its rounded square.
struct AppIconImage: View {
    let size: CGFloat

    var body: some View {
        Image("Icon")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension View {
    /// A row of a settings card: as tall as a list's row, its contents from the start.
    func settingsRow() -> some View {
        frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .padding(.vertical, 2)
    }
}

/// Hours and minutes on the wheel, in 24-hour time (app.js openTimeWheel): a length of time, as a day's
/// standard hours, or a time of day, as the night's start. Saved as decimal hours (9.1 is 9:06).
struct HoursSheet: View {
    let title: String
    let save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date

    init(title: String, hours: Double, save: @escaping (Double) -> Void) {
        self.title = title
        self.save = save
        var h = Int(hours.rounded(.down))
        var m = Int(jsRound((hours - Double(h)) * 60))
        if m == 60 {
            h += 1
            m = 0
        }
        _time = State(initialValue: Self.reference(min(max(h, 0), 23), m))
    }

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("ביטול")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            let p = LocalTime.parts(time)
                            save(Double(p.hour) + Double(p.minute) / 60)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("שמירה")
                    }
                }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .presentationDetents([.height(320)])
    }

    /// The hour and minute on a day with no change of the clocks.
    private static func reference(_ hour: Int, _ minute: Int) -> Date {
        LocalTime.date(2026, 0, 1, hour, minute)
    }
}

/// A moment of the last day on the wheels, its day, hour and minute: when a shift began or ended, for a press
/// made too late. Only a moment in `range` can be chosen.
struct MomentSheet: View {
    let title: String
    let range: ClosedRange<Date>
    let save: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var moment: Date

    init(title: String, range: ClosedRange<Date>, save: @escaping (Date) -> Void) {
        self.title = title
        self.range = range
        self.save = save
        _moment = State(initialValue: range.upperBound)
    }

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $moment, in: range, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("ביטול")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            // to the minute the wheels show, and not before the range
                            let minute = Date(timeIntervalSince1970: (moment.timeIntervalSince1970 / 60).rounded(.down) * 60)
                            save(max(minute, range.lowerBound))
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("שמירה")
                    }
                }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .presentationDetents([.height(320)])
    }
}

/// A paid vacation or sick day on a day picked from the month, today first. A day of work or of another day off
/// can't take one: a day is either work or a day off (DayDetail).
struct DayOffSheet: View {
    let type: ShiftType
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()

    var body: some View {
        let key = LocalTime.dayKey(day)
        let taken = store.shifts.contains { $0.type != .adjustment && LocalTime.dayKey($0.start) == key }
        NavigationStack {
            VStack(spacing: 8) {
                DatePicker(title, selection: $day, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                if taken {
                    Text("ביום הזה כבר יש משמרת או יום חופש.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ScreenMargin.side)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("ביטול")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        withAnimation { _ = store.addDayOff(day, type: type) }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(taken)
                    .accessibilityLabel("שמירה")
                }
            }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .presentationDetents([.height(540), .large])
    }

    private var title: String {
        switch type {
        case .sick: "יום מחלה"
        case .reserve: "יום מילואים"
        default: "יום חופש"
        }
    }
}

// MARK: Menus on a long press

extension ShiftType: Identifiable {
    var id: String { rawValue }

    /// A day off's line in a day's list: "חופשה בתשלום", "יום מחלה", "יום מילואים".
    var dayOffTitle: String {
        switch self {
        case .vacation: "חופשה בתשלום"
        case .sick: "יום מחלה"
        case .reserve: "יום מילואים"
        case .adjustment: "תוספת או ניכוי"
        case .work: "משמרת"
        }
    }

    /// A day off's word, in the calendar's day.
    var dayOffWord: String {
        switch self {
        case .vacation: "חופש"
        case .sick: "מחלה"
        case .reserve: "מילואים"
        case .work, .adjustment: ""
        }
    }

    /// A day off's symbol and color, the same wherever it shows: on the calendar, in a list, on the week's card. The
    /// beach umbrella is drawn on its way to the screen (DayOffSymbol); its name here is for what takes a name.
    var dayOffSymbol: String {
        switch self {
        case .vacation: "beach.umbrella.fill"
        case .sick: "cross.case.fill"
        case .reserve: "shield.fill"
        case .work, .adjustment: "circle.fill"
        }
    }

    var dayOffColor: Color {
        switch self {
        case .vacation: .vacation
        case .sick: .pink
        case .reserve: .reserveDuty
        case .work, .adjustment: .secondary
        }
    }
}

extension Shift {
    /// "07:12 – 16:40", the start on the right; "מ־07:12" while it runs; nil for a day off.
    var span: String? {
        guard type == .work else { return nil }
        guard let end else { return "מ־" + Format.clock(start) }
        return "\u{200F}" + Format.clock(start) + " – " + Format.clock(end)
    }

    /// A sum once's word: "תוספת" or "ניכוי".
    var adjustmentTitle: String {
        (amount ?? 0) < 0 ? "ניכוי" : "תוספת"
    }

    /// Its line on a day: its hours, a sum once's name, or the kind of day off.
    var dayTitle: String {
        if type == .adjustment { return note.isEmpty ? adjustmentTitle : note }
        return span ?? type.dayOffTitle
    }

    /// What it adds to its day's sum: a sum once, or a wage; nothing of its own on a day of reserve duty or paid by a
    /// month's fixed pay.
    func dayPay(_ breakdown: Breakdown, _ settings: Settings) -> Double? {
        if type == .adjustment { return amount ?? 0 }
        return type == .reserve || settings.isMonthly(self) ? nil : breakdown.pay
    }

    /// For the clipboard: "יום ג׳, 28 באוקטובר · 07:10 – 16:20 · 8:40 שע׳ · ₪ 470.25", the note under it.
    func summary(_ breakdown: Breakdown, _ settings: Settings) -> String {
        var parts = [Format.weekday(start) + ", " + Format.dateLong(start)]
        switch type {
        case .vacation:
            parts.append("חופשה בתשלום")
        case .sick:
            parts.append("יום מחלה")
        case .reserve:
            parts.append("יום מילואים")
        case .adjustment:
            parts.append(dayTitle)
            parts.append(Format.signedMoney(amount ?? 0, settings.currency))
            return parts.joined(separator: " · ")
        case .work:
            if let span { parts.append(span) }
            parts.append(Format.hoursShort(breakdown.netHours))
        }
        // a month's fixed pay's shift has no pay of its own, nor has a day of reserve duty
        if type != .reserve && !settings.isMonthly(self) { parts.append(Format.money(breakdown.pay, settings.currency)) }
        let line = parts.joined(separator: " · ")
        return note.isEmpty ? line : line + "\n" + note
    }
}

extension ShiftStore {
    /// A finished shift of another day can be copied to today, unless today is a day off. Asked of each row as
    /// the list is drawn, so by the records' times, not by their days' keys.
    func canCopyToToday(_ shift: Shift) -> Bool {
        let today = LocalTime.startOfDay(Date())
        let tomorrow = LocalTime.addingDays(1, to: today)
        guard shift.type == .work, shift.end != nil, shift.start < today || shift.start >= tomorrow else { return false }
        return !records.contains { !$0.deleted && $0.isDayOff && $0.start >= today && $0.start < tomorrow }
    }
}

extension View {
    /// A shift's menu on a long press (Lift.swift), the shift lifted with how its pay adds up: editing it, its
    /// hours again today (in the editor, `copy`), its summary copied, and deleting it.
    func shiftMenu(_ shift: Shift, _ breakdown: Breakdown, _ settings: Settings, edit: @escaping () -> Void,
                   copy: @escaping () -> Void) -> some View {
        modifier(ShiftMenu(shift: shift, breakdown: breakdown, settings: settings, edit: edit, copy: copy))
    }
}

private struct ShiftMenu: ViewModifier {
    let shift: Shift
    let breakdown: Breakdown
    let settings: Settings
    let edit: () -> Void
    let copy: () -> Void
    @Environment(ShiftStore.self) private var store

    func body(content: Content) -> some View {
        content.liftable(card: true) {
            ShiftPreview(shift: shift, breakdown: breakdown, settings: settings)
        } sections: {
            sections()
        }
    }

    private func sections() -> [LiftSection] {
        var items: [LiftItem] = []
        // a day off has no hours to edit (ShiftEditor)
        if !shift.isDayOff {
            items.append(LiftItem(title: "עריכה", systemImage: "pencil", action: edit))
        }
        if store.canCopyToToday(shift) {
            items.append(LiftItem(title: "שכפול להיום", systemImage: "plus.square.on.square", action: copy))
        }
        items.append(LiftItem(title: "העתקת הסיכום", systemImage: "doc.on.doc") {
            // a running shift's as it is now
            let now = shift.end == nil ? Calc.breakdown(shift, settings, asOf: Date().ms, before: breakdown.before) : breakdown
            UIPasteboard.general.string = shift.summary(now, settings)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        })
        let delete = LiftItem(title: "מחיקה", systemImage: "trash", destructive: true) {
            withAnimation { store.delete(shift.id) }
        }
        return [LiftSection(items: items), LiftSection(items: [delete])]
    }
}

/// A line of a lifted shift or day: what it is, its hours, and what it pays.
struct PayLine: View {
    let title: String
    let hours: String
    let pay: Double?
    let currency: String
    /// A sum once, with its sign.
    var signed = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
            Spacer(minLength: 8)
            Text(hours)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(pay.map { signed ? Format.signedMoney($0, currency) : Format.money($0, currency) } ?? "")
                .monospacedDigit()
                .frame(width: 96, alignment: .trailing)
        }
        .font(.subheadline)
    }
}

/// A shift lifted by a long press: its day and hours, its pay by rate, its break and its note, and its wage; a
/// running one's going up each second.
struct ShiftPreview: View {
    let shift: Shift
    let breakdown: Breakdown
    let settings: Settings

    var body: some View {
        if shift.type == .work && shift.end == nil {
            TimelineView(.periodic(from: NowView.anchor, by: 1)) { context in
                card(Calc.breakdown(shift, settings, asOf: context.date.ms, before: breakdown.before))
            }
        } else {
            card(breakdown)
        }
    }

    private func card(_ b: Breakdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.weekday(shift.start) + ", " + Format.dateLong(shift.start))
                    .font(.headline)
                Spacer(minLength: 8)
                if let span = shift.span {
                    Text(span)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 8) {
                ForEach(Array(lines(b).enumerated()), id: \.offset) { _, line in
                    PayLine(title: line.title, hours: line.hours, pay: line.pay, currency: settings.currency,
                            signed: shift.type == .adjustment)
                }
            }
            if !shift.note.isEmpty && shift.type != .adjustment {
                Text(shift.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if shift.type == .reserve {
                // for the record, with no total: its pay is not counted
                Text(settings.isMonthly(shift) ? "המשכורת ממשיכה גם בימי המילואים."
                     : "לתיעוד. התגמול משולם לפי כללי ביטוח לאומי, שמשתנים כל שנה, ולכן לא נכלל בחישוב.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if shift.type != .adjustment {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text(b.ongoing ? "עד עכשיו" : "סה״כ")
                        .font(.headline)
                    Spacer()
                    // a month's fixed pay's shift: its hours
                    Text(settings.isMonthly(shift) ? Format.hoursShort(b.netHours) : Format.money(b.pay, settings.currency))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .liftedCard()
    }

    /// The hours by rate and what each pays (Calc.breakdown), then the break; a month's fixed pay's shift, its
    /// hours alone.
    private func lines(_ b: Breakdown) -> [(title: String, hours: String, pay: Double?)] {
        let s = settings.effective(for: shift)
        let paid = !settings.isMonthly(shift)
        func pay(_ value: Double) -> Double? { paid ? value : nil }
        switch shift.type {
        case .vacation:
            return [("חופשה בתשלום", Format.hoursToHM(b.netHours), pay(b.pay))]
        case .sick:
            let tier = b.sickTier ?? 1
            return [("יום מחלה \(tier)" + (tier >= 4 ? "+" : ""), "\(Int(jsRound(b.sickPct ?? 0)))%", pay(b.pay))]
        case .reserve:
            return [("יום מילואים", "", nil)]
        case .adjustment:
            return [(shift.dayTitle, "", shift.amount ?? 0)]
        case .work:
            var list: [(title: String, hours: String, pay: Double?)] = []
            if b.isHoliday {
                list.append(("שבת / חג · " + Self.percent(s.holidayMult), Format.hoursToHM(s.lawOvertime ? b.regularHours : b.netHours), pay(b.basePay)))
                // its overtime on top of it, where the law's count is set
                if s.lawOvertime && b.ot1Hours > 0.001 {
                    let rate = s.holidayMult + s.overtime1Mult - 1
                    list.append(("נוספות " + Self.percent(rate), Format.hoursToHM(b.ot1Hours), pay(b.ot1Hours * rate * s.hourlyWage)))
                }
                if s.lawOvertime && b.ot2Hours > 0.001 {
                    let rate = s.holidayMult + s.overtime2Mult - 1
                    list.append(("נוספות " + Self.percent(rate), Format.hoursToHM(b.ot2Hours), pay(b.ot2Hours * rate * s.hourlyWage)))
                }
            } else {
                list.append(("שעות רגילות", Format.hoursToHM(b.regularHours), pay(b.basePay)))
                if b.ot1Hours > 0.001 {
                    list.append(("נוספות " + Self.percent(s.overtime1Mult), Format.hoursToHM(b.ot1Hours),
                                 pay(b.ot1Hours * s.overtime1Mult * s.hourlyWage)))
                }
                if b.ot2Hours > 0.001 {
                    list.append(("נוספות " + Self.percent(s.overtime2Mult), Format.hoursToHM(b.ot2Hours),
                                 pay(b.ot2Hours * s.overtime2Mult * s.hourlyWage)))
                }
                if b.nightPremium > 0.005 {
                    list.append(("תוספת לילה", Format.hoursToHM(b.nightHours), pay(b.nightPremium)))
                }
            }
            if b.breakMs > 0 {
                list.append(("הפסקה", Format.hoursToHM(b.breakMs / 3_600_000), nil))
            }
            return list
        }
    }

    /// "125%"
    private static func percent(_ multiplier: Double) -> String {
        "\(Int(jsRound(multiplier * 100)))%"
    }
}

/// A day of the calendar lifted by a long press: its holiday, its shifts or day off with their hours and pay,
/// and the day's wage; or that it has none.
struct DayPreview: View {
    let date: Date
    /// The day's shifts, the first first.
    let shifts: [Shift]
    let settings: Settings
    let sickDates: Set<String>
    /// What came before each shift in its day and week (Calc.workedBefore).
    var before: [String: WorkedBefore] = [:]
    /// The day as a holiday paid by itself (Calc.holidayPays).
    var holidayPays: [HolidayPayDay] = []
    @AppStorage(HebrewDates.key) private var hebrewDate = false

    var body: some View {
        let now = Date().ms
        let breakdowns = shifts.map { Calc.breakdown($0, settings, asOf: now, sickDates: sickDates, before: before[$0.id]) }
        let worked = zip(shifts, breakdowns).filter { $0.0.type == .work }.reduce(0) { $0 + $1.1.netHours }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Format.weekday(date) + ", " + Format.dateLong(date))
                        .font(.headline)
                    if hebrewDate {
                        Text(Format.hebrewDate(date))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if worked > 0 {
                    Text(Format.hoursShort(worked))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            if let holiday {
                Text(holiday)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("Holiday"))
            }
            if shifts.isEmpty && holidayPays.isEmpty {
                Text("אין משמרת ביום זה")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(zip(shifts, breakdowns).enumerated()), id: \.offset) { _, pair in
                        PayLine(title: pair.0.dayTitle,
                                hours: pair.0.type == .work ? Format.hoursToHM(pair.1.netHours) : "",
                                pay: pair.0.dayPay(pair.1, settings), currency: settings.currency,
                                signed: pair.0.type == .adjustment)
                    }
                    ForEach(holidayPays) { pay in
                        PayLine(title: "דמי חג", hours: Format.hoursToHM(pay.hours), pay: pay.amount, currency: settings.currency)
                    }
                }
                // a day of reserve duty alone has no total: its pay is not counted
                if !holidayPays.isEmpty || !shifts.allSatisfy({ $0.type == .reserve }) {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("סה״כ")
                            .font(.headline)
                        Spacer()
                        // a day of a month's fixed pay alone: its hours
                        Text(total(breakdowns) ?? Format.hoursShort(worked))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .liftedCard()
    }

    /// What the day comes to; nil when nothing on it is paid by itself.
    private func total(_ breakdowns: [Breakdown]) -> String? {
        var paid: [Double] = holidayPays.map(\.amount)
        for (shift, breakdown) in zip(shifts, breakdowns) {
            if let pay = shift.dayPay(breakdown, settings) { paid.append(pay) }
        }
        return paid.isEmpty ? nil : Format.money(paid.reduce(0, +), settings.currency)
    }

    /// "ערב פסח · יום מקוצר", or the holiday's name.
    private var holiday: String? {
        guard settings.holidaysEnabled else { return nil }
        let info = Holidays.info(date)
        guard let kind = info.kind, let name = info.name else { return nil }
        return kind == .short ? name + " · יום מקוצר" : name
    }
}
