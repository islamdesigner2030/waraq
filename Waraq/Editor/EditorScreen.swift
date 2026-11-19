import SwiftUI

/// Loads the notebook, then shows the editor.
struct EditorContainer: View {
    let notebookID: UUID
    let playOpening: Bool
    @Environment(AppModel.self) private var model
    @State private var session: NotebookSession?

    var body: some View {
        ZStack {
            DeskBackground()
            if let session {
                EditorScreen(session: session, playOpening: playOpening)
            }
        }
        .task {
            if session == nil {
                if let s = model.makeSession(notebookID) {
                    session = s
                } else {
                    model.route = .home
                }
            }
        }
    }
}

/// The writing view: the page fills the screen; a glass toolbar on top, a save button below.
struct EditorScreen: View {
    let session: NotebookSession
    @Environment(AppModel.self) private var model
    @Environment(\.appLanguage) private var lang
    @Environment(\.scenePhase) private var scenePhase

    @State private var bridge = ReaderBridge()
    @State private var opening: Bool
    @State private var showUnsavedAlert = false
    @State private var savedToast = false
    @State private var saveError = false
    @State private var toastTask: Task<Void, Never>?
    @State private var showTurnHint: Bool

    init(session: NotebookSession, playOpening: Bool) {
        self.session = session
        _opening = State(initialValue: playOpening)
        _showTurnHint = State(initialValue: !UserDefaults.standard.bool(forKey: AppModel.turnHintKey))
    }

    var body: some View {
        ZStack {
            DeskBackground()

            ReaderRepresentable(session: session, bridge: bridge, showTurnHint: showTurnHint)
                .ignoresSafeArea()

            if opening, bridge.pageFrame != .zero {
                CoverOpeningOverlay(style: session.meta.style,
                                    name: session.meta.name,
                                    photo: session.coverImage,
                                    spineOnLeft: !session.lang.isRTL,
                                    frame: bridge.pageFrame) {
                    opening = false
                }
                .transition(.identity)
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    GlassIconButton(systemName: "chevron.backward", label: lang.t("My notebooks", "دفاتري"), size: 46) {
                        attemptClose()
                    }
                    .accessibilityIdentifier("editor.close")
                    Spacer(minLength: 0)
                    FloatingToolbar(session: session, lang: lang) { tool in
                        bridge.controller?.perform(tool)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                Spacer()

                saveButton
                    .padding(.bottom, session.drawingMode ? 96 : 10)
            }
            .opacity(opening ? 0 : 1)
            .animation(.easeInOut(duration: 0.35), value: opening)

            if savedToast {
                savedConfirmation
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .onAppear {
            if showTurnHint { model.turnHintShown = true }
            PaperSound.shared.prepare()
        }
        .onDisappear {
            PaperSound.shared.shutdown()
        }
        .onChange(of: scenePhase) { _, phase in
            // never lose writing if the app is closed from the background
            if phase == .background, session.isDirty { try? session.save() }
            if phase == .background { session.rememberCurrentPage() }
        }
        .alert(lang.t("Unsaved changes", "تغييرات غير محفوظة"), isPresented: $showUnsavedAlert) {
            Button(lang.t("Save", "احفظ")) {
                if save(showToast: false) { close() }
            }
            Button(lang.t("Don't save", "لا تحفظ"), role: .destructive) { close() }
            Button(lang.t("Cancel", "إلغاء"), role: .cancel) {}
        } message: {
            Text(lang.t("Save your pages before closing the notebook?", "هل تحفظ صفحاتك قبل إغلاق الدفتر؟"))
        }
        .alert(lang.t("Couldn't save", "تعذّر الحفظ"), isPresented: $saveError) {
            Button(lang.t("OK", "حسنًا"), role: .cancel) {}
        } message: {
            Text(lang.t("There may not be enough space on this iPhone.", "قد لا تتوفر مساحة كافية على هذا الآيفون."))
        }
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            _ = save(showToast: true)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                Text(lang.t("Save", "حفظ"))
                    .font(.system(.callout, design: .serif, weight: .semibold))
            }
            .foregroundStyle(session.isDirty ? Color.white : Palette.deepTeal)
            .padding(.horizontal, 22)
            .frame(height: 48)
            .overlay(alignment: .topTrailing) {
                if session.isDirty {
                    Circle().fill(Palette.champagne).frame(width: 7, height: 7).offset(x: 10, y: 8)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(session.isDirty ? Glass.regular.tint(Palette.mutedTeal).interactive() : Glass.regular.interactive(), in: Capsule())
        .accessibilityLabel(session.isDirty ? lang.t("Save, unsaved changes", "حفظ، توجد تغييرات") : lang.t("Saved", "محفوظ"))
        .animation(.easeInOut(duration: 0.25), value: session.isDirty)
        .accessibilityIdentifier("editor.save")
    }

    private var savedConfirmation: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.mutedTeal.opacity(0.12)).frame(width: 54, height: 54)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.deepTeal)
                    .symbolEffect(.bounce, value: savedToast)
            }
            Text(lang.t("Saved on this iPhone", "حُفظ على هذا الآيفون"))
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Palette.ink)
            Button {
                close()
            } label: {
                Text(lang.t("Back to my notebooks", "العودة إلى دفاتري"))
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.deepTeal)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(Palette.mutedTeal.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toast.home")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { hideToast() }
    }

    @discardableResult
    private func save(showToast: Bool) -> Bool {
        do {
            try session.save()
            session.rememberCurrentPage()
            Haptics.saved()
            if showToast {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { savedToast = true }
                toastTask?.cancel()
                toastTask = Task {
                    try? await Task.sleep(for: .seconds(2.6))
                    if !Task.isCancelled { hideToast() }
                }
            }
            return true
        } catch {
            saveError = true
            return false
        }
    }

    private func hideToast() {
        withAnimation(.easeOut(duration: 0.3)) { savedToast = false }
    }

    // MARK: Close

    private func attemptClose() {
        if session.isDirty {
            showUnsavedAlert = true
        } else {
            close()
        }
    }

    private func close() {
        toastTask?.cancel()
        session.drawingMode = false
        session.rememberCurrentPage()
        model.closeEditor()
    }
}
