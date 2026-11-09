import PDFKit
import SwiftUI

/// A pay period's hours report at one workplace (Shifty Pro): a PDF to send to the employer, a manpower company or an
/// accountant, seen as it will go. The worker's name on it stays on this iPhone; nothing leaves it but by the share.
struct ReportSheet: View {
    /// A day of the pay period on screen: the report's is the one around it, by the workplace's own pay month.
    let around: Date
    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("reportName") private var name = ""
    @AppStorage("reportAmounts") private var amounts = true
    /// nil for the settings' own workplace.
    @State private var place: String?
    @State private var file: URL?
    /// Each report made, for the page shown to be drawn again: the file keeps its name.
    @State private var made = 0

    init(around: Date, place: String?) {
        self.around = around
        _place = State(initialValue: place)
    }

    var body: some View {
        let settings = store.settings
        NavigationStack {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    if !settings.workplaces.isEmpty {
                        HStack {
                            Text("מקום עבודה")
                            Spacer()
                            Picker("מקום עבודה", selection: $place) {
                                Text(settings.workplaceName).tag(String?.none)
                                ForEach(settings.workplaces) { place in
                                    Text(place.name).tag(Optional(place.id))
                                }
                            }
                            .labelsHidden()
                        }
                        .settingsRow()
                        Divider()
                    }
                    HStack(spacing: 12) {
                        Text("שם העובד")
                        TextField("לא חובה", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .submitLabel(.done)
                    }
                    .settingsRow()
                    Divider()
                    Toggle("כולל סכומים", isOn: $amounts)
                        .settingsRow()
                }
                .padding(.horizontal, 16)
                .card(padding: 0)
                Group {
                    if let file {
                        ReportPreview(url: file)
                            .id(made)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("דוח שעות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("סגירה")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let file {
                        ShareLink(item: file) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("שליחת הדוח")
                    }
                }
            }
            // made again as the choices change, a moment after the last letter of a name
            .task(id: (place ?? "") + "|" + name + "|" + String(amounts)) {
                if made > 0 {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                }
                let report = Calc.report(store.shifts, store.settings, place: place, around: around, asOf: Date().ms)
                file = ReportPDF.file(report, name: name.trimmingCharacters(in: .whitespacesAndNewlines), amounts: amounts)
                made += 1
            }
        }
        .environment(\.locale, Locale(identifier: "he_IL"))
        .presentationDetents([.large])
    }
}

/// A PDF on screen, to scroll and to pinch.
private struct ReportPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}

/// The report as an A4 PDF: SwiftUI's pages drawn into it, as text and lines.
@MainActor
enum ReportPDF {
    static let width: CGFloat = 595
    static let height: CGFloat = 842
    static let rowHeight: CGFloat = 17
    static let lineHeight: CGFloat = 15
    /// What a page has for its rows: under its margins, its table's head and its foot, and on the first its title.
    private static let firstRows = 37
    private static let nextRows = 42

    /// In the temporary folder, named by its period; nil if it can't be written.
    static func file(_ report: HoursReport, name: String, amounts: Bool) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("דוח שעות " + report.title.replacingOccurrences(of: "/", with: "-") + ".pdf")
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        let lines = shownLines(report, amounts: amounts)
        let divided = pages(report.rows, lines: lines.count)
        for (index, rows) in divided.enumerated() {
            let renderer = ImageRenderer(content: ReportPage(report: report, rows: rows, lines: lines, name: name, amounts: amounts,
                                                             number: index + 1, count: divided.count))
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
    }

    /// The sum's lines: without the amounts, those that have hours or days.
    private static func shownLines(_ report: HoursReport, amounts: Bool) -> [HoursReport.Line] {
        amounts ? report.lines : report.lines.filter { !$0.detail.isEmpty }
    }

    /// The rows by page, the sum on the last: on a page of its own when it does not fit under them.
    private static func pages(_ rows: [HoursReport.Row], lines: Int) -> [[HoursReport.Row]] {
        // the lines, the total and the signatures, in rows
        let sum = Int(((CGFloat(lines) * lineHeight + 110) / rowHeight).rounded(.up))
        var pages: [[HoursReport.Row]] = []
        var rest = rows[...]
        while true {
            let room = pages.isEmpty ? firstRows : nextRows
            if rest.isEmpty || rest.count + sum <= room {
                pages.append(Array(rest))
                return pages
            }
            let taken = min(rest.count, room)
            pages.append(Array(rest.prefix(taken)))
            rest = rest.dropFirst(taken)
        }
    }
}

