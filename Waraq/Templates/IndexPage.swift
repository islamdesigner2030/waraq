import SwiftUI

/// Index: every page's name and number. Tap a line to turn to that page.
struct IndexPageView: View {
    let session: NotebookSession
    let page: PageRecord

    private var lang: AppLanguage { session.lang }

    var body: some View {
        let entries = session.meta.pages.enumerated().filter { $0.element.kind != .index }

        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: lang.t("Index", "الفهرس"),
                       subtitle: lang.t("Tap a line to open its page", "اضغط على سطر لتنتقل إلى صفحته"),
                       symbol: "list.bullet")
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(entries, id: \.element.id) { i, p in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            session.navigator?(i)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: symbol(for: p.kind))
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Ink.accent.opacity(0.8))
                                    .frame(width: 16)
                                Text(session.title(for: p))
                                    .font(AppFont.paper(14.5))
                                    .foregroundStyle(Ink.main)
                                    .lineLimit(1)
                                // dotted leader
                                Line()
                                    .stroke(Ink.soft.opacity(0.4), style: StrokeStyle(lineWidth: 0.8, dash: [1, 3]))
                                    .frame(height: 1)
                                    .padding(.top, 8)
                                Text(BJCalendar.number(i + 1, lang: lang))
                                    .font(.system(size: 13, weight: .medium, design: .serif))
                                    .monospacedDigit()
                                    .foregroundStyle(Ink.accent)
                                    .fixedSize()
                            }
                            .frame(height: PageMetrics.line)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(session.title(for: p) + ", " + lang.t("page", "صفحة") + " " + BJCalendar.number(i + 1, lang: lang))
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func symbol(for kind: PageKind) -> String {
        switch kind {
        case .daily: return "sun.max"
        case .monthCalendar: return "calendar"
        case .monthPlan: return "flag"
        case .habits: return "leaf"
        case .thoughts: return "cloud"
        case .index: return "list.bullet"
        case .free: return "text.alignleft"
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
