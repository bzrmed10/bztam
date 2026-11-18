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

    static func value(_ category: BudgetCategory) -> CategoryValue {
        CategoryValue(id: category.id, budget: category.budget, isFixed: category.isFixed)
    }

    static func summary(entries: [Entry], categories: [BudgetCategory], period: BudgetPeriod, expectedIncome: Centimes) -> PeriodSummary {
        BudgetCalculator.summary(entries: values(entries), categories: categories.map(value),
                                 period: period, expectedIncome: expectedIncome)
    }

    /// Lines in Home order: still being spent first, then paid, then unused; each group by the user's order.
    static func lines(entries: [Entry], categories: [BudgetCategory], period: BudgetPeriod) -> [CategoryLine] {
        let ev = values(entries)
        return categories
            .map { CategoryLine(category: $0, status: BudgetCalculator.status(for: value($0), entries: ev, period: period)) }
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

    /// "Today", "Yesterday" or "12 Nov".
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return L10n.t("Today") }
        if calendar.isDateInYesterday(date) { return L10n.t("Yesterday") }
        return formatter("d MMM").string(from: date)
    }
}
