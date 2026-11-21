import SwiftData
import SwiftUI

/// Settings → Recurring: every rule with its next date. Tap to edit, or stop repeating.
struct RecurringListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecurringRule.startDate) private var rules: [RecurringRule]
    @State private var editing: RecurringRule?

    private var active: [RecurringRule] { rules.filter(\.isActive) }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: L10n.t("Recurring"))
                Text(L10n.t("Added automatically on their day. To add one, choose Repeat when you add an expense or money in."))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            .padding(.top, Theme.Space.m)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 8, trailing: Theme.Space.l))

            if active.isEmpty {
                EmptyState(symbol: "arrow.triangle.2.circlepath", title: L10n.t("Nothing recurring yet"),
                           message: L10n.t("Rent, salary and subscriptions you repeat show up here."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(active) { rule in
                Button { editing = rule } label: { RecurringRow(rule: rule) }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Space.l, bottom: 0, trailing: Theme.Space.l))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .sheet(item: $editing) { RecurringEditSheet(rule: $0) }
    }
}

struct RecurringRow: View {
    let rule: RecurringRule

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            if rule.kind == .income {
                IconCircle(symbol: "arrow.down.to.line", fill: Theme.Colors.brandTint, tint: Theme.Colors.positive)
            } else {
                IconCircle(symbol: rule.category?.symbol ?? "arrow.triangle.2.circlepath")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayTitle).font(.bzBodyStrong).lineLimit(1)
                Text(details).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.format(rule.amount, sign: rule.kind == .income, privacy: rule.kind == .income ? .income : .any))
                .font(.bzAmount)
                .foregroundStyle(rule.kind == .income ? Theme.Colors.positive : Theme.Colors.ink)
        }
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = [rule.frequency.title]
        if let next = rule.nextDate() { parts.append(L10n.t("next %@", DateText.short(next))) }
        return parts.joined(separator: " · ")
    }
}

/// Change a rule for all future entries, or stop it. Entries already added stay as they are.
struct RecurringEditSheet: View {
    @Bindable var rule: RecurringRule
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @State private var amount = AmountInput()
    @State private var editingAmount = false
    @State private var confirmStop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: rule.displayTitle)
                Text(L10n.t("Changes apply to the next entries. Entries already added stay as they are."))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)

                Button { editingAmount = true } label: {
                    AmountField(caption: L10n.t("Amount"), text: amount.display())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.kind == .expense ? L10n.t("Shop or note") : L10n.t("Note"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                    TextField(L10n.t("Optional"), text: rule.kind == .expense ? $rule.merchant : $rule.note)
                        .font(.bzBodyStrong)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

                Text(L10n.t("Repeat")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                FlowLayout(spacing: 8) {
                    ForEach(Frequency.allCases) { f in
                        Chip(title: f.title, selected: rule.frequency == f) { rule.frequency = f }
                    }
                }

                if rule.kind == .expense {
                    Text(L10n.t("Category")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    FlowLayout(spacing: 8) {
                        ForEach(categories) { c in
                            Chip(title: c.displayName, selected: rule.category?.id == c.id) { rule.category = c }
                        }
                    }
                }

                Button(L10n.t("Save")) {
                    if amount.centimes > 0 { rule.amount = amount.centimes }
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.pillPrimary)

                Button(L10n.t("Stop repeating")) { confirmStop = true }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.negative)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .keyboardDoneButton()
        .sheet(isPresented: $editingAmount) { AmountEditSheet(title: L10n.t("Amount"), input: $amount) }
        .confirmationDialog(L10n.t("Stop repeating?"), isPresented: $confirmStop, titleVisibility: .visible) {
            Button(L10n.t("Stop repeating"), role: .destructive) {
                rule.isActive = false
                try? context.save()
                dismiss()
            }
        } message: {
            Text(L10n.t("No new entries will be added. Past entries stay."))
        }
        .onAppear { amount = AmountInput(centimes: rule.amount) }
    }
}

/// Home card: "Netflix looks like a subscription. Make it recurring?"
struct SubscriptionCard: View {
    let candidate: SubscriptionCandidate
    let onYes: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Theme.Colors.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("%@ every month?", candidate.merchant)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(L10n.t("%@ each time. Add it automatically?", Money.format(candidate.amount)))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer(minLength: 4)
            Button(L10n.t("Yes"), action: onYes)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(Theme.Colors.onBrand)
                .background(Theme.Colors.brand, in: Capsule())
                .buttonStyle(.plain)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("Dismiss"))
        }
        .padding(12)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}
