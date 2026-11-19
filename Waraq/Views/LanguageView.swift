import SwiftUI

/// First launch only: choose Arabic or English. No account, nothing else.
struct LanguageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 10) {
                    Text("أهلًا بك")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                    Text("Welcome")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.inkSoft)
                }
                .foregroundStyle(Palette.ink)
                .opacity(appear ? 1 : 0)
                .offset(y: appear || reduceMotion ? 0 : 6)

                Capsule()
                    .fill(Palette.champagne)
                    .frame(width: 36, height: 1.5)
                    .padding(.vertical, 34)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: 14) {
                    choice(.arabic, subtitle: "اكتب من اليمين إلى اليسار")
                    choice(.english, subtitle: "Write from left to right")
                }
                .opacity(appear ? 1 : 0)
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appear = true }
        }
    }

    private func choice(_ lang: AppLanguage, subtitle: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            model.setLanguage(lang)
            model.route = .welcome
        } label: {
            VStack(spacing: 3) {
                Text(lang.displayName)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: 250, height: 70)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.layoutDirection, lang.layoutDirection)
        .accessibilityIdentifier("lang." + lang.rawValue)
    }
}
