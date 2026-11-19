import SwiftUI
import PencilKit

/// Finger drawing with PencilKit. Shown only while drawing mode is on for the current page;
/// otherwise the page shows a cached image of the same drawing.
struct DrawingCanvas: UIViewRepresentable {
    let session: NotebookSession
    let pageID: UUID

    func makeCoordinator() -> Coordinator { Coordinator(session: session, pageID: pageID) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawing = session.drawing(for: pageID)
        canvas.tool = PKInkingTool(.pen, color: UIColor(hex: 0x2B2A27), width: 2.4)
        canvas.delegate = context.coordinator
        canvas.accessibilityLabel = session.lang.t("Drawing area", "مساحة الرسم")

        let picker = context.coordinator.picker
        picker.addObserver(canvas)
        DispatchQueue.main.async {
            picker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.picker.setVisible(false, forFirstResponder: canvas)
        coordinator.picker.removeObserver(canvas)
        canvas.resignFirstResponder()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let session: NotebookSession
        let pageID: UUID
        let picker = PKToolPicker()

        init(session: NotebookSession, pageID: UUID) {
            self.session = session
            self.pageID = pageID
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            session.setDrawing(canvasView.drawing, for: pageID)
        }
    }
}
