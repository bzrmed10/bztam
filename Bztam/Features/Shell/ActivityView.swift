import SwiftData
import SwiftUI

/// Every entry, newest first, grouped by day. Search and filters arrive in Milestone 4.
struct ActivityView: View {
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @State private var editing: Entry?

    private var days: [(Date, [Entry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            HStack {
                ScreenTitle(text: L10n.t("Activity"))
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.brand, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Add"))
            }
            .padding(.top, Theme.Space.m)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))

            if entries.isEmpty {
                EmptyState(symbol: "list.bullet", title: L10n.t("No entries yet"),
                           message: L10n.t("Expenses and money in you add show up here."))
                    .listRowSeparator(.hidden)
            }

            ForEach(days, id: \.0) { day, items in
                Section {
                    ForEach(items) { entry in
                        Button { editing = entry } label: { EntryRow(entry: entry) }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 0, trailing: Theme.Space.l))
                            .swipeActions {
                                Button(L10n.t("Delete"), role: .destructive) {
                                    EntryActions.delete(entry, context: context, undo: undo)
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(DateText.day(day)).font(.system(size: 14, weight: .bold))
                        Spacer()
                        let spent = items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
                        if spent > 0 {
                            Text(Money.format(spent)).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .sheet(item: $editing) { entry in
            AddEntryView(editing: entry).environment(undo)
        }
    }
}

/// Placeholder until Milestone 4.
struct InsightsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(text: L10n.t("Insights"))
                EmptyState(symbol: "chart.pie", title: L10n.t("Charts are coming"),
                           message: L10n.t("Where your money went, in vs out and month-to-month comparisons arrive in a later update."))
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)
        }
        .background(Theme.Colors.canvas)
    }
}
