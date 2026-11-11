import SwiftUI

/// The workplaces at the top of the settings: each a row with its pay now, opening its page (WorkplacePage); and
/// another one. Designed in ios/preview first.
struct WorkplacesSection: View {
    @Environment(ShiftStore.self) private var store
    /// A workplace just added, its page opened.
    @State private var added: String?

    var body: some View {
        let s = store.settings
        SettingsSection(title: "מקומות עבודה",
                        note: "השכר ותקופת השכר, השעות, השעות הנוספות, החופשה, הפנסיה והתזכורת של כל מעסיק נמצאים בדף שלו.") {
            NavigationLink {
                WorkplacePage(placeID: nil)
            } label: {
                row(s.place(nil), s)
            }
            .buttonStyle(.plain)
            ForEach(s.workplaces) { place in
                Divider()
                NavigationLink {
                    WorkplacePage(placeID: place.id)
                } label: {
                    row(place, s)
                }
                .buttonStyle(.plain)
            }
            Divider()
            Button(action: add) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("הוספת מקום עבודה")
                    Spacer()
                }
                .foregroundStyle(.tint)
                .settingsRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationDestination(item: $added) { id in
            WorkplacePage(placeID: id)
        }
    }

    private func row(_ place: Workplace, _ s: Settings) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                Text(PayText.summary(Settings.terms(place.pay, at: Date()) ?? place.pay[0], s.currency)
                     + (place.ended(by: Date()) ? " · הסתיים" : ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .settingsRow()
        .contentShape(Rectangle())
    }

    /// Another workplace, by the hour at the own one's wage, with its standard hours and its employer's rules, on its
    /// page.
    private func add() {
        let id = ShiftStore.newID()
        let own = store.settings
        let place = Workplace(id: id, name: "מקום עבודה \(own.workplaces.count + 2)",
                              pay: [PayTerms(id: id + "-pay", from: PayTerms.start, hourlyWage: own.hourlyWage)],
                              standardByDay: own.standardByDay, rules: own.startingRules)
        store.updateSettings { $0.workplaces.append(place) }
        added = id
    }
}

/// A workplace's page: its name, its pay from each date, the newest first (a sheet changes one or adds one from a
/// date), its pay now when it is global or has a bonus, its pay month, its standard hours, and what its employer
/// sets: overtime, breaks, Shabbat and night, a holiday's eve, vacation and sick days and the days left of them, the
/// pension and travel; the reminder of its place, and what ending the work there comes to (TerminationPage). Another
/// workplace can be deleted, its shifts then counted as the own one's.
struct WorkplacePage: View {
    /// nil for the settings' own workplace.
    let placeID: String?
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PayEdit?
    @State private var hoursEdit: HoursEdit?
    @State private var deleting = false
    @State private var message: String?
    // the place's reminder, this iPhone's (Place)
    @AppStorage private var placeOn: Bool
    @AppStorage private var placeRadius: Double
    @State private var placeSet: Bool
    @State private var placeBusy = false

    private static let dayNames = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
    /// How far around the workplace counts as there, in meters.
    private static let radii: [Double] = [100, 150, 250, 400]

    init(placeID: String?) {
        self.placeID = placeID
        _placeOn = AppStorage(wrappedValue: false, Place.key(Place.enabledKey, placeID))
        _placeRadius = AppStorage(wrappedValue: 150.0, Place.key(Place.radiusKey, placeID))
        _placeSet = State(initialValue: Place.coordinate(placeID) != nil)
    }

    var body: some View {
        let s = store.settings
        let place = s.place(placeID)
        let now = Settings.terms(place.pay, at: Date()) ?? place.pay[0]
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: nil) {
                    TextRow(title: "שם", text: name, fallback: placeID == nil ? Settings().workplaceName : "מקום עבודה")
                }

