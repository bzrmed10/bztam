import Foundation

/// Spending in one category for a period (nil = no category).
struct CategorySpend: Equatable, Sendable {
    var categoryID: UUID?
    var amount: Centimes
}

/// How one category changed from the previous period.
struct CategoryChange: Equatable, Sendable {
    var categoryID: UUID?
    var current: Centimes
    var previous: Centimes
    /// +0.18 = 18% more.
    var ratio: Double
}

/// Numbers for the Insights tab. Pure, unit-tested.
enum InsightsCalculator {
    /// Expenses per category in the period, largest first.
    static func spendByCategory(_ entries: [EntryValue], period: BudgetPeriod) -> [CategorySpend] {
        var totals: [UUID?: Centimes] = [:]
        for e in entries where e.kind == .expense && period.contains(e.date) {
            totals[e.categoryID, default: 0] += e.amount
        }
        return totals.map { CategorySpend(categoryID: $0.key, amount: $0.value) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : ($0.categoryID?.uuidString ?? "") < ($1.categoryID?.uuidString ?? "") }
    }

    /// Keeps the `limit - 1` largest slices and folds the rest into one "other" slice (categoryID nil).
    static func topSlices(_ spends: [CategorySpend], limit: Int = 6) -> [CategorySpend] {
        guard spends.count > limit else { return spends }
        let head = Array(spends.prefix(limit - 1))
        let rest = spends.dropFirst(limit - 1).reduce(0) { $0 + $1.amount }
        return head + [CategorySpend(categoryID: nil, amount: rest)]
    }

    /// Relative change; nil when there is nothing to compare with.
    static func change(current: Centimes, previous: Centimes) -> Double? {
        guard previous > 0 else { return nil }
        return Double(current - previous) / Double(previous)
    }

    /// The categories that changed the most (at least 50 DH in one of the two periods), up to `limit`.
    static func biggestChanges(current: [CategorySpend], previous: [CategorySpend],
                               minimum: Centimes = Money.scaled(5_000), limit: Int = 3) -> [CategoryChange] {
        var ids = Set(current.map(\.categoryID))
        ids.formUnion(previous.map(\.categoryID))
        let changes: [CategoryChange] = ids.compactMap { id in
            let c = current.first { $0.categoryID == id }?.amount ?? 0
            let p = previous.first { $0.categoryID == id }?.amount ?? 0
            guard id != nil, max(c, p) >= minimum, p > 0, let r = change(current: c, previous: p), abs(r) >= 0.05 else { return nil }
            return CategoryChange(categoryID: id, current: c, previous: p, ratio: r)
        }
        return Array(changes.sorted { abs($0.ratio) != abs($1.ratio) ? abs($0.ratio) > abs($1.ratio) : $0.current > $1.current }.prefix(limit))
    }
}
