import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// The settings (app.js renderSettings): the wage and the workplace, each weekday's standard hours, the
/// holidays, vacation and sick days and the days left of them, overtime, breaks, Shabbat and night, travel
/// and the pay period, the net pay's estimate, the look, the notifications, the lock, iCloud and the
/// backup. Each change is saved as it is made, and goes to iCloud.
struct SettingsView: View {
    @Environment(ShiftStore.self) private var store
    @AppStorage(AppLock.key) private var lockOn = false
    @AppStorage(Alerts.key) private var alerts = true
    @AppStorage(Alerts.breakKey) private var breakReminder = true
    @AppStorage(Alerts.summaryKey) private var periodSummary = true
    @AppStorage(Place.enabledKey) private var placeOn = false
    @AppStorage(Place.radiusKey) private var placeRadius = 150.0
    @AppStorage(CardLook.key) private var glassCards = false
    @AppStorage(Perf.key) private var measuring = false
    @State private var placeSet = Place.coordinate != nil
    @State private var placeBusy = false
    @State private var hoursEdit: HoursEdit?
    @State private var exporting = false
    @State private var backup = BackupFile(data: Data())
    @State private var importing = false
    @State private var restoring: Data?
    @State private var message: String?
    /// The lock's switch, which follows `lockOn` once Face ID or the passcode agrees.
    @State private var lockSwitch = false
    @State private var lockProblem = false

    private static let dayNames = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
    /// How far around the workplace counts as there, in meters.
    private static let radii: [Double] = [100, 150, 250, 400]

    var body: some View {
        let s = store.settings
        let _ = Perf.drew("הגדרות")
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: "שכר ומקום עבודה") {
                    TextRow(title: "שם מקום העבודה", text: setting(\.workplaceName), fallback: Settings().workplaceName)
                    Divider()
                    NumberRow(title: "שכר לשעה", value: setting(\.hourlyWage), unit: s.currency)
                }

                SettingsSection(title: "שעות תקן ליום",
                                note: "השעות הרגילות של כל יום. מעבר להן נספרות שעות נוספות, והן גם היעד בטבעת של מסך עכשיו.") {
                    ForEach(0..<7, id: \.self) { day in
                        if day > 0 { Divider() }
                        standardRow(day, s)
                    }
                }

                SettingsSection(title: "חגי ישראל",
                                note: "חגים, ערבי חג ויום הזיכרון מזוהים לבד, בכל שנה. בערב חג וביום מקוצר התקן הוא השעות שכאן.") {
                    Toggle("זיהוי חגים אוטומטי", isOn: setting(\.holidaysEnabled))
                        .settingsRow()
                    Divider()
                    hoursRow("שעות עבודה בערב חג", \.holidayEveHours, s)
                }

