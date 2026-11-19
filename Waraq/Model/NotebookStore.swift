import Foundation
import UIKit
import PencilKit

/// Plain files in Application Support — nothing leaves the device.
///
///     Notebooks/<notebook-id>/notebook.json      metadata + every page record (templates inline)
///     Notebooks/<notebook-id>/cover.jpg          optional cover photo
///     Notebooks/<notebook-id>/pages/<page>.rtf   free text with its formatting
///     Notebooks/<notebook-id>/pages/<page>.drawing  PencilKit drawing
final class NotebookStore {
    static let shared = NotebookStore()

    let root: URL
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        root = base.appendingPathComponent("Notebooks", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: Paths

    func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func pagesFolder(_ id: UUID) -> URL { folder(id).appendingPathComponent("pages", isDirectory: true) }
    private func metaURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("notebook.json") }
    private func coverURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("cover.jpg") }
    private func textURL(_ nb: UUID, _ page: UUID) -> URL { pagesFolder(nb).appendingPathComponent(page.uuidString + ".rtf") }
    private func drawingURL(_ nb: UUID, _ page: UUID) -> URL { pagesFolder(nb).appendingPathComponent(page.uuidString + ".drawing") }

    // MARK: Notebooks

    func loadAllMeta() -> [NotebookMeta] {
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        let metas = dirs.compactMap { dir -> NotebookMeta? in
            let url = dir.appendingPathComponent("notebook.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(NotebookMeta.self, from: data)
        }
        return metas.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadMeta(_ id: UUID) -> NotebookMeta? {
        guard let data = try? Data(contentsOf: metaURL(id)) else { return nil }
        return try? decoder.decode(NotebookMeta.self, from: data)
    }

    func writeMeta(_ meta: NotebookMeta) throws {
        try fm.createDirectory(at: pagesFolder(meta.id), withIntermediateDirectories: true)
        let data = try encoder.encode(meta)
        try data.write(to: metaURL(meta.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func deleteNotebook(_ id: UUID) {
        try? fm.removeItem(at: folder(id))
    }

    // MARK: Cover

    func writeCover(_ image: UIImage?, for id: UUID) throws {
        try fm.createDirectory(at: folder(id), withIntermediateDirectories: true)
        if let image, let data = image.jpegData(compressionQuality: 0.86) {
            try data.write(to: coverURL(id), options: [.atomic])
        } else {
            try? fm.removeItem(at: coverURL(id))
        }
    }

    func loadCover(for id: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: coverURL(id)) else { return nil }
        return UIImage(data: data)
    }

    // MARK: Page files

    func loadText(notebook: UUID, page: UUID) -> NSAttributedString? {
        guard let data = try? Data(contentsOf: textURL(notebook, page)) else { return nil }
        return try? NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
    }

    func writeText(_ text: NSAttributedString, notebook: UUID, page: UUID) throws {
        let url = textURL(notebook, page)
        if text.length == 0 {
            try? fm.removeItem(at: url)
            return
        }
        try fm.createDirectory(at: pagesFolder(notebook), withIntermediateDirectories: true)
        let data = try text.data(from: NSRange(location: 0, length: text.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func loadDrawing(notebook: UUID, page: UUID) -> PKDrawing? {
        guard let data = try? Data(contentsOf: drawingURL(notebook, page)) else { return nil }
        return try? PKDrawing(data: data)
    }

    func writeDrawing(_ drawing: PKDrawing, notebook: UUID, page: UUID) throws {
        let url = drawingURL(notebook, page)
        if drawing.strokes.isEmpty {
            try? fm.removeItem(at: url)
            return
        }
        try fm.createDirectory(at: pagesFolder(notebook), withIntermediateDirectories: true)
        try drawing.dataRepresentation().write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func deletePageFiles(notebook: UUID, page: UUID) {
        try? fm.removeItem(at: textURL(notebook, page))
        try? fm.removeItem(at: drawingURL(notebook, page))
    }
}