                SettingsSection(title: "תקופת העבודה", note: seniorityNote(place)) {
                    if place.startDate == nil {
                        Button {
                            change { $0.startDate = LocalTime.startOfDay(Date()) }
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
                    } else {
                        DatePicker("תאריך תחילת עבודה", selection: startDate, in: ...Date(), displayedComponents: .date)
                            .settingsRow()
                    }
                    Divider()
                    Toggle("סיימתי לעבוד כאן", isOn: hasEnded)
                        .settingsRow()
                    if place.endDate != nil {
                        Divider()
                        DatePicker("יום העבודה האחרון", selection: endDate,
                                   in: (place.startDate.map(LocalTime.startOfDay) ?? .distantPast)..., displayedComponents: .date)
                            .settingsRow()
                    }
                }

                SettingsSection(title: "שכר", note: "משמרות שלפני כל תאריך נשארות בשכר שהיה אז.") {
                    ForEach(Array(place.pay.reversed())) { terms in
                        Button {
                            editing = PayEdit(terms: terms, first: terms.id == place.pay[0].id, new: false)
                        } label: {
                            termsRow(terms, current: terms.id == now.id, first: terms.id == place.pay[0].id, s.currency)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Button {
                        var terms = now
                        terms.id = ShiftStore.newID()
                        terms.from = LocalTime.startOfDay(Date())
                        editing = PayEdit(terms: terms, first: false, new: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("שינוי בשכר מתאריך")
                        }
                        .foregroundStyle(.tint)
                        .settingsRow()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if now.kind == .monthly || now.bonus > 0 {
                    SettingsSection(title: "השכר עכשיו", note: nowNote(now)) {
                        if now.kind == .monthly {
                            valueRow("שעות נוספות", PayText.cover(now))
                            if now.overtimeCover == .upTo || now.overtimeCover == .none {
                                Divider()
                                valueRow("ערך שעה", Format.money(now.hourValue, s.currency))
                            }
                        }
                        if now.bonus > 0 {
                            if now.kind == .monthly { Divider() }
                            valueRow("בונוס שנתי", PayText.amount(now.bonus, s.currency) + " ב" + Format.monthName(now.bonusMonth))
                        }
                    }
                }

                SettingsSection(title: "תקופת השכר",
                                note: placeID == nil
                                    ? "החודש שבתלוש של המעסיק. לפיו מקובצות המשמרות, ונספרים השעות הנוספות והיעדים."
                                    : "החודש שבתלוש של המעסיק הזה. לפיו נספרים השעות הנוספות והיעדים שלו.") {
                    HStack {
                        Text("יום תחילת החודש")
                        Spacer()
                        Picker("יום תחילת החודש", selection: monthStartDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text(verbatim: String(day)).tag(day)
                            }
                        }
                        .labelsHidden()
                    }
                    .settingsRow()
                }

                SettingsSection(title: "שעות תקן ליום",
                                note: "השעות הרגילות של כל יום. מעבר להן נספרות שעות נוספות, והן גם היעד בטבעת של מסך עכשיו.") {
                    ForEach(0..<7, id: \.self) { day in
                        if day > 0 { Divider() }
                        standardRow(day, place)
                    }
                }

                SettingsSection(title: "שעות נוספות", note: overtimeNote(place.rules)) {
                    PercentRow(title: "שעתיים ראשונות", value: multiplier(\.overtime1Mult), range: 100...300)
                    Divider()
                    PercentRow(title: "מעבר לכך", value: multiplier(\.overtime2Mult), range: 100...300)
                    Divider()
                    Toggle("ספירה לפי יום ושבוע", isOn: rule(\.lawOvertime))
                        .settingsRow()
                    if place.rules.lawOvertime {
                        Divider()
                        NumberRow(title: "שעות בשבוע", value: rule(\.weeklyHours), unit: "שעות")
                    }
                }

                SettingsSection(title: "הפסקות, שבת ולילה",
                                note: "ההפסקה האוטומטית יורדת מכל משמרת ארוכה, אם לא נרשמה הפסקה ארוכה ממנה. משמרת לילה היא משמרת שלפחות שעתיים ממנה בין 22:00 ל־06:00. לפי החוק יום מלא בה הוא 7 שעות, ומעבר להן שעות נוספות.") {
                    MinutesRow(title: "הפסקה אוטומטית", value: rule(\.autoBreakMinutes))
                    Divider()
                    hoursRow("מעל כמה שעות", \.autoBreakAfterHours, place.rules)
                    Divider()
                    PercentRow(title: "תוספת שבת וחג", value: multiplier(\.holidayMult), range: 100...300)
                    Divider()
                    Toggle("חישוב שעות לילה", isOn: rule(\.nightEnabled))
                        .settingsRow()
                    if place.rules.nightEnabled {
                        Divider()
                        hoursRow("תחילת הלילה", \.nightStart, place.rules)
                        Divider()
                        hoursRow("סוף הלילה", \.nightEnd, place.rules)
                        Divider()
                        PercentRow(title: "תוספת לילה", value: multiplier(\.nightMult), range: 100...300)
                    }
                    Divider()
                    Toggle("משמרת לילה של 7 שעות", isOn: rule(\.nightShift))
                        .settingsRow()
                }

                SettingsSection(title: "ערב חג", note: "בערב חג וביום מקוצר, התקן הוא השעות שכאן.") {
                    hoursRow("שעות עבודה בערב חג", \.holidayEveHours, place.rules)
                }

                if now.kind == .hourly {
                    SettingsSection(title: "דמי חג", note: holidayPayNote(place)) {
                        Toggle("תשלום על ימי חג", isOn: rule(\.holidayPay))
                            .settingsRow()
                    }
                }

                SettingsSection(title: "חופשה ומחלה",
                                note: "יום חופש משלם את השעות שכאן. יום מחלה משלם חלק מהתקן של היום, לפי מספר ימי המחלה ברצף.") {
                    hoursRow("שעות ליום חופש", \.vacationHours, place.rules)
                    Divider()
                    PercentRow(title: "מחלה, יום 1", value: rule(\.sickDay1Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 2", value: rule(\.sickDay2Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 3", value: rule(\.sickDay3Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 4 והלאה", value: rule(\.sickDay4Pct), range: 0...100)
                }

                SettingsSection(title: "יתרת חופשה ומחלה", note: leaveNote(place)) {
                    Toggle("מעקב יתרות", isOn: keepsBalance)
                        .settingsRow()
                    if place.rules.balanceDate != nil {
                        Divider()
                        DatePicker("נכון לתאריך", selection: balanceDate, displayedComponents: .date)
                            .settingsRow()
                        Divider()
                        NumberRow(title: "יתרת חופשה", value: rule(\.vacationBalance), unit: "ימים")
                        Divider()
                        NumberRow(title: "יתרת מחלה", value: rule(\.sickBalance), unit: "ימים")
                        Divider()
                        NumberRow(title: "ימי חופשה בשנה", value: vacationDays, unit: "ימים")
                        // the extension order for a shortened week: a five-day week's
                        if place.startDate != nil && place.standardByDay.compactMap({ $0 }).count < 6 {
                            Divider()
                            Toggle("צו ההרחבה חל", isOn: rule(\.extensionOrder))
                                .settingsRow()
                        }
                    }
                }

                SettingsSection(title: "דמי הבראה", note: recuperationNote(place)) {
                    Toggle("חישוב דמי הבראה", isOn: rule(\.recuperationOn))
                        .settingsRow()
                    if place.rules.recuperationOn {
                        Divider()
                        NumberRow(title: "תעריף ליום", value: rule(\.recuperationRate), unit: s.currency)
                        Divider()
                        Picker("תשלום", selection: rule(\.recuperationMonthly)) {
                            Text("פעם בשנה").tag(false)
                            Text("כל חודש").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 12)
                        if !place.rules.recuperationMonthly {
                            Divider()
                            HStack {
                                Text("בחודש")
                                Spacer()
                                Picker("בחודש", selection: rule(\.recuperationMonth)) {
                                    ForEach(0..<12, id: \.self) { month in
                                        Text(Format.monthName(month)).tag(month)
                                    }
                                }
                                .labelsHidden()
                            }
                            .settingsRow()
                        }
                    }
                }

                SettingsSection(title: "פנסיה",
                                note: "העובד מפריש בדרך כלל 6%, והמעביד לפחות 6.5% ועוד 6% לפיצויים. החלק שלך יורד מהנטו המשוער, והחלק של המעביד מופיע בדף הנטו.") {
                    NumberRow(title: "הפרשת עובד", value: rule(\.pensionPercent), unit: "%")
                    Divider()
                    NumberRow(title: "הפרשת מעביד", value: rule(\.pensionEmployerPercent), unit: "%")
                    Divider()
                    NumberRow(title: "פיצויים", value: rule(\.severancePercent), unit: "%")
                }

                SettingsSection(title: "קרן השתלמות",
                                note: studyFundNote(s.currency)) {
                    NumberRow(title: "הפרשת עובד", value: rule(\.studyFundPercent), unit: "%")
                    Divider()
                    NumberRow(title: "הפרשת מעביד", value: rule(\.studyFundEmployerPercent), unit: "%")
                }

                SettingsSection(title: "נסיעות",
                                note: place.travelMonthly == nil ? "תקרה של 0 היא בלי תקרה." : "סכום קבוע בכל חודש שעבדת בו. נכנס למס, לא לפנסיה.") {
                    Picker("נסיעות", selection: travelByMonth) {
                        Text("לפי יום").tag(false)
                        Text("לחודש").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 12)
                    Divider()
                    if place.travelMonthly == nil {
                        NumberRow(title: "החזר נסיעות ליום", value: field(\.travelPerDay), unit: s.currency)
                        Divider()
                        NumberRow(title: "תקרת נסיעות חודשית", value: field(\.travelMonthlyCap), unit: s.currency)
                    } else {
                        NumberRow(title: "סכום לחודש מלא", value: travelMonthly, unit: s.currency)
                    }
                }

                SettingsSection(title: "תזכורת לפי מיקום", note: placeNote) {
                    Toggle("כשמגיעים ל" + place.name + " ויוצאים", isOn: $placeOn)
                        .settingsRow()
                    if placeOn {
                        Divider()
                        Button(action: setPlaceHere) {
                            HStack {
                                Text(placeSet ? "קבע מחדש את מקום העבודה כאן" : "קבע את מקום העבודה כאן")
                                    .foregroundStyle(.tint)
                                Spacer()
                                if placeBusy {
                                    ProgressView()
                                } else if placeSet {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .settingsRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(placeBusy)
                        Divider()
                        HStack {
                            Text("טווח")
                            Spacer()
                            Picker("טווח", selection: $placeRadius) {
                                ForEach(Self.radii, id: \.self) { meters in
                                    Text(verbatim: "\(Int(meters)) מ׳").tag(meters)
                                }
                            }
                            .labelsHidden()
                        }
                        .settingsRow()
                    }
                }

                SettingsSection(title: "סיום העבודה", note: "פיצויים, הודעה מוקדמת, פדיון ימי החופשה ודמי הבראה, לפי החוק.") {
                    NavigationLink {
                        TerminationPage(placeID: placeID)
                    } label: {
                        HStack(spacing: 8) {
                            Text("מה מגיע לי בסיום העבודה")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .settingsRow()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if placeID != nil {
                    SettingsSection(title: nil) {
                        Button(role: .destructive) {
                            deleting = true
                        } label: {
                            Text("מחיקת מקום העבודה")
                                .frame(maxWidth: .infinity)
                                .settingsRow()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, ScreenMargin.side)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(place.name)
        .sheet(item: $editing) { edit in
            PayTermsSheet(edit: edit, currency: s.currency, save: save) {
                remove(edit.terms.id)
            }
        }
        .sheet(item: $hoursEdit) { edit in
            HoursSheet(title: edit.title, hours: edit.hours) { value in
                store.updateSettings { edit.apply(&$0, value) }
            }
        }
        .alert("למחוק את מקום העבודה?", isPresented: $deleting) {
            Button("מחיקה", role: .destructive, action: deletePlace)
            Button("ביטול", role: .cancel) {}
        } message: {
            Text("המשמרות שלו יישארו, ויחושבו לפי מקום העבודה הראשון.")
        }
        .alert(message ?? "", isPresented: messageShown) {
            Button("אישור", role: .cancel) { message = nil }
        }
        .onChange(of: placeOn) { _, on in
            if on { Place.shared.askAlways() }
            Place.shared.start()
        }
        .onChange(of: placeRadius) { _, _ in
            Place.shared.start()
        }
        // a place whose work has ended is no longer watched
        .onChange(of: store.settings.place(placeID).endDate) { _, _ in
            Place.shared.start()
        }
    }

    // MARK: Rows

    /// A pay and the date it holds from, the one in effect now marked; the first holds from the start.
    private func termsRow(_ terms: PayTerms, current: Bool, first: Bool, _ currency: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PayText.summary(terms, currency))
                Text(first ? "מההתחלה" : "מ־" + Format.dateLong(terms.from) + " \(LocalTime.parts(terms.from).year)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if current {
                Text("עכשיו")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .settingsRow()
        .contentShape(Rectangle())
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .settingsRow()
    }

    /// What counting overtime by the day and the week does, at this employer's rates, as kolzchut.org.il has it.
    private func overtimeNote(_ rules: EmployerRules) -> String {
        guard rules.lawOvertime else {
            return "כל משמרת נספרת כרגע לבדה מול שעות התקן של היום. הספירה לפי יום ושבוע היא הכלל של החוק: היא מחברת את שעות היום, מוסיפה את שעות השבוע, ומחשבת שעות נוספות בשבת ובחג."
        }
        let first = Format.percent(rules.holidayMult + rules.overtime1Mult - 1)
        let second = Format.percent(rules.holidayMult + rules.overtime2Mult - 1)
        return "כל שעות היום נספרות יחד, גם בכמה משמרות, וכל שעה מעבר לשעות השבוע היא נוספת: 42 במגזר הפרטי, 40 בציבורי. שעות נוספות בשבת ובחג הן \(first) ואז \(second), ומשמרת שמתחילה בהם מסומנת לבד. הכלל לא חל על תפקידי ניהול ואמון."
    }

    /// Holiday pay's conditions, and the start date it needs.
    private func holidayPayNote(_ place: Workplace) -> String {
        let rule = "עובד לפי שעה מקבל תשלום על עד 9 ימי חג בשנה שחלים ביום עבודה, מ־3 חודשי עבודה, אם לא נעדר ביום שלפני החג ואחריו. הסכום הוא ממוצע השעות ליום ב־3 החודשים שלפני החג, בלי שעות נוספות, כפול השכר לשעה."
        return place.rules.holidayPay && place.startDate == nil ? "צריך תאריך תחילת עבודה, בראש הדף. " + rule : rule
    }

    /// The study fund's ceiling, at this year's rates.
    private func studyFundNote(_ currency: String) -> String {
        let rates = Calc.taxRates(year: LocalTime.parts(Date()).year)
        return "משכר של עד " + Format.moneyShort(rates.studyFundWage, currency) + " בחודש, התקרה הפטורה ממס ב־\(rates.year). החלק שלך יורד מהנטו המשוער."
    }

    /// What the pay now does, under it.
    private func nowNote(_ terms: PayTerms) -> String? {
        guard terms.kind == .monthly else { return nil }
        switch terms.overtimeCover {
        case .tiers: return "כל יעד שמגיעים אליו בחודש מוסיף את הבונוס שלו."
        case .upTo, .none: return "ערך שעה הוא השכר החודשי חלקי 182. לפיו מחושבות שעות נוספות שמעבר לכלולות, ב־125% וב־150%."
        case .all: return nil
        }
    }

    /// A weekday's standard hours, or a day off (SettingsView's, for this workplace).
    private func standardRow(_ day: Int, _ place: Workplace) -> some View {
        let value = place.standardByDay.indices.contains(day) ? place.standardByDay[day] : nil
        let on = Binding<Bool>(
            get: { value != nil },
            set: { working in
                change { place in
                    var days = place.standardByDay
                    while days.count < 7 { days.append(nil) }
                    if !working {
                        days[day] = nil
                    } else if days[day] == nil {
                        // a day turned on starts at the regular day's hours
                        days[day] = days.compactMap { $0 }.first ?? 8.6
                    }
                    place.standardByDay = days
                }
            }
        )
        return HStack(spacing: 12) {
            Text(Self.dayNames[day])
            Spacer()
            if let value {
                Button {
                    let id = placeID
                    hoursEdit = HoursEdit(title: Self.dayNames[day], hours: value) { settings, hours in
                        var place = settings.place(id)
                        var days = place.standardByDay
                        while days.count < 7 { days.append(nil) }
                        days[day] = hours
                        place.standardByDay = days
                        settings.setPlace(id, place)
                    }
                } label: {
                    ValueChip(text: Format.hoursToHM(value))
                }
                .buttonStyle(.plain)
            } else {
                Text("חופש")
                    .foregroundStyle(.secondary)
            }
            Toggle("יום עבודה", isOn: on)
                .labelsHidden()
        }
        .settingsRow()
    }

    /// Hours and minutes of an employer's rule, on the wheel.
    private func hoursRow(_ title: String, _ key: WritableKeyPath<EmployerRules, Double>, _ rules: EmployerRules) -> some View {
        let value = rules[keyPath: key]
        return HStack {
            Text(title)
            Spacer()
            Button {
                let id = placeID
                hoursEdit = HoursEdit(title: title, hours: value) { settings, hours in
                    var place = settings.place(id)
                    place.rules[keyPath: key] = hours
                    settings.setPlace(id, place)
                }
            } label: {
                ValueChip(text: Format.hoursToHM(value))
            }
            .buttonStyle(.plain)
        }
        .settingsRow()
    }

    // MARK: Changes

    /// The workplace changed, saved and sent to iCloud.
    private func change(_ edit: (inout Workplace) -> Void) {
        let id = placeID
        store.updateSettings { settings in
            var place = settings.place(id)
            edit(&place)
            settings.setPlace(id, place)
        }
    }

    private var name: Binding<String> {
        Binding(
            get: { store.settings.place(placeID).name },
            set: { value in
                guard store.settings.place(placeID).name != value else { return }
                change { $0.name = value }
            }
        )
    }

    private func field(_ key: WritableKeyPath<Workplace, Double>) -> Binding<Double> {
        Binding(
            get: { store.settings.place(placeID)[keyPath: key] },
            set: { value in
                guard store.settings.place(placeID)[keyPath: key] != value else { return }
                change { $0[keyPath: key] = value }
            }
        )
    }

    /// An employer's rule, saved as it changes.
    private func rule<Value: Equatable>(_ key: WritableKeyPath<EmployerRules, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings.place(placeID).rules[keyPath: key] },
            set: { value in
                guard store.settings.place(placeID).rules[keyPath: key] != value else { return }
                change { $0.rules[keyPath: key] = value }
            }
        )
    }

    /// A multiplier of the employer's as a percentage: 1.25 is 125.
    private func multiplier(_ key: WritableKeyPath<EmployerRules, Double>) -> Binding<Double> {
        Binding(
            get: { jsRound(store.settings.place(placeID).rules[keyPath: key] * 100) },
            set: { percent in
                let value = percent / 100
                guard store.settings.place(placeID).rules[keyPath: key] != value else { return }
                change { $0.rules[keyPath: key] = value }
            }
        )
    }

    /// The day work began there, a day.
    private var startDate: Binding<Date> {
        Binding(
            get: { store.settings.place(placeID).startDate ?? LocalTime.startOfDay(Date()) },
            set: { date in
                let day = LocalTime.startOfDay(date)
                guard store.settings.place(placeID).startDate != day else { return }
                change { $0.startDate = day }
            }
        )
    }

    /// Whether the work there has ended: from today, until its own last day is picked.
    private var hasEnded: Binding<Bool> {
        Binding(
            get: { store.settings.place(placeID).endDate != nil },
            set: { on in
                guard on != (store.settings.place(placeID).endDate != nil) else { return }
                change { $0.endDate = on ? LocalTime.startOfDay(Date()) : nil }
            }
        )
    }

    /// The last day of work there, a day.
    private var endDate: Binding<Date> {
        Binding(
            get: { store.settings.place(placeID).endDate ?? LocalTime.startOfDay(Date()) },
            set: { date in
                let day = LocalTime.startOfDay(date)
                guard store.settings.place(placeID).endDate != day else { return }
                change { $0.endDate = day }
            }
        )
    }

    /// The vacation days a year: its own number, or the law's by the seniority when more.
    private var vacationDays: Binding<Double> {
        Binding(
            get: { Calc.vacationDaysPerYear(store.settings, at: placeID, on: Date()) },
            set: { value in
                guard store.settings.place(placeID).rules.vacationDaysPerYear != value else { return }
                change { $0.rules.vacationDaysPerYear = value }
            }
        )
    }

    /// The seniority, up to the last day when it is set, and what it decides; and what the last day stops.
    private func seniorityNote(_ place: Workplace) -> String {
        let ended = place.endDate == nil ? ""
            : " אחרי היום האחרון לא נספרים כאן שכר חודשי, בונוס, הבראה וצבירת חופשה, והמקום לא מוצע למשמרת הבאה."
        guard let start = place.startDate else { return "לפי התאריך נקבעים הוותק, ימי החופשה בשנה ודמי ההבראה." + ended }
        let worked = Calc.seniority(from: start, to: place.until.map { min(Date(), $0) } ?? Date())
        return Format.seniority(years: worked.years, months: worked.months) + ". לפיו נקבעים ימי החופשה בשנה ודמי ההבראה." + ended
    }

    /// The days off left, and the vacation days a year by the seniority.
    private func leaveNote(_ place: Workplace) -> String {
        let kept = "היתרות והתאריך מהתלוש האחרון של המעסיק הזה. מאז, בכל חודש נוסף חלק מימי החופשה של השנה ו-1.5 ימי מחלה (עד 90), ויורדים ימי החופשה והמחלה שרשמת כאן."
        guard let start = place.startDate, let legal = Calc.legalVacationDays(store.settings, at: placeID, on: Date()) else {
            return kept + " עם תאריך תחילת עבודה, ימי החופשה בשנה נקבעים לפי הוותק."
        }
        let year = max(1, LocalTime.parts(Date()).year - LocalTime.parts(start).year + 1)
        let by = place.standardByDay.compactMap { $0 }.count >= 6 ? "לפי החוק, בשבוע של 6 ימים"
            : place.rules.extensionOrder ? "לפי צו ההרחבה. הצו חל על רוב מקומות העבודה עם שבוע של 5 ימים, לא על מקום עם פחות מ־4 עובדים, חברות ממשלתיות ועירוניות ומשק בית"
            : "לפי החוק, בשבוע של 5 ימים"
        return kept + " בשנה \(year) לעבודה מגיעים לפחות \(Int(legal)) ימי חופשה \(by). אם המעסיק נותן יותר, אפשר לרשום."
    }

    /// The recuperation pay's days by the seniority, and the job's share.
    private func recuperationNote(_ place: Workplace) -> String {
        guard let start = place.startDate else {
            return "צריך תאריך תחילת עבודה, בראש הדף: 5 ימים בשנה אחרי שנת העבודה הראשונה, ועד 10 מהשנה ה־20."
        }
        let years = Calc.seniority(from: start, to: Date()).years
        let days = years < 1 ? "מגיעים אחרי שנת עבודה" : "\(Int(Calc.recuperationDays(year: years))) ימים בשנה לפי הוותק"
        let share = Int(jsRound(Calc.jobShare(place) * 100))
        return days + ", בהיקף משרה של \(share)% לפי שעות התקן. התעריף במגזר הפרטי ב־2026 הוא " + PayText.amount(451.5, store.settings.currency) + "."
    }

    /// Travel by the day, or a fixed sum a month.
    private var travelByMonth: Binding<Bool> {
        Binding(
            get: { store.settings.place(placeID).travelMonthly != nil },
            set: { monthly in
                guard monthly != (store.settings.place(placeID).travelMonthly != nil) else { return }
                change { $0.travelMonthly = monthly ? 0 : nil }
            }
        )
    }

    /// The month's sum of travel.
    private var travelMonthly: Binding<Double> {
        Binding(
            get: { store.settings.place(placeID).travelMonthly ?? 0 },
            set: { value in
                guard store.settings.place(placeID).travelMonthly != value else { return }
                change { $0.travelMonthly = value }
            }
        )
    }

    /// The day its pay month starts; the own workplace's is the app's pay period.
    private var monthStartDay: Binding<Int> {
        Binding(
            get: { store.settings.monthStartDay(of: placeID) },
            set: { day in
                guard store.settings.monthStartDay(of: placeID) != day else { return }
                change { $0.monthStartDay = day }
            }
        )
    }

    /// Whether the days off left are kept: from today's payslip, until its own date is picked.
    private var keepsBalance: Binding<Bool> {
        Binding(
            get: { store.settings.place(placeID).rules.balanceDate != nil },
            set: { on in
                guard on != (store.settings.place(placeID).rules.balanceDate != nil) else { return }
                change { $0.rules.balanceDate = on ? LocalTime.startOfDay(Date()) : nil }
            }
        )
    }

    /// The payslip's date, a day.
    private var balanceDate: Binding<Date> {
        Binding(
            get: { store.settings.place(placeID).rules.balanceDate ?? LocalTime.startOfDay(Date()) },
            set: { date in
                let day = LocalTime.startOfDay(date)
                guard store.settings.place(placeID).rules.balanceDate != day else { return }
                change { $0.rules.balanceDate = day }
            }
        )
    }

    private var messageShown: Binding<Bool> {
        Binding(get: { message != nil }, set: { shown in
            if !shown { message = nil }
        })
    }

    /// A pay saved from its sheet: changed in place, or added at its date.
    private func save(_ terms: PayTerms) {
        change { place in
            if let i = place.pay.firstIndex(where: { $0.id == terms.id }) {
                place.pay[i] = terms
            } else {
                place.pay.append(terms)
            }
        }
    }

    /// A change of the pay taken back: the shifts from its date are paid by the one before it again.
    private func remove(_ id: String) {
        change { place in
            guard place.pay.count > 1, place.pay.first?.id != id else { return }
            place.pay.removeAll { $0.id == id }
        }
    }

    private func deletePlace() {
        guard let placeID else { return }
        store.updateSettings { $0.workplaces.removeAll { $0.id == placeID } }
        if store.nextWorkplace == nil { store.chooseNextWorkplace(nil) }
        UserDefaults.standard.set(false, forKey: Place.key(Place.enabledKey, placeID))
        Place.shared.start()
        dismiss()
    }

    // MARK: The place

    /// What the place's reminder does, and what it still needs.
    private var placeNote: String {
        guard placeOn else {
            return "האייפון ישאל אם להתחיל משמרת כשמגיעים לעבודה, ואם לסיים כשיוצאים, גם כשהאפליקציה סגורה. מקום העבודה נשמר רק באייפון הזה."
        }
        if !placeSet { return "עמוד במקום העבודה ולחץ על הכפתור." }
        if !Place.shared.always {
            return "כדי שזה יעבוד גם כשהאפליקציה סגורה, צריך לאפשר מיקום תמיד: בהגדרות האייפון, Shifty, מיקום."
        }
        return "מקום העבודה נקבע. ההתראות יגיעו גם כשהאפליקציה סגורה."
    }

    private func setPlaceHere() {
        placeBusy = true
        let id = placeID
        Place.shared.setHere(id) { found in
            Task { @MainActor in
                placeBusy = false
                placeSet = Place.coordinate(id) != nil
                if !found { message = "לא הצלחתי למצוא את המיקום. בדוק שהמיקום מאופשר ל-Shifty." }
            }
        }
    }
}

/// A pay being changed or added, on its sheet.
struct PayEdit: Identifiable {
    let id = UUID()
    let terms: PayTerms
    /// The workplace's first pay: it has no date, and stays.
    let first: Bool
    let new: Bool
}

/// A pay from a date, on a sheet: its date (the first has none), by the hour or global, its amount, what a global
/// pay does with the overtime (covers all of it, some hours, none, or pays a bonus at each target of hours), and an
/// annual bonus with its month.
struct PayTermsSheet: View {
    let edit: PayEdit
    let currency: String
    let save: (PayTerms) -> Void
    let remove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var terms: PayTerms

    /// What a global pay does with the overtime, each with its line.
    private struct Cover: Identifiable {
        let cover: OvertimeCover
        let title: String
        let line: String
        var id: OvertimeCover { cover }
    }

    private static let covers = [
        Cover(cover: .all, title: "כלולות בשכר", line: "השכר מכסה את כל השעות הנוספות."),
        Cover(cover: .upTo, title: "כלולות עד מספר שעות", line: "שעות מעבר לכך משולמות לפי ערך שעה."),
        Cover(cover: .none, title: "משולמות כולן", line: "כל שעה נוספת משולמת לפי ערך שעה."),
        Cover(cover: .tiers, title: "בונוס ביעד", line: "סכום קבוע כשמגיעים למספר שעות בחודש. שעות שלא הגיעו ליעד לא משולמות."),
    ]

    init(edit: PayEdit, currency: String, save: @escaping (PayTerms) -> Void, remove: @escaping () -> Void) {
        self.edit = edit
        self.currency = currency
        self.save = save
        self.remove = remove
        _terms = State(initialValue: edit.terms)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsSection(title: nil) {
                        if !edit.first {
                            DatePicker("מתאריך", selection: $terms.from, displayedComponents: .date)
                                .settingsRow()
                            Divider()
                        }
                        Picker("סוג השכר", selection: $terms.kind) {
                            Text("לפי שעה").tag(PayKind.hourly)
                            Text("גלובלי").tag(PayKind.monthly)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 12)
                        Divider()
                        if terms.kind == .hourly {
                            NumberRow(title: "שכר לשעה", value: $terms.hourlyWage, unit: currency)
                        } else {
                            NumberRow(title: "שכר חודשי", value: $terms.monthlySalary, unit: currency)
                        }
                    }

                    if terms.kind == .monthly {
                        // one of four, then the hours it covers or its targets; the note under the last card
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsSection(title: "שעות נוספות", note: hasDetail ? nil : coverNote) {
                                ForEach(Self.covers) { choice in
                                    if choice.cover != Self.covers[0].cover { Divider() }
                                    Button {
                                        choose(choice.cover)
                                    } label: {
                                        coverRow(choice)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if terms.overtimeCover == .upTo {
                                SettingsSection(title: nil, note: coverNote) {
                                    NumberRow(title: "עד", value: $terms.overtimeHours, unit: "שעות בחודש")
                                }
                            } else if terms.overtimeCover == .tiers {
                                SettingsSection(title: nil, note: coverNote) {
                                    ForEach(terms.overtimeTiers.indices, id: \.self) { i in
                                        if i > 0 { Divider() }
                                        TierRow(hours: tier(i, \.hours), amount: tier(i, \.amount), currency: currency)
                                    }
                                    if !terms.overtimeTiers.isEmpty { Divider() }
                                    Button {
                                        let last = terms.overtimeTiers.last?.hours ?? 0
                                        terms.overtimeTiers.append(OvertimeTier(hours: last + 20, amount: 0))
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus")
                                            Text("הוספת יעד")
                                        }
                                        .foregroundStyle(.tint)
                                        .settingsRow()
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if terms.overtimeTiers.count > 1 {
                                        Divider()
                                        Button {
                                            terms.overtimeTiers.removeLast()
                                        } label: {
                                            Text("הסרת היעד האחרון")
                                                .foregroundStyle(.red)
                                                .settingsRow()
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    SettingsSection(title: "בונוס שנתי",
                                    note: "סכום קבוע שמגיע פעם בשנה, עם השכר של החודש שבחרת. הוא נכנס להכנסה ולנטו המשוער של אותו חודש.") {
                        NumberRow(title: "סכום", value: $terms.bonus, unit: currency)
                        if terms.bonus > 0 {
                            Divider()
                            HStack {
                                Text("בחודש")
                                Spacer()
                                Picker("בחודש", selection: $terms.bonusMonth) {
                                    ForEach(0..<12, id: \.self) { month in
                                        Text(Format.monthName(month)).tag(month)
                                    }
                                }
                                .labelsHidden()
                            }
                            .settingsRow()
                        }
                    }

                    if !edit.first && !edit.new {
                        SettingsSection(title: nil) {
                            Button(role: .destructive) {
                                remove()
                                dismiss()
                            } label: {
                                Text("מחיקת השינוי")
                                    .frame(maxWidth: .infinity)
                                    .settingsRow()
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(edit.first ? "השכר" : "שינוי בשכר")
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
                        var saved = terms
                        if !edit.first { saved.from = LocalTime.startOfDay(saved.from) }
                        saved.overtimeTiers.sort { $0.hours < $1.hours }
                        save(saved)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("שמירה")
                }
            }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
    }

    /// A choice of what the pay does with the overtime, checked when it is the pay's.
    private func coverRow(_ choice: Cover) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.title)
                Text(choice.line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if terms.overtimeCover == choice.cover {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 8)
        .settingsRow()
        .contentShape(Rectangle())
    }

    /// A bonus at targets starts with one, of 20 hours.
    private func choose(_ cover: OvertimeCover) {
        terms.overtimeCover = cover
        if cover == .tiers && terms.overtimeTiers.isEmpty {
            terms.overtimeTiers = [OvertimeTier(hours: 20, amount: 0)]
        }
    }

    /// A target's hours or bonus, while it is there.
    private func tier(_ i: Int, _ key: WritableKeyPath<OvertimeTier, Double>) -> Binding<Double> {
        Binding(
            get: { i < terms.overtimeTiers.count ? terms.overtimeTiers[i][keyPath: key] : 0 },
            set: { value in
                if i < terms.overtimeTiers.count { terms.overtimeTiers[i][keyPath: key] = value }
            }
        )
    }

    /// The hours it covers or its targets, in a card of their own.
    private var hasDetail: Bool {
        terms.overtimeCover == .upTo || terms.overtimeCover == .tiers
    }

    private var coverNote: String {
        switch terms.overtimeCover {
        case .all: "השעון ימשיך לספור את השעות הנוספות."
        case .upTo, .none: "ערך שעה הוא השכר החודשי חלקי 182, ב־125% וב־150%."
        case .tiers: "כל יעד שמגיעים אליו בחודש מוסיף את הבונוס שלו להכנסה ולנטו. השעון מראה כמה נשאר ליעד הבא."
        }
    }
}

/// A target of overtime hours a month and its bonus, in a row: "ביעד של 20 שעות", and the amount.
private struct TierRow: View {
    @Binding var hours: Double
    @Binding var amount: Double
    let currency: String

    var body: some View {
        HStack(spacing: 8) {
            Text("ביעד של")
            NumberField(value: $hours, width: 56)
            Text("שעות")
            Spacer()
            NumberField(value: $amount)
            Text(currency)
                .foregroundStyle(.secondary)
        }
        .settingsRow()
    }
}

/// How a pay is said: "₪ 54 לשעה", "₪ 12,000 לחודש · גלובלי", and what a global one does with the overtime.
enum PayText {
    static func summary(_ terms: PayTerms, _ currency: String) -> String {
        terms.kind == .monthly ? amount(terms.monthlySalary, currency) + " לחודש · גלובלי" : amount(terms.hourlyWage, currency) + " לשעה"
    }

    /// A whole amount without its agorot: "₪ 12,000", "₪ 54.50".
    static func amount(_ value: Double, _ currency: String) -> String {
        value == value.rounded() ? Format.moneyShort(value, currency) : Format.money(value, currency)
    }

    /// "כלולות בשכר", "עד 30 שעות בחודש", "משולמות כולן", "בונוס ב־20 וב־40 שעות".
    static func cover(_ terms: PayTerms) -> String {
        switch terms.overtimeCover {
        case .all: "כלולות בשכר"
        case .upTo: "עד " + hours(terms.overtimeHours) + " בחודש"
        case .none: "משולמות כולן"
        case .tiers: terms.overtimeTiers.isEmpty ? "בונוס ביעד"
            : "בונוס ב־" + terms.overtimeTiers.map { number($0.hours) }.joined(separator: " וב־") + " שעות"
        }
    }

    /// "30 שעות", "12:30 שעות".
    static func hours(_ value: Double) -> String {
        number(value) + " שעות"
    }

    /// "30", "12:30".
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : Format.hoursToHM(value)
    }
}
