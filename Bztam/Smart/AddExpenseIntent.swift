import AppIntents
import SwiftData
import SwiftUI

/// Adds an expense from Siri or Shortcuts without opening Bztam.
@MainActor
enum SiriAdd {
    struct Added {
        let entryID: UUID
        let amount: Centimes
        let categoryName: String
        let title: String
    }

    static func add(amount centimes: Centimes, label: String, context: ModelContext) -> Added {
        let quick = QuickEntryParser.parse(label)
        let text = quick.text.isEmpty ? label.trimmingCharacters(in: .whitespacesAndNewlines) : quick.text
        let categories = (try? context.fetch(FetchDescriptor<BudgetCategory>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let records = ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map { EntryRecord($0) }
        let remembered = CategoryMemory.category(for: text, in: records)
        let category = categories.first { $0.id == remembered }
            ?? categories.first { $0.key == quick.categoryKey }
            ?? categories.first { $0.key == "other" }

        let entry = Entry(kind: .expense, amount: centimes, date: .now, merchant: text, category: category)
        context.insert(entry)
        try? context.save()
        BudgetAlerts.afterAdding(entry, context: context)
        WidgetSync.update(context: context)
        return Added(entryID: entry.id, amount: centimes, categoryName: category?.displayName ?? L10n.t("Other"),
                     title: text.isEmpty ? (category?.displayName ?? L10n.t("Expense")) : text)
    }
}

/// Siri: "Add to Bztam" → "What did you spend?" → "taxi 20". One answer, like typing it in the app.
struct AddFromTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Add from text"
    static let description = IntentDescription("Adds an expense from a few words, like \"taxi 20\" or \"café 38\".")
    static let openAppWhenRun = false

    @Parameter(title: "What you spent", requestValueDialog: IntentDialog("What did you spend? For example: taxi 20"))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let quick = QuickEntryParser.parse(text)
        guard let amount = quick.amount, amount > 0 else {
            throw $text.needsValueError(IntentDialog("How much was it? For example: taxi 20"))
        }
        let added = SiriAdd.add(amount: amount, label: text, context: DataStore.shared.mainContext)
        let message = L10n.t("Added %@ to %@.", Money.format(added.amount), added.categoryName)
        return .result(dialog: IntentDialog(stringLiteral: message), view: AddedSnippet(added: added))
    }
}

/// Shortcuts: an amount and what it was for. Also what a Wallet automation can call with the amount and the shop.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add an expense"
    static let description = IntentDescription("Adds an expense to Bztam. The category is guessed from what you say.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "What for")
    var label: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let centimes = Int((amount * 100).rounded())
        guard centimes > 0 else {
            throw $amount.needsValueError(IntentDialog("How much was it?"))
        }
        let added = SiriAdd.add(amount: centimes, label: label ?? "", context: DataStore.shared.mainContext)
        let message = L10n.t("Added %@ to %@.", Money.format(added.amount), added.categoryName)
        return .result(dialog: IntentDialog(stringLiteral: message), view: AddedSnippet(added: added))
    }
}

/// The Undo button under Siri's answer.
struct UndoAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Entry")
    var entryID: String

    init() {}
    init(entryID: UUID) { self.entryID = entryID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.shared.mainContext
        if let id = UUID(uuidString: entryID),
           let entry = try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })).first {
            context.delete(entry)
            try? context.save()
            WidgetSync.update(context: context)
        }
        return .result(dialog: IntentDialog(stringLiteral: L10n.t("Removed.")))
    }
}

/// Siri: "How much is left in Bztam?"
struct LeftToSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "What's left to spend"
    static let description = IntentDescription("Tells you what's left to spend this month.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.shared.mainContext
        let settings = DataStore.settings(in: context)
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let categories = ((try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []).filter { !$0.isArchived }
        let moves = (try? context.fetch(FetchDescriptor<GoalMove>())) ?? []
        let period = BudgetCalculator.period(containing: .now, payday: settings.payday)
        let s = BudgetSnapshot.summary(entries: entries, categories: categories, period: period,
                                       expectedIncome: settings.expectedIncome, moves: moves)
        let days = max(1, Calendar.current.dateComponents([.day], from: .now, to: period.end).day ?? 1)
        let message = L10n.t("%@ left to spend, for %d more days.", Money.format(s.left, privacy: .never), days)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

/// What Siri shows after adding: the amount, where it went, and Undo.
struct AddedSnippet: View {
    let added: SiriAdd.Added

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.onBrand)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.brand, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(Money.format(added.amount)).font(.system(size: 20, weight: .heavy))
                Text(added.title + " · " + added.categoryName).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(intent: UndoAddIntent(entryID: added.entryID)) {
                Text(L10n.t("Undo")).font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct BztamShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddFromTextIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "Add an expense in \(.applicationName)",
                "New expense in \(.applicationName)",
                "\(.applicationName) add an expense"
            ],
            shortTitle: "Add expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: LeftToSpendIntent(),
            phrases: [
                "How much is left in \(.applicationName)",
                "What's left in \(.applicationName)",
                "\(.applicationName) what's left"
            ],
            shortTitle: "What's left",
            systemImageName: "wallet.bifold"
        )
        AppShortcut(
            intent: QuickScanIntent(),
            phrases: ["Scan a receipt with \(.applicationName)"],
            shortTitle: "Scan receipt",
            systemImageName: "camera"
        )
    }
}
