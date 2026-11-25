import Foundation

/// Suggests a first monthly plan from a few easy answers, for people who don't know what each category should get.
/// Pure, unit-tested.
enum BudgetPlanner {
    enum Level: Int, CaseIterable, Sendable { case low, mid, high }

    /// What to do with money nobody claimed.
    enum Leftover: String, CaseIterable, Sendable { case buffer, savings, spread }

    struct Answers: Equatable, Sendable {
        var income: Centimes
        /// Fixed bills by category key ("rent", "loans", "phone"…); several bills can share a key.
        var fixed: [String: Centimes] = [:]
        /// How often you eat out or go to cafés.
        var eatingOut: Level = .mid
        /// low = walk or public transport, mid = taxis, high = your own car.
        var gettingAround: Level = .mid
        /// low = not now, mid = a little (10%), high = a lot (20%).
        var saving: Level = .mid
        /// People you buy groceries for.
        var adults: Int = 1
        var children: Int = 0
    }

    struct Plan: Equatable, Sendable {
        /// Budget per category key.
        var budgets: [String: Centimes]
        /// Kept aside for savings each month.
        var savings: Centimes
        /// Money in that no category or savings claims.
        var leftover: Centimes = 0
    }

    static let everydayKeys = ["courses", "food", "goingout", "transport", "other"]

    /// Groceries share of income: about 12% for one person, more for each extra adult and child, capped.
    static func groceriesPercent(adults: Int, children: Int) -> Int {
        min(35, 12 + 5 * max(0, adults - 1) + 4 * max(0, children))
    }

    /// Share of income for each everyday category before scaling, in percent.
    static func weights(_ a: Answers) -> [String: Int] {
        let food = [4, 8, 12][a.eatingOut.rawValue]
        let goingOut = [3, 6, 9][a.eatingOut.rawValue]
        let transport = [3, 7, 11][a.gettingAround.rawValue]
        return ["courses": groceriesPercent(adults: a.adults, children: a.children), "food": food,
                "goingout": goingOut, "transport": transport, "other": 4]
    }

    static func plan(_ a: Answers) -> Plan {
        let fixed = a.fixed.filter { $0.value > 0 }
        var budgets = fixed
        guard a.income > 0 else { return Plan(budgets: budgets, savings: 0) }

        let fixedTotal = fixed.values.reduce(0, +)
        let wantedSavings = round50(a.income * [0, 10, 20][a.saving.rawValue] / 100)
        let savings = fixedTotal + wantedSavings <= a.income ? wantedSavings : 0
        let available = max(0, a.income - fixedTotal - savings)
        let wanted = weights(a).mapValues { a.income * $0 / 100 }
        let wantedTotal = wanted.values.reduce(0, +)
        // Shrink everyday categories evenly when they don't fit in what's left after bills and savings.
        let scale = wantedTotal > available && wantedTotal > 0 ? Double(available) / Double(wantedTotal) : 1
        for (key, amount) in wanted {
            // A bill in an everyday category (a transport pass) comes on top of the everyday amount.
            budgets[key] = (fixed[key] ?? 0) + round50(Int(Double(amount) * scale))
        }
        let used = budgets.values.reduce(0, +) + savings
        return Plan(budgets: budgets, savings: savings, leftover: max(0, a.income - used))
    }

    /// Applies the leftover choice: keep it, add it to savings, or share it across everyday categories.
    static func apply(_ choice: Leftover, to plan: Plan, answers: Answers) -> Plan {
        guard plan.leftover > 0 else { return plan }
        var p = plan
        switch choice {
        case .buffer:
            return plan
        case .savings:
            p.savings += round50(plan.leftover)
            p.leftover = plan.leftover - round50(plan.leftover)
        case .spread:
            let w = weights(answers)
            let total = w.values.reduce(0, +)
            guard total > 0 else { return plan }
            var given = 0
            for key in everydayKeys {
                let extra = round50(plan.leftover * (w[key] ?? 0) / total)
                p.budgets[key, default: 0] += extra
                given += extra
            }
            p.leftover = plan.leftover - given
        }
        return p
    }

    /// Down to the nearest 50 DH (or a round amount of the same size in other currencies): 1,249 DH becomes 1,200 DH.
    static func round50(_ centimes: Centimes) -> Centimes {
        let step = Money.scaled(5_000)
        return max(0, centimes) / step * step
    }
}
