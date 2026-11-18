import SwiftData
import SwiftUI
import UIKit

/// Add (or edit) an expense or money in: amount keypad, category or source, date and shop.
struct AddEntryView: View {
    private let editing: Entry?
    private let initialKind: EntryKind
    private let initialCategoryID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]

    @State private var kind: EntryKind = .expense
    @State private var amount = AmountInput()
    @State private var categoryID: UUID?
    @State private var incomeSource: IncomeSource = .salary
    @State private var date = Date.now
    @State private var merchant = ""
    @State private var loaded = false

    init(request: AddRequest) {
        editing = nil
        initialKind = request.kind
        initialCategoryID = request.categoryID
    }

    init(editing entry: Entry) {
        editing = entry
        initialKind = entry.kind
        initialCategoryID = entry.category?.id
    }

    private var title: String {
        if editing != nil { return kind == .expense ? L10n.t("Edit expense") : L10n.t("Edit money in") }
        return kind == .expense ? L10n.t("Add expense") : L10n.t("Add money in")
    }

    private var canSave: Bool { amount.centimes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
                SegmentedPill(options: [(EntryKind.expense, L10n.t("Expense")), (EntryKind.income, L10n.t("Money in"))],
                              selection: $kind)
                    .frame(width: 220)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            ScreenTitle(text: title)

            AmountField(caption: L10n.t("Amount"), text: amount.display())
                .accessibilityIdentifier("add.amount")

            FlowLayout(spacing: 8) {
                if kind == .expense {
                    ForEach(categories) { c in
                        Chip(title: c.displayName, selected: c.id == categoryID) { categoryID = c.id }
                    }
                } else {
                    ForEach(IncomeSource.allCases) { s in
                        Chip(title: s.title, selected: s == incomeSource) { incomeSource = s }
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Date")).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                    DatePicker("", selection: $date, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .expense ? L10n.t("Shop or note") : L10n.t("Note"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                    TextField(L10n.t("Optional"), text: $merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .submitLabel(.done)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }

            Spacer(minLength: 0)

            KeypadView { amount.press($0) }

            Button(editing == nil ? title : L10n.t("Save")) { save() }
                .buttonStyle(.pillPrimary)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .accessibilityIdentifier("add.save")

            if let entry = editing {
                Button(L10n.t("Delete")) {
                    dismiss()
                    EntryActions.delete(entry, context: context, undo: undo)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.negative)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.large)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        kind = initialKind
        categoryID = initialCategoryID
        if let e = editing {
            amount = AmountInput(centimes: e.amount)
            incomeSource = e.incomeSource
            date = e.date
            merchant = e.merchant.isEmpty ? e.note : e.merchant
        }
        if LaunchOptions.demoData && LaunchOptions.openScreen == "add" && editing == nil {
            amount = AmountInput(text: "38")
            categoryID = categories.first(where: { $0.key == "food" })?.id
            merchant = "Café Clock"
        }
    }

    private func save() {
        guard canSave else { return }
        let category = kind == .expense
            ? (categories.first(where: { $0.id == categoryID }) ?? categories.first(where: { $0.key == "other" }) ?? categories.last)
            : nil
        let text = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = editing {
            e.kind = kind
            e.amount = amount.centimes
            e.date = date
            e.merchant = kind == .expense ? text : ""
            e.note = kind == .income ? text : ""
            e.category = category
            e.incomeSource = incomeSource
        } else {
            context.insert(Entry(kind: kind, amount: amount.centimes, date: date, merchant: kind == .expense ? text : "",
                                 note: kind == .income ? text : "", category: category, incomeSource: incomeSource))
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
