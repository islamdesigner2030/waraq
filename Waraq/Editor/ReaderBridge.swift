import SwiftUI
import Observation

/// Connects the SwiftUI chrome (toolbar, save) with the UIKit reader.
@Observable
final class ReaderBridge {
    /// Where the page sits on screen (full-screen coordinates), published by the reader.
    var pageFrame: CGRect = .zero
    @ObservationIgnored weak var controller: ReaderViewController?
}

struct ReaderRepresentable: UIViewControllerRepresentable {
    let session: NotebookSession
    let bridge: ReaderBridge
    let showTurnHint: Bool

    func makeUIViewController(context: Context) -> ReaderViewController {
        let vc = ReaderViewController(session: session, bridge: bridge)
        vc.wantsTurnHint = showTurnHint
        bridge.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: ReaderViewController, context: Context) {}
}
