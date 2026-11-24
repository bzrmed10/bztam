import SwiftData
import SwiftUI

/// Pure math for the spending calendar: what was spent each day of a month, and how strong to shade it.
enum SpendingCalendar {
    /// Net spent per day (refunds from friends count back), keyed by the day's start.
    static func daily(_ entries: [EntryValue], month: Date, calendar: Calendar = .current) -> [Date: Centimes] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        var result: [Date: Centimes] = [:]
        for e in entries where e.kind == .expense && interval.contains(e.date) {
            result[calendar.startOfDay(for: e.date), default: 0] += e.amount
        }
        return result
    }

    /// 0 = nothing, 1 = a little, 2 = usual, 3 = a lot (compared with this month's average spending day).
    static func level(_ value: Centimes, average: Centimes) -> Int {
        guard value > 0 else { return 0 }
        guard average > 0 else { return 2 }
        if value < average / 2 { return 1 }
        if value <= average * 3 / 2 { return 2 }
        return 3
    }

    /// The month's cells, Monday or Sunday first as the iPhone is set: nil for the blanks before day 1.
    static func cells(month: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: blanks)
        for d in 0..<days { cells.append(calendar.date(byAdding: .day, value: d, to: interval.start)) }
        return cells
    }
}

/// A month of spending as a calendar: each day shows what was spent, shaded from light to lime. Tap a day for its expenses.
struct SpendingCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var month = Calendar.current.startOfDay(for: .now)
    @State private var selected: Date? = Calendar.current.startOfDay(for: .now)
    @State private var editing: Entry?

    private let calendar: Calendar = {
        var c = Calendar.current
        c.locale = L10n.locale
        return c
    }()

    var body: some View {
        let values = BudgetSnapshot.values(entries)
        let daily = SpendingCalendar.daily(values, month: month, calendar: calendar)
        let total = daily.values.reduce(0, +)
        let today = calendar.startOfDay(for: .now)
        let isThisMonth = calendar.isDate(month, equalTo: .now, toGranularity: .month)
        let elapsed = isThisMonth ? calendar.component(.day, from: .now) : (calendar.range(of: .day, in: .month, for: month)?.count ?? 30)
        let spendingDays = daily.values.filter { $0 > 0 }
        let average = spendingDays.isEmpty ? 0 : spendingDays.reduce(0, +) / spendingDays.count
        let zeroDays = max(0, elapsed - spendingDays.count)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 4) {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                    Button { shift(-1) } label: { Image(systemName: "chevron.backward").frame(width: 40, height: 44) }
                        .accessibilityLabel(L10n.t("Previous month"))
                    Text(DateText.month(month)).font(.scaled(size: 16, weight: .bold))
                        .contentTransition(.numericText())
                    Button { shift(1) } label: { Image(systemName: "chevron.forward").frame(width: 40, height: 44) }
                        .disabled(isThisMonth)
                        .opacity(isThisMonth ? 0.3 : 1)
                        .accessibilityLabel(L10n.t("Next month"))
                }
                .font(.scaled(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Spent in %@", DateText.monthName(month))).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    Text(Money.format(total)).font(.scaled(size: 34, weight: .heavy)).tracking(-0.8)
                        .contentTransition(.numericText(value: Double(total)))
                    if elapsed > 0 && total > 0 {
                        Text(L10n.t("About %@ a day", Money.format(total / max(1, elapsed)))
                             + (zeroDays > 0 ? " · " + (zeroDays == 1 ? L10n.t("1 day with nothing spent") : L10n.t("%d days with nothing spent", zeroDays)) : ""))
                            .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                }

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.scaled(size: 11, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    ForEach(Array(SpendingCalendar.cells(month: month, calendar: calendar).enumerated()), id: \.offset) { _, day in
                        if let day {
                            let value = daily[day] ?? 0
                            let future = day > today
                            DayCell(day: calendar.component(.day, from: day), value: value, future: future,
                                    level: SpendingCalendar.level(value, average: average),
                                    isToday: day == today, isSelected: day == selected) {
                                withAnimation(.snappy) { selected = day }
                            }
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selected)

                HStack(spacing: 6) {
                    Text(L10n.t("Less"))
                    ForEach(0..<4) { level in
                        RoundedRectangle(cornerRadius: 3).fill(DayCell.fill(level)).frame(width: 16, height: 10)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.Colors.line, lineWidth: level == 0 ? 1 : 0))
                    }
                    Text(L10n.t("More"))
                }
                .font(.scaled(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.inkMuted)
                .accessibilityHidden(true)

                if let day = selected, calendar.isDate(day, equalTo: month, toGranularity: .month) {
                    let dayEntries = entries.filter { $0.kind == .expense && calendar.isDate($0.date, inSameDayAs: day) }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(DateText.day(day)).font(.scaled(size: 15, weight: .heavy))
                            Spacer()
                            Text(Money.format(daily[day] ?? 0)).font(.scaled(size: 15, weight: .heavy))
                        }
                        .padding(.bottom, 4)
                        if dayEntries.isEmpty {
                            Text(L10n.t("Nothing spent this day.")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        ForEach(dayEntries) { e in
                            Button { editing = e } label: { EntryRow(entry: e) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Theme.Colors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(Theme.Space.l)
        }
        .scrollIndicators(.hidden)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .presentationDetents([.large])
        .sheet(item: $editing) { AddEntryView(editing: $0) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func shift(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(.snappy) {
            month = next
            selected = calendar.isDate(next, equalTo: .now, toGranularity: .month) ? calendar.startOfDay(for: .now) : nil
        }
    }
}

private struct DayCell: View {
    let day: Int
    let value: Centimes
    let future: Bool
    let level: Int
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    static func fill(_ level: Int) -> Color {
        switch level {
        case 0: Theme.Colors.surface.opacity(0.5)
        case 1: Theme.Colors.brandTint
        case 2: Theme.Colors.brand.opacity(0.6)
        default: Theme.Colors.brand
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(day)").font(.scaled(size: 13, weight: .bold))
                if !future {
                    Text(value > 0 ? Money.format(value, symbol: false) : "0")
                        .font(.scaled(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(level >= 2 ? Theme.Colors.onBrand : Theme.Colors.inkMuted)
                }
            }
            .foregroundStyle(level >= 2 ? Theme.Colors.onBrand : Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(future ? Color.clear : Self.fill(level), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.Colors.ink : isToday ? Theme.Colors.positive : .clear,
                                                                lineWidth: isSelected ? 2 : 1.5))
            .opacity(future ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel("\(day) · " + Money.format(value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
