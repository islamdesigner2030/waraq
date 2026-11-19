import SwiftUI
import PhotosUI

/// Create a notebook: every choice updates the 3D preview live. Sensible defaults mean
/// a single tap on "Create notebook" is enough.
struct CreateNotebookView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appLanguage) private var lang

    @State private var style = NotebookStyle()
    @State private var name = ""
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var section: Panel = .shape
    @FocusState private var nameFocused: Bool

    enum Panel: CaseIterable, Identifiable {
        case shape, color, paper, cover, name
        var id: Self { self }
        func title(_ l: AppLanguage) -> String {
            switch self {
            case .shape: return l.t("Shape", "الشكل")
            case .color: return l.t("Color", "اللون")
            case .paper: return l.t("Paper", "الورق")
            case .cover: return l.t("Cover", "الغلاف")
            case .name: return l.t("Name", "الاسم")
            }
        }
    }

    private var spineOnLeft: Bool { !lang.isRTL }
    private var editingPhoto: Bool { style.coverArt == .photo && photo != nil && section == .cover }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topBar
                previewArea(size: CGSize(width: geo.size.width, height: max(220, geo.size.height * 0.38)))
                panelPicker
                    .padding(.top, 6)
                panel
                    .frame(height: 176, alignment: .top)
                    .padding(.top, 14)
                Spacer(minLength: 8)
                GlassCapsuleButton(systemName: "book.closed", title: lang.t("Create notebook", "إنشاء الدفتر"), prominent: true) {
                    nameFocused = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    model.createNotebook(name: name, style: style, photo: photo)
                }
                .accessibilityIdentifier("create.confirm")
                .padding(.bottom, 18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(WarmBackground())
        .ignoresSafeArea(.keyboard)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    photo = img.downscaled(maxDimension: 1600)
                    style.photoScale = 1
                    style.photoOffsetX = 0
                    style.photoOffsetY = 0
                    withAnimation(.easeInOut) { style.coverArt = .photo }
                }
            }
        }
    }

    // MARK: Parts

    private var topBar: some View {
        ZStack {
            Text(lang.t("New notebook", "دفتر جديد"))
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ink)
            HStack {
                GlassIconButton(systemName: "xmark", label: lang.t("Close", "إغلاق"), size: 40) {
                    model.route = .home
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func previewArea(size: CGSize) -> some View {
        ZStack {
            if editingPhoto, let photo {
                let h = size.height * 0.82
                let w = h * style.proportion.aspect
                VStack(spacing: 8) {
                    PhotoCropper(photo: photo, style: $style, spineOnLeft: spineOnLeft)
                        .frame(width: w, height: h)
                        .paperShadow()
                    Text(lang.t("Drag and pinch to position", "اسحب وقرّب لضبط الصورة"))
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
            } else {
                NotebookPreview3D(style: style, name: name, photo: photo, spineOnLeft: spineOnLeft,
                                  maxSize: CGSize(width: size.width * 0.52, height: size.height * 0.84))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var panelPicker: some View {
        HStack(spacing: 6) {
            ForEach(Panel.allCases) { p in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy) { section = p }
                    if p != .name { nameFocused = false }
                } label: {
                    Text(p.title(lang))
                        .font(.system(.subheadline, design: .serif, weight: section == p ? .semibold : .regular))
                        .foregroundStyle(section == p ? Palette.deepTeal : Palette.inkSoft)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background {
                            if section == p {
                                Capsule().fill(Palette.mutedTeal.opacity(0.12))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == p ? .isSelected : [])
                .accessibilityIdentifier("create.tab.\(p)")
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
    }

    @ViewBuilder
    private var panel: some View {
        switch section {
        case .shape:
            VStack(spacing: 12) {
                optionRow(lang.t("Proportion", "النسبة")) {
                    ForEach(NotebookProportion.allCases) { p in
                        OptionChip(title: p.name(lang), selected: style.proportion == p) { style.proportion = p }
                    }
                }
                optionRow(lang.t("Corners", "الزوايا")) {
                    ForEach(CornerStyle.allCases) { c in
                        OptionChip(title: c.name(lang), selected: style.corner == c) { style.corner = c }
                    }
                }
                optionRow(lang.t("Binding", "التجليد")) {
                    ForEach(BindingStyle.allCases) { b in
                        OptionChip(title: b.name(lang), selected: style.binding == b) { style.binding = b }
                    }
                }
            }
        case .color:
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(52), spacing: 14), count: 5), spacing: 14) {
                ForEach(CoverColor.allCases) { c in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        style.coverColor = c
                    } label: {
                        Circle()
                            .fill(c.color)
                            .overlay(LinenView().clipShape(Circle()).blendMode(.overlay))
                            .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 0.5))
                            .frame(width: 44, height: 44)
                            .padding(4)
                            .overlay(Circle().stroke(style.coverColor == c ? Palette.champagne : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.name(lang))
                    .accessibilityAddTraits(style.coverColor == c ? .isSelected : [])
                }
            }
        case .paper:
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ForEach(PaperTone.allCases) { t in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            style.paperTone = t
                        } label: {
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(t.color)
                                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(style.paperTone == t ? Palette.champagne : .black.opacity(0.1), lineWidth: style.paperTone == t ? 2 : 0.5))
                                    .frame(width: 40, height: 40)
                                Text(t.name(lang)).font(.caption2).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(style.paperTone == t ? .isSelected : [])
                    }
                }
                HStack(spacing: 12) {
                    ForEach(PaperPattern.allCases) { p in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            style.pattern = p
                        } label: {
                            VStack(spacing: 5) {
                                PaperBackground(tone: style.paperTone, pattern: p, binding: .stitched, spineOnLeft: true)
                                    .frame(width: 140, height: 190)
                                    .scaleEffect(0.36)
                                    .frame(width: 50, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(style.pattern == p ? Palette.champagne : .black.opacity(0.1), lineWidth: style.pattern == p ? 2 : 0.5))
                                Text(p.name(lang)).font(.caption2).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(style.pattern == p ? .isSelected : [])
                    }
                }
            }
        case .cover:
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(CoverArt.readyMade) { art in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            style.coverArt = art
                        } label: {
                            coverThumb(art: art)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(art.name(lang))
                        .accessibilityAddTraits(style.coverArt == art ? .isSelected : [])
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 5) {
                            ZStack {
                                if let photo {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                } else {
                                    Palette.softBeige
                                    Image(systemName: "photo")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Palette.deepTeal)
                                }
                            }
                            .frame(width: 50, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(style.coverArt == .photo ? Palette.champagne : .black.opacity(0.1), lineWidth: style.coverArt == .photo ? 2 : 0.5))
                            Text(CoverArt.photo.name(lang)).font(.caption2).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        if photo != nil { style.coverArt = .photo }
                    })
                    .accessibilityLabel(lang.t("Choose a photo", "اختر صورة"))
                }
                Text(lang.t("Photos are chosen privately — no library access needed.", "تُختار الصورة بخصوصية تامة دون الوصول إلى مكتبتك."))
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
            }
        case .name:
            VStack(spacing: 8) {
                TextField(lang.t("Notebook name (optional)", "اسم الدفتر (اختياري)"), text: $name)
                    .font(.system(.title3, design: .serif))
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 36)
                    .onChange(of: name) { _, v in if v.count > 40 { name = String(v.prefix(40)) } }
                Text(lang.t("It appears in gold on the cover.", "يظهر بالذهبي على الغلاف."))
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            .onAppear { nameFocused = true }
        }
    }

    private func coverThumb(art: CoverArt) -> some View {
        var s = style
        s.coverArt = art
        return VStack(spacing: 5) {
            CoverArtwork(style: s, name: "", photo: nil, spineOnLeft: spineOnLeft)
                .frame(width: 50, height: 70)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(style.coverArt == art ? Palette.champagne : .clear, lineWidth: 2))
            Text(art.name(lang)).font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(1)
        }
        .frame(width: 56)
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 74, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }
}

struct OptionChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.system(.footnote, design: .serif, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(selected ? Palette.mutedTeal : Palette.softBeige.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
