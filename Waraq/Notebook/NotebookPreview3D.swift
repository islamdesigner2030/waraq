import SwiftUI

/// A light 3D notebook that follows every choice live. Drag to turn it a little.
struct NotebookPreview3D: View {
    let style: NotebookStyle
    let name: String
    let photo: UIImage?
    let spineOnLeft: Bool
    let maxSize: CGSize

    @State private var restYaw: Double = -14
    @GestureState private var dragYaw: Double = 0

    var body: some View {
        let aspect = style.proportion.aspect
        var w = maxSize.width
        var h = w / aspect
        if h > maxSize.height { h = maxSize.height; w = h * aspect }
        let thickness = max(5, w * 0.035)
        let outerSign: CGFloat = spineOnLeft ? 1 : -1

        return ZStack {
            // page block, seen at the opening edge and bottom
            ForEach(0..<3, id: \.self) { i in
                CoverShape(spineOnLeft: spineOnLeft, radius: style.corner.pageRadius)
                    .fill(style.paperTone.color)
                    .overlay(CoverShape(spineOnLeft: spineOnLeft, radius: style.corner.pageRadius)
                        .stroke(.black.opacity(0.10), lineWidth: 0.5))
                    .frame(width: w - 4, height: h - 4)
                    .offset(x: outerSign * thickness * CGFloat(3 - i) / 3, y: thickness * CGFloat(3 - i) / 4)
            }
            // back board
            CoverShape(spineOnLeft: spineOnLeft, radius: style.corner.coverRadius * w / 260)
                .fill(style.coverColor.color.opacity(0.92))
                .frame(width: w, height: h)
                .offset(x: outerSign * thickness * 1.25, y: thickness)
                .zIndex(-1)

            CoverArtwork(style: style, name: name, photo: photo, spineOnLeft: spineOnLeft)
                .frame(width: w, height: h)
        }
        .frame(width: w + thickness * 2, height: h + thickness * 2)
        .rotation3DEffect(.degrees((spineOnLeft ? restYaw : -restYaw) + dragYaw), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(7), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 2)
        .shadow(color: .black.opacity(0.18), radius: 22, x: outerSign * 10, y: 18)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragYaw) { value, state, _ in
                    state = max(-38, min(38, Double(value.translation.width) * 0.25))
                }
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: style)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: dragYaw)
        .accessibilityHidden(true)
    }
}
