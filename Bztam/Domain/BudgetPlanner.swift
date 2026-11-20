import Foundation

/// Suggests a first monthly plan from a few easy answers, for people who don't know what each category should get.
/// Pure, unit-tested.
enum BudgetPlanner {
    enum Level: Int, CaseIterable, Sendable { case low, mid, high }

    struct Answers: Equatable, Sendable {
        var income: Centimes
        /// Fixed bills by category key ("rent", "bills", "phone"); missing means you don't pay it.
        var fixed: [String: Centimes] = [:]
        /// How often you eat out or go to cafés.
        var eatingOut: Level = .mid
        /// low = walk or public transport, mid = taxis, high = your own car.
        var gettingAround: Level = .mid
        /// low = not now, mid = a little (10%), high = a lot (20%).
        var saving: Level = .mid
    }

    struct Plan: Equatable, Sendable {
        /// Budget per category key.
        var budgets: [String: Centimes]
        /// Kept aside for savings (left unplanned on purpose).
        var savings: Centimes
    }

    /// Share of income for each everyday category before scaling, in percent.
    static func weights(_ a: Answers) -> [String: Int] {
        let food = [4, 8, 12][a.eatingOut.rawValue]
        let goingOut = [3, 6, 9][a.eatingOut.rawValue]
        let transport = [3, 7, 11][a.gettingAround.rawValue]
        return ["courses": 15, "food": food, "goingout": goingOut, "transport": transport, "other": 4]
    }

    static func plan(_ a: Answers) -> Plan {
        var budgets: [String: Centimes] = [:]
        for (key, amount) in a.fixed where amount > 0 { budgets[key] = amount }
        guard a.income > 0 else { return Plan(budgets: budgets, savings: 0) }

        let fixedTotal = budgets.values.reduce(0, +)
        let savings = round50(a.income * [0, 10, 20][a.saving.rawValue] / 100)
        let available = max(0, a.income - fixedTotal - savings)
        let w = weights(a)
        let wanted = w.mapValues { a.income * $0 / 100 }
        let wantedTotal = wanted.values.reduce(0, +)
        // Shrink everyday categories evenly when they don't fit in what's left after bills and savings.
        let scale = wantedTotal > available && wantedTotal > 0 ? Double(available) / Double(wantedTotal) : 1
        for (key, amount) in wanted {
            budgets[key] = round50(Int(Double(amount) * scale))
        }
        return Plan(budgets: budgets, savings: fixedTotal + savings <= a.income ? savings : 0)
    }

    /// Down to the nearest 50 DH: 1,249 DH becomes 1,200 DH.
    static func round50(_ centimes: Centimes) -> Centimes {
        let step = 50 * 100
        return max(0, centimes) / step * step
    }
}
