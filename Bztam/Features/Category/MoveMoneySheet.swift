import SwiftData
import SwiftUI
import UIKit

/// Move money between two categories for this month only (next month starts from the normal budgets again).
struct MoveMoneySheet: View {
    let category: BudgetCategory
    let period: BudgetPeriod

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @State private var giving = true
    @State private var otherID: UUID?
    @State private var amount = AmountInput()

    private var others: [BudgetCategory] { categories.filter { $0.id != category.id } }
    private var canSave: Bool { amount.centimes > 0 && otherID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
                SegmentedPill(options: [(true, L10n.t("Give")), (false, L10n.t("Take"))], selection: $giving)
                    .frame(width: 180)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(text: L10n.t("Move money"))
                    Text(giving ? L10n.t("From %@ to another category, for this month only.", category.displayName)
                                : L10n.t("From another category to %@, for this month only.", category.displayName))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    AmountField(caption: L10n.t("Amount"), text: amount.display())
                    Text(giving ? L10n.t("To") : L10n.t("From")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    FlowLayout(spacing: 8) {
                        ForEach(others) { c in
                            Chip(title: c.displayName, selected: otherID == c.id) { otherID = c.id }
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                KeypadView { amount.press($0) }
                Button(L10n.t("Move")) { move() }
                    .buttonStyle(.pillPrimary)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
    }

    private func move() {
        guard let other = others.first(where: { $0.id == otherID }) else { return }
        let key = BudgetCategory.periodKey(period)
        let value = amount.centimes
        let from = giving ? category : other
        let to = giving ? other : category
        var fromAdjustments = from.periodAdjustments
        fromAdjustments[key, default: 0] -= value
        from.periodAdjustments = fromAdjustments
        var toAdjustments = to.periodAdjustments
        toAdjustments[key, default: 0] += value
        to.periodAdjustments = toAdjustments
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
