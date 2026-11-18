import Charts
import SwiftData
import SwiftUI

/// Where the money went, money in vs out, and how this period compares with the previous one.
struct InsightsView: View {
    @Query private var entries: [Entry]
    @Query private var allCategories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @State private var offset = 0

    private static let palette: [Color] = [
        Theme.Colors.ink, Theme.Colors.brand, Color(hex: 0x5E8F3A), Color(hex: 0x9AAE8C), Color(hex: 0xC9D6BE), Theme.Colors.line
    ]

    private var payday: Int { settingsRows.first?.payday ?? 1 }
    private var period: BudgetPeriod {
        let current = BudgetCalculator.period(containing: .now, payday: payday)
        return offset == 0 ? current : BudgetCalculator.period(current, offset: offset, payday: payday)
    }

    private func name(_ id: UUID?) -> String {
        guard let id else { return L10n.t("Other") }
        return allCategories.first { $0.id == id }?.displayName ?? L10n.t("Other")
    }

    var body: some View {
        let values = BudgetSnapshot.values(entries)
        let previousPeriod = BudgetCalculator.period(period, offset: -1, payday: payday)
        let spends = InsightsCalculator.spendByCategory(values, period: period)
        let previousSpends = InsightsCalculator.spendByCategory(values, period: previousPeriod)
        let slices = InsightsCalculator.topSlices(spends)
        let summary = BudgetCalculator.summary(entries: values, categories: [], period: period)
        let previousSpent = previousSpends.reduce(0) { $0 + $1.amount }
        let changes = InsightsCalculator.biggestChanges(current: spends, previous: previousSpends)

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 4) {
                    ScreenTitle(text: L10n.t("Insights"))
                    Button { offset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                        .accessibilityLabel(L10n.t("Previous period"))
                    Button { offset += 1 } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                        .disabled(offset >= 0).opacity(offset >= 0 ? 0.3 : 1)
                        .accessibilityLabel(L10n.t("Next period"))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink)

                Text(DateText.period(period))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    .padding(.top, -24)

                if spends.isEmpty && summary.moneyIn == 0 {
                    EmptyState(symbol: "chart.pie", title: L10n.t("Nothing this period"),
                               message: L10n.t("Add expenses and money in to see where your money goes."))
                } else {
                    whereItWent(slices, total: summary.spent)
                    inVsOut(summary)
                    comparison(spent: summary.spent, previous: previousSpent, changes: changes)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)
            .padding(.bottom, Theme.Space.l)
        }
        .background(Theme.Colors.canvas)
    }

    @ViewBuilder
    private func whereItWent(_ slices: [CategorySpend], total: Centimes) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: L10n.t("Where your money went"))
            if slices.isEmpty {
                Text(L10n.t("No expenses yet.")).font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            } else {
                HStack(spacing: 20) {
                    Chart(Array(slices.enumerated()), id: \.offset) { item in
                        SectorMark(angle: .value("Amount", item.element.amount), innerRadius: .ratio(0.64), angularInset: 1.5)
                            .foregroundStyle(Self.palette[item.offset % Self.palette.count])
                            .cornerRadius(2)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 136, height: 136)
                    .overlay {
                        VStack(spacing: 0) {
                            Text(Money.format(total, symbol: false)).font(.system(size: 20, weight: .heavy).monospacedDigit())
                            Text(L10n.t("%@ spent", Money.currencySymbol)).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    .accessibilityLabel(L10n.t("Spending by category"))

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(slices.enumerated()), id: \.offset) { item in
                            let slice = item.element
                            HStack(spacing: 8) {
                                Circle().fill(Self.palette[item.offset % Self.palette.count]).frame(width: 10, height: 10)
                                Text(name(slice.categoryID)).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(percent(slice.amount, of: total)).font(.system(size: 14, weight: .bold).monospacedDigit())
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func inVsOut(_ s: PeriodSummary) -> some View {
        let maxValue = max(s.moneyIn, s.spent, 1)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: L10n.t("In vs out"))
            bar(L10n.t("Money in"), Money.format(s.moneyIn, sign: true), Theme.Colors.positive,
                value: Double(s.moneyIn) / Double(maxValue), fill: Theme.Colors.positive)
            bar(L10n.t("Spent"), Money.format(s.spent), Theme.Colors.ink,
                value: Double(s.spent) / Double(maxValue), fill: s.spent > s.moneyIn ? Theme.Colors.negative : Theme.Colors.ink)
            Text(s.left >= 0 ? L10n.t("%@ still in your bztam.", Money.format(s.left))
                             : L10n.t("%@ more spent than came in.", Money.format(-s.left)))
                .font(.bzCaption)
                .foregroundStyle(s.left >= 0 ? Theme.Colors.inkMuted : Theme.Colors.negative)
        }
    }

    private func bar(_ label: String, _ value: String, _ color: Color, value fraction: Double, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                Spacer()
                Text(value).font(.system(size: 14, weight: .bold).monospacedDigit()).foregroundStyle(color)
            }
            ProgressPill(value: fraction, height: 10, fill: fill)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func comparison(spent: Centimes, previous: Centimes, changes: [CategoryChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L10n.t("Compared with the previous month"))
            if let ratio = InsightsCalculator.change(current: spent, previous: previous) {
                let pct = Int((abs(ratio) * 100).rounded())
                Text(ratio <= 0 ? L10n.t("%d%% less spent", pct) : L10n.t("%d%% more spent", pct))
                    .font(.bzTitleXL).tracking(-0.6)
                Text(L10n.t("%@ last month", Money.format(previous))).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                ForEach(changes, id: \.categoryID) { change in
                    let p = Int((abs(change.ratio) * 100).rounded())
                    HStack {
                        Text(name(change.categoryID)).font(.system(size: 16, weight: .medium))
                        Spacer()
                        Text(change.ratio > 0 ? L10n.t("+%d%% more", p) : L10n.t("%d%% less", p))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(change.ratio > 0 ? Theme.Colors.negative : Theme.Colors.positive)
                    }
                    .frame(minHeight: 44)
                }
            } else {
                Text(L10n.t("Nothing to compare with yet. Come back next month."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
    }

    private func percent(_ part: Centimes, of total: Centimes) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(part) / Double(total) * 100).rounded()))%"
    }
}
