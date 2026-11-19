import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    var simd4: SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
    }
}

/// App interface colours. Notebook colours live separately in `CoverColor` / `PaperTone`.
enum Palette {
    static let ivory = Color(hex: 0xF8F3E8)
    static let warmWhite = Color(hex: 0xFCFAF5)
    static let softBeige = Color(hex: 0xE9DFCC)
    static let mutedTeal = Color(hex: 0x4F7C7A)
    static let deepTeal = Color(hex: 0x2F5452)
    static let champagne = Color(hex: 0xC9A96A)
    static let ink = Color(hex: 0x2B2A27)
    static let inkSoft = Color(hex: 0x77726A)
    static let rule = Color(hex: 0x7F8E90)

    static let uiInk = UIColor(hex: 0x2B2A27)
    static let uiInkSoft = UIColor(hex: 0x77726A)
}

enum AppFont {
    static let arabicCalligraphy = "ArefRuqaa-Regular"
    static let englishCalligraphy = "GreatVibes-Regular"

    /// Decorative calligraphy — used on the welcome screen only.
    static func calligraphy(_ lang: AppLanguage, size: CGFloat) -> Font {
        let name = lang == .arabic ? arabicCalligraphy : englishCalligraphy
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: .largeTitle)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    /// Readable serif used inside notebooks (New York for Latin, SF Arabic falls back for Arabic).
    static func paper(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func paperUIFont(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serif, size: size)
        }
        return base
    }
}

/// Fixed geometry shared by the page background, the text view and the templates,
/// so that writing sits on the printed rules.
enum PageMetrics {
    static let line: CGFloat = 28
    static let top: CGFloat = 46
    static let bottom: CGFloat = 34
    static let outer: CGFloat = 24
    static let spine: CGFloat = 30
    /// Drawing area keeps clear of the outer edge, which belongs to the page-turn gesture.
    static let drawingOuterInset: CGFloat = 26

    static func rowCount(height: CGFloat) -> Int {
        max(0, Int(((height - top - bottom) / line).rounded(.down)))
    }
}

/// Where the paper page sits on screen. Shared by UIKit (reader) and SwiftUI (opening animation).
enum PageLayout {
    static let topChrome: CGFloat = 70
    static let bottomChrome: CGFloat = 74
    static let side: CGFloat = 16

    static func pageFrame(in size: CGSize, safe: UIEdgeInsets, aspect: CGFloat) -> CGRect {
        let avail = CGRect(x: side + safe.left,
                           y: safe.top + topChrome,
                           width: size.width - side * 2 - safe.left - safe.right,
                           height: size.height - safe.top - topChrome - safe.bottom - bottomChrome)
        guard avail.width > 10, avail.height > 10 else { return .zero }
        var w = avail.width
        var h = w / aspect
        if h > avail.height {
            h = avail.height
            w = h * aspect
        }
        return CGRect(x: (size.width - w) / 2, y: avail.minY + (avail.height - h) / 2, width: w, height: h).integral
    }
}
