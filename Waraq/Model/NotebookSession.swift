import Foundation
import Observation
import UIKit
import PencilKit

enum JournalTool: String, CaseIterable, Identifiable {
    case daily, monthly, habits, thoughts, index
    var id: String { rawValue }
}

enum ToolResult {
    /// The current page changed in place (a blank page became a template).
    case stay
    /// Turn to this page index.
    case go(Int)
}

/// The open notebook: an in-memory working copy that only reaches disk on `save()`.
@Observable
final class NotebookSession {
    var meta: NotebookMeta
    var currentIndex: Int
    var isDirty = false
    var drawingMode = false
    /// Bumped when typing hits the bottom of the page, so the page can show a gentle hint.
    var pageFullPulse = 0
    var coverImage: UIImage?

    let store: NotebookStore
    @ObservationIgnored private var texts: [UUID: NSAttributedString] = [:]
    @ObservationIgnored private var drawings: [UUID: PKDrawing] = [:]
    @ObservationIgnored private var drawingImages: [UUID: (size: CGSize, image: UIImage)] = [:]
    @ObservationIgnored private var changedTexts: Set<UUID> = []
    @ObservationIgnored private var changedDrawings: Set<UUID> = []
    /// Set by the reader so that the index page can turn to a page.
    @ObservationIgnored var navigator: ((Int) -> Void)?

    init(meta: NotebookMeta, store: NotebookStore = .shared, startIndex: Int) {
        var meta = meta
        if meta.pages.isEmpty { meta.pages = [.blank()] }
        self.meta = meta
        self.store = store
        self.currentIndex = max(0, min(startIndex, meta.pages.count - 1))
        self.coverImage = meta.hasCoverPhoto ? store.loadCover(for: meta.id) : nil
    }

    var lang: AppLanguage { meta.language }
    var pages: [PageRecord] { meta.pages }

    // MARK: Lookup

    func page(_ id: UUID?) -> PageRecord? {
        guard let id else { return nil }
        return meta.pages.first { $0.id == id }
    }

    func index(of id: UUID) -> Int? { meta.pages.firstIndex { $0.id == id } }

    func mutate(_ id: UUID, _ body: (inout PageRecord) -> Void) {
        guard let i = index(of: id) else { return }
        var p = meta.pages[i]
        body(&p)
        if p != meta.pages[i] {
            meta.pages[i] = p
            isDirty = true
        }
    }

    // MARK: Text & drawings

    func text(for id: UUID) -> NSAttributedString {
        if let t = texts[id] { return t }
        let t = store.loadText(notebook: meta.id, page: id) ?? NSAttributedString()
        texts[id] = t
        return t
    }

    func setText(_ text: NSAttributedString, for id: UUID) {
        texts[id] = NSAttributedString(attributedString: text)
        changedTexts.insert(id)
        if !isDirty { isDirty = true }
    }

    func drawing(for id: UUID) -> PKDrawing {
        if let d = drawings[id] { return d }
        let d = store.loadDrawing(notebook: meta.id, page: id) ?? PKDrawing()
        drawings[id] = d
        return d
    }

    func setDrawing(_ drawing: PKDrawing, for id: UUID) {
        drawings[id] = drawing
        drawingImages[id] = nil
        changedDrawings.insert(id)
        let has = !drawing.strokes.isEmpty
        if let i = index(of: id), meta.pages[i].hasDrawing != has {
            meta.pages[i].hasDrawing = has
        }
        if !isDirty { isDirty = true }
    }

    /// Cached raster of a page's drawing, used whenever the page is not being drawn on.
    func drawingImage(for id: UUID, size: CGSize, scale: CGFloat) -> UIImage? {
        guard page(id)?.hasDrawing == true else { return nil }
        if let cached = drawingImages[id], cached.size == size { return cached.image }
        let d = drawing(for: id)
        guard !d.strokes.isEmpty else { return nil }
        let image = d.image(from: CGRect(origin: .zero, size: size), scale: scale)
        drawingImages[id] = (size, image)
        return image
    }

