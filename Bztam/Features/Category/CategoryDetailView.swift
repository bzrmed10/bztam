import SwiftData
import SwiftUI

/// One category: what's left this period, the bar and its entries. Swipe to delete, tap to edit.
struct CategoryDetailView: View {
    @Bindable var category: BudgetCategory
    let period: BudgetPeriod
    let onAdd: (AddRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query private var allEntries: [Entry]
    @State private var editingBudget = false
    @State private var moving = false
    @State private var editing: Entry?

    private var entries: [Entry] {
        allEntries
            .filter { $0.kind == .expense && $0.category?.id == category.id && period.contains($0.date) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let status = BudgetCalculator.status(for: BudgetSnapshot.value(category, period: period),
                                             entries: BudgetSnapshot.values(allEntries), period: period)
        List {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    CircleIconButton(symbol: "chevron.backward", label: L10n.t("Back")) { dismiss() }
                    Spacer()
                    Button(L10n.t("Move money")) { moving = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Theme.Colors.surface, in: Capsule())
                    Button(L10n.t("Edit budget")) { editingBudget = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Theme.Colors.surface, in: Capsule())
                }
                VStack(alignment: .leading, spacing: 14) {
                    IconCircle(symbol: category.symbol, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline(status)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        Text(hero(status))
                            .font(.bzAmountHero)
                            .tracking(-1.2)
                            .foregroundStyle(heroColor(status))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(detail(status)).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                        let back = SplitActions.comingBack(categoryID: category.id, in: period, context: context)
                        if back > 0 {
                            Label(L10n.t("%@ coming back from friends", Money.format(back)), systemImage: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Colors.positive)
                                .padding(.top, 2)
                        }
                    }
                    if status.budget > 0 {
                        ProgressPill(value: status.progress, fill: heroColor(status) == Theme.Colors.negative ? Theme.Colors.negative : Theme.Colors.ink)
                    }
                }
                HStack {
                    SectionTitle(text: L10n.t("This period"))
                    Spacer()
                    Button {
                        onAdd(AddRequest(kind: .expense, categoryID: category.id))
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.onBrand)
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.brand, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Add expense"))
                }
            }
            .padding(.top, Theme.Space.m)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))

            if entries.isEmpty {
                EmptyState(symbol: category.symbol, title: L10n.t("Nothing spent yet"),
                           message: L10n.t("Expenses in this category show up here."),
                           actionTitle: L10n.t("Add an expense"), action: { onAdd(AddRequest(kind: .expense, categoryID: category.id)) })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(entries) { entry in
                    Button { editing = entry } label: { EntryRow(entry: entry, showsDate: true) }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 0, trailing: Theme.Space.l))
                        .swipeActions {
                            Button(L10n.t("Delete"), role: .destructive) {
                                EntryActions.delete(entry, context: context, undo: undo)
                            }
                        }
                }
            }
            // Room to scroll the last row above the floating tab bar.
            Color.clear.frame(height: Theme.Size.tabBarSpace)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .statusBarFade()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editingBudget) {
            BudgetEditSheet(category: category)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $moving) {
            MoveMoneySheet(category: category, period: period)
        }
        .sheet(item: $editing) { entry in
            AddEntryView(editing: entry)
                .environment(undo)
        }
    }

    private func headline(_ s: CategoryStatus) -> String {
        switch s.state {
        case .over: L10n.t("%@ · over budget", category.displayName)
        case .paid: L10n.t("%@ · paid", category.displayName)
        case .noBudget: L10n.t("%@ · spent this period", category.displayName)
        case .left: L10n.t("%@ · left this period", category.displayName)
        }
    }

    private func hero(_ s: CategoryStatus) -> String {
        switch s.state {
        case .left(let x), .over(let x): Money.format(x)
        case .paid: Money.format(s.budget)
        case .noBudget: Money.format(s.spent)
        }
    }

    private func heroColor(_ s: CategoryStatus) -> Color {
        if case .over = s.state { return Theme.Colors.negative }
        if case .paid = s.state { return Theme.Colors.positive }
        return Theme.Colors.ink
    }

    private func detail(_ s: CategoryStatus) -> String {
        if s.budget == 0 { return L10n.t("No budget set") }
        return L10n.t("%@ spent of %@", Money.format(s.spent, symbol: false), Money.format(s.budget))
    }
}

/// Edit a category's monthly budget with the keypad.
struct BudgetEditSheet: View {
    @Bindable var category: BudgetCategory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var input = AmountInput()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            ScreenTitle(text: L10n.t("Budget for %@", category.displayName))
            AmountField(caption: L10n.t("Every month"), text: input.display())
            Toggle(isOn: $category.isFixed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Planned first")).font(.bzBodyStrong)
                    Text(L10n.t("For rent and bills: shows Paid once fully spent.")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
            }
            .tint(Theme.Colors.positive)
            Spacer(minLength: 0)
            KeypadView { input.press($0) }
            Button(L10n.t("Save")) {
                category.budget = input.centimes
                try? context.save()
                dismiss()
            }
            .buttonStyle(.pillPrimary)
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .onAppear { input = AmountInput(centimes: category.budget) }
    }
}
