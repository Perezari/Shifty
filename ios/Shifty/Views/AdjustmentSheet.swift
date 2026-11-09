import SwiftUI
import UIKit

/// A sum once on a day, new or edited (Shift.amount): added to its pay period's income, as a commission or a grant, or
/// taken off it, as an advance or the meals. ShiftEditor shows it for one edited.
struct AdjustmentSheet: View {
    /// The one edited; nil for a new one.
    var shift: Shift? = nil
    /// A new one's day; today without one.
    var day: Date? = nil

    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var takenOff = false
    @State private var sum = ""
    @State private var title = ""
    @State private var date = Date()
    /// nil for the settings' own workplace.
    @State private var workplace: String?
    @State private var loaded = false
    @State private var deleting = false
    @FocusState private var typing: Bool

    var body: some View {
        let settings = store.settings
        NavigationStack {
            Form {
                Section {
                    Picker("סוג", selection: $takenOff) {
                        Text("תוספת").tag(false)
                        Text("ניכוי").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section {
                    HStack(spacing: 8) {
                        Text("סכום")
                        TextField("0", text: $sum)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($typing)
                        Text(settings.currency)
                            .foregroundStyle(.secondary)
                    }
                    TextField("שם, לא חובה", text: $title)
                    HStack(spacing: 8) {
                        ForEach(takenOff ? ["מקדמה", "ארוחות"] : ["עמלה", "מענק"], id: \.self) { word in
                            Button(word) { title = word }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                } footer: {
                    Text(takenOff ? "ניכוי יורד מההכנסה של התקופה ומהנטו המשוער, בלי לשנות את המס."
                         : "תוספת נכנסת להכנסה של התקופה ולמס, אבל לא לפנסיה.")
                }
                Section {
                    DatePicker("תאריך", selection: $date, displayedComponents: .date)
                    if !settings.workplaces.isEmpty {
                        Picker("מקום עבודה", selection: $workplace) {
                            Text(settings.workplaceName).tag(String?.none)
                            ForEach(settings.workplaces) { place in
                                Text(place.name).tag(Optional(place.id))
                            }
                        }
                    }
                }
                if shift != nil {
                    Section {
                        // the question rises from the button itself, as iOS 26 places it
                        Button("מחיקה", role: .destructive) { deleting = true }
                            .confirmationDialog("למחוק את הסכום?", isPresented: $deleting, titleVisibility: .visible) {
                                Button("מחיקה", role: .destructive, action: delete)
                            }
                    }
                }
            }
            .navigationTitle(shift == nil ? "תוספת או ניכוי" : "עריכת סכום")
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
                    .disabled(amount == nil)
                    .accessibilityLabel("שמירה")
                }
            }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .onAppear(perform: load)
    }

    /// The sum typed, above zero.
    private var amount: Double? {
        Double(sum.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let shift else {
            date = day ?? Date()
            workplace = store.nextWorkplace
            typing = true
            return
        }
        let value = shift.amount ?? 0
        takenOff = value < 0
        sum = abs(value) == abs(value).rounded() ? String(Int(abs(value))) : String(abs(value))
        title = shift.note
        date = shift.start
        workplace = shift.workplaceId
    }

    private func save() {
        guard let amount else { return }
        let signed = takenOff ? -amount : amount
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = store.settings.workplaces.contains { $0.id == workplace } ? workplace : nil
        if var edited = shift {
            let p = LocalTime.parts(date)
            let noon = LocalTime.date(p.year, p.month0, p.day, 12)
            edited.start = noon
            edited.end = noon
            edited.note = name
            edited.amount = signed
            edited.workplaceId = place
            withAnimation { store.upsert(edited) }
        } else {
            withAnimation { _ = store.addAdjustment(date, amount: signed, title: name, at: place) }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    /// Deleted, and offered back for a few seconds on the screen under it (UndoStrip).
    private func delete() {
        if let shift { withAnimation { store.delete(shift.id) } }
        dismiss()
    }
}
