import SwiftUI

/// Small translucent glass bar at the top. Each tool writes straight into the notebook.
struct FloatingToolbar: View {
    let session: NotebookSession
    let lang: AppLanguage
    let perform: (JournalTool) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                tool("daily", "sun.max", lang.t("Daily", "يومي")) { perform(.daily) }
                tool("monthly", "calendar", lang.t("Month", "شهري")) { perform(.monthly) }
                tool("habits", "leaf", lang.t("Habits", "عادات")) { perform(.habits) }
                tool("thoughts", "cloud", lang.t("Thoughts", "خواطر")) { perform(.thoughts) }
                tool("index", "list.bullet", lang.t("Index", "الفهرس")) { perform(.index) }
                Rectangle().fill(Palette.ink.opacity(0.12)).frame(width: 0.5, height: 26).padding(.horizontal, 2)
                tool("draw", session.drawingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip",
                     lang.t("Draw", "رسم"),
                     active: session.drawingMode) {
                    withAnimation(.snappy) { session.drawingMode.toggle() }
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 54)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private func tool(_ id: String, _ symbol: String, _ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
            action()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(active ? Palette.mutedTeal : Palette.ink.opacity(0.82))
            .frame(width: 40, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("tool." + id)
    }
}
