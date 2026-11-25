import Foundation

/// A category that will run out before payday at the current pace.
struct PaceWarning: Equatable, Sendable {
    var categoryID: UUID
    var runOut: Date
}

/// A budget suggested from the last months of real spending.
struct BudgetSuggestion: Equatable, Sendable {
    var categoryID: UUID
    var amount: Centimes
}

/// Pace warnings, budget suggestions and recap numbers. Pure, unit-tested; the text is written by the views.
enum Advice {
    /// Categories on track to run out before the period ends.
    /// Needs at least 3 days of data and 30% of the budget spent; already used-up categories are left to the alerts.
    static func paceWarnings(categories: [CategoryValue], entries: [EntryValue], period: BudgetPeriod,
                             now: Date = .now, calendar: Calendar = .current) -> [PaceWarning] {
        guard period.contains(now) else { return [] }
        let elapsed = max(1, (calendar.dateComponents([.day], from: period.start, to: now).day ?? 0) + 1)
        guard elapsed >= 3 else { return [] }
        return categories.compactMap { c -> PaceWarning? in
            guard c.budget > 0, !c.isFixed else { return nil }
            let spent = entries.filter { $0.kind == .expense && $0.categoryID == c.id && $0.date >= period.start && $0.date <= now }
                .reduce(0) { $0 + $1.amount }
            guard spent * 10 >= c.budget * 3, spent < c.budget else { return nil }
            let perDay = Double(spent) / Double(elapsed)
            let daysToRunOut = Double(c.budget) / perDay
            guard let runOut = calendar.date(byAdding: .day, value: Int(daysToRunOut.rounded(.down)), to: period.start),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: period.end),
                  runOut < lastDay else { return nil }
            return PaceWarning(categoryID: c.id, runOut: runOut)
        }
        .sorted { $0.runOut < $1.runOut }
    }

    /// Share (0...1) of a category's spending that happened on Saturday or Sunday.
    static func weekendShare(categoryID: UUID, entries: [EntryValue], period: BudgetPeriod, calendar: Calendar = .current) -> Double {
        let mine = entries.filter { $0.kind == .expense && $0.categoryID == categoryID && period.contains($0.date) }
        let total = mine.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return 0 }
        let weekend = mine.filter { calendar.isDateInWeekend($0.date) }.reduce(0) { $0 + $1.amount }
        return Double(weekend) / Double(total)
    }

    /// Average spending per category over up to 3 previous periods that had spending (at least 2 needed),
    /// rounded up to 50 DH. Suggested when it differs from the budget by 15% and at least 100 DH, or there is no budget.
    static func budgetSuggestions(categories: [CategoryValue], entries: [EntryValue], current: BudgetPeriod,
                                  payday: Int, calendar: Calendar = .current) -> [BudgetSuggestion] {
        let periods = (1...3).map { BudgetCalculator.period(current, offset: -$0, payday: payday, calendar: calendar) }
        let active = periods.filter { p in entries.contains { $0.kind == .expense && p.contains($0.date) } }
        guard active.count >= 2 else { return [] }
        let step = Money.scaled(5_000)
        return categories.compactMap { c in
            let total = entries.filter { e in e.kind == .expense && e.categoryID == c.id && active.contains { $0.contains(e.date) } }
                .reduce(0) { $0 + $1.amount }
            let average = total / active.count
            guard average > 0 else { return nil }
            let rounded = (average + step - 1) / step * step
            if c.budget == 0 { return rounded >= step ? BudgetSuggestion(categoryID: c.id, amount: rounded) : nil }
            let gap = abs(rounded - c.budget)
            guard gap >= max(Money.scaled(10_000), c.budget * 15 / 100) else { return nil }
            return BudgetSuggestion(categoryID: c.id, amount: rounded)
        }
    }

    /// The largest expense of the period.
    static func biggestExpense(_ entries: [EntryValue], period: BudgetPeriod) -> EntryValue? {
        entries.filter { $0.kind == .expense && period.contains($0.date) }.max { $0.amount < $1.amount }
    }

    /// Whole days left before the next payday (today counts).
    static func daysLeft(in period: BudgetPeriod, now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: period.end).day ?? 0)
    }
}
