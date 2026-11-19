import Foundation

/// Small calendar helpers for the Bullet Journal templates (always Gregorian).
enum BJCalendar {
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private static var formatters: [String: DateFormatter] = [:]
    private static var numberFormatters: [String: NumberFormatter] = [:]

    private static func formatter(_ template: String, _ lang: AppLanguage) -> DateFormatter {
        let key = template + lang.rawValue
        if let f = formatters[key] { return f }
        let f = DateFormatter()
        f.calendar = lang.calendar
        f.locale = lang.locale
        if template == "time" {
            f.timeStyle = .short
            f.dateStyle = .none
        } else {
            f.setLocalizedDateFormatFromTemplate(template)
        }
        formatters[key] = f
        return f
    }

    static func yearMonth(of date: Date) -> (year: Int, month: Int) {
        let c = gregorian.dateComponents([.year, .month], from: date)
        return (c.year ?? 2026, c.month ?? 1)
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static func daysIn(year: Int, month: Int) -> Int {
        let d = date(year: year, month: month, day: 1)
        return gregorian.range(of: .day, in: .month, for: d)?.count ?? 30
    }

    /// Calendar weekday (1 = Sunday … 7 = Saturday).
    static func weekday(year: Int, month: Int, day: Int) -> Int {
        gregorian.component(.weekday, from: date(year: year, month: month, day: day))
    }

    /// Weeks counted in 7-day blocks from day 1 (days 1–7 = week 1, …).
    static func weekCount(year: Int, month: Int) -> Int {
        (daysIn(year: year, month: month) + 6) / 7
    }

    static func week(ofDay day: Int) -> Int { (day - 1) / 7 }

    static func isToday(year: Int, month: Int, day: Int) -> Bool {
        let c = gregorian.dateComponents([.year, .month, .day], from: Date())
        return c.year == year && c.month == month && c.day == day
    }

    static func monthTitle(year: Int, month: Int, lang: AppLanguage) -> String {
        formatter("MMMMyyyy", lang).string(from: date(year: year, month: month, day: 1))
    }

    static func monthName(year: Int, month: Int, lang: AppLanguage) -> String {
        formatter("MMMM", lang).string(from: date(year: year, month: month, day: 1))
    }

    static func dayTitle(_ date: Date, lang: AppLanguage) -> String {
        formatter("EEEE", lang).string(from: date)
    }

    static func longDate(_ date: Date, lang: AppLanguage) -> String {
        formatter("dMMMMyyyy", lang).string(from: date)
    }

    static func shortDate(_ date: Date, lang: AppLanguage) -> String {
        formatter("dMMM", lang).string(from: date)
    }

    static func time(_ date: Date, lang: AppLanguage) -> String {
        formatter("time", lang).string(from: date)
    }

    /// Very short weekday symbol for a calendar weekday (1…7).
    static func weekdayInitial(_ weekday: Int, lang: AppLanguage) -> String {
        let symbols = lang == .arabic
            ? ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
            : ["S", "M", "T", "W", "T", "F", "S"]
        return symbols[max(0, min(6, weekday - 1))]
    }

    /// Weekdays in the order the language's week starts.
    static func orderedWeekdays(lang: AppLanguage) -> [Int] {
        let first = lang == .arabic ? 7 : 1   // Saturday-first for Arabic, Sunday-first for English
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    static func number(_ n: Int, lang: AppLanguage) -> String {
        let key = lang.rawValue
        let f: NumberFormatter
        if let cached = numberFormatters[key] {
            f = cached
        } else {
            f = NumberFormatter()
            f.locale = lang.locale
            numberFormatters[key] = f
        }
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
