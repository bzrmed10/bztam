import Foundation
import SwiftData

/// Something you save for: "Summer trip, 6,000 DH by July". Money put aside lowers what's left to spend,
/// but it is saved, not spent, so it never shows in spending.
@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "leaf"
    /// 0 means no target (just saving).
    var target: Int = 0
    var deadline: Date?
    /// What you plan to put aside each month (0 = no plan).
    var monthlyPlan: Int = 0
    var order: Int = 0
    var isArchived: Bool = false
    var reachedAt: Date?
    var createdAt: Date = Date()

    init(name: String, symbol: String = "leaf", target: Centimes = 0, deadline: Date? = nil, monthlyPlan: Centimes = 0, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.target = target
        self.deadline = deadline
        self.monthlyPlan = monthlyPlan
        self.order = order
        self.createdAt = .now
    }
}

/// Money put into a goal (positive) or taken out (negative).
@Model
final class GoalMove {
    var id: UUID = UUID()
    var goalID: UUID?
    var amount: Int = 0
    var date: Date = Date()
    var createdAt: Date = Date()

    init(goalID: UUID, amount: Centimes, date: Date = .now) {
        self.id = UUID()
        self.goalID = goalID
        self.amount = amount
        self.date = date
        self.createdAt = .now
    }
}

/// Plain values for the math, so it never touches the database.
struct GoalMoveValue: Sendable, Equatable {
    var goalID: UUID?
    var amount: Centimes
    var date: Date
}

/// All goal math. Pure, unit-tested.
enum GoalMath {
    static let symbols = ["leaf", "airplane", "house", "car", "graduationcap", "gift", "heart", "cross.case",
                          "laptopcomputer", "sparkles", "moon.stars", "shield"]

    static func saved(_ goalID: UUID, in moves: [GoalMoveValue]) -> Centimes {
        max(0, moves.filter { $0.goalID == goalID }.reduce(0) { $0 + $1.amount })
    }

    /// Net money put aside during a period, all goals together (taking out counts back).
    static func saved(in period: BudgetPeriod, moves: [GoalMoveValue]) -> Centimes {
        moves.filter { period.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    /// Put aside for one goal during a period.
    static func saved(_ goalID: UUID, in period: BudgetPeriod, moves: [GoalMoveValue]) -> Centimes {
        moves.filter { $0.goalID == goalID && period.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    static func progress(saved: Centimes, target: Centimes) -> Double {
        guard target > 0 else { return 0 }
        return min(1, Double(saved) / Double(target))
    }

    /// Whole months from now until the deadline, counting the current one (at least 1).
    static func monthsLeft(until deadline: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.dateComponents([.year, .month], from: now)
        let end = calendar.dateComponents([.year, .month], from: deadline)
        let months = ((end.year ?? 0) - (start.year ?? 0)) * 12 + ((end.month ?? 0) - (start.month ?? 0))
        return max(1, months + (deadline > now ? 0 : 1))
    }

    /// What to put aside each month to reach the target on time, rounded up to 10 (0 when there is nothing to plan).
    static func suggestedMonthly(target: Centimes, saved: Centimes, deadline: Date?, now: Date = .now,
                                 calendar: Calendar = .current) -> Centimes {
        guard target > saved, let deadline else { return 0 }
        let months = monthsLeft(until: deadline, now: now, calendar: calendar)
        let raw = (target - saved + months - 1) / months
        let step = 10 * 100
        return (raw + step - 1) / step * step
    }
}

@MainActor
extension GoalMove {
    static func values(_ moves: [GoalMove]) -> [GoalMoveValue] {
        moves.map { GoalMoveValue(goalID: $0.goalID, amount: $0.amount, date: $0.date) }
    }
}
