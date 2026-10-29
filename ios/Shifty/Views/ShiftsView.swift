import SwiftUI

/// The shifts of a pay period, the newest first: the period's hours, hours missing, shifts and income, and
/// each shift's hours and pay, a running one's live (app.js renderShifts). A shift opens in the editor.
struct ShiftsView: View {
    @Environment(ShiftStore.self) private var store
    @State private var offset = 0
    @State private var adding = false
    @State private var editing: Shift?
    @State private var picking = false
    @State private var deleting: Shift?

    var body: some View {
        let range = Calc.period(around: Date(), monthStartDay: store.settings.monthStartDay, offset: offset)
        let running = store.active.map { Calc.inRange($0, range) } ?? false
        TimelineView(.periodic(from: .now, by: running ? 1 : 60)) { context in
            list(range, at: context.date)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("משמרות")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("הוספת משמרת")
            }
        }
        .sheet(isPresented: $adding) {
            ShiftEditor(shift: nil, day: nil)
                .environment(store)
        }
        .sheet(item: $editing) { shift in
            ShiftEditor(shift: shift, day: nil)
                .environment(store)
        }
        .sheet(isPresented: $picking) {
            PeriodPicker(current: Calc.periodMonth(range)) { year, month in
                offset = Calc.periodOffset(year: year, month0: month, monthStartDay: store.settings.monthStartDay, now: Date())
            }
        }
        .confirmationDialog("למחוק את המשמרת?", isPresented: deletingShown, titleVisibility: .visible, presenting: deleting) { shift in
            Button("מחיקה", role: .destructive) {
                withAnimation { store.delete(shift.id) }
            }
        }
    }

    private var deletingShown: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { shown in
            if !shown { deleting = nil }
        })
    }

    private func list(_ range: TimeRange, at date: Date) -> some View {
        let settings = store.settings
        let summary = Calc.summary(store.shifts, settings, range: range, asOf: date.ms)
        let cells = [
            SummaryCell(title: "שעות", value: Format.hoursToHM(summary.totals.netHours)),
            SummaryCell(title: "שעות חוסר", value: Format.hoursToHM(summary.shortfall.total)),
            SummaryCell(title: "משמרות", value: String(summary.totals.count)),
            SummaryCell(title: "סה״כ", value: Format.moneyShort(summary.totals.total, settings.currency)),
        ]
        return ScrollView {
            VStack(spacing: 12) {
                PeriodBar(range: range, offset: $offset) { picking = true }
                SummaryCard(cells: cells)
                    .padding(.bottom, 6)
                if summary.shifts.isEmpty {
                    ContentUnavailableView("אין משמרות בתקופה זו", systemImage: "calendar",
                                           description: Text("אפשר להוסיף משמרת בכפתור הפלוס למעלה."))
                        .padding(.top, 24)
                }
                ForEach(summary.shifts) { shift in
                    if let breakdown = summary.breakdowns[shift.id] {
                        Button {
                            editing = shift
                        } label: {
                            ShiftRow(shift: shift, breakdown: breakdown, currency: settings.currency,
                                     short: summary.days[LocalTime.dayKey(shift.start)]?.short == true && shift.type == .work)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("עריכה", systemImage: "pencil") { editing = shift }
                            Button("מחיקה", systemImage: "trash", role: .destructive) { deleting = shift }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}
