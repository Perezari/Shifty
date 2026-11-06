import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// The settings (app.js renderSettings): the workplaces, each on its page with what its employer sets
/// (WorkplaceViews.swift); then the user's own: the holidays, the pay period, the net pay's credit points, the look,
/// the notifications, the lock, iCloud and the backup; Shifty Pro on top, and its sections marked without it. Each
/// change is saved as it is made, and goes to iCloud.
struct SettingsView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(Pro.self) private var pro
    @AppStorage(AppLock.key) private var lockOn = false
    @AppStorage(Alerts.key) private var alerts = true
    @AppStorage(Alerts.breakKey) private var breakReminder = true
    @AppStorage(Alerts.summaryKey) private var periodSummary = true
    @AppStorage(CardLook.key) private var glassCards = false
    @AppStorage(HebrewDates.key) private var hebrewDate = false
    @AppStorage(Perf.key) private var measuring = false
    @State private var exporting = false
    @State private var backup = BackupFile(data: Data())
    @State private var importing = false
    @State private var restoring: Data?
    @State private var message: String?
    /// The lock's switch, which follows `lockOn` once Face ID or the passcode agrees.
    @State private var lockSwitch = false
    @State private var lockProblem = false

    var body: some View {
        let s = store.settings
        let _ = Perf.drew("הגדרות")
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ProCard()

                // each workplace on its page: its pay from each date, standard hours, travel and employer's rules
                WorkplacesSection()

                SettingsSection(title: "חגי ישראל",
                                note: "חגים, ערבי חג ויום הזיכרון מזוהים לבד, בכל שנה. השעות של ערב חג נקבעות בדף של כל מקום עבודה.") {
                    Toggle("זיהוי חגים אוטומטי", isOn: setting(\.holidaysEnabled))
                        .settingsRow()
                }

                // the pay period is each workplace's, on its page
                SettingsSection(title: "יעד הכנסה",
                                note: "היעד שלך, מכל מקומות העבודה יחד. יעד של 0 הוא בלי יעד. תקופת השכר נקבעת בדף של מקום העבודה.") {
                    NumberRow(title: "יעד הכנסה חודשי", value: setting(\.monthlyIncomeGoal), unit: s.currency)
                }

                SettingsSection(title: "נטו משוער",
                                note: "לכל תושב 2.25 נקודות זיכוי, ולאישה 2.75. ההפרשות לפנסיה ולקרן השתלמות נקבעות בדף של כל מקום עבודה. החישוב לפי מדרגות המס, ביטוח לאומי ומס בריאות של 2026, ולכן התלוש יכול להיות שונה מעט.",
                                pro: true) {
                    NumberRow(title: "נקודות זיכוי", value: setting(\.creditPoints), unit: "נק׳")
                }

                SettingsSection(title: "תצוגה",
                                note: "התאריך העברי מופיע לצד הלועזי בשעון, בלוח ובפירוט של כל יום. כרטיסי זכוכית כבדים יותר לציור. מדידת המהירות מראה בראש המסך, בכל שנייה, כמה פריימים הוצגו, כמה מהם איטיים, וכמה פעמים כל מסך צויר מחדש.") {
                    Picker("מראה", selection: setting(\.theme)) {
                        Text("כמו באייפון").tag("system")
                        Text("בהיר").tag("light")
                        Text("כהה").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 12)
                    Divider()
                    Toggle("תאריך עברי", isOn: $hebrewDate)
                        .settingsRow()
                    Divider()
                    Toggle("כרטיסי זכוכית", isOn: $glassCards)
                        .settingsRow()
                    Divider()
                    Toggle("מדידת מהירות", isOn: $measuring)
                        .settingsRow()
                }

                SettingsSection(title: "אייקון", pro: true) {
                    IconPicker()
                }

                SettingsSection(title: pro.unlocked ? "מסך הנעילה והתראות" : "התראות", note: alertsNote) {
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

                SettingsSection(title: "נעילה",
                                note: "האפליקציה ננעלת בפתיחה ואחרי דקה ברקע, ונפתחת ב-\(AppLock.biometryName) או בקוד של האייפון. הנעילה היא של האייפון הזה בלבד.") {
                    Toggle("נעילה עם \(AppLock.biometryName)", isOn: $lockSwitch)
                        .settingsRow()
                }

                SettingsSection(title: "iCloud", note: cloudNote, pro: true) {
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

                SettingsSection(title: nil) {
                    Link(destination: AppInfo.support) { actionRow("תמיכה ושאלות נפוצות") }
                    Divider()
                    Link(destination: AppInfo.privacy) { actionRow("מדיניות פרטיות") }
                }

                // a right-to-left mark first: iOS lays out a line by its first letter, and Shifty's is English
                Text("\u{200F}Shifty · גרסה \(AppInfo.version)")
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
        .onAppear { lockSwitch = lockOn }
        .onChange(of: lockSwitch) { _, on in
            guard on != lockOn else { return }
            Task { await setLock(on) }
        }
    }

    // MARK: Rows

    /// A row that does something, in the tint.
    private func actionRow(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.tint)
            .settingsRow()
            .contentShape(Rectangle())
    }

    // MARK: Bindings

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

    // MARK: The notifications

    /// The notifications, and the Lock Screen's shift with Shifty Pro.
    private var alertsNote: String {
        let alerts = "ההתראות: כשמגיעים ליעד היומי, כשמתחילות השעות הנוספות של 150%, אחרי 6 שעות ברצף בלי הפסקה, ואחרי 12 שעות של משמרת פתוחה. הסיכום מגיע בבוקר שאחרי סוף התקופה."
        guard pro.unlocked else { return alerts + " המשמרת במסך הנעילה וב-Dynamic Island: ב-Shifty Pro." }
        return "המשמרת שרצה מופיעה במסך הנעילה וב-Dynamic Island, עם כפתורים להפסקה ולסיום. " + alerts
    }

    // MARK: iCloud

    private var cloudSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var cloudStatus: String {
        pro.unlocked && cloudSignedIn ? "פעיל" : "כבוי"
    }

    private var cloudNote: String {
        guard pro.unlocked else {
            return "המשמרות וההגדרות נשמרות גם ב-iCloud, כמו שהן בכל המכשירים שלך, וחוזרות באייפון חדש או בהתקנה מחדש."
        }
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
struct ValueChip: View {
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
struct TextRow: View {
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
struct NumberRow: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            NumberField(value: $value)
            Text(unit)
                .foregroundStyle(.secondary)
        }
        .settingsRow()
    }
}

/// NumberRow's field, a number in a capsule: also two in one row, as a bonus's target and its amount.
struct NumberField: View {
    @Binding var value: Double
    var width: CGFloat = 84
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $draft)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .focused($focused)
            .frame(width: width)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(Color.primary.opacity(0.07))
            }
            .onChange(of: draft) { _, typed in
                if let number = Double(typed.replacingOccurrences(of: ",", with: ".")), number >= 0 {
                    value = number
                }
            }
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
struct PercentRow: View {
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
struct MinutesRow: View {
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
