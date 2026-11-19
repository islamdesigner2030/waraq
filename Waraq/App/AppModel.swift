import SwiftUI
import Observation

enum Route: Equatable {
    case language
    case welcome
    case home
    case create
    case editor(UUID, opening: Bool)
}

/// App-wide state: language, sound preference, the notebook shelf and where we are.
/// Only basic settings live in UserDefaults; notebooks are files (see `NotebookStore`).
@Observable
final class AppModel {
    private enum Keys {
        static let language = "appLanguage"
        static let sound = "pageSound"
        static let turnHintShown = AppModel.turnHintKey
    }

    static let turnHintKey = "turnHintShown"

    private(set) var language: AppLanguage?
    private(set) var soundEnabled: Bool
    var route: Route
    private(set) var notebooks: [NotebookMeta] = []

    let store = NotebookStore.shared
    @ObservationIgnored private var coverCache: [UUID: UIImage] = [:]

    init() {
        let d = UserDefaults.standard
        #if DEBUG
        // UI screenshot tests start from a clean install: no language, no notebooks, no turn hint.
        if ProcessInfo.processInfo.environment["WARAQ_RESET"] == "1" {
            for key in d.dictionaryRepresentation().keys
            where key == Keys.language || key == Keys.sound || key.hasPrefix("lastPage.") {
                d.removeObject(forKey: key)
            }
            d.set(true, forKey: Keys.turnHintShown)
            try? FileManager.default.removeItem(at: NotebookStore.shared.root)
            try? FileManager.default.createDirectory(at: NotebookStore.shared.root, withIntermediateDirectories: true)
        }
        #endif
        let lang = d.string(forKey: Keys.language).flatMap(AppLanguage.init(rawValue:))
        language = lang
        soundEnabled = (d.object(forKey: Keys.sound) as? Bool) ?? true
        route = lang == nil ? .language : .welcome
        notebooks = store.loadAllMeta()
        PaperSound.shared.isEnabled = soundEnabled
    }

    var currentLanguage: AppLanguage { language ?? .english }

    func setLanguage(_ lang: AppLanguage) {
        language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: Keys.language)
    }

    func setSound(_ on: Bool) {
        soundEnabled = on
        PaperSound.shared.isEnabled = on
        UserDefaults.standard.set(on, forKey: Keys.sound)
    }

    var turnHintShown: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.turnHintShown) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.turnHintShown) }
    }

    // MARK: Notebooks

    func reload() {
        notebooks = store.loadAllMeta()
    }

    func cover(for meta: NotebookMeta) -> UIImage? {
        guard meta.hasCoverPhoto else { return nil }
        if let img = coverCache[meta.id] { return img }
        let img = store.loadCover(for: meta.id)
        coverCache[meta.id] = img
        return img
    }

    /// Creates the notebook with one blank first page and opens it with the cover animation.
    func createNotebook(name: String, style: NotebookStyle, photo: UIImage?) {
        var style = style
        let usePhoto = style.coverArt == .photo && photo != nil
        if style.coverArt == .photo && photo == nil { style.coverArt = .plain }
        let meta = NotebookMeta(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                style: style,
                                language: currentLanguage,
                                hasCoverPhoto: usePhoto,
                                pages: [.blank()])
        do {
            if usePhoto { try store.writeCover(photo, for: meta.id) }
            try store.writeMeta(meta)
        } catch {
            return
        }
        if usePhoto { coverCache[meta.id] = photo }
        reload()
        route = .editor(meta.id, opening: true)
    }

    func makeSession(_ id: UUID) -> NotebookSession? {
        guard let meta = store.loadMeta(id) else { return nil }
        let last = UserDefaults.standard.object(forKey: NotebookSession.lastPageKey(id)) as? Int ?? 0
        return NotebookSession(meta: meta, store: store, startIndex: last)
    }

    func open(_ id: UUID) {
        route = .editor(id, opening: true)
    }

    func closeEditor() {
        reload()
        route = .home
    }

    func delete(_ id: UUID) {
        store.deleteNotebook(id)
        coverCache[id] = nil
        UserDefaults.standard.removeObject(forKey: NotebookSession.lastPageKey(id))
        reload()
    }
}
