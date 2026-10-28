import Foundation

/// Times, hours and money in Hebrew, as the web app writes them (assets/js/format.js).
enum Format {
    static let weekdays = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"]
    static let months = ["ינואר", "פברואר", "מרץ", "אפריל", "מאי", "יוני",
                         "יולי", "אוגוסט", "ספטמבר", "אוקטובר", "נובמבר", "דצמבר"]
    private static let hebrew = Locale(identifier: "he_IL")

    static func pad(_ n: Int) -> String {
        let text = String(n)
        return text.count >= 2 ? text : String(repeating: "0", count: 2 - text.count) + text
    }

    /// "07:10"
    static func clock(_ date: Date) -> String {
        let p = LocalTime.parts(date)
        return pad(p.hour) + ":" + pad(p.minute)
    }

    /// "04:52:56", of milliseconds.
    static func hms(_ ms: Double) -> String {
        let t = Int((max(ms, 0) / 1000).rounded(.down))
        return pad(t / 3600) + ":" + pad(t % 3600 / 60) + ":" + pad(t % 60)
    }

    /// "8:41", of hours.
    static func hoursToHM(_ hours: Double) -> String {
        let total = Int(jsRound((hours > 0 ? hours : 0) * 60))
        return "\(total / 60):" + pad(total % 60)
    }

    /// "8:41 שע׳"
    static func hoursShort(_ hours: Double) -> String {
        hoursToHM(hours) + " שע׳"
    }

    /// "₪ 442.72"
    static func money(_ amount: Double, _ symbol: String = "₪") -> String {
        let value = jsRound((amount + Double.ulpOfOne) * 100) / 100
        return symbol + " " + value.formatted(.number.precision(.fractionLength(2)).locale(hebrew))
    }

    /// "₪ 1,235"
    static func moneyShort(_ amount: Double, _ symbol: String = "₪") -> String {
        symbol + " " + jsRound(amount).formatted(.number.precision(.fractionLength(0)).locale(hebrew))
    }

    /// "21/6"
    static func dayMonth(_ date: Date) -> String {
        let p = LocalTime.parts(date)
        return "\(p.day)/\(p.month0 + 1)"
    }

    /// "21 ביוני"
    static func dateLong(_ date: Date) -> String {
        let p = LocalTime.parts(date)
        return "\(p.day) ב" + months[p.month0]
    }

    /// "יום א׳, 21 ביוני 2026"
    static func dateFull(_ date: Date) -> String {
        let p = LocalTime.parts(date)
        return "יום " + weekdays[p.weekday] + ", \(p.day) ב" + months[p.month0] + " \(p.year)"
    }

    /// "יום א׳"
    static func weekday(_ date: Date) -> String {
        "יום " + weekdays[LocalTime.parts(date).weekday]
    }

    /// "א׳"
    static func weekdayShort(_ date: Date) -> String {
        weekdays[LocalTime.parts(date).weekday]
    }

    static func monthName(_ month0: Int) -> String {
        months[month0]
    }
}
