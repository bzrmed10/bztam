import AppIntents
import SwiftData

/// Siri and Shortcuts: "Add an expense in Bztam" → amount → what for.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add an expense"
    static let description = IntentDescription("Adds an expense to Bztam. The category is guessed from what you say.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "What for")
    var label: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let centimes = Int((amount * 100).rounded())
        guard centimes > 0 else { return .result(dialog: "\(L10n.t("The amount must be more than zero."))") }

        let context = DataStore.shared.mainContext
        let quick = QuickEntryParser.parse(label ?? "")
        let categories = (try? context.fetch(FetchDescriptor<BudgetCategory>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let records = ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map { EntryRecord($0) }
        let remembered = CategoryMemory.category(for: quick.text, in: records)
        let category = categories.first { $0.id == remembered }
            ?? categories.first { $0.key == quick.categoryKey }
            ?? categories.first { $0.key == "other" }

        let entry = Entry(kind: .expense, amount: centimes, date: .now, merchant: quick.text, category: category)
        context.insert(entry)
        try? context.save()
        BudgetAlerts.afterAdding(entry, context: context)

        let message = L10n.t("Added %@ to %@.", Money.format(centimes), category?.displayName ?? L10n.t("Other"))
        return .result(dialog: "\(message)")
    }
}

struct BztamShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Add to \(.applicationName)",
                "New expense in \(.applicationName)"
            ],
            shortTitle: "Add expense",
            systemImageName: "plus.circle"
        )
    }
}
