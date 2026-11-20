import SwiftData
import SwiftUI

/// Welcome, payday, money in, fixed bills, three questions about how you live, then a suggested plan
/// (or "just track first"). Most people don't know what each category should get, so Bztam proposes it.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var payday = 1
    @State private var income = AmountInput()
    @State private var bills: [String: AmountInput] = [:]
    @State private var answers = BudgetPlanner.Answers(income: 0)
    @State private var trackFirst = false

    private let stepsCount = 5
    private static let billKeys: [(key: String, title: String, symbol: String)] = [
        ("rent", "Rent", "house"), ("bills", "Water and electricity", "bolt"), ("phone", "Phone and internet", "iphone")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if step > 0 {
                HStack {
                    HStack(spacing: 6) {
                        ForEach(1...stepsCount, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Theme.Colors.ink : Theme.Colors.surface)
                                .frame(width: 26, height: 6)
                        }
                    }
                    .animation(.snappy, value: step)
                    .accessibilityElement()
                    .accessibilityLabel(L10n.t("Step %d of %d", step, stepsCount))
                    Spacer()
                    Button(L10n.t("Back")) { go(step - 1) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.link)
                }
            }

            Group {
                switch step {
                case 0: welcome
                case 1: paydayStep
                case 2: incomeStep
                case 3: billsStep
                case 4: lifeStep
                default: PlanMonthView(income: income.centimes, savings: trackFirst ? 0 : BudgetPlanner.plan(currentAnswers).savings,
                                       trackFirst: trackFirst, budgets: suggestedBudgets(), onFinish: finish)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
    }

    private func go(_ next: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = next }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer(minLength: 0)
            Image("AppIconImage").resizable().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Know what's left to spend."))
                    .font(.system(size: 40, weight: .heavy)).tracking(-1)
                Text(L10n.t("Bztam shows what came in, what you spent and what's left in every category."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            VStack(alignment: .leading, spacing: 16) {
                tour("camera", L10n.t("Scan a receipt or share a bill"), L10n.t("Photos, screenshots and PDFs, read on your iPhone."))
                tour("text.bubble", L10n.t("Or just type it, or say it"), L10n.t("\"taxi 20\" is enough."))
                tour("lock", L10n.t("Private"), L10n.t("No account, no bank connection, no ads."))
            }
            Spacer(minLength: 0)
            Button(L10n.t("Get started")) { go(1) }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
        }
    }

    private func tour(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconCircle(symbol: symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bzBodyStrong)
                Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
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
                        withAnimation(.snappy) { payday = day }
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
            .sensoryFeedback(.selection, trigger: payday)
            Text(L10n.t("Paid at the end of the month? Pick 25 or 28."))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            Spacer()
            Button(L10n.t("Continue")) { go(2) }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
        }
    }

    private var incomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("How much comes in each month?"))
                Text(L10n.t("Your salary and any other money in. It stays on your iPhone, and you can hide it later."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            AmountField(caption: L10n.t("Money in each month"), text: income.display())
            Spacer(minLength: 0)
            KeypadView { income.press($0) }
            Button(L10n.t("Continue")) { go(3) }
                .buttonStyle(.pillPrimary)
                .disabled(income.centimes == 0)
                .opacity(income.centimes == 0 ? 0.5 : 1)
                .accessibilityIdentifier("onboarding.continue")
            Button(L10n.t("Skip for now")) { income = AmountInput(); go(3) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.link)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("onboarding.skip")
        }
    }

    private var billsStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("Your fixed bills"))
                Text(L10n.t("Tap the ones you pay every month and write about how much. Skip what you don't pay."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Self.billKeys, id: \.key) { bill in
                        BillRow(symbol: bill.symbol, title: L10n.t(bill.title),
                                input: Binding(get: { bills[bill.key] }, set: { bills[bill.key] = $0 }))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            Button(L10n.t("Continue")) { go(4) }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
        }
    }

    private var lifeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: L10n.t("How do you live?"))
                Text(L10n.t("Three quick questions so the plan fits you."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    question(L10n.t("Cafés and eating out"), [L10n.t("Rarely"), L10n.t("Sometimes"), L10n.t("Often")],
                             selection: $answers.eatingOut)
                    question(L10n.t("Getting around"), [L10n.t("Walk or bus"), L10n.t("Taxis"), L10n.t("My car")],
                             selection: $answers.gettingAround)
                    question(L10n.t("Saving each month"), [L10n.t("Not now"), L10n.t("A little"), L10n.t("A lot")],
                             selection: $answers.saving)
                }
            }
            Button(L10n.t("See my plan")) { trackFirst = false; go(5) }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
            Button(L10n.t("Just track first, plan later")) { trackFirst = true; go(5) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.link)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func question(_ title: String, _ options: [String], selection: Binding<BudgetPlanner.Level>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 17, weight: .bold))
            HStack(spacing: 8) {
                ForEach(BudgetPlanner.Level.allCases, id: \.rawValue) { level in
                    let on = selection.wrappedValue == level
                    Button { withAnimation(.snappy) { selection.wrappedValue = level } } label: {
                        Text(options[level.rawValue])
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(on ? Theme.Colors.onInk : Theme.Colors.ink)
                            .background(on ? Theme.Colors.ink : Theme.Colors.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: selection.wrappedValue)
        }
    }

    private var currentAnswers: BudgetPlanner.Answers {
        var a = answers
        a.income = income.centimes
        a.fixed = bills.compactMapValues { $0.centimes > 0 ? $0.centimes : nil }
        return a
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

    /// Called by the plan step when it first appears: creates the categories with the suggested budgets.
    private func suggestedBudgets() -> [String: Centimes] {
        let plan = BudgetPlanner.plan(currentAnswers)
        guard trackFirst else { return plan.budgets }
        return plan.budgets.filter { ["rent", "bills", "phone"].contains($0.key) }
    }
}

/// A fixed bill: tap to say you pay it, then type about how much.
private struct BillRow: View {
    let symbol: String
    let title: String
    @Binding var input: AmountInput?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let on = input != nil
        HStack(spacing: 14) {
            IconCircle(symbol: symbol, size: 44, fill: on ? Theme.Colors.brand : Theme.Colors.surface,
                       tint: on ? Theme.Colors.onBrand : Theme.Colors.ink)
            Text(title).font(.bzBodyStrong)
            Spacer()
            if on {
                HStack(spacing: 4) {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .frame(width: 90)
                        .focused($focused)
                        .onChange(of: text) { _, t in input = AmountInput(centimes: (Int(t.filter(\.isNumber)) ?? 0) * 100) }
                    Text(Money.currencySymbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(on ? Theme.Colors.positive : Theme.Colors.line)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(12)
        .background(Theme.Colors.surface.opacity(on ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) {
                if on { input = nil; text = "" } else { input = AmountInput(); focused = true }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Give each category an amount; fixed ones first. Used by onboarding and Settings.
struct PlanMonthView: View {
    let income: Centimes
    var savings: Centimes = 0
    var trackFirst = false
    /// Suggested budgets by category key, applied once when the step opens.
    var budgets: [String: Centimes] = [:]
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]

    private var planned: Centimes { categories.reduce(0) { $0 + $1.budget } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ScreenTitle(text: trackFirst ? L10n.t("Track first") : L10n.t("Your plan"))
                Text(trackFirst
                     ? L10n.t("Just your bills for now. After a month, Bztam suggests budgets from what you really spend.")
                     : income > 0 ? L10n.t("Here's a plan for %@ a month. Change any amount.", Money.format(income, privacy: .never))
                                  : L10n.t("Give each category an amount. Rent and bills come first, so what's left is yours to spend."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
                if savings > 0 {
                    Label(L10n.t("%@ kept aside for savings", Money.format(savings, privacy: .never)), systemImage: "leaf")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
                }
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
        .onAppear {
            DataStore.ensureCategories(in: context, income: 0)
            guard !budgets.isEmpty || trackFirst else { return }
            let all = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
            for c in all { c.budget = budgets[c.key] ?? 0 }
            try? context.save()
        }
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
