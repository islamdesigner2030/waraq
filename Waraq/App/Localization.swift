import SwiftUI

/// The two languages the app speaks. Arabic is fully right-to-left.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }
    var isRTL: Bool { self == .arabic }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
    var locale: Locale { Locale(identifier: self == .arabic ? "ar" : "en_US") }

    /// Picks the string for this language. Strings live next to the views that use them,
    /// so switching language at runtime needs no relaunch and no string tables.
    func t(_ english: String, _ arabic: String) -> String {
        self == .arabic ? arabic : english
    }

    var displayName: String { self == .arabic ? "العربية" : "English" }

    /// A Gregorian calendar that speaks this language (month and weekday names, first weekday).
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.timeZone = .current
        return cal
    }
}

extension EnvironmentValues {
    /// The language of the surrounding UI (app chrome) or notebook (inside pages).
    @Entry var appLanguage: AppLanguage = .english
}

extension String {
    /// Direction of the first strong character: Arabic letters make a line right-to-left.
    var naturalDirection: LayoutDirection? {
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return .rightToLeft
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F:
                return .leftToRight
            default:
                continue
            }
        }
        return nil
    }
}
