import SwiftUI

/// The front cover swings open around the spine, revealing the first page beneath.
/// Placed exactly over the reader's page frame so the hand-off is seamless.
struct CoverOpeningOverlay: View {
    let style: NotebookStyle
    let name: String
    let photo: UIImage?
    let spineOnLeft: Bool
    let frame: CGRect
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    var body: some View {
        GeometryReader { _ in
            OpeningCover(progress: progress, style: style, name: name, photo: photo, spineOnLeft: spineOnLeft)
                .frame(width: frame.width + 8, height: frame.height + 8)
                .position(x: frame.midX, y: frame.midY)
        }
        .ignoresSafeArea()
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(progress < 0.6)
        .onAppear {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.35)) { progress = 1 } completion: { onFinished() }
            } else {
                withAnimation(.timingCurve(0.45, 0.05, 0.25, 1, duration: 1.25).delay(0.15)) {
                    progress = 1
                } completion: {
                    onFinished()
                }
            }
        }
    }
}

private struct OpeningCover: View, Animatable {
    var progress: Double
    let style: NotebookStyle
    let name: String
    let photo: UIImage?
    let spineOnLeft: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let degrees = progress * 172
        let showInside = degrees > 90
        ZStack {
            // the cover's shadow lifting off the page
            Rectangle()
                .fill(Color.black.opacity(0.22 * (1 - progress) * (progress > 0.02 ? 1 : 0)))
                .blur(radius: 10)
                .padding(4)
            Group {
                if showInside {
                    CoverLining(style: style)
                        .clipShape(CoverShape(spineOnLeft: !spineOnLeft, radius: style.corner.coverRadius))
                } else {
                    CoverArtwork(style: style, name: name, photo: photo, spineOnLeft: spineOnLeft)
                        .overlay(Color.black.opacity(sin(progress * .pi) * 0.18))
                }
            }
            .rotation3DEffect(.degrees(spineOnLeft ? -degrees : degrees),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: spineOnLeft ? UnitPoint(x: 0, y: 0.5) : UnitPoint(x: 1, y: 0.5),
                              perspective: 0.42)
            .opacity(progress > 0.92 ? (1 - progress) / 0.08 : 1)
        }
    }
}
