import SwiftUI
import UIKit

/// The last deletion, for six seconds at the bottom of a screen that deletes (the Shifts list, the calendar, a day's
/// sheet), above its tab bar: what was deleted, and ביטול to bring it back. After it, the deletion is still in
/// Settings › נמחקו לאחרונה. Set as the screen's bottom safe area, so that its last row scrolls above it. Also what is
/// left after a day off is added, with Shifty Pro where the days left are kept (there and on the Now screen).
///
/// It has to be seen: a solid capsule in the other look's colors (dark on a light screen, light on a dark one) with
/// a shadow, rising with a bounce and a tap of the iPhone. Glass, as at first, sank into the cards and the tab bar.
struct UndoStrip: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    /// How long a deletion is offered back here.
    static let seconds: Double = 6

    var body: some View {
        ZStack {
            // not one whose time ran out while no screen of these was shown
            if let deletion = store.deletion, Date().timeIntervalSince(deletion.at) < Self.seconds {
                strip(deletion)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: deletion.at) {
                        // the tap as it comes up after a deletion, not as a screen shows one already made
                        if Date().timeIntervalSince(deletion.at) < 0.5 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        let left = Self.seconds - Date().timeIntervalSince(deletion.at)
                        if left > 0 { try? await Task.sleep(for: .seconds(left)) }
                        guard !Task.isCancelled else { return }
                        // the list's room for it closing smoothly too
                        withAnimation(.easeOut(duration: 0.25)) { store.forget(deletion) }
                    }
            } else if let added = store.addedDayOff, Date().timeIntervalSince(added.at) < Self.seconds, let text = left(added) {
                capsule {
                    HStack(spacing: 12) {
                        DayOffSymbol(type: added.type, size: 15)
                            .foregroundStyle(added.type.dayOffColor)
                        Text(text)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 8)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: added.at) {
                    let left = Self.seconds - Date().timeIntervalSince(added.at)
                    if left > 0 { try? await Task.sleep(for: .seconds(left)) }
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.25)) { store.forget(added) }
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: store.deletion)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: store.addedDayOff)
    }

    /// "נשארו 11.5 ימי חופש", as of the day added when it is still ahead; nil without Shifty Pro, for a day of reserve
    /// duty, and where the workplace does not keep its days left.
    private func left(_ added: AddedDayOff) -> String? {
        guard ProFlag.on, added.type == .vacation || added.type == .sick, let shift = store.shift(added.id),
              let balance = Calc.leave(store.shifts, store.settings, asOf: max(Date(), shift.start),
                                       at: store.settings.workplace(of: shift)?.id) else { return nil }
        let days = added.type == .vacation ? balance.vacation : balance.sick
        let word = added.type == .vacation ? "חופש" : "מחלה"
        if days < -0.04 { return "חריגה של " + Format.days(-days) + " ימי " + word }
        if Format.days(days) == "1" { return "נשאר יום " + word + " אחד" }
        return "נשארו " + Format.days(days) + " ימי " + word
    }

    /// The solid capsule in the other look's colors.
    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(.primary)
            .padding(.leading, 20)
            .padding(.trailing, 4)
            .frame(height: 54)
            .background(Capsule().fill(Color(white: scheme == .dark ? 0.94 : 0.12)))
            // the text, its gray and the tint as the other look draws them, to stand on the capsule
            .environment(\.colorScheme, scheme == .dark ? .light : .dark)
            .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.25), radius: 18, y: 8)
            .padding(.horizontal, ScreenMargin.side)
            .padding(.bottom, 10)
    }

    private func strip(_ deletion: Deletion) -> some View {
        capsule {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(title(deletion))
                .font(.body.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                withAnimation { store.restore(deletion.ids) }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("ביטול", systemImage: "arrow.uturn.backward")
                    .font(.body.weight(.bold))
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("ביטול המחיקה")
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
        case .adjustment: return "הסכום נמחק"
        default: return "המשמרת נמחקה"
        }
    }
}