                SettingsSection(title: "חופשה ומחלה",
                                note: "יום חופש משלם את השעות שכאן. יום מחלה משלם חלק מהתקן של היום, לפי מספר ימי המחלה ברצף.") {
                    hoursRow("שעות ליום חופש", \.vacationHours, s)
                    Divider()
                    PercentRow(title: "מחלה, יום 1", value: setting(\.sickDay1Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 2", value: setting(\.sickDay2Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 3", value: setting(\.sickDay3Pct), range: 0...100)
                    Divider()
                    PercentRow(title: "מחלה, יום 4 והלאה", value: setting(\.sickDay4Pct), range: 0...100)
                }

                SettingsSection(title: "יתרת חופשה ומחלה",
                                note: "היתרות והתאריך מהתלוש האחרון. מאז, בכל חודש נוסף חלק מימי החופשה של השנה ו-1.5 ימי מחלה (עד 90), ויורדים ימי החופשה והמחלה שרשמת. לפי החוק, בשבוע עבודה של 5 ימים יש 12 ימי חופשה בשנה בחמש השנים הראשונות.") {
                    Toggle("מעקב יתרות", isOn: keepsBalance)
                        .settingsRow()
                    if s.balanceDate != nil {
                        Divider()
                        DatePicker("נכון לתאריך", selection: balanceDate, displayedComponents: .date)
                            .settingsRow()
                        Divider()
                        NumberRow(title: "יתרת חופשה", value: setting(\.vacationBalance), unit: "ימים")
                        Divider()
                        NumberRow(title: "יתרת מחלה", value: setting(\.sickBalance), unit: "ימים")
                        Divider()
                        NumberRow(title: "ימי חופשה בשנה", value: setting(\.vacationDaysPerYear), unit: "ימים")
                    }
                }

                SettingsSection(title: "שעות נוספות") {
                    PercentRow(title: "שעתיים ראשונות", value: multiplier(\.overtime1Mult), range: 100...300)
                    Divider()
                    PercentRow(title: "מעבר לכך", value: multiplier(\.overtime2Mult), range: 100...300)
                }

                SettingsSection(title: "הפסקות, שבת ולילה",
                                note: "ההפסקה האוטומטית יורדת מכל משמרת ארוכה, אם לא נרשמה הפסקה ארוכה ממנה.") {
                    MinutesRow(title: "הפסקה אוטומטית", value: setting(\.autoBreakMinutes))
                    Divider()
                    hoursRow("מעל כמה שעות", \.autoBreakAfterHours, s)
                    Divider()
                    PercentRow(title: "תוספת שבת וחג", value: multiplier(\.holidayMult), range: 100...300)
                    Divider()
                    Toggle("חישוב שעות לילה", isOn: setting(\.nightEnabled))
                        .settingsRow()
                    if s.nightEnabled {
                        Divider()
                        hoursRow("תחילת הלילה", \.nightStart, s)
                        Divider()
                        hoursRow("סוף הלילה", \.nightEnd, s)
                        Divider()
                        PercentRow(title: "תוספת לילה", value: multiplier(\.nightMult), range: 100...300)
                    }
                }

                SettingsSection(title: "נסיעות ותקופה",
                                note: "תקרה של 0 היא בלי תקרה, ויעד של 0 הוא בלי יעד. התקופה מתחילה ביום שבחרת בכל חודש.") {
                    NumberRow(title: "החזר נסיעות ליום", value: setting(\.travelPerDay), unit: s.currency)
                    Divider()
                    NumberRow(title: "תקרת נסיעות חודשית", value: setting(\.travelMonthlyCap), unit: s.currency)
                    Divider()
                    HStack {
                        Text("יום תחילת החודש")
                        Spacer()
                        Picker("יום תחילת החודש", selection: setting(\.monthStartDay)) {
                            ForEach(1...28, id: \.self) { day in
                                Text(verbatim: String(day)).tag(day)
                            }
                        }
                        .labelsHidden()
                    }
                    .settingsRow()
                    Divider()
                    NumberRow(title: "יעד הכנסה חודשי", value: setting(\.monthlyIncomeGoal), unit: s.currency)
                }

                SettingsSection(title: "נטו משוער",
                                note: "לכל תושב 2.25 נקודות זיכוי, ולאישה 2.75. העובד מפריש לפנסיה בדרך כלל 6%. החישוב לפי מדרגות המס, ביטוח לאומי ומס בריאות של 2026, ולכן התלוש יכול להיות שונה מעט.") {
                    NumberRow(title: "נקודות זיכוי", value: setting(\.creditPoints), unit: "נק׳")
                    Divider()
                    NumberRow(title: "הפרשה לפנסיה", value: setting(\.pensionPercent), unit: "%")
                }

                SettingsSection(title: "תצוגה",
                                note: "כרטיסי זכוכית כבדים יותר לציור. מדידת המהירות מראה בראש המסך, בכל שנייה, כמה פריימים הוצגו, כמה מהם איטיים, וכמה פעמים כל מסך צויר מחדש.") {
                    Picker("מראה", selection: setting(\.theme)) {
                        Text("כמו באייפון").tag("system")
                        Text("בהיר").tag("light")
                        Text("כהה").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 12)
                    Divider()
                    Toggle("כרטיסי זכוכית", isOn: $glassCards)
                        .settingsRow()
                    Divider()
                    Toggle("מדידת מהירות", isOn: $measuring)
                        .settingsRow()
                }

                SettingsSection(title: "מסך הנעילה והתראות",
                                note: "המשמרת שרצה מופיעה במסך הנעילה וב-Dynamic Island, עם כפתורים להפסקה ולסיום. ההתראות: כשמגיעים ליעד היומי, כשמתחילות השעות הנוספות של 150%, אחרי 6 שעות ברצף בלי הפסקה, ואחרי 12 שעות של משמרת פתוחה. הסיכום מגיע בבוקר שאחרי סוף התקופה.") {
                    Toggle("התראות על המשמרת", isOn: $alerts)
                        .settingsRow()
                    Divider()
                    Toggle("תזכורת להפסקה אחרי 6 שעות", isOn: $breakReminder)
                        .settingsRow()
                        .disabled(!alerts)
                    Divider()
                    Toggle("סיכום בסוף כל תקופה", isOn: $periodSummary)
                        .settingsRow()
                }

                SettingsSection(title: "תזכורת לפי מיקום", note: placeNote) {
                    Toggle("כשמגיעים לעבודה ויוצאים ממנה", isOn: $placeOn)
                        .settingsRow()
                    if placeOn {
                        Divider()
                        Button(action: setPlaceHere) {
                            HStack {
                                Text(placeButton)
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

                SettingsSection(title: "נעילה",
                                note: "Shifty ננעלת בפתיחה ואחרי דקה ברקע, ונפתחת ב-\(AppLock.biometryName) או בקוד של האייפון. הנעילה היא של האייפון הזה בלבד.") {
                    Toggle("נעילה עם \(AppLock.biometryName)", isOn: $lockSwitch)
                        .settingsRow()
                }

                SettingsSection(title: "iCloud", note: cloudNote) {
                    HStack {
                        Text("גיבוי ב-iCloud")
                        Spacer()
                        Text(cloudStatus)
                            .foregroundStyle(.secondary)
                    }
                    .settingsRow()
                }

                SettingsSection(title: "גיבוי לקובץ", note: "גם קובץ גיבוי של האתר משוחזר כאן.") {
                    // the exporter and the importer each on a view of its own: on one view, one of them
                    // may never show
                    Button(action: export) { actionRow("ייצוא לקובץ") }
                        .buttonStyle(.plain)
                        .fileExporter(isPresented: $exporting, document: backup, contentType: .json,
                                      defaultFilename: "shifty-backup-\(Self.stamp())") { result in
                            if case .failure = result { message = "הגיבוי לא נשמר." }
                        }
                    Divider()
                    Button {
                        importing = true
                    } label: {
                        actionRow("שחזור מגיבוי")
                    }
                    .buttonStyle(.plain)
                    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                        read(result)
                    }
                }

                Text("Shifty · גרסה \(AppInfo.version)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("הגדרות")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("סיום", action: hideKeyboard)
            }
        }
        .sheet(item: $hoursEdit) { edit in
            HoursSheet(title: edit.title, hours: edit.hours) { value in
                store.updateSettings { edit.apply(&$0, value) }
            }
        }
        .alert("לשחזר מהגיבוי?", isPresented: restoringShown) {
            Button("שחזור", role: .destructive, action: restore)
            Button("ביטול", role: .cancel) { restoring = nil }
        } message: {
            Text("כל המשמרות וההגדרות כאן, וב-iCloud, יוחלפו במה שבקובץ.")
        }
        .alert(message ?? "", isPresented: messageShown) {
            Button("אישור", role: .cancel) { message = nil }
        }
        .alert("אין קוד באייפון", isPresented: $lockProblem) {
            Button("אישור", role: .cancel) {}
        } message: {
            Text("כדי לנעול את Shifty צריך להגדיר קוד לאייפון, בהגדרות של האייפון.")
        }
        .onChange(of: alerts) { _, _ in
            LiveShift.refresh(store)
        }
        .onChange(of: breakReminder) { _, _ in
            LiveShift.refresh(store)
        }
        .onChange(of: periodSummary) { _, _ in
            LiveShift.refresh(store)
        }
        .onChange(of: placeOn) { _, on in
            if on { Place.shared.askAlways() }
            Place.shared.start()
        }
        .onChange(of: placeRadius) { _, _ in
            Place.shared.start()
        }
        .onAppear { lockSwitch = lockOn }
        .onChange(of: lockSwitch) { _, on in
            guard on != lockOn else { return }
            Task { await setLock(on) }
        }
    }

    // MARK: Rows

    /// A weekday's standard hours, or a day off (app.js dayHoursRow).
    private func standardRow(_ day: Int, _ s: Settings) -> some View {
        let value = s.standard(onWeekday: day)
        let on = Binding<Bool>(
            get: { store.settings.standard(onWeekday: day) != nil },
            set: { working in
                store.updateSettings { settings in
                    var days = settings.standardByDay
                    while days.count < 7 { days.append(nil) }
                    if !working {
                        days[day] = nil
                    } else if days[day] == nil {
                        // a day turned on starts at the regular day's hours
                        let regular = settings.regularDailyHours
                        days[day] = regular != 0 ? regular : 8.6
                    }
                    settings.standardByDay = days
                }
            }
        )
        return HStack(spacing: 12) {
            Text(Self.dayNames[day])
            Spacer()
            if let value {
                Button {
                    hoursEdit = HoursEdit(title: Self.dayNames[day], hours: value) { settings, hours in
                        var days = settings.standardByDay
                        while days.count < 7 { days.append(nil) }
                        days[day] = hours
                        settings.standardByDay = days
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

    /// Hours and minutes of a setting, on the wheel.
    private func hoursRow(_ title: String, _ key: WritableKeyPath<Settings, Double>, _ s: Settings) -> some View {
        let value = s[keyPath: key]
        return HStack {
            Text(title)
            Spacer()
            Button {
                hoursEdit = HoursEdit(title: title, hours: value) { settings, hours in
                    settings[keyPath: key] = hours
                }
            } label: {
                ValueChip(text: Format.hoursToHM(value))
            }
            .buttonStyle(.plain)
        }
        .settingsRow()
    }

    /// A row that does something, in the tint.
    private func actionRow(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.tint)
            .settingsRow()
            .contentShape(Rectangle())
    }

    // MARK: Bindings

    /// Whether the days off left are kept: from today's payslip, until its own date is picked.
    private var keepsBalance: Binding<Bool> {
        Binding(
            get: { store.settings.balanceDate != nil },
            set: { on in
                guard on != (store.settings.balanceDate != nil) else { return }
                store.updateSettings { $0.balanceDate = on ? LocalTime.startOfDay(Date()) : nil }
            }
        )
    }

    /// The payslip's date, a day.
    private var balanceDate: Binding<Date> {
        Binding(
            get: { store.settings.balanceDate ?? LocalTime.startOfDay(Date()) },
            set: { date in
                let day = LocalTime.startOfDay(date)
                guard store.settings.balanceDate != day else { return }
                store.updateSettings { $0.balanceDate = day }
            }
        )
    }

    /// A setting, saved (and sent to iCloud) as it changes.
    private func setting<Value: Equatable>(_ key: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: key] },
            set: { value in
                guard store.settings[keyPath: key] != value else { return }
                store.updateSettings { $0[keyPath: key] = value }
            }
        )
    }

    /// A multiplier as a percentage: 1.25 is 125.
    private func multiplier(_ key: WritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(
            get: { jsRound(store.settings[keyPath: key] * 100) },
            set: { percent in
                let value = percent / 100
                guard store.settings[keyPath: key] != value else { return }
                store.updateSettings { $0[keyPath: key] = value }
            }
        )
    }

    /// Turns the lock on or off once the owner is known, by Face ID or the passcode; the switch goes back
    /// when they are not. With no passcode on the iPhone there is nothing to lock with: the lock can only
    /// be turned off.
    private func setLock(_ on: Bool) async {
        if AppLock.available {
            let reason = on ? "הפעלת הנעילה של Shifty" : "ביטול הנעילה של Shifty"
            if await AppLock.authenticate(reason) { lockOn = on }
        } else if on {
            lockProblem = true
        } else {
            lockOn = false
        }
        lockSwitch = lockOn
    }

    private var restoringShown: Binding<Bool> {
        Binding(get: { restoring != nil }, set: { shown in
            if !shown { restoring = nil }
        })
    }

    private var messageShown: Binding<Bool> {
        Binding(get: { message != nil }, set: { shown in
            if !shown { message = nil }
        })
    }

    // MARK: The place

    private var placeButton: String {
        placeSet ? "קבע מחדש את מקום העבודה כאן" : "קבע את מקום העבודה כאן"
    }

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
        Place.shared.setHere { found in
            Task { @MainActor in
                placeBusy = false
                placeSet = Place.coordinate != nil
                if !found { message = "לא הצלחתי למצוא את המיקום. בדוק שהמיקום מאופשר ל-Shifty." }
            }
        }
    }

    // MARK: iCloud

    private var cloudSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var cloudStatus: String {
        cloudSignedIn ? "פעיל" : "כבוי"
    }

    private var cloudNote: String {
        if cloudSignedIn {
            return "המשמרות וההגדרות נשמרות באייפון וב-iCloud, וחוזרות באייפון חדש או בהתקנה מחדש."
        }
        return "האייפון לא מחובר ל-iCloud, אז המשמרות נשמרות רק בו. אפשר להתחבר בהגדרות של האייפון."
    }

    // MARK: Backup

    private func export() {
        do {
            backup = BackupFile(data: try store.exportBackup())
            exporting = true
        } catch {
            message = "לא הצלחתי להכין את הגיבוי."
        }
    }

    private func read(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        do {
            restoring = try Data(contentsOf: url)
        } catch {
            message = "לא הצלחתי לקרוא את הקובץ."
        }
    }

    private func restore() {
        guard let data = restoring else { return }
        restoring = nil
        do {
            try store.importBackup(data)
            message = "הנתונים שוחזרו."
        } catch {
            message = "הקובץ אינו גיבוי של Shifty."
        }
    }

    /// "2026-10-29", the backup's day (app.js doExport).
    private static func stamp() -> String {
        let p = LocalTime.parts(Date())
        return "\(p.year)-" + Format.pad(p.month0 + 1) + "-" + Format.pad(p.day)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// A setting of hours being changed on the wheel.
struct HoursEdit: Identifiable {
    let id = UUID()
    let title: String
    let hours: Double
    let apply: (inout Settings, Double) -> Void
}

/// The backup file, for the Files app (store.exportAll's JSON).
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// A value to tap, as a list's: hours and minutes.
private struct ValueChip: View {
    let text: String

    var body: some View {
        Text(text)
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(Color.primary.opacity(0.07))
            }
    }
}

/// A name typed in; an empty one goes back to the default (app.js textRow).
private struct TextRow: View {
    let title: String
    @Binding var text: String
    let fallback: String
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            TextField(fallback, text: $draft)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
        }
        .settingsRow()
        .onAppear { draft = text }
        .onChange(of: focused) { _, now in
            if !now { commit() }
        }
        .onChange(of: text) { _, now in
            if !focused { draft = now }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed.isEmpty ? fallback : trimmed
        draft = text
    }
}

/// A number typed on the decimal keypad, saved as it is typed: a field left empty or half-typed keeps the
/// last number (app.js numRow).
private struct NumberRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            TextField("0", text: $draft)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .focused($focused)
                .frame(width: 84)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(Color.primary.opacity(0.07))
                }
                .onChange(of: draft) { _, typed in
                    if let number = Double(typed.replacingOccurrences(of: ",", with: ".")), number >= 0 {
                        value = number
                    }
                }
            Text(unit)
                .foregroundStyle(.secondary)
        }
        .settingsRow()
        .onAppear { draft = Self.text(value) }
        .onChange(of: focused) { _, now in
            if !now { draft = Self.text(value) }
        }
        .onChange(of: value) { _, now in
            if !focused { draft = Self.text(now) }
        }
    }

    /// 50 as "50", 22.6 as "22.6".
    private static func text(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
    }
}

/// A percentage, by fives (app.js numRow's percentages).
private struct PercentRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        Stepper(value: $value, in: range, step: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: "\(Int(jsRound(value)))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .settingsRow()
    }
}

/// Minutes, by fives.
private struct MinutesRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        Stepper(value: $value, in: 0...240, step: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: "\(Int(jsRound(value))) דק׳")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .settingsRow()
    }
}
