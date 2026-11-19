import Foundation
import SwiftData

/// Someone you split bills with. Your own list, not your contacts.
@Model
final class Friend {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}

/// One shared bill, split equally.
/// Counting works like a bank account (option B): when you pay, the whole bill leaves your money;
/// what friends pay back comes back into the same category like a refund. When a friend pays,
/// nothing leaves your money until you pay them your share.
@Model
final class SplitBill {
    var id: UUID = UUID()
    var merchant: String = ""
    var total: Int = 0
    var date: Date = Date()
    var categoryID: UUID?
    /// Who paid at the table; nil means you.
    var payerID: UUID?
    /// Friends in the split (UUID strings).
    var memberIDs: [String] = []
    /// Whether you are one of the people sharing (you can pay for others without a share).
    var includesMe: Bool = true
    var createdAt: Date = Date()

    init(merchant: String, total: Centimes, date: Date, categoryID: UUID?, payerID: UUID?, memberIDs: [UUID], includesMe: Bool) {
        self.id = UUID()
        self.merchant = merchant
        self.total = total
        self.date = date
        self.categoryID = categoryID
        self.payerID = payerID
        self.memberIDs = memberIDs.map(\.uuidString)
        self.includesMe = includesMe
        self.createdAt = .now
    }

    var paidByMe: Bool { payerID == nil }
}

/// What one person owes the payer for one bill. Only shares that involve you are stored:
/// each friend's share when you paid, or your own share (friendID nil) when a friend paid.
@Model
final class SplitShare {
    var id: UUID = UUID()
    var billID: UUID = UUID()
    /// The friend who owes you; nil means it's your share, owed to the bill's payer.
    var friendID: UUID?
    var amount: Int = 0
    /// How much of it has been paid back (or let go).
    var settled: Int = 0
    var lastSettledAt: Date?

    init(billID: UUID, friendID: UUID?, amount: Centimes) {
        self.id = UUID()
        self.billID = billID
        self.friendID = friendID
        self.amount = amount
    }

    var open: Centimes { max(0, amount - settled) }
}

/// Split math on plain values. Pure, unit-tested.
enum SplitMath {
    /// Equal shares in centimes for `people` people; the leftover centimes go to the payer's own share
    /// (index `payerIndex`), or to the first people when the payer isn't sharing. Always sums to `total`.
    static func equalShares(total: Centimes, people: Int, payerIndex: Int?) -> [Centimes] {
        guard people > 0, total > 0 else { return [] }
        let base = total / people
        var shares = Array(repeating: base, count: people)
        var rest = total - base * people
        if let p = payerIndex, shares.indices.contains(p) {
            shares[p] += rest
        } else {
            var i = 0
            while rest > 0 { shares[i % people] += 1; rest -= 1; i += 1 }
        }
        return shares
    }

    /// Spreads a payment over open debts, oldest first. Returns (index, amount) for each debt touched.
    static func allocate(_ payment: Centimes, over open: [Centimes]) -> [(index: Int, amount: Centimes)] {
        var left = payment
        var out: [(index: Int, amount: Centimes)] = []
        for (i, o) in open.enumerated() where left > 0 && o > 0 {
            let take = min(o, left)
            out.append((index: i, amount: take))
            left -= take
        }
        return out
    }
}

/// Balance with one friend, both directions kept apart (they can owe you and you can owe them).
struct FriendBalance: Identifiable, Equatable {
    let friendID: UUID
    var name: String
    /// What this friend still owes you.
    var owesYou: Centimes
    /// What you still owe this friend.
    var youOwe: Centimes
    var id: UUID { friendID }
    var net: Centimes { owesYou - youOwe }
}
