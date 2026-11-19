import SwiftUI

/// Calm ivory backdrop with faint warm light, like good paper under a window.
struct WarmBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.warmWhite, Palette.ivory, Color(hex: 0xF2EADB)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.75), .clear],
                           center: UnitPoint(x: 0.25, y: 0.12), startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Palette.champagne.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.85, y: 0.85), startRadius: 10, endRadius: 380)
            PaperGrainView(opacity: 0.35)
        }
        .ignoresSafeArea()
    }
}

/// The desk the open notebook rests on.
struct DeskBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xEFE7D8), Color(hex: 0xE5DBC8)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.45), .clear],
                           center: UnitPoint(x: 0.5, y: 0.35), startRadius: 20, endRadius: 520)
            PaperGrainView(opacity: 0.25)
        }
        .ignoresSafeArea()
    }
}

/// A small round Liquid Glass button with an SF Symbol.
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var size: CGFloat = 44
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.85))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

/// Capsule glass button with icon + text.
struct GlassCapsuleButton: View {
    let systemName: String
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(.callout, design: .default, weight: .semibold))
            }
            .foregroundStyle(prominent ? Color.white : Palette.ink)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? Glass.regular.tint(Palette.mutedTeal).interactive() : Glass.regular.interactive(), in: Capsule())
    }
}

extension View {
    /// Soft, layered paper shadow.
    func paperShadow(_ strength: Double = 1) -> some View {
        self
            .shadow(color: .black.opacity(0.10 * strength), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.12 * strength), radius: 14, x: 0, y: 10)
    }
}
