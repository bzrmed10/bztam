import Foundation

/// One category with its numbers for a period, ready to display.
struct CategoryLine: Identifiable {
    let category: BudgetCategory
    let status: CategoryStatus
    var id: UUID { category.id }
}

/// Bridges SwiftData objects to `BudgetCalculator`.
@MainActor
enum BudgetSnapshot {
    static func values(_ entries: [Entry]) -> [EntryValue] {
        entries.map { EntryValue(kind: $0.kind, amount: $0.amount, date: $0.date, categoryID: $0.category?.id) }
    }

    /// The category for the calculator; with a period, money moved for that period is included.
    static func value(_ category: BudgetCategory, period: BudgetPeriod? = nil) -> CategoryValue {
        CategoryValue(id: category.id, budget: period.map { category.budget(in: $0) } ?? category.budget, isFixed: category.isFixed)
    }

    static func summary(entries: [Entry], categories: [BudgetCategory], period: BudgetPeriod, expectedIncome: Centimes,
                        moves: [GoalMove] = []) -> PeriodSummary {
        BudgetCalculator.summary(entries: values(entries), categories: categories.map { value($0, period: period) },
                                 period: period, expectedIncome: expectedIncome,
                                 saved: GoalMath.saved(in: period, moves: GoalMove.values(moves)))
    }

    /// Lines in Home order: still being spent first, then paid, then unused; each group by the user's order.
    static func lines(entries: [Entry], categories: [BudgetCategory], period: BudgetPeriod) -> [CategoryLine] {
        let ev = values(entries)
        return categories
            .map { CategoryLine(category: $0, status: BudgetCalculator.status(for: value($0, period: period), entries: ev, period: period)) }
            .sorted {
                let a = BudgetCalculator.homeRank($0.status), b = BudgetCalculator.homeRank($1.status)
                return a != b ? a < b : $0.category.order < $1.category.order
            }
    }
}

/// Date labels in the app language.
enum DateText {
    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    /// "25 Oct – 24 Nov"
    static func period(_ p: BudgetPeriod) -> String {
        let f = formatter("d MMM")
        return f.string(from: p.start) + " – " + f.string(from: p.lastDay())
    }

    /// "25 Nov"
    static func short(_ date: Date) -> String { formatter("d MMM").string(from: date) }

    /// "July 2027"
    static func month(_ date: Date) -> String { formatter("MMMM yyyy").string(from: date) }

    /// "July"
    static func monthName(_ date: Date) -> String { formatter("MMMM").string(from: date) }

    /// "Today", "Yesterday" or "12 Nov".
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return L10n.t("Today") }
        if calendar.isDateInYesterday(date) { return L10n.t("Yesterday") }
        return formatter("d MMM").string(from: date)
    }
}
