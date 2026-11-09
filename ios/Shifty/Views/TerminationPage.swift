import SwiftUI

/// What ending the work at a workplace comes to (Calc.termination), on a dismissal or a resignation and a last day
/// picked: the seniority, the severance or the pension fund's severance money, the vacation days left paid out, the
/// recuperation pay due and their total; and the notice, in days and in pay. From a workplace's page, with Shifty Pro.
struct TerminationPage: View {
    /// nil for the settings' own workplace.
    let placeID: String?
    @Environment(ShiftStore.self) private var store
    @State private var leaving = Leaving.dismissal
    /// The last day picked here; until then the workplace's own (Workplace.endDate), or today.
    @State private var picked: Date?

    var body: some View {
        let s = store.settings
        let place = s.place(placeID)
        let lastDay = picked ?? place.endDate.map(LocalTime.startOfDay) ?? LocalTime.startOfDay(Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if let start = place.startDate.map(LocalTime.startOfDay) {
                    SettingsSection(title: nil) {
                        Picker("סיום העבודה", selection: $leaving) {
                            Text("פיטורים").tag(Leaving.dismissal)
                            Text("התפטרות").tag(Leaving.resignation)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 12)
                        Divider()
                        DatePicker("תאריך תחילת עבודה", selection: startDate, in: ...Date(), displayedComponents: .date)
                            .settingsRow()
                        Divider()
                        DatePicker("יום העבודה האחרון",
                                   selection: Binding(get: { lastDay }, set: { picked = LocalTime.startOfDay($0) }),
                                   in: start..., displayedComponents: .date)
                            .settingsRow()
                    }
                    if let ending = Calc.termination(store.shifts, s, at: placeID, lastDay: max(lastDay, start)) {
                        money(ending, place, s.currency)
                        notice(ending, s.currency)
                    }
                } else {
                    SettingsSection(title: nil, note: "החישוב לפי הוותק, מהיום שבו התחלת לעבוד כאן.") {
                        Button {
                            setStart()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                Text("תאריך תחילת עבודה")
                            }
                            .foregroundStyle(.tint)
                            .settingsRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, ScreenMargin.side)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("סיום העבודה")
    }

    // MARK: Sections

    /// The money due: the severance or the fund's, the vacation days left, the recuperation pay, and the total.
    private func money(_ t: Termination, _ place: Workplace, _ currency: String) -> some View {
        SettingsSection(title: "מה מגיע לך",
                        note: "הערכה לפי החוק, בשכר של היום האחרון. בחוזה או בהסכם קיבוצי יכולים להיות תנאים טובים יותר. יש התפטרויות שנחשבות כמו פיטורים, למשל בגלל הרעה מוחשית בתנאים, מצב בריאותי או אחרי לידה.") {
            line("ותק", Format.seniority(years: t.years, months: t.months))
            Divider()
            severance(t, place, currency)
            Divider()
            if let days = t.vacationDays {
                line("פדיון חופשה", Format.moneyShort(t.vacationPay, currency),
                     detail: Self.days(days) + ", " + Format.moneyShort(t.vacationDayPay, currency) + " ליום")
            } else {
                line("פדיון חופשה", "—", detail: "צריך מעקב יתרות, בדף של מקום העבודה.")
            }
            if let days = t.recuperationDays {
                Divider()
                line("דמי הבראה", Format.moneyShort(t.recuperationPay, currency),
                     detail: days > 0.005 ? Self.days(days) + " שעוד לא שולמו" : t.years < 1 ? "מגיעים אחרי שנת עבודה" : "שולמו כולם")
            }
            Divider()
            line("סך הכול", Format.moneyShort(t.total(leaving), currency), detail: "ברוטו, בלי ההודעה המוקדמת", strong: true)
        }
    }

    /// The severance on a dismissal after a year, or the pension fund's severance money, the worker's either way.
    @ViewBuilder
    private func severance(_ t: Termination, _ place: Workplace, _ currency: String) -> some View {
        let perYear = Format.moneyShort(t.monthPay, currency) + " לכל שנת עבודה"
            + (t.monthly ? "" : ", לפי " + PayText.number(jsRound(Calc.monthHours(place))) + " שעות בחודש")
        let fund = "בערך " + Format.moneyShort(t.fund, currency)
        if leaving == .dismissal && t.severanceDue {
            let from = t.fundShare >= 1 ? ". כולם מהכסף שהמעסיק הפריש לקרן הפנסיה."
                : t.fundShare > 0 ? ". " + fund + " מהם בקרן הפנסיה, והשאר מהמעסיק." : "."
            line("פיצויי פיטורים", Format.moneyShort(t.severanceBase, currency), detail: perYear + from)
        } else if t.fundShare > 0 {
            line("פיצויים בקרן הפנסיה", fund,
                 detail: leaving == .dismissal
                    ? "פיצויים מלאים מגיעים אחרי שנת עבודה. הכסף שהמעסיק הפריש לפיצויים נשאר שלך גם לפני."
                    : "הכסף שהמעסיק הפריש לפיצויים נשאר שלך. פיצויים מלאים מגיעים בפיטורים אחרי שנה.")
        } else {
            line("פיצויי פיטורים", "—",
                 detail: leaving == .dismissal ? "מגיעים אחרי שנת עבודה." : "מגיעים בפיטורים אחרי שנה.")
        }
    }

    /// The notice the employer gives on a dismissal, or the worker on a resignation, and its pay.
    private func notice(_ t: Termination, _ currency: String) -> some View {
        SettingsSection(title: "הודעה מוקדמת", note: "בימים קלנדריים, כולל סופי שבוע.") {
            line(leaving == .dismissal ? "המעסיק צריך להודיע לך" : "עליך להודיע למעסיק",
                 t.noticeDays.map { Self.days($0) + " מראש" } ?? "חודש מראש")
            Divider()
            line("תשלום במקום ההודעה", Format.moneyShort(t.noticePay, currency),
                 detail: "אם המעסיק מוותר על העבודה בימים האלה")
        }
    }

    // MARK: Rows

    /// A line of the card: its name, and under it what it is made of; its amount at its end.
    private func line(_ title: String, _ value: String, detail: String? = nil, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(strong ? .semibold : .regular)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Text(value)
                .monospacedDigit()
                .fontWeight(strong ? .semibold : .regular)
                .foregroundStyle(strong ? Color.primary : Color.secondary)
        }
        .padding(.vertical, detail == nil ? 0 : 10)
        .settingsRow()
    }

    /// "יום", "יומיים", "12 ימים", "11.5 ימים".
    private static func days(_ value: Double) -> String {
        let tenths = jsRound(value * 10) / 10
        if tenths == 1 { return "יום" }
        if tenths == 2 { return "יומיים" }
        let number = tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
        return number + " ימים"
    }

    /// The day work began there, as on the workplace's page: a day, saved as it changes.
    private var startDate: Binding<Date> {
        Binding(
            get: { store.settings.place(placeID).startDate ?? LocalTime.startOfDay(Date()) },
            set: { date in
                let day = LocalTime.startOfDay(date)
                guard store.settings.place(placeID).startDate != day else { return }
                setStart(day)
            }
        )
    }

    /// The day work began there: today at first, then the day picked.
    private func setStart(_ day: Date = LocalTime.startOfDay(Date())) {
        let id = placeID
        store.updateSettings { settings in
            var place = settings.place(id)
            place.startDate = day
            settings.setPlace(id, place)
        }
    }
}