    func isBlank(_ p: PageRecord) -> Bool {
        p.kind == .free && !p.hasDrawing && text(for: p.id).string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Pages

    /// Turning past the last page adds a page with the same paper.
    @discardableResult
    func appendBlankPage() -> Int {
        meta.pages.append(.blank())
        isDirty = true
        return meta.pages.count - 1
    }

    private func place(_ new: [PageRecord]) -> ToolResult {
        guard !new.isEmpty else { return .stay }
        let current = meta.pages[currentIndex]
        isDirty = true
        if isBlank(current) {
            meta.pages[currentIndex] = new[0]
            texts[current.id] = nil
            drawings[current.id] = nil
            changedTexts.remove(current.id)
            changedDrawings.remove(current.id)
            store.deletePageFiles(notebook: meta.id, page: current.id)
            meta.pages.insert(contentsOf: new.dropFirst(), at: currentIndex + 1)
            return .stay
        }
        // keep a month's calendar and plan side by side
        var insertAt = currentIndex + 1
        if current.kind == .monthCalendar, insertAt < meta.pages.count, meta.pages[insertAt].kind == .monthPlan {
            insertAt += 1
        }
        meta.pages.insert(contentsOf: new, at: insertAt)
        return .go(insertAt)
    }

    private func found(_ i: Int) -> ToolResult { i == currentIndex ? .stay : .go(i) }

    /// Toolbar tools write their templates straight into the notebook.
    func apply(_ tool: JournalTool, today: Date = Date()) -> ToolResult {
        let cal = BJCalendar.gregorian
        let (y, m) = BJCalendar.yearMonth(of: today)
        switch tool {
        case .daily:
            if let i = meta.pages.firstIndex(where: { $0.kind == .daily && cal.isDate($0.daily?.date ?? .distantPast, inSameDayAs: today) }) {
                return found(i)
            }
            return place([.daily(today)])
        case .monthly:
            if let i = meta.pages.firstIndex(where: { $0.kind == .monthCalendar && $0.month?.year == y && $0.month?.month == m }) {
                return found(i)
            }
            return place([.monthCalendar(year: y, month: m), .monthPlan(year: y, month: m)])
        case .habits:
            if let i = meta.pages.firstIndex(where: { $0.kind == .habits && $0.habits?.year == y && $0.habits?.month == m }) {
                return found(i)
            }
            return place([.habits(year: y, month: m)])
        case .thoughts:
            let cur = meta.pages[currentIndex]
            if cur.kind == .thoughts, cal.isDate(cur.thoughts?.date ?? .distantPast, inSameDayAs: today), !thoughtsPageIsFull(cur) {
                return .stay
            }
            return place([.thoughts(today)])
        case .index:
            if let i = meta.pages.firstIndex(where: { $0.kind == .index }) { return found(i) }
            if isBlank(meta.pages[currentIndex]) && currentIndex == 0 {
                return place([.index()])
            }
            meta.pages.insert(.index(), at: 0)
            currentIndex += 1
            isDirty = true
            return .go(0)
        }
    }

    /// Thoughts pages hold a limited number of short entries; a full one starts a fresh page.
    @ObservationIgnored var thoughtsCapacity: Int = 9
    func thoughtsPageIsFull(_ p: PageRecord) -> Bool {
        (p.thoughts?.entries.count ?? 0) >= thoughtsCapacity
    }

    // MARK: Bullet Journal logic

    struct PendingTask: Identifiable {
        var id: UUID { item.id }
        let pageID: UUID
        let item: BulletItem
        let date: Date
    }

    /// Open tasks left on earlier daily pages — the "review" in the daily log.
    func pendingTasks(before date: Date, excluding pageID: UUID) -> [PendingTask] {
        let start = BJCalendar.gregorian.startOfDay(for: date)
        var result: [PendingTask] = []
        for p in meta.pages where p.kind == .daily && p.id != pageID {
            guard let d = p.daily, d.date < start else { continue }
            for item in d.priorities + d.items where item.state == .task && !item.text.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(PendingTask(pageID: p.id, item: item, date: d.date))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private func setState(_ state: ItemState, item: UUID, on pageID: UUID) {
        mutate(pageID) { p in
            guard var d = p.daily else { return }
            if let i = d.items.firstIndex(where: { $0.id == item }) { d.items[i].state = state }
            if let i = d.priorities.firstIndex(where: { $0.id == item }) { d.priorities[i].state = state }
            p.daily = d
        }
    }

    /// Migration: the old task gets ">" and a copy joins today's list.
    func migrate(_ task: PendingTask, to pageID: UUID) {
        setState(.migrated, item: task.item.id, on: task.pageID)
        mutate(pageID) { p in
            p.daily?.items.append(BulletItem(text: task.item.text, state: .task, originPage: task.pageID))
        }
    }

    func complete(_ task: PendingTask) { setState(.done, item: task.item.id, on: task.pageID) }
    func drop(_ task: PendingTask) { setState(.dropped, item: task.item.id, on: task.pageID) }

    func habitPageID(year: Int, month: Int) -> UUID? {
        meta.pages.first { $0.kind == .habits && $0.habits?.year == year && $0.habits?.month == month }?.id
    }

    func toggleHabit(page: UUID, habit: UUID, day: Int) {
        mutate(page) { p in
            guard var h = p.habits, let i = h.habits.firstIndex(where: { $0.id == habit }) else { return }
            if let j = h.habits[i].done.firstIndex(of: day) {
                h.habits[i].done.remove(at: j)
            } else {
                h.habits[i].done.append(day)
            }
            p.habits = h
        }
    }

    // MARK: Titles (index)

    func title(for p: PageRecord) -> String {
        let l = lang
        switch p.kind {
        case .daily:
            return BJCalendar.dayTitle(p.daily?.date ?? p.createdAt, lang: l) + " · " + BJCalendar.shortDate(p.daily?.date ?? p.createdAt, lang: l)
        case .monthCalendar:
            let mo = p.month
            return BJCalendar.monthTitle(year: mo?.year ?? 2026, month: mo?.month ?? 1, lang: l) + " · " + l.t("Calendar", "التقويم")
        case .monthPlan:
            let mo = p.monthPlan
            return BJCalendar.monthName(year: mo?.year ?? 2026, month: mo?.month ?? 1, lang: l) + " · " + l.t("Plan", "الخطة")
        case .habits:
            let h = p.habits
            return l.t("Habits", "العادات") + " · " + BJCalendar.monthName(year: h?.year ?? 2026, month: h?.month ?? 1, lang: l)
        case .thoughts:
            return l.t("Thoughts", "خواطر") + " · " + BJCalendar.shortDate(p.thoughts?.date ?? p.createdAt, lang: l)
        case .index:
            return l.t("Index", "الفهرس")
        case .free:
            let first = text(for: p.id).string
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            if let first { return String(first.prefix(40)) }
            if p.hasDrawing { return l.t("Sketch", "رسم") }
            return l.t("Blank page", "صفحة فارغة")
        }
    }

    // MARK: Saving

    func save() throws {
        for i in meta.pages.indices where meta.pages[i].kind == .free {
            let id = meta.pages[i].id
            let first = text(for: id).string
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            meta.pages[i].titleHint = first.map { String($0.prefix(40)) }
        }
        let liveIDs = Set(meta.pages.map(\.id))
        for id in changedTexts where liveIDs.contains(id) {
            try store.writeText(texts[id] ?? NSAttributedString(), notebook: meta.id, page: id)
        }
        for id in changedDrawings where liveIDs.contains(id) {
            try store.writeDrawing(drawings[id] ?? PKDrawing(), notebook: meta.id, page: id)
        }
        meta.updatedAt = Date()
        try store.writeMeta(meta)
        changedTexts.removeAll()
        changedDrawings.removeAll()
        isDirty = false
    }

    // MARK: Last page

    static func lastPageKey(_ id: UUID) -> String { "lastPage." + id.uuidString }

    func rememberCurrentPage() {
        UserDefaults.standard.set(currentIndex, forKey: Self.lastPageKey(meta.id))
    }
}
