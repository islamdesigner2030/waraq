import SwiftUI

/// Thoughts & Moods: quick, short entries — a thought, a note, an event or a feeling —
/// with the circumstances around it. No ratings, no questionnaires.
struct ThoughtsPageView: View {
    let session: NotebookSession
    let page: PageRecord
    let rows: Int

    private var lang: AppLanguage { session.lang }

    @State private var kind: ThoughtKind = .thought
    @State private var draft = ""
    @State private var context = ""
    @FocusState private var focus: Field?
    enum Field { case text, context }

    var body: some View {
        let data = page.thoughts ?? ThoughtsData(date: page.createdAt, entries: [])
        let capacity = max(2, rows - 2 - 3)
        let full = data.entries.count >= capacity

        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: lang.t("Thoughts & moods", "خواطر ومشاعر"),
                       subtitle: BJCalendar.longDate(data.date, lang: lang),
                       symbol: "cloud")
            ForEach(data.entries) { entry in
                entryRow(entry)
            }
            Spacer(minLength: 0)
            if full {
                Text(lang.t("This page is full — tap Thoughts again for a fresh page.", "امتلأت الصفحة — اضغط «خواطر» لصفحة جديدة."))
                    .font(AppFont.paper(12.5))
                    .foregroundStyle(Ink.soft)
                    .frame(height: PageMetrics.line)
            } else {
                composer
            }
        }
        .onAppear { session.thoughtsCapacity = capacity }
    }

    private func entryRow(_ e: Thought) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: e.kind.symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(e.kind == .feeling ? Ink.gold : Ink.accent)
                .frame(width: 22)
            Text(e.text)
                .font(AppFont.paper(15))
                .foregroundStyle(Ink.main)
                .lineLimit(1)
                .layoutPriority(1)
            if !e.context.isEmpty {
                Text(e.context)
                    .font(AppFont.paper(12).italic())
                    .foregroundStyle(Ink.soft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(BJCalendar.time(e.time, lang: lang))
                .font(.system(size: 9.5, design: .serif))
                .foregroundStyle(Ink.soft.opacity(0.8))
                .fixedSize()
        }
        .frame(height: PageMetrics.line)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                session.mutate(page.id) { p in p.thoughts?.entries.removeAll { $0.id == e.id } }
            } label: { Label(lang.t("Remove", "إزالة"), systemImage: "trash") }
        }
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(ThoughtKind.allCases) { k in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        kind = k
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: k.symbol).font(.system(size: 9, weight: .medium))
                            Text(k.name(lang)).font(.system(size: 11, weight: kind == k ? .semibold : .regular, design: .serif))
                        }
                        .foregroundStyle(kind == k ? Color.white : Ink.accent)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(kind == k ? Palette.mutedTeal : Palette.mutedTeal.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(kind == k ? .isSelected : [])
                }
            }
            .frame(height: PageMetrics.line)

            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.soft)
                    .frame(width: 22)
                PaperField(placeholder: lang.t("What's on your mind?", "بماذا تفكر الآن؟"), text: $draft, size: 15) {
                    focus = .context
                }
                .focused($focus, equals: .text)
                .accessibilityIdentifier("thought.field")
                Button(action: add) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Ink.soft.opacity(0.35) : Palette.mutedTeal)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(lang.t("Add", "إضافة"))
                .accessibilityIdentifier("thought.add")
            }
            .frame(height: PageMetrics.line)

            HStack(spacing: 6) {
                Color.clear.frame(width: 22, height: 1)
                PaperField(placeholder: lang.t("Circumstances — where, with whom, what happened", "الظروف — أين، مع من، ماذا حدث"),
                           text: $context, size: 13, color: Ink.soft, onSubmit: add)
                    .focused($focus, equals: .context)
            }
            .frame(height: PageMetrics.line)
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let entry = Thought(kind: kind, text: String(text.prefix(120)),
                            context: String(context.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
                            time: Date())
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        withAnimation(.easeOut(duration: 0.25)) {
            session.mutate(page.id) { p in p.thoughts?.entries.append(entry) }
        }
        draft = ""
        context = ""
        focus = .text
    }
}
