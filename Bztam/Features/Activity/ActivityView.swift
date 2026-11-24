import SwiftData
import SwiftUI

/// Which entries Activity shows.
enum ActivityFilter: Hashable {
    case all, expenses, income
    case category(UUID)
}

/// Every entry, newest first, grouped by day, with search and filters.
struct ActivityView: View {
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @State private var editing: Entry?
    @State private var search = ""
    @State private var filter: ActivityFilter = .all
    @State private var showCalendar = false

    private var filtered: [Entry] {
        let query = ReceiptParser.fold(search.trimmingCharacters(in: .whitespaces))
        return entries.filter { e in
            switch filter {
            case .all: break
            case .expenses: if e.kind != .expense { return false }
            case .income: if e.kind != .income { return false }
            case .category(let id): if e.category?.id != id { return false }
            }
            guard !query.isEmpty else { return true }
            let haystack = [e.merchant, e.note, e.category?.displayName ?? "", e.kind == .income ? e.incomeSource.title : "",
                            Money.format(e.amount, symbol: false), String(e.amount / 100)]
            return haystack.contains { ReceiptParser.fold($0).contains(query) }
        }
    }

    private var days: [(Date, [Entry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var categoryChipTitle: String {
        if case .category(let id) = filter, let c = categories.first(where: { $0.id == id }) { return c.displayName }
        return L10n.t("Category")
    }

    private var isCategoryFilter: Bool {
        if case .category = filter { return true }
        return false
    }

    var body: some View {
        List {
            HStack {
                ScreenTitle(text: L10n.t("Activity"))
                Button { showCalendar = true } label: {
                    Image(systemName: "calendar")
                        .font(.scaled(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Spending calendar"))
                .accessibilityIdentifier("activity.calendar")
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.scaled(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.onBrand)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.brand, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Add"))
            }
            .padding(.top, Theme.Space.m)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))

            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.inkMuted)
                        TextField(L10n.t("Search shop, note or amount"), text: $search)
                            .font(.scaled(size: 15, weight: .medium))
                            .submitLabel(.search)
                            .accessibilityIdentifier("activity.search")
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.inkMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.t("Clear search"))
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Theme.Colors.surface, in: Capsule())

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Chip(title: L10n.t("All"), selected: filter == .all) { filter = .all }
                            Chip(title: L10n.t("Expenses"), selected: filter == .expenses) { filter = .expenses }
                            Chip(title: L10n.t("Money in"), selected: filter == .income) { filter = .income }
                            Menu {
                                ForEach(categories) { c in
                                    Button(c.displayName) { filter = .category(c.id) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(categoryChipTitle)
                                    Image(systemName: "chevron.down").font(.scaled(size: 11, weight: .bold))
                                }
                                .font(.scaled(size: 14, weight: .semibold))
                                .foregroundStyle(isCategoryFilter ? Theme.Colors.onInk : Theme.Colors.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(isCategoryFilter ? Theme.Colors.ink : Theme.Colors.surface, in: Capsule())
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))
            }

            if entries.isEmpty {
                EmptyState(symbol: "list.bullet", title: L10n.t("No entries yet"),
                           message: L10n.t("Scan a receipt, share a bill or type \"taxi 20\". Everything you add shows up here."),
                           actionTitle: L10n.t("Add your first expense"), action: onAdd)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if filtered.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: L10n.t("Nothing found"),
                           message: L10n.t("Try another word or filter."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(days, id: \.0) { day, items in
                Section {
                    ForEach(items) { entry in
                        Button { editing = entry } label: { EntryRow(entry: entry) }
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
                } header: {
                    HStack {
                        Text(DateText.day(day)).font(.scaled(size: 14, weight: .bold))
                        Spacer()
                        let spent = items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
                        if spent > 0 {
                            Text(Money.format(spent)).font(.scaled(size: 14, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.canvas)
                    .listRowInsets(EdgeInsets())
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
        .animation(.snappy, value: entries.count)
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.Colors.canvas)
        .statusBarFade()
        .sheet(isPresented: $showCalendar) { SpendingCalendarView() }
        .sheet(item: $editing) { entry in
            AddEntryView(editing: entry).environment(undo)
        }
    }
}

