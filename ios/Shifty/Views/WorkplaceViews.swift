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
        SettingsSection(title: "מקומות עבודה") {
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

    /// Another workplace, by the hour at the own one's wage and with its standard hours, on its page; with Shifty
    /// Pro.
    private func add() {
        guard pro.unlocked else {
            pro.offer()
            return
        }
        let id = ShiftStore.newID()
        let own = store.settings
        let place = Workplace(id: id, name: "מקום עבודה \(own.workplaces.count + 2)",
                              pay: [PayTerms(id: id + "-pay", from: PayTerms.start, hourlyWage: own.hourlyWage)],
                              standardByDay: own.standardByDay)
        store.updateSettings { $0.workplaces.append(place) }
        added = id
    }
}

/// A workplace's page: its name, its pay from each date, the newest first (a sheet changes one or adds one from a
/// date), its pay now when it is global or has a bonus, its standard hours and its travel; another workplace can be
/// deleted, its shifts then counted as the own one's.
struct WorkplacePage: View {
    /// nil for the settings' own workplace.
    let placeID: String?
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PayEdit?
    @State private var hoursEdit: HoursEdit?
    @State private var deleting = false

    private static let dayNames = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]

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
                    SettingsSection(title: "השכר עכשיו",
                                    note: now.kind == .monthly ? "ערך שעה הוא השכר החודשי חלקי 182. לפיו מחושבות שעות נוספות שמעבר לכלולות, ב־125% וב־150%." : nil) {
                        if now.kind == .monthly {
                            valueRow("שעות נוספות כלולות", PayText.cover(now))
                            Divider()
                            valueRow("ערך שעה", Format.money(now.hourValue, s.currency))
                        }
                        if now.bonus > 0 {
                            if now.kind == .monthly { Divider() }
                            valueRow("בונוס שנתי", PayText.amount(now.bonus, s.currency) + " ב" + Format.monthName(now.bonusMonth))
                        }
                    }
                }

                SettingsSection(title: "שעות תקן ליום",
                                note: "השעות הרגילות של כל יום. מעבר להן נספרות שעות נוספות, והן גם היעד בטבעת של מסך עכשיו.") {
                    ForEach(0..<7, id: \.self) { day in
                        if day > 0 { Divider() }
                        standardRow(day, place)
                    }
                }

                SettingsSection(title: "נסיעות", note: "תקרה של 0 היא בלי תקרה.") {
                    NumberRow(title: "החזר נסיעות ליום", value: field(\.travelPerDay), unit: s.currency)
                    Divider()
                    NumberRow(title: "תקרת נסיעות חודשית", value: field(\.travelMonthlyCap), unit: s.currency)
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
        dismiss()
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
/// pay covers of the overtime, and an annual bonus with its month.
struct PayTermsSheet: View {
    let edit: PayEdit
    let currency: String
    let save: (PayTerms) -> Void
    let remove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var terms: PayTerms

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
                        SettingsSection(title: "שעות נוספות כלולות בשכר", note: coverNote) {
                            Picker("שעות נוספות כלולות", selection: $terms.overtimeCover) {
                                Text("כולן").tag(OvertimeCover.all)
                                Text("עד מספר שעות").tag(OvertimeCover.upTo)
                                Text("אף אחת").tag(OvertimeCover.none)
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 12)
                            if terms.overtimeCover == .upTo {
                                Divider()
                                NumberRow(title: "עד", value: $terms.overtimeHours, unit: "שעות בחודש")
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

    private var coverNote: String {
        switch terms.overtimeCover {
        case .all: "השכר כולל את כל השעות הנוספות. השעון ימשיך לספור אותן."
        case .upTo: "שעות נוספות שמעבר לכלולות מתווספות לשכר, לפי ערך שעה: השכר החודשי חלקי 182."
        case .none: "כל שעה נוספת מתווספת לשכר, לפי ערך שעה: השכר החודשי חלקי 182."
        }
    }
}

/// How a pay is said: "₪ 54 לשעה", "₪ 12,000 לחודש · גלובלי", and what a global one covers.
enum PayText {
    static func summary(_ terms: PayTerms, _ currency: String) -> String {
        terms.kind == .monthly ? amount(terms.monthlySalary, currency) + " לחודש · גלובלי" : amount(terms.hourlyWage, currency) + " לשעה"
    }

    /// A whole amount without its agorot: "₪ 12,000", "₪ 54.50".
    static func amount(_ value: Double, _ currency: String) -> String {
        value == value.rounded() ? Format.moneyShort(value, currency) : Format.money(value, currency)
    }

    static func cover(_ terms: PayTerms) -> String {
        switch terms.overtimeCover {
        case .all: "כולן"
        case .upTo: "עד " + hours(terms.overtimeHours) + " בחודש"
        case .none: "אף אחת"
        }
    }

    /// "30 שעות", "12:30 שעות".
    static func hours(_ value: Double) -> String {
        (value == value.rounded() ? String(Int(value)) : Format.hoursToHM(value)) + " שעות"
    }
}
