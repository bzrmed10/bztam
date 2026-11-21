import Foundation

/// The fixed bills offered in onboarding, the categories they go to, and the dates their recurring
/// entries start. Pure, unit-tested.
enum BillCatalog {
    struct Kind: Identifiable, Sendable, Equatable {
        let id: String
        let title: String
        let symbol: String
        /// Category the bill goes to.
        let categoryKey: String
        /// Same amount every month by default (becomes a recurring expense). Off for bills that change.
        let sameEveryMonth: Bool
    }

    static let kinds: [Kind] = [
        Kind(id: "rent", title: "Rent", symbol: "house", categoryKey: "rent", sameEveryMonth: true),
        Kind(id: "housingLoan", title: "Housing loan", symbol: "building.columns", categoryKey: "loans", sameEveryMonth: true),
        Kind(id: "loan", title: "Consumer loan", symbol: "creditcard", categoryKey: "loans", sameEveryMonth: true),
        Kind(id: "utilities", title: "Water and electricity", symbol: "bolt", categoryKey: "bills", sameEveryMonth: false),
        Kind(id: "phone", title: "Phone and internet", symbol: "iphone", categoryKey: "phone", sameEveryMonth: true),
        Kind(id: "school", title: "School fees", symbol: "graduationcap", categoryKey: "school", sameEveryMonth: true),
        Kind(id: "insurance", title: "Insurance", symbol: "shield", categoryKey: "insurance", sameEveryMonth: true),
        Kind(id: "transportPass", title: "Transport pass", symbol: "tram", categoryKey: "transport", sameEveryMonth: true),
        Kind(id: "gym", title: "Gym", symbol: "figure.run", categoryKey: "sport", sameEveryMonth: true),
        Kind(id: "subscriptions", title: "Subscriptions", symbol: "play.rectangle", categoryKey: "subscriptions", sameEveryMonth: true),
        Kind(id: "family", title: "Helping family", symbol: "heart", categoryKey: "familyhelp", sameEveryMonth: true),
        Kind(id: "housekeeper", title: "Housekeeper", symbol: "sparkles.rectangle.stack", categoryKey: "homehelp", sameEveryMonth: true)
    ]

    static func kind(_ id: String) -> Kind? { kinds.first { $0.id == id } }

    /// A bill the user picked.
    struct Bill: Identifiable, Equatable, Sendable {
        var id = UUID()
        /// Catalog id, or "" for one the user named.
        var kindID: String
        var customName: String = ""
        var amount: Centimes = 0
        /// Day of the month it is paid (1...28).
        var day: Int
        var sameEveryMonth: Bool
        /// When this month's date has already passed: true = already paid, added as an expense now.
        var paidThisMonth = true

        var kind: Kind? { BillCatalog.kind(kindID) }
        var isCustom: Bool { kindID.isEmpty }
        var symbol: String { kind?.symbol ?? "pin" }
        /// Custom bills each get their own category, keyed by their id.
        var categoryKey: String { kind?.categoryKey ?? "custom-\(id.uuidString.prefix(8).lowercased())" }
    }

    /// This period's date for a bill paid on `day`, inside [period.start, period.end).
    static func dateInPeriod(day: Int, period: BudgetPeriod, calendar: Calendar = .current) -> Date {
        let d = max(1, min(28, day))
        var c = calendar.dateComponents([.year, .month], from: period.start)
        c.day = d
        c.hour = 9
        let candidate = calendar.date(from: c) ?? period.start
        if candidate < period.start {
            return calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    /// Has this period's date already come?
    static func hasPassed(day: Int, period: BudgetPeriod, now: Date = .now, calendar: Calendar = .current) -> Bool {
        dateInPeriod(day: day, period: period, calendar: calendar) <= now
    }

    /// First date the recurring entry is added: this period's date, unless it has passed and wasn't paid yet
    /// in Bztam (then next month's).
    static func startDate(for bill: Bill, period: BudgetPeriod, now: Date = .now, calendar: Calendar = .current) -> Date {
        let date = dateInPeriod(day: bill.day, period: period, calendar: calendar)
        if date <= now && !bill.paidThisMonth {
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
        return date
    }

    /// Fixed amounts by category key for the planner (several bills can share one category).
    static func fixedByCategory(_ bills: [Bill]) -> [String: Centimes] {
        bills.filter { $0.amount > 0 }.reduce(into: [:]) { $0[$1.categoryKey, default: 0] += $1.amount }
    }
}
