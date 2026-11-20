import SwiftData
import SwiftUI

/// Three steps: payday, money in, plan the month.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var payday = 1
    @State private var income = AmountInput()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Theme.Colors.ink : Theme.Colors.surface)
                            .frame(width: 34, height: 6)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(L10n.t("Step %d of 3", step + 1))
                Spacer()
                if step > 0 {
                    Button(L10n.t("Back")) { step -= 1 }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.link)
                }
            }

            switch step {
            case 0: paydayStep
            case 1: incomeStep
            default: PlanMonthView(income: income.centimes, onFinish: finish)
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
    }

    private var paydayStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("When do you get paid?"))
                Text(L10n.t("Your budget month starts on this day, so it matches your salary."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...28, id: \.self) { day in
                    Button {
                        payday = day
                    } label: {
                        Text("\(day)")
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundStyle(day == payday ? Theme.Colors.onInk : Theme.Colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(day == payday ? Theme.Colors.ink : Theme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(day == payday ? .isSelected : [])
                }
            }
            Text(L10n.t("Paid at the end of the month? Pick 25 or 28."))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            Spacer()
            Button(L10n.t("Continue")) { step = 1 }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
        }
    }

    private var incomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("How much comes in each month?"))
                Text(L10n.t("Your salary and any other money in. You can change it any time."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            AmountField(caption: L10n.t("Money in this month"), text: income.display())
            Spacer(minLength: 0)
            KeypadView { income.press($0) }
            Button(L10n.t("Continue")) { step = 2 }
                .buttonStyle(.pillPrimary)
                .disabled(income.centimes == 0)
                .opacity(income.centimes == 0 ? 0.5 : 1)
            Button(L10n.t("Skip for now")) { income = AmountInput(); step = 2 }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.link)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func finish() {
        let settings = DataStore.settings(in: context)
        settings.payday = payday
        settings.expectedIncome = income.centimes
        if income.centimes > 0 {
            context.insert(Entry(kind: .income, amount: income.centimes, date: .now, incomeSource: .salary))
        }
        settings.onboardingDone = true
        try? context.save()
    }
}

/// Give each category an amount; fixed ones first. Used by onboarding and Settings.
struct PlanMonthView: View {
    let income: Centimes
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]

    private var planned: Centimes { categories.reduce(0) { $0 + $1.budget } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("Plan your month"))
                Text(L10n.t("Give each category an amount. Rent and bills come first, so what's left is yours to spend."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(categories) { c in
                        BudgetRow(category: c)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            if income > 0 {
                HStack {
                    Text(L10n.t("Not planned yet")).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                    Spacer()
                    TagPill(text: Money.format(max(0, income - planned), privacy: .income),
                            fill: income - planned < 0 ? Theme.Colors.surface : Theme.Colors.brandTint)
                }
                if planned > income {
                    Text(L10n.t("You planned %@ more than comes in.", Money.format(planned - income)))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.negative)
                }
            }
            if let onFinish {
                Button(L10n.t("Start using Bztam")) {
                    try? context.save()
                    onFinish()
                }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.finish")
            }
        }
        .onAppear { DataStore.ensureCategories(in: context, income: income) }
    }
}

/// One category with an editable budget in whole dirhams.
private struct BudgetRow: View {
    @Bindable var category: BudgetCategory
    @State private var text = ""

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: category.symbol, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.displayName).font(.bzBodyStrong)
                if category.isFixed {
                    Text(L10n.t("Planned first")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
                }
            }
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .padding(.horizontal, 16)
                .frame(width: 112, height: 40)
                .background(Theme.Colors.surface, in: Capsule())
                .accessibilityLabel(L10n.t("Budget for %@", category.displayName))
                .onChange(of: text) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { text = digits }
                    category.budget = (Int(digits.prefix(7)) ?? 0) * 100
                }
        }
        .frame(height: 60)
        .onAppear { text = category.budget > 0 ? String(category.budget / 100) : "" }
    }
}