/// A page of the report, right to left, black on white whatever the iPhone's look: its title on the first, its table,
/// and on the last the sum and the signatures.
private struct ReportPage: View {
    let report: HoursReport
    let rows: [HoursReport.Row]
    let lines: [HoursReport.Line]
    let name: String
    let amounts: Bool
    /// Its place among the pages, from 1.
    let number: Int
    let count: Int

    /// The wages' column: with the amounts, where hours are paid by themselves.
    private var paid: Bool {
        amounts && report.rows.contains { $0.pay != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if number == 1 { title }
            head
            ForEach(rows) { row in
                rowLine(row)
            }
            if report.rows.isEmpty {
                Text("אין משמרות בתקופה זו")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            if number == count { sum }
            Spacer(minLength: 0)
            foot
        }
        .padding(28)
        .frame(width: ReportPDF.width, height: ReportPDF.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.colorScheme, .light)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("דוח שעות")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(report.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(details)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(.bottom, 14)
    }

    /// The worker, the workplace and, with the amounts, the wage.
    private var details: String {
        var parts = name.isEmpty ? [] : [name]
        parts.append(report.workplace)
        if amounts, let wage = report.hourlyWage { parts.append("שכר לשעה " + Format.money(wage, report.currency)) }
        return parts.joined(separator: " · ")
    }

    private var head: some View {
        cells(date: "תאריך", day: "יום", start: "כניסה", end: "יציאה", rest: "הפסקה", net: "שעות", regular: "רגילות",
              first: report.firstTier, second: report.secondTier, holiday: "שבת/חג", pay: "שכר", note: "הערה")
            .font(.system(size: 8.5, weight: .semibold))
            .background(Color(white: 0.92))
    }

    private func rowLine(_ row: HoursReport.Row) -> some View {
        cells(date: Format.dayMonth(row.date), day: Format.weekdayShort(row.date), start: row.start, end: row.end,
              rest: row.breakMinutes > 0 ? String(row.breakMinutes) : "", net: hours(row.net), regular: hours(row.regular),
              first: hours(row.first), second: hours(row.second), holiday: hours(row.holiday),
              pay: row.pay.map { Format.money($0, report.currency) } ?? "", note: row.note)
            .font(.system(size: 9))
            .monospacedDigit()
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(white: 0.85))
                    .frame(height: 0.5)
            }
    }

    /// A row of the table, the date on the right.
    private func cells(date: String, day: String, start: String, end: String, rest: String, net: String, regular: String,
                       first: String, second: String, holiday: String, pay: String, note: String) -> some View {
        HStack(spacing: 0) {
            Text(date).frame(width: 34)
            Text(day).frame(width: 18)
            Text(start).frame(width: 36)
            Text(end).frame(width: 36)
            Text(rest).frame(width: 34)
            Text(net).frame(width: 34)
            Text(regular).frame(width: 34)
            Text(first).frame(width: 32)
            Text(second).frame(width: 32)
            Text(holiday).frame(width: 36)
            if paid {
                Text(pay).frame(width: 56)
            }
            Text(note)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
        }
        .frame(height: ReportPDF.rowHeight)
    }

    private func hours(_ value: Double) -> String {
        value > 0.001 ? Format.hoursToHM(value) : ""
    }

    /// The lines, the total and the signatures.
    private var sum: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                sumRow(line.title, detail: line.detail, amount: line.amount.map(amountText) ?? "")
                    .font(.system(size: 10))
                    .frame(height: ReportPDF.lineHeight)
            }
            Rectangle()
                .fill(Color.black)
                .frame(height: 0.75)
                .padding(.vertical, 3)
            sumRow("סה״כ", detail: Format.hoursShort(report.netHours), amount: Format.money(report.total, report.currency))
                .font(.system(size: 11, weight: .bold))
            HStack(spacing: 40) {
                signature("חתימת העובד")
                signature("חתימת המעסיק")
            }
            .padding(.top, 30)
        }
        .monospacedDigit()
        .padding(.top, 14)
    }

    private func sumRow(_ title: String, detail: String, amount: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(detail)
                .frame(width: 70, alignment: .trailing)
            if amounts {
                Text(amount)
                    .frame(width: 84, alignment: .trailing)
            }
        }
    }

    /// A sum taken off, with its sign.
    private func amountText(_ amount: Double) -> String {
        amount < 0 ? Format.signedMoney(amount, report.currency) : Format.money(amount, report.currency)
    }

    private func signature(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 0.5)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private var foot: some View {
        HStack {
            Text(amounts ? "הופק ב־Shifty. הסכומים הם חישוב של האפליקציה, לא תלוש שכר." : "הופק ב־Shifty.")
            Spacer()
            if count > 1 {
                Text(verbatim: "עמוד \(number) מתוך \(count)")
            }
        }
        .font(.system(size: 8))
        .foregroundStyle(Color(white: 0.4))
    }
}
