import SwiftUI

/// A shift by hand, new or edited: its day, its hours in 24-hour time, its break in minutes, Shabbat or
/// holiday and a note; and deleting it (app.js openShiftEditor).
struct ShiftEditor: View {
    /// The shift edited; nil for a new one.
    let shift: Shift?
    /// A new shift's day; today without one.
    let day: Date?

    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var start = Date()
    @State private var end = Date()
    @State private var hasEnd = true
    @State private var breakMinutes = 0
    @State private var isHoliday = false
    @State private var note = ""
    @State private var loaded = false
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("תאריך", selection: $date, displayedComponents: .date)
                    DatePicker("שעת כניסה", selection: $start, displayedComponents: .hourAndMinute)
                    if hasEnd {
                        DatePicker("שעת יציאה", selection: $end, displayedComponents: .hourAndMinute)
                    } else {
                        Button("הוספת שעת יציאה") { hasEnd = true }
                    }
                }
                Section {
                    Stepper(value: $breakMinutes, in: 0...600, step: 5) {
                        HStack {
                            Text("הפסקה")
                            Spacer()
                            Text("\(breakMinutes) דק׳")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("שבת / חג", isOn: $isHoliday)
                }
                Section {
                    TextField("הערה", text: $note, axis: .vertical)
                }
                if shift != nil {
                    Section {
                        Button("מחיקת משמרת", role: .destructive) { deleting = true }
                    }
                }
            }
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
                    Button(action: save) {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("שמירה")
                }
            }
            .confirmationDialog("למחוק את המשמרת?", isPresented: $deleting, titleVisibility: .visible) {
                Button("מחיקה", role: .destructive, action: delete)
            }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .onAppear(perform: load)
    }

    private var title: String {
        shift == nil ? "משמרת חדשה" : "עריכת משמרת"
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let shift else {
            // a new shift: 9:00 to 17:00 of its day
            let base = day ?? Date()
            date = base
            start = Self.time(9, 0, on: base)
            end = Self.time(17, 0, on: base)
            return
        }
        date = shift.start
        start = shift.start
        end = shift.end ?? Self.time(17, 0, on: shift.start)
        hasEnd = shift.end != nil
        // the breaks as minutes, an open one up to now
        let now = Date().ms
        var ms = 0.0
        for b in shift.breaks {
            ms += max(0, (b.end?.ms ?? now) - b.start.ms)
        }
        breakMinutes = Int(jsRound(ms / 60000))
        isHoliday = shift.isHoliday
        note = shift.note
    }

    private func save() {
        let d = LocalTime.parts(date)
        let s = LocalTime.parts(start)
        let startDate = LocalTime.date(d.year, d.month0, d.day, s.hour, s.minute)
        var endDate: Date? = nil
        if hasEnd {
            let e = LocalTime.parts(end)
            var value = LocalTime.date(d.year, d.month0, d.day, e.hour, e.minute)
            if value <= startDate { value = LocalTime.addingDays(1, to: value) } // over midnight
            endDate = value
        }
        var edited = shift ?? Shift(id: ShiftStore.newID(), start: startDate)
        edited.start = startDate
        edited.end = endDate
        edited.isHoliday = isHoliday
        edited.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // the break as one span, from a minute after the start, as the web app keeps an edited break
        if breakMinutes > 0 {
            let breakStart = startDate.addingTimeInterval(60)
            edited.breaks = [Break(start: breakStart, end: breakStart.addingTimeInterval(Double(breakMinutes) * 60))]
        } else {
            edited.breaks = []
        }
        store.upsert(edited)
        dismiss()
    }

    private func delete() {
        if let shift { store.delete(shift.id) }
        dismiss()
    }

    private static func time(_ hour: Int, _ minute: Int, on day: Date) -> Date {
        let p = LocalTime.parts(day)
        return LocalTime.date(p.year, p.month0, p.day, hour, minute)
    }
}
