import SwiftUI

/// The first setup, at the first launch: the own workplace filled in four short steps, its name and the day work began
/// there, its pay and travel, its days and hours, and its pay period. Each has a sensible value but the pay, which is
/// the user's to give; all is saved at the last step, as the workplace's page would save it (Settings.setPlace), and is
/// changed there. Shown while no shift was ever kept and it was not done (RootView); shifts from iCloud close it.
struct Welcome: View {
    static let doneKey = "welcomed"

    /// Due: never done, and no shift kept.
    @MainActor
    static func due(_ store: ShiftStore) -> Bool {
        !UserDefaults.standard.bool(forKey: doneKey) && store.records.isEmpty
    }

    /// How it ends: into the app, a shift started or not; or to the settings, to restore a backup.
    enum Finish {
        case app, start, restore
    }

    let finish: (Finish) -> Void
    @Environment(ShiftStore.self) private var store

    @State private var step = 0
    @State private var name = ""
    @State private var hasStart = false
    @State private var startDate = Date()
    @State private var global = false
    @State private var wage = 0.0
    @State private var salary = 0.0
    @State private var cover: OvertimeCover = .all
    @State private var travelMonthly = false
    @State private var travel = 0.0
    /// Sunday to Shabbat, and the regular day's hours (42 a week in five days); a day's own hours over them.
    @State private var workdays = [true, true, true, true, true, false, false]
    @State private var hours = 8.4
    @State private var otherHours: [Int: Double] = [:]
    @State private var fromDay = 1
    @State private var editing: DayHours?

