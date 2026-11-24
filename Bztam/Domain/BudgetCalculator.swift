import Foundation

/// A budget month: from payday (inclusive) to the next payday (exclusive).
struct BudgetPeriod: Equatable, Hashable, Sendable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    /// Last day inside the period (for "25 Oct – 24 Nov").
    func lastDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: end) ?? end
    }
}

/// Plain values the calculator works on, so it never touches the database.
struct EntryValue: Sendable, Equatable {
    var kind: EntryKind
    var amount: Centimes
    var date: Date
    var categoryID: UUID?
}

struct CategoryValue: Sendable, Equatable {
    var id: UUID
    var budget: Centimes
    var isFixed: Bool
}

/// How a category stands in a period.
struct CategoryStatus: Sendable, Equatable {
    enum State: Sendable, Equatable {
        /// Money still available.
        case left(Centimes)
        /// Spent more than the budget, by this much.
        case over(Centimes)
        /// A fixed category fully paid.
        case paid
        /// No budget set.
        case noBudget
    }

    var budget: Centimes
    var spent: Centimes
    var state: State

    /// Share of the budget spent, 0...1 (1 when over).
    var progress: Double {
        guard budget > 0 else { return spent > 0 ? 1 : 0 }
        return min(1, Double(spent) / Double(budget))
    }
}

/// Totals for a period.
struct PeriodSummary: Sendable, Equatable {
    var moneyIn: Centimes
    var spent: Centimes
    /// Money in (plus what came from last month) minus spent, minus what was put aside in savings goals.
    var left: Centimes { moneyIn + carriedIn - carriedOut - spent - saved }
    /// Sum of category budgets.
    var planned: Centimes
    /// Money in (or the expected income when nothing came in yet) not given to any category.
    var notPlanned: Centimes
    /// Net money put aside in savings goals this period (saved, not spent).
    var saved: Centimes = 0
    /// Left over (or over, negative) from last month and carried into this one.
    var carriedIn: Centimes = 0
    /// Carried from this month into the next one, once this month ended.
    var carriedOut: Centimes = 0
    /// Share of money in already spent or put aside, 0...1.
    var progress: Double {
        let base = moneyIn + carriedIn
        guard base > 0 else { return spent + saved > 0 ? 1 : 0 }
        return min(1, Double(max(0, spent + saved + carriedOut)) / Double(base))
    }
}

/// All money math. Pure functions, unit-tested; the UI only displays what comes out of here.
enum BudgetCalculator {
    /// The period containing `date` for a payday (1...28; larger values are clamped to 28).
    static func period(containing date: Date, payday: Int, calendar: Calendar = .current) -> BudgetPeriod {
        let day = max(1, min(28, payday))
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let thisMonth = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: day))
            ?? calendar.startOfDay(for: date)
        let start = (comps.day ?? 1) < day
            ? (calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth)
            : thisMonth
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return BudgetPeriod(start: start, end: end)
    }

    /// The period `offset` periods away (negative = earlier).
    static func period(_ base: BudgetPeriod, offset: Int, payday: Int, calendar: Calendar = .current) -> BudgetPeriod {
        let moved = calendar.date(byAdding: .month, value: offset, to: base.start) ?? base.start
        return period(containing: moved, payday: payday, calendar: calendar)
    }

    static func summary(entries: [EntryValue], categories: [CategoryValue], period: BudgetPeriod,
                        expectedIncome: Centimes = 0, saved: Centimes = 0,
                        carriedIn: Centimes = 0, carriedOut: Centimes = 0) -> PeriodSummary {
        var moneyIn = 0, spent = 0
        for e in entries where period.contains(e.date) {
            switch e.kind {
            case .income: moneyIn += e.amount
            case .expense: spent += e.amount
            }
        }
        let planned = categories.reduce(0) { $0 + max(0, $1.budget) }
        let base = moneyIn > 0 ? moneyIn : expectedIncome
        return PeriodSummary(moneyIn: moneyIn, spent: spent, planned: planned, notPlanned: max(0, base - planned), saved: saved,
                             carriedIn: carriedIn, carriedOut: carriedOut)
    }

    static func status(for category: CategoryValue, entries: [EntryValue], period: BudgetPeriod) -> CategoryStatus {
        let spent = entries
            .filter { $0.kind == .expense && $0.categoryID == category.id && period.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
        let budget = max(0, category.budget)
        let state: CategoryStatus.State
        if budget == 0 {
            state = .noBudget
        } else if spent > budget {
            state = .over(spent - budget)
        } else if category.isFixed && spent == budget {
            state = .paid
        } else {
            state = .left(budget - spent)
        }
        return CategoryStatus(budget: budget, spent: spent, state: state)
    }

    /// Sort order for Home: categories still being spent first, over-budget among them, paid and empty last.
    static func homeRank(_ status: CategoryStatus) -> Int {
        switch status.state {
        case .left, .over: 0
        case .noBudget: status.spent > 0 ? 0 : 2
        case .paid: 1
        }
    }
}
