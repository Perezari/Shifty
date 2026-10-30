import SwiftUI
import UIKit

// The pieces the Shifts, Calendar and Settings screens share.

/// The pay period on screen, between the earlier one and the later (app.js .period-bar): right to left, the
/// earlier on the right. Its name opens the period picker.
struct PeriodBar: View {
    let range: TimeRange
    @Binding var offset: Int
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
                HStack(spacing: 4) {
                    Text(Calc.periodTitle(range))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
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

/// Any month of any year, for its pay period (app.js openPeriodPicker).
struct PeriodPicker: View {
    /// The month shown now.
    let current: (year: Int, month0: Int)
    let pick: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int

    init(current: (year: Int, month0: Int), pick: @escaping (Int, Int) -> Void) {
        self.current = current
        self.pick = pick
        _year = State(initialValue: current.year)
    }

    var body: some View {
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
                        MonthButton(name: Format.monthName(month), on: year == current.year && month == current.month0) {
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
        .presentationDetents([.medium])
    }
}

private struct MonthButton: View {
    let name: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.body.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 46)
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
/// add up.
struct ShiftRow: View {
    let shift: Shift
    let breakdown: Breakdown
    let currency: String
    /// The day fell short of its standard.
    var short = false
    /// The day's date on the side; a day's own list has none.
    var showsDate = true

    var body: some View {
        let _ = Perf.drew("שורה")
        HStack(spacing: 14) {
            if showsDate {
                DateBadge(date: shift.start, short: short, dayOff: shift.type != .work)
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
                    Text(Format.money(breakdown.pay, currency))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                Text(meta)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if !shift.note.isEmpty {
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

    /// "07:12 – 16:40", "התחלה 07:12" while it runs, or the kind of day off (app.js entryLabel). The mark
    /// makes the line right to left, so that the start is on the right.
    private var time: Text {
        switch shift.type {
        case .vacation:
            return Text("חופשה בתשלום")
        case .sick:
            return Text("יום מחלה")
        case .work:
            guard let end = shift.end else {
                return Text("התחלה " + Format.clock(shift.start))
            }
            return Text("\u{200F}" + Format.clock(shift.start) + " – " + Format.clock(end))
        }
    }

    /// "8:41 שע׳ · הפסקה 30׳ · נ.ש 0:35 · שבת/חג" (app.js shiftMetaHtml), or what a day off pays.
    private var meta: String {
        let b = breakdown
        switch shift.type {
        case .vacation:
            return Format.hoursToHM(b.netHours) + " שע׳ בתשלום"
        case .sick:
            let tier = b.sickTier ?? 1
            let plus = tier >= 4 ? "+" : ""
            let pct = Int(jsRound(b.sickPct ?? 0))
            return "יום \(tier)\(plus) · \(pct)% מהתקן"
        case .work:
            var parts = [Format.hoursToHM(b.netHours) + " שע׳"]
            if b.breakMs > 0 { parts.append("הפסקה \(Int(jsRound(b.breakMs / 60000)))׳") }
            if b.overtimeHours > 0.01 { parts.append("נ.ש " + Format.hoursToHM(b.overtimeHours)) }
            if b.isHoliday { parts.append("שבת/חג") }
            return parts.joined(separator: " · ")
        }
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
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
}

/// A shift's day in a list: the day of the month over its weekday, red when the day fell short of its
/// standard, faint for a day off.
private struct DateBadge: View {
    let date: Date
    let short: Bool
    let dayOff: Bool

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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        }
    }

    private var color: Color {
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
        let taken = store.shifts.contains { LocalTime.dayKey($0.start) == key }
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
            .padding(.horizontal, 16)
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
        type == .sick ? "יום מחלה" : "יום חופש"
    }
}

// MARK: Menus on a long press

extension ShiftType: Identifiable {
    var id: String { rawValue }
}

extension Shift {
    /// "07:12 – 16:40", the start on the right; "מ־07:12" while it runs; nil for a day off.
    var span: String? {
        guard type == .work else { return nil }
        guard let end else { return "מ־" + Format.clock(start) }
        return "\u{200F}" + Format.clock(start) + " – " + Format.clock(end)
    }

    /// For the clipboard: "יום ג׳, 28 באוקטובר · 07:10 – 16:20 · 8:40 שע׳ · ₪ 470.25", the note under it.
    func summary(_ breakdown: Breakdown, _ settings: Settings) -> String {
        var parts = [Format.weekday(start) + ", " + Format.dateLong(start)]
        switch type {
        case .vacation:
            parts.append("חופשה בתשלום")
        case .sick:
            parts.append("יום מחלה")
        case .work:
            if let span { parts.append(span) }
            parts.append(Format.hoursShort(breakdown.netHours))
        }
        parts.append(Format.money(breakdown.pay, settings.currency))
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
        return !records.contains { !$0.deleted && $0.type != .work && $0.start >= today && $0.start < tomorrow }
    }
}

/// What a plus adds, its menu on a long press: a shift by hand, or a paid vacation or sick day (the toolbar's
/// plus, a menu of iOS's; LiftSection.adding for the others).
struct AddMenu: View {
    let shift: () -> Void
    let dayOff: (ShiftType) -> Void

    var body: some View {
        Button("משמרת", systemImage: "timer", action: shift)
        Button("יום חופש", systemImage: "sun.max") { dayOff(.vacation) }
        Button("יום מחלה", systemImage: "cross.case") { dayOff(.sick) }
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
        if shift.type == .work {
            items.append(LiftItem(title: "עריכה", systemImage: "pencil", action: edit))
        }
        if store.canCopyToToday(shift) {
            items.append(LiftItem(title: "שכפול להיום", systemImage: "plus.square.on.square", action: copy))
        }
        items.append(LiftItem(title: "העתקת הסיכום", systemImage: "doc.on.doc") {
            // a running shift's as it is now
            let now = shift.end == nil ? Calc.breakdown(shift, settings, asOf: Date().ms) : breakdown
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
            Spacer(minLength: 8)
            Text(hours)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(pay.map { Format.money($0, currency) } ?? "")
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
            TimelineView(.periodic(from: .now, by: 1)) { context in
                card(Calc.breakdown(shift, settings, asOf: context.date.ms))
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
                    PayLine(title: line.title, hours: line.hours, pay: line.pay, currency: settings.currency)
                }
            }
            if !shift.note.isEmpty {
                Text(shift.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(b.ongoing ? "עד עכשיו" : "סה״כ")
                    .font(.headline)
                Spacer()
                Text(Format.money(b.pay, settings.currency))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .liftedCard()
    }

    /// The hours by rate and what each pays (Calc.breakdown), then the break.
    private func lines(_ b: Breakdown) -> [(title: String, hours: String, pay: Double?)] {
        let s = settings
        switch shift.type {
        case .vacation:
            return [("חופשה בתשלום", Format.hoursToHM(b.netHours), b.pay)]
        case .sick:
            let tier = b.sickTier ?? 1
            return [("יום מחלה \(tier)" + (tier >= 4 ? "+" : ""), "\(Int(jsRound(b.sickPct ?? 0)))%", b.pay)]
        case .work:
            var list: [(title: String, hours: String, pay: Double?)] = []
            if b.isHoliday {
                list.append(("שבת / חג · " + Self.percent(s.holidayMult), Format.hoursToHM(b.netHours), b.basePay))
            } else {
                list.append(("שעות רגילות", Format.hoursToHM(b.regularHours), b.basePay))
                if b.ot1Hours > 0.001 {
                    list.append(("נוספות " + Self.percent(s.overtime1Mult), Format.hoursToHM(b.ot1Hours),
                                 b.ot1Hours * s.overtime1Mult * s.hourlyWage))
                }
                if b.ot2Hours > 0.001 {
                    list.append(("נוספות " + Self.percent(s.overtime2Mult), Format.hoursToHM(b.ot2Hours),
                                 b.ot2Hours * s.overtime2Mult * s.hourlyWage))
                }
                if b.nightPremium > 0.005 {
                    list.append(("תוספת לילה", Format.hoursToHM(b.nightHours), b.nightPremium))
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

    var body: some View {
        let now = Date().ms
        let breakdowns = shifts.map { Calc.breakdown($0, settings, asOf: now, sickDates: sickDates) }
        let worked = zip(shifts, breakdowns).filter { $0.0.type == .work }.reduce(0) { $0 + $1.1.netHours }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.weekday(date) + ", " + Format.dateLong(date))
                    .font(.headline)
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
            if shifts.isEmpty {
                Text("אין משמרת ביום זה")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(zip(shifts, breakdowns).enumerated()), id: \.offset) { _, pair in
                        PayLine(title: pair.0.span ?? (pair.0.type == .sick ? "יום מחלה" : "חופשה בתשלום"),
                                hours: pair.0.type == .work ? Format.hoursToHM(pair.1.netHours) : "",
                                pay: pair.1.pay, currency: settings.currency)
                    }
                }
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("סה״כ")
                        .font(.headline)
                    Spacer()
                    Text(Format.money(breakdowns.reduce(0) { $0 + $1.pay }, settings.currency))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .liftedCard()
    }

    /// "ערב פסח · יום מקוצר", or the holiday's name.
    private var holiday: String? {
        guard settings.holidaysEnabled else { return nil }
        let info = Holidays.info(date)
        guard let kind = info.kind, let name = info.name else { return nil }
        return kind == .short ? name + " · יום מקוצר" : name
    }
}
