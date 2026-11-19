import SwiftUI

/// Habit Tracker for one month: up to three small habits, each with its planned weekdays,
/// a tap-to-track grid of the month's days and simple progress; then a short plan per week
/// (week 1 planned first, the rest adjusted as the month goes).
struct HabitPageView: View {
    let session: NotebookSession
    let page: PageRecord

    private var lang: AppLanguage { session.lang }
    static let maxHabits = 3

    var body: some View {
        let data = page.habits ?? HabitData(year: 2026, month: 1, habits: [], weekPlans: [])
        let days = BJCalendar.daysIn(year: data.year, month: data.month)

        TemplateScroll {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(title: lang.t("Habits", "العادات"),
                           subtitle: BJCalendar.monthTitle(year: data.year, month: data.month, lang: lang),
                           symbol: "leaf")

                ForEach(data.habits) { habit in
                    habitBlock(habit, data: data, days: days)
                }

                if data.habits.count < Self.maxHabits {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        session.mutate(page.id) { p in
                            guard (p.habits?.habits.count ?? 0) < Self.maxHabits else { return }
                            p.habits?.habits.append(Habit())
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .medium)).frame(width: 22)
                            Text(lang.t("Add a small habit", "أضف عادة صغيرة")).font(AppFont.paper(14))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Ink.soft.opacity(0.75))
                        .frame(height: PageMetrics.line)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                SectionLabel(text: lang.t("Weekly plan", "خطة كل أسبوع"))
                ForEach(Array(data.weekPlans.enumerated()), id: \.offset) { i, plan in
                    weekRow(index: i, plan: plan, data: data)
                }
            }
        }
    }

    // MARK: Habit

    private func habitBlock(_ habit: Habit, data: HabitData, days: Int) -> some View {
        let planned = (1...days).filter { habit.weekdays.contains(BJCalendar.weekday(year: data.year, month: data.month, day: $0)) }
        let doneCount = habit.done.filter { (1...days).contains($0) }.count
        let progress: CGFloat = planned.isEmpty ? 0 : min(1, CGFloat(doneCount) / CGFloat(planned.count))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.accent)
                    .frame(width: 22)
                PaperField(placeholder: lang.t("e.g. read 10 minutes", "مثال: قراءة ١٠ دقائق"),
                           text: Binding(get: { habit.name }, set: { v in update(habit.id) { $0.name = String(v.prefix(30)) } }),
                           size: 15, weight: .medium)
                Menu {
                    ForEach(BJCalendar.orderedWeekdays(lang: lang), id: \.self) { wd in
                        Toggle(isOn: Binding(get: { habit.weekdays.contains(wd) }, set: { on in
                            update(habit.id) { h in
                                if on { if !h.weekdays.contains(wd) { h.weekdays.append(wd) } }
                                else if h.weekdays.count > 1 { h.weekdays.removeAll { $0 == wd } }
                            }
                        })) {
                            Text(weekdayName(wd))
                        }
                    }
                    if data.habits.count > 1 {
                        Divider()
                        Button(role: .destructive) {
                            session.mutate(page.id) { p in p.habits?.habits.removeAll { $0.id == habit.id } }
                        } label: { Label(lang.t("Remove habit", "إزالة العادة"), systemImage: "trash") }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar").font(.system(size: 10))
                        Text(BJCalendar.number(habit.weekdays.count, lang: lang) + lang.t("/wk", "/أسبوع"))
                            .font(.system(size: 10, weight: .medium, design: .serif))
                    }
                    .foregroundStyle(Ink.accent)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Capsule().fill(Palette.mutedTeal.opacity(0.09)))
                }
                .accessibilityLabel(lang.t("Planned days", "الأيام المخطط لها"))
            }
            .frame(height: PageMetrics.line)

            dayGrid(habit, data: data, days: days)

            HStack(spacing: 8) {
                Capsule().fill(Palette.rule.opacity(0.18))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(Palette.mutedTeal).frame(width: g.size.width * progress)
                        }
                    }
                Text(BJCalendar.number(doneCount, lang: lang) + " / " + BJCalendar.number(planned.count, lang: lang))
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Ink.soft)
                    .fixedSize()
            }
            .padding(.leading, 28)
            .frame(height: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(lang.t("Progress", "التقدم") + " " + BJCalendar.number(doneCount, lang: lang) + " / " + BJCalendar.number(planned.count, lang: lang))
        }
        .padding(.bottom, 8)
    }

    private func dayGrid(_ habit: Habit, data: HabitData, days: Int) -> some View {
        let perRow = 16
        let rowsNeeded = (days + perRow - 1) / perRow
        return VStack(spacing: 3) {
            ForEach(0..<rowsNeeded, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<perRow, id: \.self) { c in
                        let day = r * perRow + c + 1
                        if day <= days {
                            dayCell(habit, day: day, data: data)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.leading, 28)
    }

    private func dayCell(_ habit: Habit, day: Int, data: HabitData) -> some View {
        let wd = BJCalendar.weekday(year: data.year, month: data.month, day: day)
        let planned = habit.weekdays.contains(wd)
        let done = habit.done.contains(day)
        let today = BJCalendar.isToday(year: data.year, month: data.month, day: day)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            session.toggleHabit(page: page.id, habit: habit.id, day: day)
        } label: {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(done ? Palette.mutedTeal : (planned ? Palette.mutedTeal.opacity(0.06) : .clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .stroke(today ? Ink.gold : (planned ? Palette.mutedTeal.opacity(0.45) : Palette.rule.opacity(0.22)),
                                lineWidth: today ? 1.2 : 0.6)
                )
                .overlay(
                    Text(BJCalendar.number(day, lang: lang))
                        .font(.system(size: 7.5, weight: .medium, design: .serif))
                        .foregroundStyle(done ? Color.white : Ink.soft.opacity(planned ? 0.9 : 0.5))
                )
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BJCalendar.number(day, lang: lang) + (done ? lang.t(", done", "، تمت") : ""))
    }

    // MARK: Weeks

    private func weekRow(index: Int, plan: String, data: HabitData) -> some View {
        let todayYM = BJCalendar.yearMonth(of: Date())
        let todayDay = BJCalendar.gregorian.component(.day, from: Date())
        let current = todayYM.year == data.year && todayYM.month == data.month && BJCalendar.week(ofDay: todayDay) == index
        return HStack(spacing: 6) {
            Text(lang.t("W", "") + BJCalendar.number(index + 1, lang: lang))
                .font(.system(size: 11, weight: current ? .bold : .medium, design: .serif))
                .foregroundStyle(current ? Ink.gold : Ink.accent)
                .frame(width: 26, alignment: .leading)
            PaperField(placeholder: index == 0 ? lang.t("Plan for week 1", "خطة الأسبوع الأول") : lang.t("Adjust for this week", "عدّل لهذا الأسبوع"),
                       text: Binding(get: { plan }, set: { v in
                           session.mutate(page.id) { p in
                               guard var h = p.habits, index < h.weekPlans.count else { return }
                               h.weekPlans[index] = v
                               p.habits = h
                           }
                       }),
                       size: 14)
        }
        .frame(height: PageMetrics.line)
    }

    private func update(_ id: UUID, _ change: (inout Habit) -> Void) {
        session.mutate(page.id) { p in
            guard var h = p.habits, let i = h.habits.firstIndex(where: { $0.id == id }) else { return }
            change(&h.habits[i])
            p.habits = h
        }
    }

    private func weekdayName(_ wd: Int) -> String {
        let symbols = lang.calendar.standaloneWeekdaySymbols
        return symbols[max(0, min(symbols.count - 1, wd - 1))]
    }
}
