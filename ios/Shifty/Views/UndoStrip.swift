import SwiftUI
import UIKit

/// The last deletion, for six seconds at the bottom of a screen that deletes (the Shifts list, the calendar, a day's
/// sheet), above its tab bar: what was deleted, and ביטול to bring it back. After it, the deletion is still in
/// Settings › נמחקו לאחרונה. Set as the screen's bottom safe area, so that its last row scrolls above it.
struct UndoStrip: View {
    @Environment(ShiftStore.self) private var store

    /// How long a deletion is offered back here.
    static let seconds: Double = 6

    var body: some View {
        // not one whose time ran out while no screen of these was shown
        if let deletion = store.deletion, Date().timeIntervalSince(deletion.at) < Self.seconds {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text(title(deletion))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    withAnimation { store.restore(deletion.ids) }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("ביטול")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("ביטול המחיקה")
            }
            .padding(.leading, 18)
            .padding(.trailing, 4)
            .frame(height: 50)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: deletion.at) {
                let left = Self.seconds - Date().timeIntervalSince(deletion.at)
                if left > 0 { try? await Task.sleep(for: .seconds(left)) }
                guard !Task.isCancelled else { return }
                withAnimation { store.forget(deletion) }
            }
        }
    }

    /// "המשמרת נמחקה", "יום החופש נמחק", or "2 משמרות נמחקו".
    private func title(_ deletion: Deletion) -> String {
        guard deletion.ids.count == 1 else { return "\(deletion.ids.count) משמרות נמחקו" }
        switch store.records.first(where: { $0.id == deletion.ids[0] })?.type {
        case .vacation: return "יום החופש נמחק"
        case .sick: return "יום המחלה נמחק"
        case .reserve: return "יום המילואים נמחק"
        default: return "המשמרת נמחקה"
        }
    }
}
