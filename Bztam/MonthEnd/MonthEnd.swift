import Foundation
import SwiftData
import UserNotifications

/// What the user did with the money left (or over) when a month ended.
enum MonthEndChoice: String, Codable, CaseIterable, Sendable {
    /// Carried into the next month (adds to it, or takes from it when over).
    case nextMonth
    /// Put into a savings goal (or taken from one when over).
    case goal
    /// Nothing moves; just a record.
    case leave
}

/// One decision per ended month. No relationships, every property has a default: CloudKit-friendly.
@Model
final class MonthClose {
    var id: UUID = UUID()
    /// The month that ended: its first day and the next payday.
    var periodStart: Date = Date.distantPast
    var periodEnd: Date = Date.distantPast
    /// What was left (positive) or over (negative) when the user decided.
    var amount: Int = 0
    /// What actually moved: to next month or to a goal, same sign as `amount`; 0 for "leave it".
    var moved: Int = 0
    var choiceRaw: String = MonthEndChoice.leave.rawValue
    var goalID: UUID?
    var goalMoveID: UUID?
    /// Done by the "When the month ends" setting, not by a tap.
    var automatic: Bool = false
    var decidedAt: Date = Date()

    init(period: BudgetPeriod, amount: Centimes, moved: Centimes, choice: MonthEndChoice, goalID: UUID? = nil,
         goalMoveID: UUID? = nil, automatic: Bool = false) {
        self.id = UUID()
        self.periodStart = period.start
        self.periodEnd = period.end
        self.amount = amount
        self.moved = moved
        self.choiceRaw = choice.rawValue
        self.goalID = goalID
        self.goalMoveID = goalMoveID
        self.automatic = automatic
        self.decidedAt = .now
    }

    var choice: MonthEndChoice { MonthEndChoice(rawValue: choiceRaw) ?? .leave }
}

/// Plain values for the math.
struct MonthCloseValue: Sendable, Equatable {
    var periodStart: Date
    var periodEnd: Date
    var amount: Centimes
    var moved: Centimes
    var choice: MonthEndChoice
    var goalID: UUID? = nil
    var decidedAt: Date = .distantPast
}

/// One past month for the "Past months" list.
struct MonthResult: Sendable, Equatable {
    var period: BudgetPeriod
    /// Left (positive) or over (negative) before any decision.
    var left: Centimes
    var close: MonthCloseValue?
}

/// All month-end math. Pure, unit-tested.
enum MonthEndMath {
    /// One decision per month: the latest wins (two iPhones may both decide while offline).
    static func latest(_ closes: [MonthCloseValue], calendar: Calendar = .current) -> [MonthCloseValue] {
        var byDay: [Date: MonthCloseValue] = [:]
        for c in closes {
            let key = calendar.startOfDay(for: c.periodStart)
            if let old = byDay[key], old.decidedAt >= c.decidedAt { continue }
            byDay[key] = c
        }
        return Array(byDay.values)
    }

    /// Money carried into `period` from the month before (negative when that month went over).
    static func carriedIn(_ period: BudgetPeriod, closes: [MonthCloseValue]) -> Centimes {
        latest(closes).filter { $0.choice == .nextMonth && period.contains($0.periodEnd) && !period.contains($0.periodStart) }
            .reduce(0) { $0 + $1.moved }
    }

    /// Money that left `period` for the next month.
    static func carriedOut(_ period: BudgetPeriod, closes: [MonthCloseValue]) -> Centimes {
        latest(closes).filter { $0.choice == .nextMonth && period.contains($0.periodStart) }.reduce(0) { $0 + $1.moved }
    }

    static func close(for period: BudgetPeriod, in closes: [MonthCloseValue], calendar: Calendar = .current) -> MonthCloseValue? {
        latest(closes, calendar: calendar).first { calendar.isDate($0.periodStart, inSameDayAs: period.start) }
    }

    /// How many days into the new month the question is still asked.
    static let askDays = 10

    /// What to ask about the month that just ended: left (positive) or over (negative), or nil when there's nothing to ask.
    /// Asked only when the app was in use before that month ended, money came in that month, and nothing was decided yet.
    static func pending(previous: BudgetPeriod, current: BudgetPeriod, previousSummary: PeriodSummary,
                        closes: [MonthCloseValue], firstUse: Date, now: Date = .now, calendar: Calendar = .current) -> Centimes? {
        guard firstUse < previous.end, previousSummary.moneyIn > 0,
              close(for: previous, in: closes, calendar: calendar) == nil,
              let lastDay = calendar.date(byAdding: .day, value: askDays, to: current.start), now < lastDay else { return nil }
        let left = previousSummary.left
        return left == 0 ? nil : left
    }

