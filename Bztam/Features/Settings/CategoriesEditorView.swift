import SwiftData
import SwiftUI

/// Add, rename, change icon and budget, reorder and archive categories.
struct CategoriesEditorView: View {
    let income: Centimes

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var entries: [Entry]
    @Query private var settingsRows: [AppSettings]
    @State private var editing: BudgetCategory?
    @State private var adding = false
    @State private var editMode: EditMode = .inactive

    private var planned: Centimes { categories.reduce(0) { $0 + $1.budget } }

    private var suggestions: [BudgetSuggestion] {
        let payday = settingsRows.first?.payday ?? 1
        return Advice.budgetSuggestions(categories: categories.map(BudgetSnapshot.value), entries: BudgetSnapshot.values(entries),
                                        current: BudgetCalculator.period(containing: .now, payday: payday), payday: payday)
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                    Button(editMode == .active ? L10n.t("Done") : L10n.t("Reorder")) {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Theme.Colors.surface, in: Capsule())
                    .buttonStyle(.plain)
                }
                ScreenTitle(text: L10n.t("Categories and budgets"))
                HStack {
                    Text(L10n.t("Planned")).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                    Spacer()
                    Text(Money.format(planned)).font(.bzAmount)
                }
                if !suggestions.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold))
                        Text(L10n.t("Budgets suggested from your last months")).font(.system(size: 14, weight: .semibold))
                        Spacer(minLength: 4)
                        Button(L10n.t("Use all")) { apply(suggestions) }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Theme.Colors.brand, in: Capsule())
                            .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                if income > 0 {
                    HStack {
                        Text(L10n.t("Not planned yet")).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                        Spacer()
                        TagPill(text: Money.format(max(0, income - planned)))
                    }
                }
            }
            .padding(.top, Theme.Space.m)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))
            .moveDisabled(true)

            ForEach(categories) { c in
                Button { editing = c } label: {
                    HStack(spacing: Theme.Space.m) {
                        IconCircle(symbol: c.symbol, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.displayName).font(.bzBodyStrong)
                            if let s = suggestions.first(where: { $0.categoryID == c.id }) {
                                Text(L10n.t("Suggested: %@", Money.format(s.amount)))
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.link)
                            } else if c.isFixed {
                                Text(L10n.t("Planned first")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
                            }
                        }
                        Spacer()
                        Text(c.budget > 0 ? Money.format(c.budget) : L10n.t("No budget"))
                            .font(.bzAmount)
                            .foregroundStyle(c.budget > 0 ? Theme.Colors.ink : Theme.Colors.inkMuted)
                    }
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 0, trailing: Theme.Space.l))
            }
            .onMove(perform: move)

            Button { adding = true } label: {
                Label(L10n.t("Add a category"), systemImage: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.Colors.surface, in: Capsule())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: Theme.Space.l, bottom: 16, trailing: Theme.Space.l))
            .moveDisabled(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .environment(\.editMode, $editMode)
        .sheet(item: $editing) { c in CategoryEditSheet(category: c) }
        .sheet(isPresented: $adding) { CategoryEditSheet(category: nil, nextOrder: (categories.map(\.order).max() ?? 0) + 1) }
    }

    private func apply(_ list: [BudgetSuggestion]) {
        for s in list { categories.first { $0.id == s.categoryID }?.budget = s.amount }
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = categories
        list.move(fromOffsets: source, toOffset: destination)
        for (index, c) in list.enumerated() { c.order = index }
        try? context.save()
    }
}

/// Create or edit one category: name, icon, budget, planned first, archive.
struct CategoryEditSheet: View {
    let category: BudgetCategory?
    var nextOrder = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var symbol = "square.grid.2x2"
    @State private var budgetText = ""
    @State private var isFixed = false
    @State private var confirmArchive = false

    static let symbols = [
        "cart", "cup.and.saucer", "fork.knife", "car", "fuelpump", "tram", "house", "bolt", "drop", "iphone",
        "wifi", "sparkles", "film", "gamecontroller", "tshirt", "heart", "cross.case", "graduationcap",
        "gift", "airplane", "pawprint", "figure.2.and.child.holdinghands", "dumbbell", "square.grid.2x2"
    ]

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: category == nil ? L10n.t("New category") : L10n.t("Edit category"))

                field(L10n.t("Name")) {
                    TextField(L10n.t("For example: Kids, Gym, Gifts"), text: $name)
                        .font(.bzBodyStrong)
                }
                field(L10n.t("Monthly budget (%@)", Money.currencySymbol)) {
                    TextField("0", text: $budgetText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .heavy).monospacedDigit())
                        .onChange(of: budgetText) { _, new in
                            let digits = String(new.filter(\.isNumber).prefix(7))
                            if digits != new { budgetText = digits }
                        }
                }

                Text(L10n.t("Icon")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Self.symbols, id: \.self) { s in
                        Button { symbol = s } label: {
                            IconCircle(symbol: s, size: 48, fill: s == symbol ? Theme.Colors.brand : Theme.Colors.surface)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s)
                        .accessibilityAddTraits(s == symbol ? .isSelected : [])
                    }
                }

                ToggleRow(symbol: "pin", title: L10n.t("Planned first"),
                          detail: L10n.t("For rent and bills: shows Paid once fully spent."), isOn: $isFixed)

                Button(L10n.t("Save")) { save() }
                    .buttonStyle(.pillPrimary)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)

                if category != nil {
                    Button(L10n.t("Archive category")) { confirmArchive = true }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.negative)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(L10n.t("Archive this category?"), isPresented: $confirmArchive, titleVisibility: .visible) {
            Button(L10n.t("Archive"), role: .destructive) {
                category?.isArchived = true
                try? context.save()
                dismiss()
            }
        } message: {
            Text(L10n.t("It disappears from Home. Its past expenses stay in Activity."))
        }
        .onAppear {
            guard let c = category else { return }
            name = c.displayName
            symbol = c.symbol
            budgetText = c.budget > 0 ? String(c.budget / 100) : ""
            isFixed = c.isFixed
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let budget = (Int(budgetText) ?? 0) * 100
        if let c = category {
            // Keep a built-in name untouched (so it still follows the language) unless the user changed it.
            if trimmed != c.displayName { c.name = trimmed }
            c.symbol = symbol
            c.budget = budget
            c.isFixed = isFixed
        } else {
            context.insert(BudgetCategory(name: trimmed, symbol: symbol, budget: budget, isFixed: isFixed, order: nextOrder))
        }
        try? context.save()
        dismiss()
    }
}
