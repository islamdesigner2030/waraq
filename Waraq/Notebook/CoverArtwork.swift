import SwiftUI

/// Notebook cover outline: binding side nearly square, opening side rounded.
struct CoverShape: Shape {
    var spineOnLeft: Bool
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = min(4, radius)
        let radii = spineOnLeft
            ? RectangleCornerRadii(topLeading: s, bottomLeading: s, bottomTrailing: radius, topTrailing: radius)
            : RectangleCornerRadii(topLeading: radius, bottomLeading: radius, bottomTrailing: s, topTrailing: s)
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}

/// The front cover of a notebook — leather colour, ready-made art or a photo,
/// gold-foil name and the binding. Always laid out left-to-right; `spineOnLeft` places the binding.
struct CoverArtwork: View {
    let style: NotebookStyle
    let name: String
    let photo: UIImage?
    let spineOnLeft: Bool

    private var gold: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xE6CF9A), Palette.champagne, Color(hex: 0xA88849)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                style.coverColor.color
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.16)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                LinenView(opacity: 1).blendMode(.overlay)

                art(size: size)

                if !name.isEmpty && style.coverArt != .photo {
                    Text(name)
                        .font(.system(size: max(12, size.width * 0.075), weight: .medium, design: .serif))
                        .tracking(size.width * 0.004)
                        .foregroundStyle(gold)
                        .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 0.6)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: size.width * 0.62)
                        .position(x: size.width * (spineOnLeft ? 0.53 : 0.47), y: size.height * (style.coverArt == .rosette ? 0.78 : 0.34))
                }

                spine(size: size)
            }
            .clipShape(CoverShape(spineOnLeft: spineOnLeft, radius: style.corner.coverRadius * size.width / 260))
            .overlay {
                CoverShape(spineOnLeft: spineOnLeft, radius: style.corner.coverRadius * size.width / 260)
                    .stroke(.white.opacity(0.18), lineWidth: 0.6)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func art(size: CGSize) -> some View {
        switch style.coverArt {
        case .plain:
            EmptyView()
        case .goldFrame:
            let inset = size.width * 0.075
            ZStack {
                Rectangle()
                    .strokeBorder(gold, lineWidth: max(0.8, size.width * 0.004))
                    .padding(inset)
                Rectangle()
                    .strokeBorder(Palette.champagne.opacity(0.7), lineWidth: max(0.5, size.width * 0.002))
                    .padding(inset + size.width * 0.018)
            }
            .padding(spineOnLeft ? .leading : .trailing, size.width * 0.06)
        case .rosette:
            Rosette()
                .stroke(gold, lineWidth: max(0.6, size.width * 0.0035))
                .frame(width: size.width * 0.46, height: size.width * 0.46)
                .position(x: size.width * (spineOnLeft ? 0.53 : 0.47), y: size.height * 0.42)
                .opacity(0.9)
        case .band:
            Rectangle()
                .fill(.black.opacity(0.22))
                .overlay(Rectangle().fill(.white.opacity(0.06)).frame(width: 1), alignment: .leading)
                .frame(width: max(6, size.width * 0.035))
                .position(x: spineOnLeft ? size.width * 0.86 : size.width * 0.14, y: size.height / 2)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(CGFloat(max(1, style.photoScale)))
                    .offset(x: CGFloat(style.photoOffsetX) * size.width, y: CGFloat(style.photoOffsetY) * size.height)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.15)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
    }

    private func spine(size: CGSize) -> some View {
        let w = max(8, size.width * (style.binding == .leather ? 0.11 : 0.06))
        return ZStack {
            switch style.binding {
            case .leather:
                Rectangle().fill(Color.black.opacity(0.28))
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.2)],
                                                startPoint: .leading, endPoint: .trailing))
            case .stitched:
                Rectangle().fill(LinearGradient(colors: [.black.opacity(0.22), .black.opacity(0.06)],
                                                startPoint: spineOnLeft ? .leading : .trailing,
                                                endPoint: spineOnLeft ? .trailing : .leading))
                Path { p in
                    let x = spineOnLeft ? w * 0.72 : w * 0.28
                    p.move(to: CGPoint(x: x, y: 8))
                    p.addLine(to: CGPoint(x: x, y: size.height - 8))
                }
                .stroke(Palette.champagne.opacity(0.55), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2.5]))
            case .spiral:
                Rectangle().fill(Color.black.opacity(0.12))
                VStack(spacing: 0) {
                    ForEach(0..<max(4, Int(size.height / 15)), id: \.self) { _ in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0xEDEDED), Color(hex: 0x8D8D8D)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: w * 1.2, height: 2.6)
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: w, height: size.height)
        .position(x: spineOnLeft ? w / 2 : size.width - w / 2, y: size.height / 2)
    }
}

/// An eight-point star rosette — abstract, geometric, calm.
struct Rosette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        func star(_ outer: CGFloat, _ inner: CGFloat, rotation: CGFloat) {
            for i in 0..<16 {
                let r = i.isMultiple(of: 2) ? outer : inner
                let a = CGFloat(i) * .pi / 8 + rotation
                let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        star(R, R * 0.72, rotation: -.pi / 2)
        star(R * 0.62, R * 0.46, rotation: -.pi / 2 + .pi / 8)
        p.addEllipse(in: CGRect(x: c.x - R * 0.2, y: c.y - R * 0.2, width: R * 0.4, height: R * 0.4))
        // two squares rotated 45° — the classic khatam
        for k in 0..<2 {
            let a0 = CGFloat(k) * .pi / 4
            for i in 0...4 {
                let a = a0 + CGFloat(i) * .pi / 2
                let pt = CGPoint(x: c.x + cos(a) * R * 0.86, y: c.y + sin(a) * R * 0.86)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        return p
    }
}

/// The inside of the front cover (seen during the opening animation).
struct CoverLining: View {
    let style: NotebookStyle
    var body: some View {
        ZStack {
            Color(hex: 0xE8DCC4)
            LinearGradient(colors: [Palette.champagne.opacity(0.18), .clear, Palette.mutedTeal.opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            PaperGrainView(opacity: 1).blendMode(.multiply)
            Rectangle().strokeBorder(style.coverColor.color, lineWidth: 5)
        }
    }
}
