import Foundation
import SwiftUI
import UIKit

// MARK: - Notebook appearance

enum NotebookProportion: String, Codable, CaseIterable, Identifiable {
    case classic, slim, wide
    var id: String { rawValue }
    /// width / height of a page
    var aspect: CGFloat {
        switch self {
        case .classic: return 0.707   // A5
        case .slim: return 0.63
        case .wide: return 0.80
        }
    }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .classic: return l.t("Classic", "كلاسيكي")
        case .slim: return l.t("Slim", "نحيف")
        case .wide: return l.t("Wide", "عريض")
        }
    }
}

enum CornerStyle: String, Codable, CaseIterable, Identifiable {
    case soft, round, sharp
    var id: String { rawValue }
    var coverRadius: CGFloat {
        switch self {
        case .soft: return 9
        case .round: return 20
        case .sharp: return 3
        }
    }
    var pageRadius: CGFloat {
        switch self {
        case .soft: return 6
        case .round: return 14
        case .sharp: return 2
        }
    }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .soft: return l.t("Soft", "ناعمة")
        case .round: return l.t("Round", "دائرية")
        case .sharp: return l.t("Sharp", "حادة")
        }
    }
}

enum BindingStyle: String, Codable, CaseIterable, Identifiable {
    case stitched, leather, spiral
    var id: String { rawValue }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .stitched: return l.t("Stitched", "مخيط")
        case .leather: return l.t("Leather", "كعب جلدي")
        case .spiral: return l.t("Spiral", "سلك")
        }
    }
}

enum PaperTone: String, Codable, CaseIterable, Identifiable {
    case ivory, warmWhite, cream, stone
    var id: String { rawValue }
    var uiColor: UIColor {
        switch self {
        case .ivory: return UIColor(hex: 0xFAF5EA)
        case .warmWhite: return UIColor(hex: 0xFDFBF6)
        case .cream: return UIColor(hex: 0xF4EAD5)
        case .stone: return UIColor(hex: 0xEDEBE5)
        }
    }
    var color: Color { Color(uiColor: uiColor) }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .ivory: return l.t("Ivory", "عاجي")
        case .warmWhite: return l.t("Warm white", "أبيض دافئ")
        case .cream: return l.t("Cream", "كريمي")
        case .stone: return l.t("Stone", "حجري")
        }
    }
}

enum PaperPattern: String, Codable, CaseIterable, Identifiable {
    case lined, dotted, grid, blank
    var id: String { rawValue }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .lined: return l.t("Lined", "مسطّر")
        case .dotted: return l.t("Dotted", "منقّط")
        case .grid: return l.t("Grid", "مربعات")
        case .blank: return l.t("Blank", "سادة")
        }
    }
}

/// Calm, luxurious cover leathers. Separate from the app's own interface palette.
enum CoverColor: String, Codable, CaseIterable, Identifiable {
    case teal, ink, burgundy, sage, sand, linen, charcoal, terracotta, blush
    var id: String { rawValue }
    var uiColor: UIColor {
        switch self {
        case .teal: return UIColor(hex: 0x4F7C7A)
        case .ink: return UIColor(hex: 0x27344B)
        case .burgundy: return UIColor(hex: 0x6C2E35)
        case .sage: return UIColor(hex: 0x8C9A7E)
        case .sand: return UIColor(hex: 0xCBB592)
        case .linen: return UIColor(hex: 0xEDE4D1)
        case .charcoal: return UIColor(hex: 0x34332F)
        case .terracotta: return UIColor(hex: 0xA6644C)
        case .blush: return UIColor(hex: 0xD8BCB0)
        }
    }
    var color: Color { Color(uiColor: uiColor) }
    var isLight: Bool { self == .sand || self == .linen || self == .blush }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .teal: return l.t("Muted teal", "أزرق مخضر")
        case .ink: return l.t("Ink blue", "أزرق حبري")
        case .burgundy: return l.t("Burgundy", "عنابي")
        case .sage: return l.t("Sage", "مريمية")
        case .sand: return l.t("Sand", "رملي")
        case .linen: return l.t("Linen", "كتّاني")
        case .charcoal: return l.t("Charcoal", "فحمي")
        case .terracotta: return l.t("Terracotta", "طيني")
        case .blush: return l.t("Blush", "وردي هادئ")
        }
    }
}

enum CoverArt: String, Codable, CaseIterable, Identifiable {
    case plain, goldFrame, rosette, band, photo
    var id: String { rawValue }
    static var readyMade: [CoverArt] { [.plain, .goldFrame, .rosette, .band] }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .plain: return l.t("Plain", "سادة")
        case .goldFrame: return l.t("Gold frame", "إطار ذهبي")
        case .rosette: return l.t("Rosette", "نجمة")
        case .band: return l.t("Band", "شريط")
        case .photo: return l.t("Photo", "صورة")
        }
    }
}

