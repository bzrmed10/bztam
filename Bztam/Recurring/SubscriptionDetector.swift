import Foundation

/// A shop paid about the same amount every month that isn't recurring yet.
struct SubscriptionCandidate: Equatable, Sendable {
    var key: String
    var merchant: String
    var amount: Centimes
    var categoryID: UUID?
    var lastDate: Date
}

/// Finds subscriptions and regular bills in the history ("Make this recurring?"). Pure, unit-tested.
enum SubscriptionDetector {
    static let dismissedKey = "dismissedSubscriptions"

    /// Same shop in at least 3 of the last 4 months, amounts within 10% of the latest, last one in the past 45 days.
    static func candidates(_ records: [EntryRecord], excluding excluded: Set<String>, now: Date = .now,
                           calendar: Calendar = .current) -> [SubscriptionCandidate] {
        let recentMonths: Set<Int> = Set((0..<4).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: now).map { monthIndex($0, calendar) }
        })
        let groups = Dictionary(grouping: records.filter { $0.kind == .expense }) { CategoryMemory.key($0.merchant) }
        return groups.compactMap { key, items -> SubscriptionCandidate? in
            guard !key.isEmpty, !excluded.contains(key), let latest = items.max(by: { $0.date < $1.date }) else { return nil }
            guard now.timeIntervalSince(latest.date) <= 45 * 86_400 else { return nil }
            let recent = items.filter { recentMonths.contains(monthIndex($0.date, calendar)) }
            let months = Set(recent.map { monthIndex($0.date, calendar) })
            guard months.count >= 3 else { return nil }
            let tolerance = max(latest.amount / 10, 100)
            guard recent.allSatisfy({ abs($0.amount - latest.amount) <= tolerance }) else { return nil }
            guard recent.count <= months.count + 1 else { return nil }
            return SubscriptionCandidate(key: key, merchant: latest.merchant, amount: latest.amount,
                                         categoryID: latest.categoryID, lastDate: latest.date)
        }
        .sorted { $0.amount > $1.amount }
    }

    private static func monthIndex(_ date: Date, _ calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.year, .month], from: date)
        return (c.year ?? 0) * 12 + (c.month ?? 0)
    }

    static var dismissed: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])
    }

    static func dismiss(_ key: String) {
        var set = dismissed
        set.insert(key)
        UserDefaults.standard.set(Array(set), forKey: dismissedKey)
    }
}
