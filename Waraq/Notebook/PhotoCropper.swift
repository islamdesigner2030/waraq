import SwiftUI
import UIKit

/// Position and zoom a photo inside the cover frame (drag + pinch). Values are stored
/// relative to the cover size, so the same crop shows at any size.
struct PhotoCropper: View {
    let photo: UIImage
    @Binding var style: NotebookStyle
    let spineOnLeft: Bool

    @State private var startOffset: CGSize?
    @State private var startScale: Double?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            CoverArtwork(style: style, name: "", photo: photo, spineOnLeft: spineOnLeft)
                .overlay {
                    // rule-of-thirds guide while adjusting
                    Path { p in
                        for f: CGFloat in [1.0 / 3, 2.0 / 3] {
                            p.move(to: CGPoint(x: size.width * f, y: 0)); p.addLine(to: CGPoint(x: size.width * f, y: size.height))
                            p.move(to: CGPoint(x: 0, y: size.height * f)); p.addLine(to: CGPoint(x: size.width, y: size.height * f))
                        }
                    }
                    .stroke(.white.opacity(0.35), lineWidth: 0.5)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            let start = startOffset ?? CGSize(width: style.photoOffsetX, height: style.photoOffsetY)
                            if startOffset == nil { startOffset = start }
                            style.photoOffsetX = clampOffset(Double(start.width + v.translation.width / size.width))
                            style.photoOffsetY = clampOffset(Double(start.height + v.translation.height / size.height))
                        }
                        .onEnded { _ in startOffset = nil }
                        .simultaneously(with:
                            MagnifyGesture()
                                .onChanged { v in
                                    let start = startScale ?? style.photoScale
                                    if startScale == nil { startScale = start }
                                    style.photoScale = max(1, min(4, start * Double(v.magnification)))
                                }
                                .onEnded { _ in startScale = nil }
                        )
                )
        }
    }

    private func clampOffset(_ v: Double) -> Double {
        let limit = max(0, (style.photoScale - 1) / 2) + 0.25
        return max(-limit, min(limit, v))
    }
}

extension UIImage {
    /// Keeps covers small on disk and in memory.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let factor = maxDimension / longest
        let newSize = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
