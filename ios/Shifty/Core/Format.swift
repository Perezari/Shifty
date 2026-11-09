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

    /// "57:24", or "4:52:56" from an hour, of milliseconds: as the iPhone's timers count, so that the app's
    /// clock reads as the Lock Screen's (not the web app's).
    static func timer(_ ms: Double) -> String {
        let t = Int((max(ms, 0) / 1000).rounded(.down))
        let hours = t / 3600
        let minutes = t % 3600 / 60
        let seconds = pad(t % 60)
        return hours > 0 ? "\(hours):" + pad(minutes) + ":" + seconds : "\(minutes):" + seconds
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

    /// "+₪ 500.00" or "−₪ 200.00": a sum added or taken off. The mark holds the sign before the sum in a line laid out
    /// right to left. The app's own.
    static func signedMoney(_ amount: Double, _ symbol: String = "₪") -> String {
        "\u{200E}" + (amount < 0 ? "−" : "+") + money(abs(amount), symbol)
    }

    /// "125%", of a multiplier. The app's own.
    static func percent(_ multiplier: Double) -> String {
        "\(Int(jsRound(multiplier * 100)))%"
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

    /// A number in Hebrew letters, as a Hebrew date writes it: 23 "כ״ג", 15 "ט״ו", 5787 "תשפ״ז", its thousands left
    /// out. The app's own.
    static func gematria(_ number: Int) -> String {
        let ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        let tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
        let hundreds = ["", "ק", "ר", "ש", "ת", "תק", "תר", "תש", "תת", "תתק"]
        let n = abs(number) % 1000
        var letters = hundreds[n / 100] + tens[n % 100 / 10] + ones[n % 10]
        // 15 and 16 as ט״ו and ט״ז, not as the Name
        if letters.hasSuffix("יה") { letters = String(letters.dropLast(2)) + "טו" }
        if letters.hasSuffix("יו") { letters = String(letters.dropLast(2)) + "טז" }
        guard let last = letters.last, letters.count > 1 else { return letters + "׳" }
        return String(letters.dropLast()) + "״" + String(last)
    }

    /// "כ״ג בחשוון"
    static func hebrewDate(_ date: Date) -> String {
        let h = Holidays.hebrewDate(date)
        return h.day + " ב" + h.month
    }

    /// The Hebrew months of a span of days: "תשרי–חשוון תשפ״ז", or "אלול תשפ״ו–תשרי תשפ״ז" across a new year.
    static func hebrewMonths(_ range: TimeRange) -> String {
        let a = Holidays.hebrewDate(range.start)
        let b = Holidays.hebrewDate(Date(ms: range.end.ms - 1))
        if a.year != b.year { return a.month + " " + a.year + "–" + b.month + " " + b.year }
        return (a.month == b.month ? a.month : a.month + "–" + b.month) + " " + b.year
    }

    /// A seniority (Calc.seniority): "5 שנים ו־7 חודשים", "שנה וחודשיים", "חודש", "פחות מחודש". The app's own.
    static func seniority(years: Int, months: Int) -> String {
        func count(_ n: Int, _ one: String, _ two: String, _ many: String) -> String {
            n == 1 ? one : n == 2 ? two : "\(n) " + many
        }
        let y = count(years, "שנה", "שנתיים", "שנים")
        let m = count(months, "חודש", "חודשיים", "חודשים")
        if years == 0 { return months == 0 ? "פחות מחודש" : m }
        if months == 0 { return y }
        // "ו" before a word, "ו־" before a number
        return y + (months > 2 ? " ו־" : " ו") + m
    }
}
