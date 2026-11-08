import SwiftUI
import UIKit

/// Settings › נמחקו לאחרונה: the shifts and days off deleted in the last 30 days, here or on another device, the last
/// deleted first. A tap asks, then brings one back to its place, on the other devices too. A deleted shift stays on
/// the iPhone as a tombstone with all it held, so that its deletion reaches iCloud: that is what lets it come back
/// (ShiftStore.restore).
struct RecentlyDeletedPage: View {
    @Environment(ShiftStore.self) private var store
    /// The shift tapped, asked about before it comes back.
    @State private var asked: Shift?
    @State private var askingAll = false

    var body: some View {
        let settings = store.settings
        let gone = store.recentlyDeleted()
        let sick = Calc.sickDates(of: store.shifts)
        ScrollView {
            VStack(spacing: 10) {
                if gone.isEmpty {
                    ContentUnavailableView("אין משמרות שנמחקו", systemImage: "trash",
                                           description: Text("משמרת שנמחקת נשארת כאן 30 יום, ואפשר להחזיר אותה."))
                        .padding(.top, 40)
                } else {
                    ForEach(gone) { shift in
                        Button {
                            asked = shift
                        } label: {
                            ShiftRow(shift: shift, breakdown: Calc.breakdown(shift, settings, asOf: Date().ms, sickDates: sick),
                                     currency: settings.currency, byHours: settings.isMonthly(shift),
                                     place: settings.placeName(of: shift))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("לחיצה על משמרת מחזירה אותה למקומה. משמרת שנמחקת נשארת כאן 30 יום.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("נמחקו לאחרונה")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if gone.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Button("שחזור הכול") { askingAll = true }
                        .confirmationDialog("לשחזר את כל \(gone.count) המשמרות?", isPresented: $askingAll,
                                            titleVisibility: .visible) {
                            Button("שחזור הכול") { restore(gone.map(\.id)) }
                            Button("ביטול", role: .cancel) {}
                        }
                }
            }
        }
        .confirmationDialog(asked.map(question) ?? "", isPresented: askedShown, titleVisibility: .visible,
                            presenting: asked) { shift in
            Button("שחזור") { restore([shift.id]) }
            Button("ביטול", role: .cancel) {}
        } message: { shift in
            Text(deleted(shift))
        }
    }

    private var askedShown: Binding<Bool> {
        Binding {
            asked != nil
        } set: { shown in
            if !shown { asked = nil }
        }
    }

    /// "לשחזר את המשמרת?", or the day off's.
    private func question(_ shift: Shift) -> String {
        switch shift.type {
        case .work: "לשחזר את המשמרת?"
        case .vacation: "לשחזר את יום החופש?"
        case .sick: "לשחזר את יום המחלה?"
        case .reserve: "לשחזר את יום המילואים?"
        }
    }

    /// "נמחקה ב־8 בנובמבר, 14:02": when, as its tombstone was stamped.
    private func deleted(_ shift: Shift) -> String {
        guard let at = shift.updatedAt else { return "" }
        return (shift.type == .work ? "נמחקה ב־" : "נמחק ב־") + Format.dateLong(at) + ", " + Format.clock(at)
    }

    private func restore(_ ids: [String]) {
        withAnimation { store.restore(ids) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Settings' row to the recently deleted, with how many there are.
struct RecentlyDeletedRow: View {
    @Environment(ShiftStore.self) private var store

    var body: some View {
        let count = store.recentlyDeleted().count
        NavigationLink {
            RecentlyDeletedPage()
        } label: {
            HStack(spacing: 8) {
                Text("נמחקו לאחרונה")
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .settingsRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
