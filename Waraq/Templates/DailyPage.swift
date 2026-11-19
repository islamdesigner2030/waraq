import SwiftUI

/// Daily Actions: the date, the top three (No. 1 is the most important task),
/// a review of open tasks from earlier days (migrate / done / drop), and today's log.
struct DailyPageView: View {
    let session: NotebookSession
    let page: PageRecord
    let rows: Int

    private var lang: AppLanguage { session.lang }

    var body: some View {
        let data = page.daily ?? DailyData(date: page.createdAt, priorities: [], items: [])
        let pending = session.pendingTasks(before: data.date, excluding: page.id)
        let reviewShown = min(pending.count, 2)
        let used = 2 + 1 + 3 + (pending.isEmpty ? 0 : 1 + reviewShown) + 1
        let taskRows = max(3, rows - used)

        TemplateScroll {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(title: BJCalendar.dayTitle(data.date, lang: lang),
                           subtitle: BJCalendar.longDate(data.date, lang: lang),
                           symbol: "sun.max")

                SectionLabel(text: lang.t("Top 3", "الأهم اليوم"))
                ForEach(Array(data.priorities.prefix(3).enumerated()), id: \.element.id) { i, item in
                    priorityRow(index: i, item: item)
                }

                if !pending.isEmpty {
                    SectionLabel(text: lang.t("From earlier days", "من الأيام السابقة"),
                                 trailing: pending.count > reviewShown ? "+\(BJCalendar.number(pending.count - reviewShown, lang: lang))" : nil)
                    ForEach(pending.prefix(reviewShown)) { task in
                        reviewRow(task)
                    }
                }

                SectionLabel(text: lang.t("Tasks & log", "المهام والتدوين"))
                BulletListEditor(items: data.items,
                                 maxRows: taskRows,
                                 placeholder: lang.t("Task, event or note", "مهمة أو حدث أو ملاحظة"),
                                 addTitle: lang.t("Add", "إضافة"),
                                 lang: lang) { change in
                    session.mutate(page.id) { p in
                        if p.daily != nil { change(&p.daily!.items) }
                    }
                }
            }
        }
    }

    private func priorityRow(index: Int, item: BulletItem) -> some View {
        let isMain = index == 0
        let done = item.state == .done
        return HStack(spacing: 6) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                updatePriority(item.id) { $0.state = done ? .task : .done }
            } label: {
                ZStack {
                    Circle()
                        .stroke(isMain ? Ink.gold : Ink.soft.opacity(0.5), lineWidth: isMain ? 1.3 : 0.8)
                        .frame(width: 19, height: 19)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Ink.accent)
                    } else {
                        Text(BJCalendar.number(index + 1, lang: lang))
                            .font(.system(size: 10.5, weight: .semibold, design: .serif))
                            .foregroundStyle(isMain ? Ink.gold : Ink.soft)
                    }
                }
                .frame(width: 22, height: PageMetrics.line)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? lang.t("Done", "منجزة") : lang.t("Mark done", "تحديد كمنجزة"))

            PaperField(placeholder: isMain ? lang.t("The most important task", "المهمة الأهم") : lang.t("Priority", "أولوية"),
                       text: Binding(get: { item.text }, set: { v in updatePriority(item.id) { $0.text = v } }),
                       weight: isMain ? .semibold : .regular,
                       color: done ? Ink.soft : Ink.main,
                       struck: done)
            if isMain {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Ink.gold)
                    .accessibilityLabel(lang.t("Most important", "الأهم"))
            }
        }
        .frame(height: PageMetrics.line)
    }

    private func reviewRow(_ task: NotebookSession.PendingTask) -> some View {
        HStack(spacing: 4) {
            BulletGlyph(state: .task)
            Text(task.item.text)
                .font(AppFont.paper(14.5))
                .foregroundStyle(Ink.main)
                .lineLimit(1)
                .environment(\.layoutDirection, task.item.text.naturalDirection ?? lang.layoutDirection)
            Text(BJCalendar.shortDate(task.date, lang: lang))
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(Ink.soft)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            reviewButton("arrow.forward", lang.t("Move to today", "ترحيل إلى اليوم")) { session.migrate(task, to: page.id) }
            reviewButton("checkmark", lang.t("Done", "تمت")) { session.complete(task) }
            reviewButton("xmark", lang.t("Drop", "إلغاء")) { session.drop(task) }
        }
        .frame(height: PageMetrics.line)
    }

    private func reviewButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            withAnimation(.easeInOut(duration: 0.25)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.accent)
                .frame(width: 26, height: 24)
                .background(Circle().fill(Palette.mutedTeal.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func updatePriority(_ id: UUID, _ change: (inout BulletItem) -> Void) {
        session.mutate(page.id) { p in
            guard var d = p.daily, let i = d.priorities.firstIndex(where: { $0.id == id }) else { return }
            change(&d.priorities[i])
            p.daily = d
        }
    }
}
