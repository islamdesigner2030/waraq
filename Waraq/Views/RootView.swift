import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lang = model.currentLanguage
        ZStack {
            Palette.ivory.ignoresSafeArea()
            switch model.route {
            case .language:
                LanguageView()
                    .transition(.opacity)
            case .welcome:
                WelcomeView()
                    .transition(.opacity)
            case .home:
                HomeView()
                    .transition(.opacity)
            case .create:
                CreateNotebookView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .editor(let id, let opening):
                EditorContainer(notebookID: id, playOpening: opening)
                    .transition(.opacity)
            }
        }
        .environment(\.appLanguage, lang)
        .environment(\.layoutDirection, lang.layoutDirection)
        .environment(\.locale, lang.locale)
        .animation(.easeInOut(duration: 0.45), value: model.route)
    }
}