    /// Hours edited on the wheel: a day's own, or (nil) the regular day's.
    private struct DayHours: Identifiable {
        let id = UUID()
        let day: Int?
        let title: String
        let hours: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            if (1...4).contains(step) {
                top
            }
            ScrollView {
                Group {
                    switch step {
                    case 0: hello
                    case 1: workplace
                    case 2: pay
                    case 3: week
                    case 4: period
                    default: ready
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, step == 0 || step == 5 ? 70 : 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            bottom
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(item: $editing) { edit in
            HoursSheet(title: edit.title, hours: edit.hours) { value in
                if let day = edit.day { otherHours[day] = value } else { hours = value }
            }
        }
    }

    // MARK: The steps

    /// The icon, the name, and three things the app does, as Apple's own first screens.
    private var hello: some View {
        VStack(spacing: 10) {
            AppIconImage(size: 92)
                .shadow(color: .black.opacity(0.18), radius: 11, y: 8)
                .padding(.bottom, 10)
            Text("ברוכים הבאים ל-Shifty")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("השעות והשכר שלך, משמרת אחרי משמרת.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 22) {
                feature("timer", "משמרת בלחיצה", "התחלה, הפסקה וסיום, והשכר עולה תוך כדי.")
                feature("calendar", "כל החודש במבט", "שעות נוספות, חוסר מול התקן, חגים וימי חופש.")
                feature("banknote", "כמה ייכנס", "צפי לסוף התקופה, ונטו משוער ב-Shifty Pro.")
            }
            .padding(.top, 26)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var workplace: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("מקום העבודה", "נתחיל במעסיק. אפשר לשנות הכול אחר כך בהגדרות.")
            SettingsSection(title: nil, note: "לפי הוותק נקבעים ימי החופשה בשנה ודמי ההבראה. לא חובה.") {
                TextRow(title: "שם", text: $name, fallback: Settings().workplaceName)
                Divider()
                HStack {
                    Text("תחילת עבודה")
                    Spacer()
                    if hasStart {
                        DatePicker("תחילת עבודה", selection: $startDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        Button("הוספה") {
                            hasStart = true
                        }
                        .fontWeight(.medium)
                    }
                }
                .settingsRow()
            }
        }
    }

    private var pay: some View {
        let currency = store.settings.currency
        return VStack(alignment: .leading, spacing: 16) {
            heading("השכר", "כמו שכתוב בחוזה או בתלוש.")
            SettingsSection(title: nil) {
                Picker("סוג השכר", selection: $global) {
                    Text("לפי שעה").tag(false)
                    Text("גלובלי").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 12)
                Divider()
                if global {
                    NumberRow(title: "שכר חודשי", value: $salary, unit: currency)
                    Divider()
                    Picker("שעות נוספות", selection: $cover) {
                        Text("כלולות בשכר").tag(OvertimeCover.all)
                        Text("משולמות כולן").tag(OvertimeCover.none)
                    }
                    .settingsRow()
                } else {
                    NumberRow(title: "שכר לשעה", value: $wage, unit: currency)
                }
            }
            SettingsSection(title: "נסיעות",
                            note: "שעות נוספות, שבת, חופשה, מחלה ופנסיה כבר לפי החוק. אפשר לשנות אותם בדף של מקום העבודה.") {
                Picker("נסיעות", selection: $travelMonthly) {
                    Text("ליום").tag(false)
                    Text("לחודש").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 12)
                Divider()
                NumberRow(title: travelMonthly ? "סכום לחודש מלא" : "החזר ליום", value: $travel, unit: currency)
            }
        }
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("ימים ושעות", "יום עבודה רגיל. מעבר לשעות האלה נספרות שעות נוספות.")
            SettingsSection(title: nil) {
                // the days, each a circle, as the Clock's alarms
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { day in
                        Button {
                            workdays[day].toggle()
                            if !workdays[day] { otherHours[day] = nil }
                        } label: {
                            Text(Format.weekdays[day].replacingOccurrences(of: "׳", with: ""))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(workdays[day] ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(Circle().fill(workdays[day] ? Color.accentColor : Color.primary.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("יום " + Format.weekdays[day])
                        .accessibilityAddTraits(workdays[day] ? .isSelected : [])
                    }
                }
                .padding(.vertical, 14)
            }
            SettingsSection(title: nil, note: "פחות מזה נספר כחוסר. בערב חג ובחג השעות מתעדכנות לבד.") {
                hoursRow("שעות ביום", hours, day: nil)
                ForEach(otherDays, id: \.self) { day in
                    Divider()
                    hoursRow("ביום " + Format.weekdays[day], otherHours[day] ?? hours, day: day)
                }
                if !daysWithoutOwn.isEmpty {
                    Divider()
                    Menu {
                        ForEach(daysWithoutOwn, id: \.self) { day in
                            Button("יום " + Format.weekdays[day]) {
                                otherHours[day] = hours
                            }
                        }
                    } label: {
                        Label("יום עם שעות אחרות", systemImage: "plus")
                            .settingsRow()
                    }
                }
            }
        }
    }

    private var period: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("תקופת השכר", "מאיזה יום בחודש מתחיל החודש בתלוש?")
            SettingsSection(title: nil, note: "לפי התקופה מקובצות המשמרות ונספרות השעות הנוספות, ובסופה מגיע סיכום.") {
                choice(1, "מה־1 בחודש", "כמו אצל רוב המעסיקים")
                Divider()
                choice(fromDay == 1 ? 20 : fromDay, "מיום אחר", "למשל מה־20 עד ה־19 בחודש הבא")
                if fromDay != 1 {
                    Divider()
                    Stepper(value: $fromDay, in: 2...28) {
                        HStack {
                            Text("מיום")
                            Spacer()
                            Text(String(fromDay))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .settingsRow()
                }
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.accentColor))
                .padding(.bottom, 8)
            Text("הכול מוכן")
                .font(.largeTitle.weight(.bold))
            Text("אפשר לשנות כל דבר בהגדרות, בדף של מקום העבודה.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsSection(title: nil) {
                line(placeName, payText)
                Divider()
                line(daysText, hoursText)
                Divider()
                line("תקופת השכר", "מה־\(fromDay) בחודש")
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The buttons

    private var top: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 26, height: 4)
                }
            }
            HStack {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("חזרה")
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var bottom: some View {
        VStack(spacing: 8) {
            Button(action: next) {
                HStack(spacing: 8) {
                    if step == 5 {
                        Image(systemName: "play.fill")
                    }
                    Text(step == 0 ? "נתחיל" : step == 4 ? "סיום" : step == 5 ? "התחלת משמרת" : "המשך")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!canGoOn)
            if step == 0 {
                Button("שחזור מגיבוי") {
                    finish(.restore)
                }
                .font(.subheadline.weight(.medium))
            } else if step == 5 {
                Button("אחר כך") {
                    finish(.app)
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    /// Each step's own is given: the pay, and a day of work.
    private var canGoOn: Bool {
        switch step {
        case 2: global ? salary > 0 : wage > 0
        case 3: workdays.contains(true)
        default: true
        }
    }

    private func next() {
        switch step {
        case 4:
            save()
            withAnimation { step = 5 }
        case 5:
            finish(.start)
        default:
            withAnimation { step += 1 }
        }
    }

    /// The workplace saved, as its page saves it, and the setup done.
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateSettings { settings in
            var place = settings.place(nil)
            place.name = trimmed.isEmpty ? Settings().workplaceName : trimmed
            place.startDate = hasStart ? LocalTime.startOfDay(startDate) : nil
            place.pay = [global
                ? PayTerms(id: "own", from: PayTerms.start, kind: .monthly, monthlySalary: salary, overtimeCover: cover)
                : PayTerms(id: "own", from: PayTerms.start, kind: .hourly, hourlyWage: wage)]
            place.travelMonthly = travelMonthly && travel > 0 ? travel : nil
            place.travelPerDay = travelMonthly ? 0 : travel
            place.standardByDay = (0..<7).map { workdays[$0] ? (otherHours[$0] ?? hours) : nil }
            // a vacation day pays the regular day
            place.rules.vacationHours = hours
            place.monthStartDay = fromDay
            settings.setPlace(nil, place)
            settings.regularDailyHours = hours
        }
        UserDefaults.standard.set(true, forKey: Self.doneKey)
    }

    // MARK: Parts

    private func heading(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(text)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A day's hours, or the regular day's, on the wheel; a day's own can be taken off.
    private func hoursRow(_ title: String, _ value: Double, day: Int?) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Button {
                editing = DayHours(day: day, title: title, hours: value)
            } label: {
                ValueChip(text: Format.hoursToHM(value))
            }
            .buttonStyle(.plain)
            if let day {
                Button {
                    otherHours[day] = nil
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("הסרה")
            }
        }
        .settingsRow()
    }

    /// The pay period from the 1st, or from another day.
    private func choice(_ day: Int, _ title: String, _ text: String) -> some View {
        let chosen = day == 1 ? fromDay == 1 : fromDay != 1
        return Button {
            fromDay = day
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if chosen {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .settingsRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .settingsRow()
    }

    // MARK: The summary

    /// The days with their own hours, Sunday first.
    private var otherDays: [Int] {
        otherHours.keys.sorted()
    }

    /// The days of work that could have their own hours.
    private var daysWithoutOwn: [Int] {
        (0..<7).filter { workdays[$0] && otherHours[$0] == nil }
    }

    private var placeName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Settings().workplaceName : trimmed
    }

    /// "₪ 54.00 לשעה", or "₪ 12,000 לחודש · גלובלי".
    private var payText: String {
        let currency = store.settings.currency
        return global ? Format.moneyShort(salary, currency) + " לחודש · גלובלי" : Format.money(wage, currency) + " לשעה"
    }

    /// "א׳–ה׳", or the days one by one.
    private var daysText: String {
        let on = (0..<7).filter { workdays[$0] }
        guard let first = on.first, let last = on.last else { return "" }
        if on.count > 2 && on == Array(first...last) { return Format.weekdays[first] + "–" + Format.weekdays[last] }
        return on.map { Format.weekdays[$0] }.joined(separator: ", ")
    }

    /// "8:24 ביום · ה׳ 6:00"
    private var hoursText: String {
        let own = otherDays.map { Format.weekdays[$0] + " " + Format.hoursToHM(otherHours[$0] ?? hours) }
        return ([Format.hoursToHM(hours) + " ביום"] + own).joined(separator: " · ")
    }
}
