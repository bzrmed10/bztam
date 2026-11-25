import SwiftData
import SwiftUI
import UserNotifications

/// First launch (and "Plan my month again"): currency, payday, money in, household, fixed bills, how you live,
/// savings, then a suggested plan and a summary of what Bztam set up. Every step can be skipped: the app works
/// with nothing filled in, and Home offers to finish later.
struct OnboardingView: View {
    static let setupSkippedKey = "setupSkipped"

    /// Opened again from Home or Settings: no welcome, a close button, and existing data is kept.
    var setupMode = false

    enum Step: Int, CaseIterable {
        case welcome, currency, payday, income, household, bills, life, savings, plan, ready
    }

    enum Household: Int, CaseIterable { case alone, two, family }

    struct ExtraIncome: Identifiable, Equatable {
        var id = UUID()
        var name = ""
        var amount: Centimes = 0
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @AppStorage(Money.currencyKey) var currency = Currency.mad.rawValue
    @AppStorage(OnboardingView.setupSkippedKey) var setupSkipped = false

    @State var step: Step = .welcome
    /// The currency picked on the currency step; saved only when you continue.
    @State var pickedCurrency: Currency?
    @State var currencyQuery = ""
    @State var payday = 1
    @State var salary = AmountInput()
    @State var salaryRepeats = true
    @State var extras: [ExtraIncome] = []
    @State var household: Household = .alone
    @State var adults = 2
    @State var children = 1
    @State var bills: [BillCatalog.Bill] = []
    @State var eatingOut: BudgetPlanner.Level = .mid
    @State var gettingAround: BudgetPlanner.Level = .mid
    @State var saving: BudgetPlanner.Level = .mid
    @State var goalName = ""
    @State var goalTarget: Centimes = 0
    @State var goalHasDate = false
    @State var goalDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State var leftover: BudgetPlanner.Leftover = .buffer
    @State var trackFirst = false
    /// The plan shown on the plan step, by category key (editable).
    @State var planBudgets: [String: Centimes] = [:]
    @State var planSavings: Centimes = 0
    @State var keyboardShown = false
    @State var notificationsAsked = false
    @State var loaded = false

    /// Steps with a progress dash (welcome and the summary have none).
    static let progressSteps: [Step] = [.currency, .payday, .income, .household, .bills, .life, .savings, .plan]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topBar
            Group {
                switch step {
                case .welcome: welcome
                case .currency: currencyStep
                case .payday: paydayStep
                case .income: incomeStep
                case .household: householdStep
                case .bills: billsStep
                case .life: lifeStep
                case .savings: savingsStep
                case .plan: planStep
                case .ready: readyStep
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .keyboardDoneButton()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.snappy) { keyboardShown = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy) { keyboardShown = false }
        }
        .onAppear(perform: load)
    }

    // MARK: Navigation

