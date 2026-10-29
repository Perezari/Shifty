import SwiftUI

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

/// The period's numbers on the accent's glass (app.js .summary-card).
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
        .glassEffect(.regular.tint(.accentColor), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
