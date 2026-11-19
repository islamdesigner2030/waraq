import SwiftUI

/// "My Notebooks": an empty desk with one glass "+" — or the collection of covers.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appLanguage) private var lang
    @State private var showSettings = false
    @State private var pendingDelete: NotebookMeta?

    var body: some View {
        ZStack {
            WarmBackground()
            if model.notebooks.isEmpty {
                emptyState
            } else {
                shelf
            }
        }
        .overlay(alignment: .topLeading) {
            GlassIconButton(systemName: "gearshape", label: lang.t("Settings", "الإعدادات")) {
                showSettings = true
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.height(330)])
                .presentationCornerRadius(28)
        }
        .confirmationDialog(lang.t("Delete this notebook?", "حذف هذا الدفتر؟"),
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button(lang.t("Delete notebook", "حذف الدفتر"), role: .destructive) {
                if let nb = pendingDelete {
                    withAnimation(.easeInOut) { model.delete(nb.id) }
                }
                pendingDelete = nil
            }
            Button(lang.t("Cancel", "إلغاء"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(lang.t("Its pages can't be recovered.", "لا يمكن استعادة صفحاته بعد الحذف."))
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 22) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                model.route = .create
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Palette.deepTeal)
                    .frame(width: 112, height: 112)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Palette.mutedTeal.opacity(0.08)).interactive(), in: Circle())
            .shadow(color: Palette.mutedTeal.opacity(0.18), radius: 24, x: 0, y: 12)
            .accessibilityLabel(lang.t("Create your first notebook", "أنشئ دفترك الأول"))
            .accessibilityIdentifier("home.create")

            Text(lang.t("Create your first notebook", "أنشئ دفترك الأول"))
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Palette.inkSoft)
        }
    }

    // MARK: Collection

    private var shelf: some View {
        GeometryReader { geo in
            let coverW = min(geo.size.width * 0.62, 300)
            VStack(spacing: 0) {
                Text(lang.t("My Notebooks", "دفاتري"))
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 64)
                Capsule().fill(Palette.champagne).frame(width: 28, height: 1.5).padding(.top, 10)

                Spacer(minLength: 10)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 26) {
                        ForEach(model.notebooks) { nb in
                            NotebookCoverCell(meta: nb, photo: model.cover(for: nb), width: coverW)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .rotation3DEffect(.degrees(phase.value * -18), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                                        .scaleEffect(1 - abs(phase.value) * 0.08)
                                        .opacity(1 - abs(phase.value) * 0.25)
                                }
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    model.open(nb.id)
                                }
                                .contextMenu {
                                    Button(role: .destructive) { pendingDelete = nb } label: {
                                        Label(lang.t("Delete", "حذف"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (geo.size.width - coverW) / 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .frame(height: coverW / 0.7 + 70)

                Spacer(minLength: 10)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    model.route = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Palette.deepTeal)
                        .frame(width: 58, height: 58)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(lang.t("New notebook", "دفتر جديد"))
                .accessibilityIdentifier("home.add")
                .padding(.bottom, 30)
            }
            .frame(width: geo.size.width)
        }
    }
}

struct NotebookCoverCell: View {
    let meta: NotebookMeta
    let photo: UIImage?
    let width: CGFloat
    @Environment(\.appLanguage) private var lang

    var body: some View {
        let h = width / meta.style.proportion.aspect
        VStack(spacing: 14) {
            ZStack {
                // page block peeking out at the opening side
                RoundedRectangle(cornerRadius: meta.style.corner.pageRadius, style: .continuous)
                    .fill(meta.style.paperTone.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: meta.style.corner.pageRadius, style: .continuous)
                            .stroke(.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .offset(x: meta.language.isRTL ? -3 : 3, y: 3)
                CoverArtwork(style: meta.style, name: meta.name, photo: photo, spineOnLeft: !meta.language.isRTL)
            }
            .frame(width: width, height: min(h, 440))
            .paperShadow(1.2)

            Text(meta.name.isEmpty ? lang.t("Untitled", "بلا اسم") : meta.name)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(lang.t("Opens the notebook", "يفتح الدفتر"))
        .accessibilityIdentifier("notebook.cell")
    }
}
