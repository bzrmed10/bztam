import Foundation
import SwiftData

/// How often a recurring entry comes back.
enum Frequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly, monthly, yearly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: L10n.t("Every week")
        case .monthly: L10n.t("Every month")
        case .yearly: L10n.t("Every year")
        }
    }
}

/// Rent, salary, subscriptions, bills: added automatically on their day.
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var kindRaw: String = EntryKind.expense.rawValue
    var amount: Int = 0
    var merchant: String = ""
    var note: String = ""
    var incomeSourceRaw: String = IncomeSource.other.rawValue
    var frequencyRaw: String = Frequency.monthly.rawValue
    var startDate: Date = Date()
    /// The last occurrence already added (nil before the first one).
    var lastGenerated: Date?
    var isActive: Bool = true
    var category: BudgetCategory?

    init(kind: EntryKind, amount: Centimes, merchant: String = "", note: String = "", category: BudgetCategory? = nil,
         incomeSource: IncomeSource = .other, frequency: Frequency, startDate: Date, lastGenerated: Date? = nil) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.merchant = merchant
        self.note = note
        self.category = category
        self.incomeSourceRaw = incomeSource.rawValue
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.lastGenerated = lastGenerated
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var incomeSource: IncomeSource {
        get { IncomeSource(rawValue: incomeSourceRaw) ?? .other }
        set { incomeSourceRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !merchant.isEmpty { return merchant }
        if !note.isEmpty { return note }
        if kind == .income { return incomeSource.title }
        return category?.displayName ?? L10n.t("Expense")
    }

    /// The next date this rule will add an entry.
    func nextDate(after date: Date = .now) -> Date? {
        RecurringEngine.occurrences(frequency: frequency, start: startDate, after: max(date, lastGenerated ?? .distantPast),
                                    through: date.addingTimeInterval(400 * 86_400), limit: 1).first
    }
}

/// Works out when recurring entries happen and adds the ones that are due.
enum RecurringEngine {
    /// The n-th occurrence, always computed from the start date so 31 Jan → 28 Feb → 31 Mar.
    static func occurrence(_ n: Int, frequency: Frequency, start: Date, calendar: Calendar = .current) -> Date {
        switch frequency {
        case .weekly: calendar.date(byAdding: .day, value: 7 * n, to: start) ?? start
        case .monthly: calendar.date(byAdding: .month, value: n, to: start) ?? start
        case .yearly: calendar.date(byAdding: .year, value: n, to: start) ?? start
        }
    }

    /// Occurrences strictly after `after` (or from the start when nil) up to and including `through`.
    static func occurrences(frequency: Frequency, start: Date, after: Date?, through: Date, limit: Int = 400,
                            calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var n = 0
        while result.count < limit && n < 5_000 {
            let date = occurrence(n, frequency: frequency, start: start, calendar: calendar)
            if date > through { break }
            if after == nil || date > after! { result.append(date) }
            n += 1
        }
        return result
    }

    /// Adds every entry that came due since the app last ran. Returns how many were added.
    @MainActor
    @discardableResult
    static func run(in context: ModelContext, now: Date = .now) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive }))) ?? []
        var added = 0
        for rule in rules {
            let due = occurrences(frequency: rule.frequency, start: rule.startDate,
                                  after: rule.lastGenerated ?? rule.startDate.addingTimeInterval(-1), through: now, limit: 60)
            for date in due {
                let entry = Entry(kind: rule.kind, amount: rule.amount, date: date, merchant: rule.merchant, note: rule.note,
                                  category: rule.kind == .expense ? rule.category : nil,
                                  incomeSource: rule.incomeSource, source: .recurring)
                entry.recurringID = rule.id
                context.insert(entry)
                added += 1
            }
            if let last = due.last { rule.lastGenerated = last }
        }
        if added > 0 { try? context.save() }
        return added
    }
}
