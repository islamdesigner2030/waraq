import SwiftUI

/// One sheet of the notebook: paper, its content (free writing or a Bullet Journal
/// template), the drawing layer and the page number. `pageID == nil` is the blank sheet
/// waiting after the last page.
struct PageSurface: View {
    let session: NotebookSession
    let pageID: UUID?
    let number: Int
    let interactive: Bool

    @Environment(\.displayScale) private var displayScale
    @State private var showFullHint = false

    var body: some View {
        let style = session.meta.style
        let lang = session.lang
        let spineOnLeft = !lang.isRTL
        let page = session.page(pageID)

        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                PaperBackground(tone: style.paperTone,
                                pattern: quietPattern(page) ? .blank : style.pattern,
                                binding: style.binding,
                                spineOnLeft: spineOnLeft)

                if let page {
                    content(page, size: size, lang: lang)
                        .padding(EdgeInsets(top: PageMetrics.top, leading: PageMetrics.spine,
                                            bottom: PageMetrics.bottom, trailing: PageMetrics.outer))
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .id(page.id)
                }

                overlays(page: page, size: size, spineOnLeft: spineOnLeft, lang: lang)
            }
        }
        .environment(\.layoutDirection, lang.layoutDirection)
        .environment(\.appLanguage, lang)
        .environment(\.locale, lang.locale)
        .clipShape(PageShape(spineOnLeft: spineOnLeft, radius: style.corner.pageRadius))
        .ignoresSafeArea()
        .onChange(of: session.pageFullPulse) { _, _ in
            guard interactive else { return }
            withAnimation(.easeOut(duration: 0.25)) { showFullHint = true }
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeIn(duration: 0.4)) { showFullHint = false }
            }
        }
    }

    /// Calendar and habit pages have their own grid; the printed pattern would fight it.
    private func quietPattern(_ page: PageRecord?) -> Bool {
        guard let page else { return false }
        return page.kind == .monthCalendar || page.kind == .habits
    }

    @ViewBuilder
    private func content(_ page: PageRecord, size: CGSize, lang: AppLanguage) -> some View {
        let contentHeight = size.height - PageMetrics.top - PageMetrics.bottom
        let rows = PageMetrics.rowCount(height: size.height)
        switch page.kind {
        case .free:
            FreeTextView(session: session, pageID: page.id, editable: interactive && !session.drawingMode, lang: lang)
                .frame(height: CGFloat(rows) * PageMetrics.line)
        case .daily:
            DailyPageView(session: session, page: page, rows: rows)
        case .monthCalendar:
            MonthCalendarPageView(session: session, page: page, contentHeight: contentHeight)
        case .monthPlan:
            MonthPlanPageView(session: session, page: page, rows: rows)
        case .habits:
            HabitPageView(session: session, page: page)
        case .thoughts:
            ThoughtsPageView(session: session, page: page, rows: rows)
        case .index:
            IndexPageView(session: session, page: page)
        }
    }

    /// Drawing layer, page number and edge hints — placed in absolute coordinates.
    @ViewBuilder
    private func overlays(page: PageRecord?, size: CGSize, spineOnLeft: Bool, lang: AppLanguage) -> some View {
        let area = Self.drawingRect(in: size, spineOnLeft: spineOnLeft)
        ZStack(alignment: .topLeading) {
            if let page {
                if interactive && session.drawingMode {
                    DrawingCanvas(session: session, pageID: page.id)
                        .frame(width: area.width, height: area.height)
                        .position(x: area.midX, y: area.midY)
                } else if page.hasDrawing, let image = session.drawingImage(for: page.id, size: area.size, scale: displayScale) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: area.width, height: area.height)
                        .position(x: area.midX, y: area.midY)
                        .allowsHitTesting(false)
                }
            }

            // a faint lifted corner hints that the page can be turned
            LinearGradient(colors: [.black.opacity(0.07), .clear],
                           startPoint: spineOnLeft ? .bottomTrailing : .bottomLeading,
                           endPoint: spineOnLeft ? UnitPoint(x: 0.55, y: 0.55) : UnitPoint(x: 0.45, y: 0.55))
                .frame(width: 34, height: 34)
                .position(x: spineOnLeft ? size.width - 17 : 17, y: size.height - 17)
                .allowsHitTesting(false)

            Text(BJCalendar.number(number, lang: lang))
                .font(.system(size: 10.5, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft.opacity(0.85))
                .position(x: spineOnLeft ? size.width - 30 : 30, y: size.height - 17)
                .accessibilityLabel(lang.t("Page", "صفحة") + " " + BJCalendar.number(number, lang: lang))

            if showFullHint {
                Text(lang.t("This page is full — turn to a new one", "امتلأت الصفحة — اقلب إلى صفحة جديدة"))
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.deepTeal)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .glassEffect(.regular, in: Capsule())
                    .position(x: size.width / 2, y: size.height - 44)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .environment(\.layoutDirection, .leftToRight)
    }

    static func drawingRect(in size: CGSize, spineOnLeft: Bool) -> CGRect {
        let inner: CGFloat = 6
        let outer = PageMetrics.drawingOuterInset
        return CGRect(x: spineOnLeft ? inner : outer, y: 8,
                      width: max(1, size.width - inner - outer), height: max(1, size.height - 16))
    }
}
