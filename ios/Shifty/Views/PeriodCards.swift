import SwiftUI

// The cards under the calendar's month: how the pay period comes to its sum, its hours by week, and its days off. And
// a day off's symbol, wherever it shows.

/// A day off's symbol, its side `size`: the beach umbrella drawn here, as the system's is half closed at these sizes.
struct DayOffSymbol: View {
    let type: ShiftType
    let size: CGFloat

    var body: some View {
        if type == .vacation {
            UmbrellaShape()
                .frame(width: size * 1.15, height: size * 1.15)
        } else {
            Image(systemName: type.dayOffSymbol)
                .font(.system(size: size, weight: .semibold))
        }
    }
}

/// A beach umbrella, open and leaning, on a line of sand.
struct UmbrellaShape: Shape {
    func path(in rect: CGRect) -> Path {
        // drawn in a square of 32
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        var canopy = Path()
        canopy.move(to: point(3.6, 14.6))
        canopy.addCurve(to: point(16, 2.4), control1: point(3.6, 7.6), control2: point(9.2, 2.4))
        canopy.addCurve(to: point(28.4, 14.6), control1: point(22.8, 2.4), control2: point(28.4, 7.6))
        canopy.addCurve(to: point(24.2, 11.9), control1: point(26.8, 12.8), control2: point(25.4, 11.9))
        canopy.addCurve(to: point(20.2, 14.6), control1: point(23, 11.9), control2: point(21.5, 12.8))
        canopy.addCurve(to: point(16, 11.9), control1: point(18.9, 12.8), control2: point(17.5, 11.9))
        canopy.addCurve(to: point(11.8, 14.6), control1: point(14.5, 11.9), control2: point(13.1, 12.8))
        canopy.addCurve(to: point(7.8, 11.9), control1: point(10.5, 12.8), control2: point(9.1, 11.9))
        canopy.addCurve(to: point(3.6, 14.6), control1: point(6.5, 11.9), control2: point(5.2, 12.8))
        canopy.closeSubpath()

        var pole = Path()
        pole.move(to: point(16, 13.2))
        pole.addLine(to: point(16, 29))
        canopy.addPath(pole.strokedPath(StrokeStyle(lineWidth: 2.3, lineCap: .round)))

        // leaning to the left, around its middle
        let lean = CGAffineTransform(translationX: 16, y: 15)
            .rotated(by: -22 * .pi / 180)
            .translatedBy(x: -16, y: -15)

        var sand = Path()
        sand.move(to: point(10.6, 29.6))
        sand.addCurve(to: point(20.2, 27.5), control1: point(13.6, 28.2), control2: point(16.8, 27.5))
        sand.addCurve(to: point(29.8, 29.6), control1: point(23.6, 27.5), control2: point(26.8, 28.2))

        var all = canopy.applying(lean)
        all.addPath(sand.strokedPath(StrokeStyle(lineWidth: 2.3, lineCap: .round)))

        let scale = min(rect.width, rect.height) / 32
        let fit = CGAffineTransform(translationX: rect.midX - 16 * scale, y: rect.midY - 16 * scale)
            .scaledBy(x: scale, y: scale)
        return all.applying(fit)
    }
}

/// The three cards under the month.
struct PeriodCards: View {
    let summary: PeriodSummary
    /// All of them.
    let shifts: [Shift]
    let settings: Settings
    let date: Date

    var body: some View {
        let lines = Calc.lines(summary, settings)
        if !lines.isEmpty {
            PeriodLinesCard(lines: lines, currency: settings.currency)
        }
        PeriodWeeksCard(weeks: Calc.periodWeeks(shifts, settings, range: summary.range, asOf: date.ms),
                        limit: settings.weeklyHours > 0 ? settings.weeklyHours : 42)
        HStack(spacing: 8) {
            tile(.vacation)
            tile(.sick)
            tile(.reserve)
        }
        .frame(maxWidth: .infinity)
        .modifier(CardTitled(title: "ימים בתקופה"))
    }

