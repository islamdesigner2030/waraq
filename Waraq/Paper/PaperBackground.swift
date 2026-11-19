import SwiftUI

/// Page outline: square at the spine, softly rounded at the outer edge.
struct PageShape: Shape {
    var spineOnLeft: Bool
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let spine: CGFloat = 1.5
        let radii = spineOnLeft
            ? RectangleCornerRadii(topLeading: spine, bottomLeading: spine, bottomTrailing: radius, topTrailing: radius)
            : RectangleCornerRadii(topLeading: radius, bottomLeading: radius, bottomTrailing: spine, topTrailing: spine)
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}

/// A sheet of paper: tone, grain, printed pattern, binding crease and edge light.
/// Drawn in absolute (left-to-right) coordinates; `spineOnLeft` decides the binding side.
struct PaperBackground: View {
    let tone: PaperTone
    let pattern: PaperPattern
    let binding: BindingStyle
    let spineOnLeft: Bool

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tone.color))
            drawPattern(in: &ctx, size: size)
            if binding == .spiral { drawHoles(in: &ctx, size: size) }
        }
        .overlay { PaperGrainView(opacity: 0.9).blendMode(.multiply) }
        .overlay { edgeLight }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
    }

    private func drawPattern(in ctx: inout GraphicsContext, size: CGSize) {
        let L = PageMetrics.line
        let top = PageMetrics.top
        let bottom = size.height - PageMetrics.bottom
        let left: CGFloat = spineOnLeft ? PageMetrics.spine - 8 : PageMetrics.outer - 8
        let right: CGFloat = size.width - (spineOnLeft ? PageMetrics.outer - 8 : PageMetrics.spine - 8)
        let ink = Palette.rule

        switch pattern {
        case .lined:
            var path = Path()
            var y = top + L
            while y <= bottom + 0.5 {
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
                y += L
            }
            ctx.stroke(path, with: .color(ink.opacity(0.30)), lineWidth: 0.6)
        case .dotted:
            let step = L / 2
            var dots = Path()
            var y = top + step
            while y <= bottom + 0.5 {
                var x = left + 2
                while x <= right {
                    dots.addEllipse(in: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6))
                    x += step
                }
                y += step
            }
            ctx.fill(dots, with: .color(ink.opacity(0.42)))
        case .grid:
            let step = L / 2
            var grid = Path()
            var y = top + step
            while y <= bottom + 0.5 {
                grid.move(to: CGPoint(x: left, y: y))
                grid.addLine(to: CGPoint(x: right, y: y))
                y += step
            }
            var x = left
            while x <= right {
                grid.move(to: CGPoint(x: x, y: top + step))
                grid.addLine(to: CGPoint(x: x, y: max(top + step, y - step)))
                x += step
            }
            ctx.stroke(grid, with: .color(ink.opacity(0.17)), lineWidth: 0.45)
        case .blank:
            break
        }
    }

    private func drawHoles(in ctx: inout GraphicsContext, size: CGSize) {
        let x: CGFloat = spineOnLeft ? 9 : size.width - 9
        var y: CGFloat = 18
        while y < size.height - 12 {
            let r = CGRect(x: x - 3.4, y: y - 3.4, width: 6.8, height: 6.8)
            ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: 0xCFC4B0)))
            ctx.stroke(Path(ellipseIn: r), with: .color(.black.opacity(0.18)), lineWidth: 0.6)
            y += 21
        }
    }

    private var edgeLight: some View {
        ZStack {
            // binding crease: the paper dips into the spine
            LinearGradient(colors: [.black.opacity(binding == .leather ? 0.16 : 0.11), .black.opacity(0.03), .clear],
                           startPoint: spineOnLeft ? .leading : .trailing,
                           endPoint: spineOnLeft ? UnitPoint(x: 0.09, y: 0.5) : UnitPoint(x: 0.91, y: 0.5))
            // the outer edge catches a little light then falls off
            LinearGradient(colors: [.clear, .black.opacity(0.035)],
                           startPoint: spineOnLeft ? UnitPoint(x: 0.96, y: 0.5) : UnitPoint(x: 0.04, y: 0.5),
                           endPoint: spineOnLeft ? .trailing : .leading)
            LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.025)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}
