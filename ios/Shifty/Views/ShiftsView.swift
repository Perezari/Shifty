import SwiftUI
import UIKit

/// The shifts of a pay period, the newest first: the period's hours, hours missing, shifts and income, and
/// each shift's hours and pay, a running one's going up each second (app.js renderShifts). A shift opens in the
/// editor, a swipe deletes it (offered back for a few seconds at the bottom, UndoStrip), and a long press lifts it with
/// its menu; the plus adds a shift, and on a long press a day off or a sum once. The period's hours report goes out from
/// the bar, with Shifty Pro. The list is drawn again each minute while it is on screen, and of the running shift only its pay
/// each second (ShiftRow.live); out of sight, neither.
struct ShiftsView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.lifter) private var lifter
    @State private var offset = 0
    @State private var adding = false
    @State private var adjusting = false
    @State private var reporting = false
    @State private var editing: Shift?
    @State private var copying: Shift?
    @State private var dayOff: ShiftType?
    @State private var picking = false
    /// The minute the list shows.
    @State private var now = Date()
    /// The list on screen, for the running shift's pay to count.
    @State private var shown = false

    var body: some View {
        let range = Calc.period(around: now, monthStartDay: store.settings.monthStartDay, offset: offset)
        list(range, at: now)
            // a shift just deleted, offered back for a few seconds
            .safeAreaInset(edge: .bottom, spacing: 0) {
                UndoStrip()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("משמרות")
            .minutes($now)
            .onAppear { shown = true }
            .onDisappear { shown = false }
            .toolbar {
                // back to the period of today, from any other
                if offset != 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("היום") {
                            withAnimation { offset = 0 }
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if pro.unlocked { reporting = true } else { pro.offer() }
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .accessibilityLabel("דוח שעות")
                }
                ToolbarItem(placement: .primaryAction) {
                    // a long press lifts it with a day off, as the Now screen's plus: sooner than a menu of iOS's,
                    // and with the iPhone's tap
                    Button(action: add) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("הוספת משמרת")
                    .liftable(card: false) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular, in: Circle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } sections: {
                        [.adding(shift: { adding = true }, dayOff: { dayOff = $0 }, adjustment: { adjusting = true })]
                    }
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
            .sheet(item: $copying) { shift in
                ShiftEditor(shift: nil, day: Date(), from: shift)
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
            .sheet(isPresented: $reporting) {
                ReportSheet(around: Date(ms: (range.start.ms + range.end.ms) / 2), place: store.nextWorkplace)
                    .environment(store)
            }
            .sheet(isPresented: $picking) {
                PeriodPicker(current: Calc.periodMonth(range)) { year, month in
                    offset = Calc.periodOffset(year: year, month0: month, monthStartDay: store.settings.monthStartDay, now: Date())
                }
                .environment(store)
            }
            #if DEBUG
            .task {
                if Screenshot.current == .report {
                    // after the tab has appeared: a sheet asked for during the switch is dropped
                    try? await Task.sleep(for: .seconds(1.5))
                    reporting = true
                }
            }
            #endif
    }

    /// A shift by hand, with the iPhone's tap; not the finger lifted after a long press.
    private func add() {
        guard lifter?.isShowing != true else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        adding = true
    }

    private func list(_ range: TimeRange, at date: Date) -> some View {
        Perf.drew("משמרות")
        let settings = store.settings
        let summary = Calc.summary(store.shifts, settings, range: range, asOf: date.ms)
        let cells = [
            SummaryCell(title: "שעות", value: Format.hoursToHM(summary.totals.netHours)),
            SummaryCell(title: "שעות חוסר", value: Format.hoursToHM(summary.shortfall.total)),
            SummaryCell(title: "משמרות", value: String(summary.totals.count)),
            SummaryCell(title: "סה״כ", value: Format.moneyShort(summary.totals.total, settings.currency)),
        ]
        // a list, for a shift to be swiped away: its rows the same cards
        return List {
            PeriodBar(range: range, offset: $offset) { picking = true }
                .cardRow()
            SummaryCard(cells: cells)
                .padding(.bottom, 6)
                .cardRow()
            if summary.shifts.isEmpty {
                ContentUnavailableView("אין משמרות בתקופה זו", systemImage: "calendar",
                                       description: Text("אפשר להוסיף משמרת בכפתור הפלוס למעלה."))
                    .padding(.top, 24)
                    .cardRow()
            }
            ForEach(summary.holidayPays) { day in
                HolidayPayRow(day: day, currency: settings.currency,
                              place: settings.workplaces.isEmpty ? nil : settings.place(day.place.isEmpty ? nil : day.place).name)
                    .cardRow()
            }
            ForEach(summary.shifts) { shift in
                if let breakdown = summary.breakdowns[shift.id] {
                    Button {
                        // not the finger lifted after a long press
                        if lifter?.isShowing != true { editing = shift }
                    } label: {
                        ShiftRow(shift: shift, breakdown: breakdown, currency: settings.currency,
                                 short: summary.days[LocalTime.dayKey(shift.start)]?.short == true && shift.type == .work,
                                 live: shown ? settings : nil, byHours: settings.isMonthly(shift), place: settings.placeName(of: shift))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { store.delete(shift.id) }
                        } label: {
                            Label("מחיקה", systemImage: "trash")
                        }
                    }
                    .shiftMenu(shift, breakdown, settings, edit: { editing = shift }, copy: { copying = shift })
                    #if DEBUG
                    // the screenshot of a menu: the last shift before the running one, lifted
                    .environment(\.liftsForScreenshot,
                                 Screenshot.current == .menu && shift.id == summary.shifts.dropFirst().first?.id)
                    #endif
                    .cardRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }
}
