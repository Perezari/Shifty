import StoreKit
import SwiftUI

/// Shifty Pro on a sheet, over the tabs: the app's icon, what it opens, and the purchase, once, at the App
/// Store's price, by the thumb, with restoring an earlier one (Apple requires it). Designed in ios/preview first.
struct ProSheet: View {
    @Environment(Pro.self) private var pro
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss
    @State private var buying = false

    private struct Feature {
        let symbol: String
        let title: String
        let text: String
    }

    /// What Shifty Pro opens, each with its line (the preview's PRO). A title that begins in English begins
    /// with a right-to-left mark: iOS lays out a line by its first letter, and Siri's would read backwards.
    private static let features = [
        Feature(symbol: "banknote", title: "נטו משוער", text: "כמה ייכנס לחשבון בסוף התקופה, אחרי מס, ביטוח לאומי ופנסיה."),
        Feature(symbol: "beach.umbrella", title: "יתרות חופשה ומחלה", text: "לפי התלוש האחרון, מתעדכנות כל חודש, ומופיעות בכל סימון של יום חופש."),
        Feature(symbol: "iphone", title: "מסך הנעילה והווידג׳טים", text: "המשמרת שרצה ב-Live Activity, ב-Dynamic Island ובמסך הבית."),
        Feature(symbol: "mic", title: "\u{200F}Siri ומרכז הבקרה", text: "להתחיל ולסיים משמרת, ולשאול כמה הרווחת, בלי לפתוח את Shifty."),
        Feature(symbol: "icloud", title: "סנכרון ב-iCloud", text: "אותן משמרות והגדרות בכל מכשיר עם אותו Apple ID."),
        Feature(symbol: "mappin.and.ellipse", title: "תזכורת לפי מיקום", text: "שאלה כשמגיעים לעבודה וכשיוצאים ממנה."),
        Feature(symbol: "briefcase", title: "סיום העבודה", text: "פיצויים, הודעה מוקדמת, פדיון חופשה והבראה, לפי החוק."),
        Feature(symbol: "doc.text", title: "דוח שעות", text: "כל תקופת שכר וכל שנה כקובץ PDF, לשליחה למעסיק או לרואה חשבון."),
        Feature(symbol: "paintpalette", title: "אייקונים לבחירה", text: "לבן, כהה או שחור־לבן, במסך הבית."),
    ]

    var body: some View {
        NavigationStack {
            // the purchase at the bottom when there is room, and all of it scrolled when the text is large
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 18) {
                        head
                        VStack(alignment: .leading, spacing: 15) {
                            ForEach(Self.features, id: \.title) { feature in
                                row(feature)
                            }
                        }
                        Spacer(minLength: 6)
                        buyBar
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("סגירה")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: pro.unlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var head: some View {
        VStack(spacing: 4) {
            AppIconImage(size: 72)
                .shadow(color: .black.opacity(0.18), radius: 9, y: 6)
                .padding(.bottom, 8)
            Text(verbatim: "Shifty Pro")
                .font(.system(size: 28, weight: .bold))
            Text("תשלום אחד, ושלך לתמיד")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: feature.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.accentColor.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                Text(feature.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// The price and the purchase; under them, that it is once, and restoring an earlier one.
    private var buyBar: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                Group {
                    if buying || pro.busy || (pro.loading && pro.price == nil) {
                        ProgressView()
                            .tint(.white)
                    } else if let price = pro.price {
                        Text("שדרוג ב־\(price)")
                    } else {
                        Text("החנות לא זמינה כרגע")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(pro.price == nil || buying || pro.busy)
            Text("בלי מנוי ובלי חיובים נוספים.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("שחזור רכישה") {
                Task { await pro.restore() }
            }
            .font(.subheadline.weight(.medium))
            .disabled(buying || pro.busy)
            if let message = pro.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// The App Store's purchase sheet, its end told to Pro.
    private func buy() async {
        guard let product = pro.product else { return }
        buying = true
        defer { buying = false }
        pro.message = nil
        do {
            let result = try await purchase(product)
            await pro.finish(result)
        } catch {
            pro.message = "הרכישה לא הושלמה: \(error.localizedDescription)"
        }
    }
}

/// Shifty Pro at the top of the settings: what it opens and its price, a button for its sheet and a restore;
/// once bought, a line that it is on.
struct ProCard: View {
    @Environment(Pro.self) private var pro

    var body: some View {
        if pro.unlocked {
            HStack(spacing: 12) {
                AppIconImage(size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Shifty Pro")
                        .font(.headline)
                    Text("פעיל. תודה!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 2)
            .card(padding: 14)
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    AppIconImage(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Shifty Pro")
                            .font(.headline)
                        Text("נטו משוער, יתרות, מסך הנעילה והווידג׳טים, Siri וסנכרון. בתשלום אחד.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Button {
                    pro.offer()
                } label: {
                    Text(upgrade)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                Button("שחזור רכישה") {
                    Task { await pro.restore() }
                }
                .font(.subheadline.weight(.medium))
                .disabled(pro.busy)
                if let message = pro.message, !pro.offering {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .card(padding: 16)
        }
    }

    /// "שדרוג ב־₪24.90", or without the price while the App Store's is not known.
    private var upgrade: String {
        guard let price = pro.price else { return "שדרוג ל-Shifty Pro" }
        return "שדרוג ב־" + price
    }
}

/// "Pro", by what Shifty Pro opens, in the free version.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "Pro")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
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