    private func tile(_ type: ShiftType) -> some View {
        PeriodDayTile(type: type, count: summary.shifts.filter { $0.type == type }.count, left: left(type))
    }

    /// What is left of a day off's kind, at the workplaces keeping it, with Shifty Pro.
    private func left(_ type: ShiftType) -> Double? {
        guard ProFlag.on, type != .reserve else { return nil }
        let places: [String?] = [nil] + settings.workplaces.map { Optional($0.id) }
        let balances = places.compactMap { Calc.leave(shifts, settings, asOf: date, at: $0) }
        guard !balances.isEmpty else { return nil }
        let days = balances.map { type == .vacation ? $0.vacation : $0.sick }
        return days.reduce(0, +)
    }
}

/// A card with a small title over its contents.
private struct CardTitled: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .card(padding: 14)
    }
}

/// How the period comes to its sum, line by line as a payslip has them (Calc.lines). Their colors and symbols are also
/// the calendar's key.
private struct PeriodLinesCard: View {
    let lines: [HoursReport.Line]
    let currency: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                PeriodLineRow(line: line, currency: currency)
            }
        }
        .modifier(CardTitled(title: "פירוט התקופה"))
    }
}

private struct PeriodLineRow: View {
    let line: HoursReport.Line
    let currency: String

    var body: some View {
        HStack(spacing: 8) {
            mark
                .frame(width: 16)
            Text(line.title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(line.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(amount)
                .fontWeight(.semibold)
                .frame(width: 78, alignment: .trailing)
        }
        .font(.subheadline)
        .monospacedDigit()
        .frame(minHeight: 28)
    }

    private var amount: String {
        guard let value = line.amount else { return "" }
        return value < 0 ? Format.signedMoney(value, currency) : Format.moneyShort(value, currency)
    }

    @ViewBuilder
    private var mark: some View {
        switch line.mark {
        case .dayOff(let type):
            DayOffSymbol(type: type, size: 12)
                .foregroundStyle(type.dayOffColor)
        case .regular:
            dot(.accentColor)
        case .overtime, .rest, .holidayPay:
            dot(Color("Holiday"))
        case .night:
            dot(.indigo)
        case .money:
            dot(.secondary)
        }
    }

    private func dot(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 9, height: 9)
    }
}

/// The period's weeks, the first on the right: each one's hours against the week's, what is past them in overtime's color.
private struct PeriodWeeksCard: View {
    let weeks: [PeriodWeek]
    let limit: Double

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(weeks, id: \.start) { week in
                PeriodWeekBar(week: week, limit: limit, scale: scale)
            }
        }
        .modifier(CardTitled(title: "שעות לפי שבוע"))
    }

    /// The hours of a full bar.
    private var scale: Double {
        max(limit, weeks.map(\.hours).max() ?? 0)
    }
}

private struct PeriodWeekBar: View {
    let week: PeriodWeek
    let limit: Double
    let scale: Double

    private static let height: CGFloat = 84

    var body: some View {
        VStack(spacing: 5) {
            Text(Format.hoursToHM(week.hours))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                bar
            }
            .frame(height: Self.height)
            Text(Format.dayMonth(week.start))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var bar: some View {
        let whole = Self.height * CGFloat(min(1, week.hours / max(scale, 1)))
        let past = Self.height * CGFloat(max(0, week.hours - limit) / max(scale, 1))
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color("Holiday"))
                .frame(height: past)
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: max(0, whole - past))
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A kind of day off in the period: how many, and with Shifty Pro how many are left.
private struct PeriodDayTile: View {
    let type: ShiftType
    let count: Int
    let left: Double?

    var body: some View {
        VStack(spacing: 3) {
            DayOffSymbol(type: type, size: 17)
                .foregroundStyle(type.dayOffColor)
                .frame(height: 22)
            Text(verbatim: String(count))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// "חופש · נשארו 9", or its word.
    private var title: String {
        guard let left else { return type.dayOffWord }
        return type.dayOffWord + " · נשארו " + Format.days(left)
    }
}