    /// The last `count` months before `current` with money in or spending, newest first.
    static func history(entries: [EntryValue], moves: [GoalMoveValue], closes: [MonthCloseValue], current: BudgetPeriod,
                        payday: Int, count: Int = 6, calendar: Calendar = .current) -> [MonthResult] {
        var out: [MonthResult] = []
        for k in 1...24 where out.count < count {
            let p = BudgetCalculator.period(current, offset: -k, payday: payday, calendar: calendar)
            let s = BudgetCalculator.summary(entries: entries, categories: [], period: p,
                                             saved: GoalMath.saved(in: p, moves: moves),
                                             carriedIn: carriedIn(p, closes: closes), carriedOut: carriedOut(p, closes: closes))
            guard s.moneyIn > 0 || s.spent > 0 else { continue }
            let c = close(for: p, in: closes, calendar: calendar)
            out.append(MonthResult(period: p, left: c?.amount ?? s.left, close: c))
        }
        return out
    }
}

@MainActor
extension MonthClose {
    static func values(_ closes: [MonthClose]) -> [MonthCloseValue] {
        closes.map { MonthCloseValue(periodStart: $0.periodStart, periodEnd: $0.periodEnd, amount: $0.amount, moved: $0.moved,
                                     choice: $0.choice, goalID: $0.goalID, decidedAt: $0.decidedAt) }
    }
}

/// The "When the month ends" setting.
enum MonthEndMode: String, CaseIterable, Identifiable, Sendable {
    case ask, nextMonth, savings, leave
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: L10n.t("Ask me")
        case .nextMonth: L10n.t("Add to next month")
        case .savings: L10n.t("Add to savings")
        case .leave: L10n.t("Leave it")
        }
    }
}

/// Deciding, undoing, and the payday notification.
@MainActor
enum MonthEnd {
    static let modeKey = "monthEndMode"
    static let notifyKey = "monthEndNotify"
    static let notificationID = "month-end"

    static var mode: MonthEndMode { MonthEndMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .ask }
    static var notifyOn: Bool { UserDefaults.standard.object(forKey: notifyKey) as? Bool ?? true }

    /// Records the decision. For a goal, money goes in on the month's last moment (so that month ends at zero);
    /// when the month went over, it comes out of the goal, at most what the goal holds.
    @discardableResult
    static func decide(_ choice: MonthEndChoice, amount: Centimes, period: BudgetPeriod, goal: SavingsGoal? = nil,
                       automatic: Bool = false, context: ModelContext) -> MonthClose {
        var moved = 0
        var moveID: UUID?
        switch choice {
        case .nextMonth:
            moved = amount
        case .goal:
            if let goal {
                let moves = (try? context.fetch(FetchDescriptor<GoalMove>())) ?? []
                let saved = GoalMath.saved(goal.id, in: GoalMove.values(moves))
                moved = amount > 0 ? amount : -min(-amount, saved)
                if moved != 0 {
                    let move = GoalMove(goalID: goal.id, amount: moved, date: period.end.addingTimeInterval(-1))
                    context.insert(move)
                    moveID = move.id
                }
            }
        case .leave:
            break
        }
        let close = MonthClose(period: period, amount: amount, moved: moved, choice: choice, goalID: goal?.id,
                               goalMoveID: moveID, automatic: automatic)
        context.insert(close)
        try? context.save()
        WidgetSync.update(context: context)
        return close
    }

    /// Takes the decision back: the question comes back on Home.
    static func undo(_ close: MonthClose, context: ModelContext) {
        if let moveID = close.goalMoveID,
           let move = try? context.fetch(FetchDescriptor<GoalMove>(predicate: #Predicate { $0.id == moveID })).first {
            context.delete(move)
        }
        context.delete(close)
        try? context.save()
        WidgetSync.update(context: context)
    }

    /// A monthly notification on payday morning.
    static func scheduleNotification(payday: Int) {
        let on = notifyOn
        let title = L10n.t("Your month is done")
        let body = L10n.t("See what's left and choose where it goes.")
        let day = max(1, min(28, payday))
        let id = notificationID
        Task.detached {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [id])
            guard on else { return }
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            var when = DateComponents()
            when.day = day
            when.hour = 10
            try? await center.add(UNNotificationRequest(identifier: id, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        }
    }
}
