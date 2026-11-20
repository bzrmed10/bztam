import Foundation

/// Last week's spending compared with usual. Pure, unit-tested.
struct WeeklyRecap: Equatable, Sendable {
    /// Monday of the week the recap is about.
    var weekStart: Date
    var spent: Centimes
    /// Average of the 4 weeks before (nil when there's no history yet).
    var usual: Centimes?
    /// Category with the most spending that week.
    var topCategoryID: UUID?
    var topAmount: Centimes

    /// −18 means 18% less than usual.
    var change: Int? {
        guard let usual, usual > 0 else { return nil }
        return Int((Double(spent - usual) / Double(usual) * 100).rounded())
    }

    static func lastWeek(_ records: [EntryRecord], now: Date = .now, calendar: Calendar = .current) -> WeeklyRecap? {
        var cal = calendar
        cal.firstWeekday = 2
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now),
              let start = cal.date(byAdding: .day, value: -7, to: thisWeek.start) else { return nil }
        func spent(from: Date, to: Date) -> [EntryRecord] {
            records.filter { $0.kind == .expense && $0.date >= from && $0.date < to }
        }
        let week = spent(from: start, to: thisWeek.start)
        guard !week.isEmpty else { return nil }
        let total = week.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return nil }

        var previous: [Centimes] = []
        for k in 1...4 {
            guard let s = cal.date(byAdding: .day, value: -7 * k, to: start),
                  let e = cal.date(byAdding: .day, value: 7, to: s) else { continue }
            let w = spent(from: s, to: e)
            if !w.isEmpty { previous.append(w.reduce(0) { $0 + $1.amount }) }
        }
        let usual = previous.count >= 2 ? previous.reduce(0, +) / previous.count : nil

        let byCategory = Dictionary(grouping: week.filter { $0.amount > 0 }, by: \.categoryID).mapValues { $0.reduce(0) { $0 + $1.amount } }
        let top = byCategory.max { $0.value != $1.value ? $0.value < $1.value : ($0.key?.uuidString ?? "") > ($1.key?.uuidString ?? "") }
        return WeeklyRecap(weekStart: start, spent: total, usual: usual, topCategoryID: top?.key ?? nil, topAmount: top?.value ?? 0)
    }
}

/// Spending that's well above usual. Pure, unit-tested.
struct UnusualSpending: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        /// A category this period, compared with the same point of the last periods.
        case category(UUID)
        /// A bill paid every month (same shop), compared with its usual amount.
        case bill(merchant: String)
    }

    var kind: Kind
    var amount: Centimes
    var usual: Centimes
    /// +45 means 45% above usual.
    var percent: Int { usual > 0 ? Int((Double(amount - usual) / Double(usual) * 100).rounded()) : 0 }

    /// Stable key, to remember a dismissed alert.
    var id: String {
        switch kind {
        case .category(let id): "cat-\(id.uuidString)"
        case .bill(let m): "bill-\(m)"
        }
    }

    static func detect(_ records: [EntryRecord], period: BudgetPeriod, payday: Int, now: Date = .now,
                       calendar: Calendar = .current) -> [UnusualSpending] {
        var out: [UnusualSpending] = []
        let expenses = records.filter { $0.kind == .expense && $0.amount > 0 }

        // Categories: spent so far this period vs. the same number of days into each of the last 3 periods.
        let elapsed = max(1, calendar.dateComponents([.day], from: period.start, to: now).day ?? 1)
        guard elapsed >= 5 else { return billAlerts(expenses, period: period, calendar: calendar) }
        let past = (1...3).map { BudgetCalculator.period(period, offset: -$0, payday: payday, calendar: calendar) }
        let categories = Set(expenses.compactMap(\.categoryID))
        for id in categories {
            let spentNow = expenses.filter { $0.categoryID == id && period.contains($0.date) && $0.date <= now }.reduce(0) { $0 + $1.amount }
            let before: [Centimes] = past.compactMap { p in
                guard let cut = calendar.date(byAdding: .day, value: elapsed, to: p.start) else { return nil }
                let inPeriod = expenses.filter { p.contains($0.date) }
                guard !inPeriod.isEmpty else { return nil }
                return inPeriod.filter { $0.categoryID == id && $0.date < cut }.reduce(0) { $0 + $1.amount }
            }
            guard before.count >= 2 else { continue }
            let usual = before.reduce(0, +) / before.count
            if usual > 0, spentNow >= usual * 3 / 2, spentNow - usual >= 20_000 {
                out.append(UnusualSpending(kind: .category(id), amount: spentNow, usual: usual))
            }
        }
        out.sort { $0.percent > $1.percent }
        return billAlerts(expenses, period: period, calendar: calendar) + out
    }

    /// The newest payment to a shop paid in at least 3 of the previous months, 30% and 50 DH above its usual amount.
    static func billAlerts(_ expenses: [EntryRecord], period: BudgetPeriod, calendar: Calendar) -> [UnusualSpending] {
        let byShop = Dictionary(grouping: expenses.filter { !CategoryMemory.key($0.merchant).isEmpty }) { CategoryMemory.key($0.merchant) }
        var out: [UnusualSpending] = []
        for (_, list) in byShop {
            let sorted = list.sorted { $0.date < $1.date }
            guard let last = sorted.last, period.contains(last.date) else { continue }
            let earlier = sorted.dropLast().filter { !period.contains($0.date) }
            let months = Set(earlier.map { calendar.dateComponents([.year, .month], from: $0.date) })
            guard months.count >= 3, earlier.count <= months.count + 1 else { continue }
            let recent = Array(earlier.suffix(4))
            let usual = recent.reduce(0) { $0 + $1.amount } / recent.count
            if usual > 0, last.amount >= usual * 13 / 10, last.amount - usual >= 5_000 {
                out.append(UnusualSpending(kind: .bill(merchant: last.merchant.trimmingCharacters(in: .whitespaces)), amount: last.amount, usual: usual))
            }
        }
        return out.sorted { $0.percent > $1.percent }
    }
}
