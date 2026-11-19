import SwiftUI

/// Monthly Log, first page: every date with its weekday and one key event,
/// plus small habit columns when the month has a habit tracker.
struct MonthCalendarPageView: View {
    let session: NotebookSession
    let page: PageRecord
    let contentHeight: CGFloat

    private var lang: AppLanguage { session.lang }

    var body: some View {
        let data = page.month ?? MonthData(year: 2026, month: 1, events: [])
        let days = BJCalendar.daysIn(year: data.year, month: data.month)
        let habitPage = session.habitPageID(year: data.year, month: data.month).flatMap { session.page($0) }
        let habits = Array((habitPage?.habits?.habits ?? []).prefix(3))
        let available = contentHeight - PageMetrics.line * 2 - 6
        // A tall page lists the month in one column; otherwise two columns keep every date readable.
        let twoColumns = available / CGFloat(days) < 19
        let perColumn = twoColumns ? (days + 1) / 2 : days
        let rowH = min(PageMetrics.line, available / CGFloat(perColumn))
        let fontSize = min(13, rowH * 0.6)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                PageHeader(title: BJCalendar.monthTitle(year: data.year, month: data.month, lang: lang),
                           subtitle: lang.t("Calendar · one key event a day", "التقويم · حدث رئيسي لكل يوم"),
                           symbol: "calendar")
                if !habits.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(habits) { h in
                            Text(String((h.name.isEmpty ? "•" : h.name).prefix(1)))
                                .font(.system(size: 9, weight: .semibold, design: .serif))
                                .foregroundStyle(Ink.accent)
                                .frame(width: 14)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(1...perColumn, id: \.self) { day in
                        dayRow(day: day, data: data, habits: habits, habitPageID: habitPage?.id, height: rowH, fontSize: fontSize)
                    }
                }
                if twoColumns {
                    Rectangle().fill(Ink.gold.opacity(0.35)).frame(width: 0.6)
                    VStack(spacing: 0) {
                        ForEach((perColumn + 1)...days, id: \.self) { day in
                            dayRow(day: day, data: data, habits: habits, habitPageID: habitPage?.id, height: rowH, fontSize: fontSize)
                        }
                    }
                }
            }
        }
    }

    private func dayRow(day: Int, data: MonthData, habits: [Habit], habitPageID: UUID?, height: CGFloat, fontSize: CGFloat) -> some View {
        let weekday = BJCalendar.weekday(year: data.year, month: data.month, day: day)
        let weekend = lang == .arabic ? (weekday == 6 || weekday == 7) : (weekday == 1 || weekday == 7)
        let today = BJCalendar.isToday(year: data.year, month: data.month, day: day)
        let event = day - 1 < data.events.count ? data.events[day - 1] : ""

        return HStack(spacing: 6) {
            Text(BJCalendar.number(day, lang: lang))
                .font(.system(size: fontSize, weight: today ? .bold : .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(today ? Ink.gold : Ink.main)
                .frame(width: 20, alignment: .trailing)
            Text(BJCalendar.weekdayInitial(weekday, lang: lang))
                .font(.system(size: fontSize * 0.85, weight: .regular, design: .serif))
                .foregroundStyle(weekend ? Ink.accent : Ink.soft)
                .frame(width: 14)
            PaperField(placeholder: "",
                       text: Binding(get: { event }, set: { v in
                           session.mutate(page.id) { p in
                               guard var m = p.month else { return }
                               while m.events.count < day { m.events.append("") }
                               m.events[day - 1] = v
                               p.month = m
                           }
                       }),
                       size: fontSize)
            if let habitPageID {
                HStack(spacing: 3) {
                    ForEach(habits) { h in
                        let planned = h.weekdays.contains(weekday)
                        let done = h.done.contains(day)
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            session.toggleHabit(page: habitPageID, habit: h.id, day: day)
                        } label: {
                            Circle()
                                .fill(done ? Palette.mutedTeal : .clear)
                                .overlay(Circle().stroke(planned ? Palette.mutedTeal.opacity(0.7) : Ink.soft.opacity(0.25), lineWidth: 0.8))
                                .frame(width: min(10, height * 0.6), height: min(10, height * 0.6))
                                .frame(width: 14, height: height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel((h.name.isEmpty ? lang.t("Habit", "عادة") : h.name) + (done ? lang.t(", done", "، تمت") : ""))
                    }
                }
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule.opacity(0.18)).frame(height: 0.5)
        }
        .background(today ? Ink.gold.opacity(0.08) : .clear)
    }
}

/// Monthly Log, second page: the month's plan — goals and tasks.
struct MonthPlanPageView: View {
    let session: NotebookSession
    let page: PageRecord
    let rows: Int

    private var lang: AppLanguage { session.lang }

    var body: some View {
        let data = page.monthPlan ?? MonthPlanData(year: 2026, month: 1, goals: [])
        TemplateScroll {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(title: BJCalendar.monthName(year: data.year, month: data.month, lang: lang),
                           subtitle: lang.t("Monthly plan", "خطة الشهر"),
                           symbol: "flag")
                SectionLabel(text: lang.t("This month", "هذا الشهر"))
                BulletListEditor(items: data.goals,
                                 maxRows: max(3, rows - 3),
                                 placeholder: lang.t("Goal or task for the month", "هدف أو مهمة للشهر"),
                                 addTitle: lang.t("Add", "إضافة"),
                                 lang: lang) { change in
                    session.mutate(page.id) { p in
                        if p.monthPlan != nil { change(&p.monthPlan!.goals) }
                    }
                }
            }
        }
    }
}