    @ViewBuilder private var topBar: some View {
        if step != .welcome {
            HStack(spacing: 12) {
                if setupMode && (step == .currency || step == .payday) {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                } else {
                    Button { back() } label: {
                        Image(systemName: "chevron.backward").font(.scaled(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Back"))
                }
                if let index = Self.progressSteps.firstIndex(of: step) {
                    HStack(spacing: 4) {
                        ForEach(0..<Self.progressSteps.count, id: \.self) { i in
                            Capsule()
                                .fill(i <= index ? Theme.Colors.ink : Theme.Colors.surface)
                                .frame(height: 5)
                        }
                    }
                    .animation(.snappy, value: step)
                    .accessibilityElement()
                    .accessibilityLabel(L10n.t("Step %d of %d", index + 1, Self.progressSteps.count))
                } else {
                    Spacer()
                }
                if step != .ready {
                    Button(L10n.t("Skip")) { skip() }
                        .font(.scaled(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.link)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("onboarding.skip")
                }
            }
        }
    }

    func go(_ next: Step) {
        hideKeyboard()
        if next == .plan { buildPlan() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = next }
    }

    func next() {
        guard let n = Step(rawValue: step.rawValue + 1) else { return }
        go(n)
    }

    func back() {
        var target = step.rawValue - 1
        if setupMode && target <= Step.currency.rawValue { target = Step.payday.rawValue }
        if target < 0 { return }
        if target == Step.welcome.rawValue && setupMode { dismiss(); return }
        hideKeyboard()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = Step(rawValue: target) ?? .welcome }
    }

    /// "Skip": move on without this step's answers.
    func skip() {
        hideKeyboard()
        switch step {
        case .income: salary = AmountInput(); extras = []
        case .household: household = .alone
        case .bills: bills = []
        case .life: eatingOut = .mid; gettingAround = .mid
        case .savings: saving = .low; goalName = ""; goalTarget = 0; goalHasDate = false
        case .plan:
            trackFirst = true
            go(.ready)
            return
        default: break
        }
        next()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let settings = DataStore.settings(in: context)
        payday = settings.payday
        if setupMode {
            step = .payday
            if settings.expectedIncome > 0 { salary = AmountInput(centimes: settings.expectedIncome) }
        } else if UserDefaults.standard.string(forKey: Money.currencyKey) == nil, let detected = Currency.ofRegion {
            pickedCurrency = detected
        }
    }


    // MARK: Plan

    var answers: BudgetPlanner.Answers {
        BudgetPlanner.Answers(
            income: totalIncome, fixed: BillCatalog.fixedByCategory(bills), eatingOut: eatingOut,
            gettingAround: gettingAround, saving: saving,
            adults: household == .alone ? 1 : household == .two ? 2 : adults,
            children: household == .family ? children : 0)
    }

    var totalIncome: Centimes { salary.centimes + extras.reduce(0) { $0 + $1.amount } }

    var basePlan: BudgetPlanner.Plan { BudgetPlanner.plan(answers) }

    /// Recomputes the plan from the answers and the leftover choice (on entering the plan step).
    func buildPlan() {
        let a = answers
        let plan = BudgetPlanner.apply(leftover, to: BudgetPlanner.plan(a), answers: a)
        planBudgets = plan.budgets
        planSavings = plan.savings
        trackFirst = false
    }

    // MARK: Finish

    /// Welcome → "Skip setup": straight into the app with the default categories and no budgets.
    func skipEverything() {
        let settings = DataStore.settings(in: context)
        DataStore.ensureCategories(in: context, income: 0)
        settings.onboardingDone = true
        setupSkipped = true
        try? context.save()
    }

    func finish() {
        let settings = DataStore.settings(in: context)
        settings.payday = payday
        settings.expectedIncome = totalIncome
        DataStore.ensureCategories(in: context, income: 0)
        let period = BudgetCalculator.period(containing: .now, payday: payday)

        // Every category the plan and the bills need, by key (built-in ones created when missing).
        let existing = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
        var byKey: [String: BudgetCategory] = [:]
        for c in existing where !c.key.isEmpty && (byKey[c.key] == nil || !c.isArchived) { byKey[c.key] = c }
        var order = (existing.map(\.order).max() ?? 0) + 1
        let neededKeys = Set(planBudgets.keys).union(bills.map(\.categoryKey))
        for key in neededKeys.sorted() {
            if let c = byKey[key] {
                c.isArchived = false
            } else if let t = DefaultCategories.template(for: key) {
                let c = BudgetCategory(key: t.key, name: t.englishName, symbol: t.symbol, isFixed: t.isFixed, order: order)
                order += 1
                context.insert(c)
                byKey[key] = c
            }
        }
        // Bills you named get their own category.
        for bill in bills where bill.isCustom && bill.amount > 0 {
            let name = bill.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            let c = BudgetCategory(name: name.isEmpty ? L10n.t("Bill") : name, symbol: "pin", isFixed: true, order: order)
            order += 1
            context.insert(c)
            byKey[bill.categoryKey] = c
        }

        // Budgets: the plan (or only the bills when tracking first).
        let fixed = BillCatalog.fixedByCategory(bills)
        let budgets = trackFirst ? fixed : planBudgets
        for (key, amount) in budgets {
            byKey[key]?.budget = amount
        }

        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive }))) ?? []
        // Salary: added every month on payday, or once for this month.
        if salary.centimes > 0 {
            if salaryRepeats {
                let start = BillCatalog.dateInPeriod(day: payday, period: period)
                if let existing = rules.first(where: { $0.kind == .income && $0.incomeSource == .salary }) {
                    existing.amount = salary.centimes
                } else {
                    context.insert(RecurringRule(kind: .income, amount: salary.centimes, incomeSource: .salary,
                                                 frequency: .monthly, startDate: start))
                }
            } else if !setupMode {
                context.insert(Entry(kind: .income, amount: salary.centimes, date: .now, incomeSource: .salary))
            }
        }
        for extra in extras where extra.amount > 0 {
            let name = extra.name.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(RecurringRule(kind: .income, amount: extra.amount, note: name, incomeSource: .other,
                                         frequency: .monthly, startDate: BillCatalog.dateInPeriod(day: payday, period: period)))
        }
        // Bills with the same amount every month become recurring expenses.
        for bill in bills where bill.amount > 0 && bill.sameEveryMonth {
            guard let c = byKey[bill.categoryKey] else { continue }
            let title = bill.isCustom ? bill.customName.trimmingCharacters(in: .whitespacesAndNewlines) : L10n.t(bill.kind?.title ?? "")
            if rules.contains(where: { $0.kind == .expense && $0.category?.id == c.id && $0.amount == bill.amount }) { continue }
            context.insert(RecurringRule(kind: .expense, amount: bill.amount, merchant: title, category: c,
                                         frequency: .monthly, startDate: BillCatalog.startDate(for: bill, period: period)))
        }
        // A goal: the one you named, or plain "Savings" when you chose to save.
        let name = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty || planSavings > 0 && !trackFirst {
            let deadline = goalHasDate ? goalDate : nil
            let suggestion = GoalMath.suggestedMonthly(target: goalTarget, saved: 0, deadline: deadline)
            context.insert(SavingsGoal(name: name.isEmpty ? L10n.t("Savings") : name, symbol: name.isEmpty ? "leaf" : "sparkles",
                                       target: goalTarget, deadline: deadline,
                                       monthlyPlan: planSavings > 0 && !trackFirst ? planSavings : suggestion))
        }

        settings.onboardingDone = true
        setupSkipped = false
        try? context.save()
        RecurringEngine.run(in: context)
        WidgetSync.update(context: context)
        if setupMode { dismiss() }
    }

    func askNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            notificationsAsked = true
            InsightAlerts.scheduleWeekly()
            MonthEnd.scheduleNotification(payday: DataStore.settings(in: context).payday)
        }
    }
}
