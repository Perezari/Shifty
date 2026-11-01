import SwiftUI

/// The workplaces at the top of the settings: each a row with its pay now, opening its page (WorkplacePage); and
/// another one, with Shifty Pro. Designed in ios/preview first.
struct WorkplacesSection: View {
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
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
                    if !pro.unlocked {
                        ProBadge()
                    }
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
                Text(PayText.summary(Settings.terms(place.pay, at: Date()) ?? place.pay[0], s.currency))
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
    /// page; with Shifty Pro.
    private func add() {
        guard pro.unlocked else {
            pro.offer()
            return
        }
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
/// pension and travel; and the reminder of its place. Another workplace can be deleted, its shifts then counted as
/// the own one's.
struct WorkplacePage: View {
    /// nil for the settings' own workplace.
    let placeID: String?
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
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

                SettingsSection(title: "שעות נוספות") {
                    PercentRow(title: "שעתיים ראשונות", value: multiplier(\.overtime1Mult), range: 100...300)
                    Divider()
                    PercentRow(title: "מעבר לכך", value: multiplier(\.overtime2Mult), range: 100...300)
                }

                SettingsSection(title: "הפסקות, שבת ולילה",
                                note: "ההפסקה האוטומטית יורדת מכל משמרת ארוכה, אם לא נרשמה הפסקה ארוכה ממנה.") {
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
                }

                SettingsSection(title: "ערב חג", note: "בערב חג וביום מקוצר, התקן הוא השעות שכאן.") {
                    hoursRow("שעות עבודה בערב חג", \.holidayEveHours, place.rules)
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

                SettingsSection(title: "יתרת חופשה ומחלה",
                                note: "היתרות והתאריך מהתלוש האחרון של המעסיק הזה. מאז, בכל חודש נוסף חלק מימי החופשה של השנה ו-1.5 ימי מחלה (עד 90), ויורדים ימי החופשה והמחלה שרשמת כאן. לפי החוק, בשבוע עבודה של 5 ימים יש 12 ימי חופשה בשנה בחמש השנים הראשונות.",
                                pro: true) {
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
                        NumberRow(title: "ימי חופשה בשנה", value: rule(\.vacationDaysPerYear), unit: "ימים")
                    }
                }

                SettingsSection(title: "פנסיה", note: "העובד מפריש לפנסיה בדרך כלל 6%. היא יורדת מהנטו המשוער.") {
                    NumberRow(title: "הפרשה לפנסיה", value: rule(\.pensionPercent), unit: "%")
                }

                SettingsSection(title: "נסיעות", note: "תקרה של 0 היא בלי תקרה.") {
                    NumberRow(title: "החזר נסיעות ליום", value: field(\.travelPerDay), unit: s.currency)
                    Divider()
                    NumberRow(title: "תקרת נסיעות חודשית", value: field(\.travelMonthlyCap), unit: s.currency)
                }

                SettingsSection(title: "תזכורת לפי מיקום", note: placeNote, pro: true) {
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
            .padding(.horizontal, 16)
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
        guard placeOn && pro.unlocked else {
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
