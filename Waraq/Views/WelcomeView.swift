import SwiftUI

/// A short, quiet welcome on every launch. Tap anywhere to skip.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appLanguage) private var lang
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 22) {
                Spacer()
                Text(lang.t("Every Page, A New Beginning.", "كل صفحة… بداية جديدة."))
                    .font(AppFont.calligraphy(lang, size: lang == .arabic ? 46 : 50))
                    .foregroundStyle(Palette.ink.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 30)
                    .opacity(appear ? 1 : 0)
                    .blur(radius: appear || reduceMotion ? 0 : 5)
                    .offset(y: appear || reduceMotion ? 0 : 10)
                Capsule()
                    .fill(Palette.champagne)
                    .frame(width: appear ? 54 : 0, height: 1.5)
                Spacer()
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { proceed() }
        .task {
            withAnimation(.easeOut(duration: 1.7)) { appear = true }
            try? await Task.sleep(for: .seconds(2.8))
            proceed()
        }
    }

    private func proceed() {
        if model.route == .welcome { model.route = .home }
    }
}
