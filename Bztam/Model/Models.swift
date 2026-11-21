import Foundation
import SwiftData

/// Expense or money in.
enum EntryKind: String, Codable, CaseIterable, Sendable {
    case expense, income
}

/// Where an entry came from.
enum EntrySource: String, Codable, Sendable {
    case manual, camera, screenshot, share, recurring
}

/// Where money in came from.
enum IncomeSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case salary, freelance, family, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary: L10n.t("Salary")
        case .freelance: L10n.t("Freelance")
        case .family: L10n.t("Family")
        case .other: L10n.t("Other")
        }
    }
}

/// One money movement. Amounts are whole centimes. Every property has a default so the store
/// migrates lightly and stays CloudKit-friendly (no unique constraints, optional relationship).
@Model
final class Entry {
    var id: UUID = UUID()
    var kindRaw: String = EntryKind.expense.rawValue
    var amount: Int = 0
    var date: Date = Date()
    var merchant: String = ""
    var note: String = ""
    var incomeSourceRaw: String = IncomeSource.other.rawValue
    var sourceRaw: String = EntrySource.manual.rawValue
    var attachmentName: String?
    /// Set when the entry was created by a recurring rule (or started one).
    var recurringID: UUID?
    /// Set when the entry is a dart payment or a collected pot.
    var dartID: UUID?
    var dartRound: Int = -1
    /// Set when the entry comes from a split bill: the bill you paid, a friend paying back (negative amount,
    /// a refund into the category), or you paying a friend back.
    var splitID: UUID?
    var createdAt: Date = Date()
    var category: BudgetCategory?

    init(kind: EntryKind, amount: Centimes, date: Date = .now, merchant: String = "", note: String = "",
         category: BudgetCategory? = nil, incomeSource: IncomeSource = .other, source: EntrySource = .manual) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.note = note
        self.category = category
        self.incomeSourceRaw = incomeSource.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = .now
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var incomeSource: IncomeSource {
        get { IncomeSource(rawValue: incomeSourceRaw) ?? .other }
        set { incomeSourceRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Title shown in lists: the shop, else the note, else the category or income source.
    var displayTitle: String {
        if !merchant.isEmpty { return merchant }
        if !note.isEmpty { return note }
        if kind == .income { return incomeSource.title }
        return category?.displayName ?? L10n.t("Expense")
    }
}

/// A spending category with a monthly budget.
@Model
final class BudgetCategory {
    var id: UUID = UUID()
    /// Key of a built-in category ("courses", "rent"…) so its name follows the app language; empty for custom ones.
    var key: String = ""
    var name: String = ""
    var symbol: String = "square.grid.2x2"
    var budget: Int = 0
    /// Planned first (rent, bills): shows "Paid" once fully spent.
    var isFixed: Bool = false
    var order: Int = 0
    var isArchived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \Entry.category) var entries: [Entry]? = []
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category) var rules: [RecurringRule]? = []
    /// Money moved in or out of this category for one period only, keyed by `BudgetCategory.periodKey`.
    var periodAdjustments: [String: Int] = [:]

    init(key: String = "", name: String, symbol: String, budget: Centimes = 0, isFixed: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.key = key
        self.name = name
        self.symbol = symbol
        self.budget = budget
        self.isFixed = isFixed
        self.order = order
    }

    /// "2026-10-25" for the period starting on 25 Oct 2026.
    static func periodKey(_ period: BudgetPeriod, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: period.start)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The budget for one period: the monthly budget plus money moved in, minus money moved out.
    func budget(in period: BudgetPeriod) -> Centimes {
        max(0, budget + (periodAdjustments[Self.periodKey(period)] ?? 0))
    }

    /// Built-in categories are shown in the app language; renamed or custom ones as typed.
    var displayName: String {
        if !key.isEmpty, let builtIn = DefaultCategories.template(for: key), name == builtIn.englishName {
            return L10n.t(builtIn.englishName)
        }
        return name
    }
}

/// App-wide settings (one row).
@Model
final class AppSettings {
    var payday: Int = 1
    var onboardingDone: Bool = false
    var expectedIncome: Int = 0
    var createdAt: Date = Date()

    init(payday: Int = 1, onboardingDone: Bool = false, expectedIncome: Centimes = 0) {
        self.payday = payday
        self.onboardingDone = onboardingDone
        self.expectedIncome = expectedIncome
        self.createdAt = .now
    }
}
