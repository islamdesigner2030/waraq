import SwiftUI

/// Shared pieces for the Bullet Journal templates. Every row is one printed line tall
/// (`PageMetrics.line`) so templates sit on the paper's rules.
enum Ink {
    static let main = Palette.ink
    static let soft = Palette.inkSoft
    static let accent = Palette.deepTeal
    static let gold = Palette.champagne
}

struct PageHeader: View {
    let title: String
    let subtitle: String?
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Ink.gold)
                }
                Text(title)
                    .font(AppFont.paper(22, weight: .medium))
                    .foregroundStyle(Ink.main)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.paper(12.5))
                    .foregroundStyle(Ink.soft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: PageMetrics.line * 2, maxHeight: PageMetrics.line * 2, alignment: .bottomLeading)
        .padding(.bottom, 5)
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(Ink.accent.opacity(0.8))
            Rectangle().fill(Ink.gold.opacity(0.45)).frame(height: 0.6)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10.5, weight: .medium, design: .serif))
                    .foregroundStyle(Ink.soft)
            }
        }
        .frame(height: PageMetrics.line, alignment: .bottom)
        .padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Rapid-logging signifiers: • task, × done, > migrated, ○ event, – note.
struct BulletGlyph: View {
    let state: ItemState
    var body: some View {
        Group {
            switch state {
            case .task:
                Circle().fill(Ink.main).frame(width: 5.5, height: 5.5)
            case .done:
                Image(systemName: "xmark").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Ink.accent)
            case .migrated:
                Image(systemName: "chevron.forward").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Ink.soft)
            case .event:
                Circle().stroke(Ink.main, lineWidth: 1.1).frame(width: 7.5, height: 7.5)
            case .note:
                Capsule().fill(Ink.main).frame(width: 9, height: 1.4)
            case .dropped:
                Circle().fill(Ink.soft.opacity(0.5)).frame(width: 5, height: 5)
            }
        }
        .frame(width: 22, height: PageMetrics.line)
    }
}

/// Text field whose direction follows what is typed (Arabic → right-to-left).
struct PaperField: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 15.5
    var weight: Font.Weight = .regular
    var color: Color = Ink.main
    var struck = false
    var onSubmit: (() -> Void)? = nil

    @Environment(\.layoutDirection) private var pageDirection

    var body: some View {
        // Alignment is set explicitly in a left-to-right frame: an empty field otherwise falls back
        // to the device language and an Arabic placeholder would sit on the left.
        let rtl = (text.naturalDirection ?? pageDirection) == .rightToLeft
        TextField(placeholder, text: $text)
            .font(AppFont.paper(size, weight: weight))
            .foregroundStyle(color)
            .strikethrough(struck, color: Ink.soft)
            .submitLabel(.next)
            .onSubmit { onSubmit?() }
            .multilineTextAlignment(rtl ? .trailing : .leading)
            .environment(\.layoutDirection, .leftToRight)
            .tint(Palette.mutedTeal)
    }
}

/// An editable list of bullets. Return adds the next bullet (rapid logging);
/// tapping a bullet ticks a task done; a long press changes its kind.
struct BulletListEditor: View {
    let items: [BulletItem]
    let maxRows: Int
    let placeholder: String
    let addTitle: String
    let lang: AppLanguage
    let update: ((inout [BulletItem]) -> Void) -> Void

    @FocusState private var focused: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items.prefix(max(0, maxRows))) { item in
                row(item)
            }
            if items.count < maxRows {
                Button {
                    let new = BulletItem()
                    update { $0.append(new) }
                    DispatchQueue.main.async { focused = new.id }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 22)
                        Text(addTitle)
                            .font(AppFont.paper(14))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Ink.soft.opacity(0.75))
                    .frame(height: PageMetrics.line)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: focused) { old, new in
            guard let old, old != new else { return }
            update { list in
                list.removeAll { $0.id == old && $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            }
        }
    }

    private func row(_ item: BulletItem) -> some View {
        HStack(spacing: 6) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                update { list in
                    guard let i = list.firstIndex(where: { $0.id == item.id }) else { return }
                    switch list[i].state {
                    case .task: list[i].state = .done
                    case .done: list[i].state = .task
                    default: break
                    }
                }
            } label: {
                BulletGlyph(state: item.state).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { set(.task, item) } label: { Label(lang.t("Task", "مهمة"), systemImage: "circle.fill") }
                Button { set(.event, item) } label: { Label(lang.t("Event", "حدث"), systemImage: "circle") }
                Button { set(.note, item) } label: { Label(lang.t("Note", "ملاحظة"), systemImage: "minus") }
                Button(role: .destructive) {
                    update { $0.removeAll { $0.id == item.id } }
                } label: { Label(lang.t("Remove", "إزالة"), systemImage: "trash") }
            }
            .accessibilityLabel(stateLabel(item.state))

            PaperField(placeholder: placeholder,
                       text: Binding(get: { item.text }, set: { v in
                           update { list in
                               if let i = list.firstIndex(where: { $0.id == item.id }) { list[i].text = v }
                           }
                       }),
                       color: item.state == .done || item.state == .migrated || item.state == .dropped ? Ink.soft : Ink.main,
                       struck: item.state == .dropped || item.state == .done,
                       onSubmit: { submit(after: item) })
                .focused($focused, equals: item.id)
        }
        .frame(height: PageMetrics.line)
    }

    private func set(_ state: ItemState, _ item: BulletItem) {
        update { list in
            if let i = list.firstIndex(where: { $0.id == item.id }) { list[i].state = state }
        }
    }

    private func submit(after item: BulletItem) {
        guard !item.text.trimmingCharacters(in: .whitespaces).isEmpty, items.count < maxRows else {
            focused = nil
            return
        }
        let new = BulletItem(state: item.state == .done ? .task : item.state)
        update { list in
            if let i = list.firstIndex(where: { $0.id == item.id }) {
                list.insert(new, at: i + 1)
            } else {
                list.append(new)
            }
        }
        DispatchQueue.main.async { focused = new.id }
    }

    private func stateLabel(_ s: ItemState) -> String {
        switch s {
        case .task: return lang.t("Task, tap to mark done", "مهمة، اضغط لإنجازها")
        case .done: return lang.t("Done", "منجزة")
        case .migrated: return lang.t("Migrated", "مُرحّلة")
        case .event: return lang.t("Event", "حدث")
        case .note: return lang.t("Note", "ملاحظة")
        case .dropped: return lang.t("Dropped", "مُلغاة")
        }
    }
}

/// Templates sit on the paper; if a small screen ever runs out of room they scroll quietly.
struct TemplateScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}
