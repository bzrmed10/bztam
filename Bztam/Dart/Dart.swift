import Foundation
import SwiftData

/// A dart (tontine): every member pays the same amount each month, and one member collects the whole pot in turn.
/// CloudKit-friendly: every property has a default.
@Model
final class Dart {
    var id: UUID = UUID()
    var name: String = ""
    /// What each member pays every round.
    var amount: Int = 0
    /// Date of the first round; the next rounds fall on the same day of the following months.
    var startDate: Date = Date()
    /// Members in turn order: member 0 collects in round 0, and so on.
    var memberNames: [String] = []
    /// Which member is the user.
    var meIndex: Int = 0
    /// Payments as "round:member", e.g. "2:4".
    var paid: [String] = []
    /// Rounds where the user recorded collecting the pot.
    var received: [Int] = []
    /// Paying adds an expense and collecting adds money in.
    var tracksMoney: Bool = true
    /// Category key for the user's payments.
    var categoryKey: String = "other"
    var reminders: Bool = true
    var createdAt: Date = Date()

    init(name: String, amount: Centimes, startDate: Date, memberNames: [String], meIndex: Int) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.startDate = startDate
        self.memberNames = memberNames
        self.meIndex = meIndex
        self.createdAt = .now
    }

    var plan: DartPlan {
        DartPlan(amount: amount, start: startDate, members: memberNames, meIndex: meIndex,
                 paid: Set(paid), received: Set(received))
    }

    /// The member name to show: the user is "You".
    func displayName(_ index: Int) -> String {
        index == meIndex ? L10n.t("You") : (memberNames.indices.contains(index) ? memberNames[index] : "")
    }
}

/// Where a dart stands on a given day.
enum DartStatus: Equatable, Sendable {
    case notStarted(first: Date)
    /// The round running now (it started on its date and lasts until the next round).
    case round(Int)
    case finished
}

/// All dart math, on plain values. Pure, unit-tested.
struct DartPlan: Equatable, Sendable {
    var amount: Centimes
    var start: Date
    var members: [String]
    var meIndex: Int
    var paid: Set<String> = []
    var received: Set<Int> = []

    var count: Int { members.count }
    /// What the collector gets each round: everyone's share, theirs included.
    var pot: Centimes { amount * count }

    static func key(round: Int, member: Int) -> String { "\(round):\(member)" }

    func date(ofRound r: Int, calendar: Calendar = .current) -> Date {
        RecurringEngine.occurrence(r, frequency: .monthly, start: start, calendar: calendar)
    }

    func collector(ofRound r: Int) -> Int { count == 0 ? 0 : r % count }

    /// The round where the user collects.
    var myRound: Int { meIndex }

    func status(on now: Date = .now, calendar: Calendar = .current) -> DartStatus {
        guard count > 0 else { return .finished }
        let today = calendar.startOfDay(for: now)
        if today < calendar.startOfDay(for: start) { return .notStarted(first: start) }
        if today >= calendar.startOfDay(for: date(ofRound: count, calendar: calendar)) { return .finished }
        var r = 0
        while r + 1 < count && calendar.startOfDay(for: date(ofRound: r + 1, calendar: calendar)) <= today { r += 1 }
        return .round(r)
    }

    func hasPaid(_ member: Int, round r: Int) -> Bool { paid.contains(Self.key(round: r, member: member)) }

    func paidCount(round r: Int) -> Int { (0..<count).filter { hasPaid($0, round: r) }.count }

    /// Rounds the user has paid.
    var myPaidRounds: [Int] { (0..<count).filter { hasPaid(meIndex, round: $0) } }

    /// What the user has put in so far, and what they collected.
    var myPaidTotal: Centimes { myPaidRounds.count * amount }
    var myReceivedTotal: Centimes { received.contains(myRound) ? pot : 0 }

    /// Rounds up to now (or all once finished) where the user hasn't paid yet.
    func myUnpaidRounds(on now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let last: Int
        switch status(on: now, calendar: calendar) {
        case .notStarted: return []
        case .round(let r): last = r
        case .finished: last = count - 1
        }
        return (0...last).filter { !hasPaid(meIndex, round: $0) }
    }

    /// Round dates from today on, for reminders.
    func upcomingRounds(after now: Date = .now, limit: Int = 3, calendar: Calendar = .current) -> [(round: Int, date: Date)] {
        let today = calendar.startOfDay(for: now)
        var result: [(round: Int, date: Date)] = []
        for r in 0..<count where result.count < limit {
            let d = date(ofRound: r, calendar: calendar)
            if calendar.startOfDay(for: d) >= today { result.append((round: r, date: d)) }
        }
        return result
    }
}