struct NotebookStyle: Codable, Equatable {
    var proportion: NotebookProportion = .classic
    var corner: CornerStyle = .soft
    var binding: BindingStyle = .stitched
    var paperTone: PaperTone = .ivory
    var pattern: PaperPattern = .lined
    var coverColor: CoverColor = .teal
    var coverArt: CoverArt = .goldFrame
    /// Photo crop: zoom factor (>= 1) and offset as a fraction of the cover size.
    var photoScale: Double = 1
    var photoOffsetX: Double = 0
    var photoOffsetY: Double = 0
}

// MARK: - Bullet Journal content

enum ItemState: String, Codable {
    case task, done, migrated, event, note, dropped
}

struct BulletItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String = ""
    var state: ItemState = .task
    /// Set when the item was migrated here from an earlier page.
    var originPage: UUID?
}

struct DailyData: Codable, Equatable {
    var date: Date
    var priorities: [BulletItem]
    var items: [BulletItem]
}

struct MonthData: Codable, Equatable {
    var year: Int
    var month: Int
    /// One key event per day, index 0 == day 1.
    var events: [String]
}

struct MonthPlanData: Codable, Equatable {
    var year: Int
    var month: Int
    var goals: [BulletItem]
}

struct Habit: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday) the habit is planned for.
    var weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    /// Days of the month on which the habit was done.
    var done: [Int] = []
}

struct HabitData: Codable, Equatable {
    var year: Int
    var month: Int
    var habits: [Habit]
    /// One short plan line per week; week 1 is planned first, the rest adjusted as the month goes.
    var weekPlans: [String]
}

enum ThoughtKind: String, Codable, CaseIterable, Identifiable {
    case thought, note, event, feeling
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .thought: return "sparkle"
        case .note: return "minus"
        case .event: return "circle"
        case .feeling: return "heart"
        }
    }
    func name(_ l: AppLanguage) -> String {
        switch self {
        case .thought: return l.t("Thought", "فكرة")
        case .note: return l.t("Note", "ملاحظة")
        case .event: return l.t("Event", "حدث")
        case .feeling: return l.t("Feeling", "شعور")
        }
    }
}

struct Thought: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ThoughtKind
    var text: String
    /// The circumstances — where, with whom, what happened around it.
    var context: String
    var time: Date
}

struct ThoughtsData: Codable, Equatable {
    var date: Date
    var entries: [Thought]
}

// MARK: - Pages and notebooks

enum PageKind: String, Codable {
    case free, daily, monthCalendar, monthPlan, habits, thoughts, index
}

struct PageRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: PageKind = .free
    var createdAt = Date()
    var daily: DailyData?
    var month: MonthData?
    var monthPlan: MonthPlanData?
    var habits: HabitData?
    var thoughts: ThoughtsData?
    /// First line of the page's free text, refreshed on save; used by the index.
    var titleHint: String?
    var hasDrawing: Bool = false

    static func blank() -> PageRecord { PageRecord() }

    static func daily(_ date: Date) -> PageRecord {
        var p = PageRecord(kind: .daily)
        p.daily = DailyData(date: date, priorities: [BulletItem(), BulletItem(), BulletItem()], items: [])
        return p
    }

    static func monthCalendar(year: Int, month: Int) -> PageRecord {
        var p = PageRecord(kind: .monthCalendar)
        let days = BJCalendar.daysIn(year: year, month: month)
        p.month = MonthData(year: year, month: month, events: Array(repeating: "", count: days))
        return p
    }

    static func monthPlan(year: Int, month: Int) -> PageRecord {
        var p = PageRecord(kind: .monthPlan)
        p.monthPlan = MonthPlanData(year: year, month: month, goals: [])
        return p
    }

    static func habits(year: Int, month: Int) -> PageRecord {
        var p = PageRecord(kind: .habits)
        let weeks = BJCalendar.weekCount(year: year, month: month)
        p.habits = HabitData(year: year, month: month, habits: [Habit()], weekPlans: Array(repeating: "", count: weeks))
        return p
    }

    static func thoughts(_ date: Date) -> PageRecord {
        var p = PageRecord(kind: .thoughts)
        p.thoughts = ThoughtsData(date: date, entries: [])
        return p
    }

    static func index() -> PageRecord { PageRecord(kind: .index) }
}

struct NotebookMeta: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var updatedAt = Date()
    var style: NotebookStyle
    /// Reading direction of this notebook (Arabic notebooks turn right-to-left).
    var language: AppLanguage
    var hasCoverPhoto: Bool = false
    var pages: [PageRecord]
}
