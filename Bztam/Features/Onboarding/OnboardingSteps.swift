import SwiftUI

// The screens of the onboarding, one per step.
extension OnboardingView {

    // MARK: Shared pieces

    func header(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenTitle(text: title)
            Text(detail).font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func continueButton(_ title: String = L10n.t("Continue"), action: (() -> Void)? = nil) -> some View {
        Button(title) { if let action { action() } else { next() } }
            .buttonStyle(.pillPrimary)
            .accessibilityIdentifier("onboarding.continue")
    }

    func choice(_ title: String, detail: String? = nil, symbol: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 14) {
                if let symbol {
                    IconCircle(symbol: symbol, size: 44, fill: selected ? Theme.Colors.brand : Theme.Colors.canvas,
                               tint: selected ? Theme.Colors.onBrand : Theme.Colors.ink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bzBodyStrong)
                    if let detail { Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted) }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.Colors.positive : Theme.Colors.line)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(12)
            .background(Theme.Colors.surface.opacity(selected ? 1 : 0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(selected ? Theme.Colors.ink : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Colors.ink)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func levels(_ title: String, _ options: [String], selection: Binding<BudgetPlanner.Level>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 17, weight: .bold))
            HStack(spacing: 8) {
                ForEach(BudgetPlanner.Level.allCases, id: \.rawValue) { level in
                    let on = selection.wrappedValue == level
                    Button { withAnimation(.snappy) { selection.wrappedValue = level } } label: {
                        Text(options[level.rawValue])
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
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

    // MARK: Welcome

    var welcome: some View {
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
            VStack(spacing: 6) {
                continueButton(L10n.t("Get started"))
                Button(L10n.t("Skip setup, I'll look around")) { skipEverything() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.link)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skipAll")
            }
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

    // MARK: Currency

    var currencyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(L10n.t("Your currency"), L10n.t("Every amount in Bztam uses it. You can change it later in Settings."))
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Currency.allCases) { c in
                        choice(c.title, detail: c == Self.detectedCurrency ? L10n.t("Your iPhone's region") : nil,
                               selected: currency == c.rawValue) { currency = c.rawValue }
                    }
                }
            }
            continueButton()
        }
    }

    // MARK: Payday

    var paydayStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            header(L10n.t("When do you get paid?"), L10n.t("Your budget month starts on this day, so it matches your salary."))
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
            continueButton()
        }
    }

    // MARK: Money in

    var incomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(L10n.t("How much comes in each month?"),
                   L10n.t("Your salary. It stays on your iPhone, and you can hide it with privacy mode."))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AmountField(caption: L10n.t("Salary each month"), text: salary.display())
                        .accessibilityIdentifier("onboarding.salary")
                    Toggle(isOn: $salaryRepeats) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("Same amount every month")).font(.bzBodyStrong)
                            Text(L10n.t("Added by itself on your payday")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    .tint(Theme.Colors.positive)
                    ForEach($extras) { $extra in
                        HStack(spacing: 8) {
                            TextField(L10n.t("Freelance, rent…"), text: $extra.name)
                                .font(.bzBodyStrong)
                                .padding(.horizontal, 14).frame(height: 44)
                                .background(Theme.Colors.surface, in: Capsule())
                            MoneyTextField(value: $extra.amount, width: 130, accessibility: L10n.t("Amount"))
                            Button {
                                withAnimation(.snappy) { extras.removeAll { $0.id == extra.id } }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.t("Remove"))
                        }
                    }
                    Button {
                        withAnimation(.snappy) { extras.append(ExtraIncome()) }
                    } label: {
                        Label(L10n.t("Other money in every month"), systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.link)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            if !keyboardShown {
                KeypadView { salary.press($0) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            continueButton()
        }
    }

    // MARK: Household

    var householdStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(L10n.t("Who do you spend for?"), L10n.t("Groceries depend a lot on how many people you feed."))
            VStack(spacing: 8) {
                choice(L10n.t("Just me"), symbol: "person", selected: household == .alone) { household = .alone }
                choice(L10n.t("Two of us"), symbol: "person.2", selected: household == .two) { household = .two }
                choice(L10n.t("A family"), symbol: "figure.2.and.child.holdinghands", selected: household == .family) { household = .family }
            }
            if household == .family {
                VStack(spacing: 4) {
                    Stepper(value: $adults, in: 1...8) {
                        HStack { Text(L10n.t("Adults")).font(.bzBodyStrong); Spacer(); Text("\(adults)").font(.bzAmount) }
                    }
                    Stepper(value: $children, in: 0...10) {
                        HStack { Text(L10n.t("Children")).font(.bzBodyStrong); Spacer(); Text("\(children)").font(.bzAmount) }
                    }
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer()
            continueButton()
        }
    }

    // MARK: Bills

    var billsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(L10n.t("Your fixed bills"), L10n.t("Tap what you pay every month. Bills with the same amount are added by themselves on their day."))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(BillCatalog.kinds) { kind in
                            let on = bills.contains { $0.kindID == kind.id }
                            billTile(L10n.t(kind.title), symbol: kind.symbol, on: on) { toggle(kind) }
                                .accessibilityIdentifier("bill.\(kind.id)")
                        }
                        billTile(L10n.t("Something else"), symbol: "plus", on: false) {
                            withAnimation(.snappy) {
                                bills.append(BillCatalog.Bill(kindID: "", day: payday, sameEveryMonth: true))
                            }
                        }
                        .accessibilityIdentifier("bill.custom")
                    }
                    if !bills.isEmpty {
                        VStack(spacing: 10) {
                            ForEach($bills) { $bill in
                                BillCard(bill: $bill) {
                                    withAnimation(.snappy) { bills.removeAll { $0.id == bill.id } }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        let total = bills.reduce(0) { $0 + $1.amount }
                        if total > 0 {
                            HStack {
                                Text(L10n.t("Fixed bills each month")).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                                Spacer()
                                Text(Money.format(total)).font(.bzAmount)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            continueButton()
        }
    }

    private func toggle(_ kind: BillCatalog.Kind) {
        withAnimation(.snappy) {
            if let i = bills.firstIndex(where: { $0.kindID == kind.id }) {
                bills.remove(at: i)
            } else {
                bills.append(BillCatalog.Bill(kindID: kind.id, day: kind.id == "rent" ? 1 : payday, sameEveryMonth: kind.sameEveryMonth))
            }
        }
    }

    private func billTile(_ title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(on ? Theme.Colors.onBrand : Theme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .background(on ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .top)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.surface.opacity(on ? 1 : 0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(on ? Theme.Colors.ink : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Colors.ink)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: How you live

    var lifeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            header(L10n.t("How do you live?"), L10n.t("Two quick questions so the plan fits you."))
            levels(L10n.t("Cafés and eating out"), [L10n.t("Rarely"), L10n.t("Sometimes"), L10n.t("Often")], selection: $eatingOut)
            levels(L10n.t("Getting around"), [L10n.t("Walk or bus"), L10n.t("Taxis"), L10n.t("My car")], selection: $gettingAround)
            Spacer()
            continueButton()
        }
    }

    // MARK: Savings

    var savingsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(L10n.t("Saving"), L10n.t("Money put aside comes off what's left to spend, so it doesn't get spent by accident."))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    levels(L10n.t("Each month"), [L10n.t("Not now"), L10n.t("A little"), L10n.t("A lot")], selection: $saving)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("Saving for something?")).font(.system(size: 17, weight: .bold))
                        TextField(L10n.t("Summer trip, Eid, new phone…"), text: $goalName)
                            .font(.bzBodyStrong)
                            .submitLabel(.done)
                            .padding(.horizontal, 16).frame(height: 48)
                            .background(Theme.Colors.surface, in: Capsule())
                            .accessibilityIdentifier("onboarding.goal")
                        if !goalName.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack {
                                Text(L10n.t("Target")).font(.bzBodyStrong)
                                Text(L10n.t("optional")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                Spacer()
                                MoneyTextField(value: $goalTarget, width: 150, accessibility: L10n.t("Target"))
                            }
                            Toggle(isOn: $goalHasDate.animation(.snappy)) { Text(L10n.t("By a date")).font(.bzBodyStrong) }
                                .tint(Theme.Colors.positive)
                            if goalHasDate {
                                DatePicker(L10n.t("Date"), selection: $goalDate, in: Date.now..., displayedComponents: .date)
                            }
                            let monthly = GoalMath.suggestedMonthly(target: goalTarget, saved: 0, deadline: goalHasDate ? goalDate : nil)
                            if monthly > 0 {
                                Label(L10n.t("%@ a month gets you there", Money.format(monthly)), systemImage: "leaf")
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            continueButton(L10n.t("See my plan"))
        }
    }

    // MARK: Plan

    var planStep: some View {
        let rows = planRows
        let income = totalIncome
        let billsTotal = rows.filter(\.isFixed).reduce(0) { $0 + (planBudgets[$1.key] ?? 0) }
        let everyday = rows.filter { !$0.isFixed }.reduce(0) { $0 + (planBudgets[$1.key] ?? 0) }
        let free = income - billsTotal - everyday - planSavings
        let base = basePlan
        return VStack(alignment: .leading, spacing: 16) {
            header(L10n.t("Your plan"), income > 0
                   ? L10n.t("Here's a plan for %@ a month. Change any amount.", Money.format(income, privacy: .never))
                   : L10n.t("Give each category an amount. Bills come first, so what's left is yours to spend."))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if income > 0 {
                        PlanBar(bills: billsTotal, everyday: everyday, savings: planSavings, free: max(0, free), income: income)
                        if free < 0 {
                            Text(L10n.t("You planned %@ more than comes in.", Money.format(-free)))
                                .font(.bzCaption).foregroundStyle(Theme.Colors.negative)
                        }
                        if base.leftover > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.t("%@ nobody claimed", Money.format(base.leftover, privacy: .never)))
                                    .font(.system(size: 15, weight: .bold))
                                FlowLayout(spacing: 8) {
                                    Chip(title: L10n.t("Keep it as a cushion"), selected: leftover == .buffer) { leftover = .buffer; buildPlan() }
                                    Chip(title: L10n.t("Add it to savings"), selected: leftover == .savings) { leftover = .savings; buildPlan() }
                                    Chip(title: L10n.t("Share it out"), selected: leftover == .spread) { leftover = .spread; buildPlan() }
                                }
                            }
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            PlanRow(row: row, why: why(row),
                                    value: Binding(get: { planBudgets[row.key] ?? 0 }, set: { planBudgets[row.key] = $0 }))
                        }
                        if planSavings > 0 {
                            HStack(spacing: Theme.Space.m) {
                                IconCircle(symbol: "leaf", size: 44, fill: Theme.Colors.brandTint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.t("Savings")).font(.bzBodyStrong)
                                    Text(L10n.t("Put aside each month")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                }
                                Spacer()
                                MoneyTextField(value: $planSavings, width: 130, accessibility: L10n.t("Savings"))
                            }
                            .frame(minHeight: 64)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            continueButton(L10n.t("Looks good")) { trackFirst = false; go(.ready) }
        }
    }

    struct PlanLine: Identifiable {
        let key: String
        let title: String
        let symbol: String
        let isFixed: Bool
        var id: String { key }
    }

    /// Default categories, the extra ones your bills need, and bills you named.
    var planRows: [PlanLine] {
        let fixed = BillCatalog.fixedByCategory(bills)
        var rows: [PlanLine] = []
        for t in DefaultCategories.all where !(t.isFixed && fixed[t.key] == nil) {
            rows.append(PlanLine(key: t.key, title: L10n.t(t.englishName), symbol: t.symbol, isFixed: t.isFixed))
        }
        for t in DefaultCategories.extras where fixed[t.key] != nil {
            rows.append(PlanLine(key: t.key, title: L10n.t(t.englishName), symbol: t.symbol, isFixed: true))
        }
        for b in bills where b.isCustom && b.amount > 0 {
            rows.append(PlanLine(key: b.categoryKey, title: b.customName.isEmpty ? L10n.t("Bill") : b.customName, symbol: "pin", isFixed: true))
        }
        return rows.sorted { $0.isFixed && !$1.isFixed }
    }

    func why(_ row: PlanLine) -> String {
        if row.isFixed { return L10n.t("Your bills") }
        let a = answers
        switch row.key {
        case "courses":
            let people = a.adults + a.children
            return people == 1 ? L10n.t("For 1 person") : L10n.t("For %d people", people)
        case "food", "goingout": return [L10n.t("Rarely"), L10n.t("Sometimes"), L10n.t("Often")][eatingOut.rawValue]
        case "transport":
            let base = [L10n.t("Walk or bus"), L10n.t("Taxis"), L10n.t("My car")][gettingAround.rawValue]
            return bills.contains { $0.kindID == "transportPass" } ? base + " + " + L10n.t("Transport pass") : base
        default: return L10n.t("Small things")
        }
    }

    // MARK: Ready

    var readyStep: some View {
        let period = BudgetCalculator.period(containing: .now, payday: payday)
        let repeating = bills.filter { $0.amount > 0 && $0.sameEveryMonth }
        let variable = bills.filter { $0.amount > 0 && !$0.sameEveryMonth }
        let name = goalName.trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 18) {
            header(L10n.t("You're set"), L10n.t("Here's what Bztam set up. You can change all of it later."))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    summaryRow("calendar", L10n.t("Your month starts on the %d", payday))
                    if salary.centimes > 0 {
                        summaryRow("arrow.down.to.line", salaryRepeats
                                   ? L10n.t("Salary of %@ added every month on payday", Money.format(salary.centimes, privacy: .never))
                                   : L10n.t("%@ added as this month's money in", Money.format(salary.centimes, privacy: .never)))
                    }
                    ForEach(extras.filter { $0.amount > 0 }) { e in
                        summaryRow("plus.circle", L10n.t("%@ added every month", (e.name.isEmpty ? L10n.t("Other") : e.name) + " · " + Money.format(e.amount, privacy: .never)))
                    }
                    ForEach($bills) { $bill in
                        if bill.amount > 0 && bill.sameEveryMonth {
                            let title = bill.isCustom ? (bill.customName.isEmpty ? L10n.t("Bill") : bill.customName) : L10n.t(bill.kind?.title ?? "")
                            VStack(alignment: .leading, spacing: 6) {
                                summaryRow(bill.symbol, L10n.t("%@ added every month on the %d", title + " · " + Money.format(bill.amount), bill.day))
                                if BillCatalog.hasPassed(day: bill.day, period: period) {
                                    Toggle(isOn: $bill.paidThisMonth) {
                                        Text(L10n.t("Already paid this month")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                    }
                                    .tint(Theme.Colors.positive)
                                    .padding(.leading, 50)
                                }
                            }
                        }
                    }
                    ForEach(variable) { bill in
                        summaryRow(bill.symbol, L10n.t("%@: a budget of %@, it changes each month", L10n.t(bill.kind?.title ?? ""), Money.format(bill.amount)))
                    }
                    if !name.isEmpty || (planSavings > 0 && !trackFirst) {
                        summaryRow("leaf", L10n.t("Goal: %@", name.isEmpty ? L10n.t("Savings") : name)
                                   + (planSavings > 0 && !trackFirst ? " · " + L10n.t("%@ a month", Money.format(planSavings)) : ""))
                    }
                    summaryRow("square.grid.2x2", trackFirst
                               ? L10n.t("Budgets only for your bills. After a month, Bztam suggests the rest.")
                               : L10n.t("%d categories with a budget", planBudgets.values.filter { $0 > 0 }.count))
                    if repeating.isEmpty && variable.isEmpty && salary.centimes == 0 {
                        Text(L10n.t("Nothing to set up yet. Add your first expense and Bztam takes it from there."))
                            .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    Button {
                        askNotifications()
                    } label: {
                        HStack(spacing: 14) {
                            IconCircle(symbol: notificationsAsked ? "checkmark" : "bell", size: 44, fill: Theme.Colors.brandTint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(notificationsAsked ? L10n.t("Reminders are set") : L10n.t("Turn on reminders")).font(.bzBodyStrong)
                                Text(L10n.t("Budget alerts, bills and your Monday recap")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    .buttonStyle(.plain)
                    .disabled(notificationsAsked)
                    .padding(.top, 8)
                }
            }
            Button(L10n.t("Start using Bztam")) { finish() }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.finish")
        }
    }

    private func summaryRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            IconCircle(symbol: symbol, size: 36)
            Text(text).font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// One bill you picked: amount, day, and whether it is the same every month.
struct BillCard: View {
    @Binding var bill: BillCatalog.Bill
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconCircle(symbol: bill.symbol, size: 40, fill: Theme.Colors.canvas)
                if bill.isCustom {
                    TextField(L10n.t("Name of the bill"), text: $bill.customName)
                        .font(.bzBodyStrong)
                        .submitLabel(.done)
                } else {
                    Text(L10n.t(bill.kind?.title ?? "")).font(.bzBodyStrong).lineLimit(1)
                }
                Spacer(minLength: 4)
                MoneyTextField(value: $bill.amount, width: 124, accessibility: L10n.t("Amount"))
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                        .frame(width: 28, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Remove"))
            }
            HStack(spacing: 10) {
                Menu {
                    Picker(L10n.t("Day"), selection: $bill.day) {
                        ForEach(1...28, id: \.self) { Text(L10n.t("Day %d of the month", $0)).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(L10n.t("On the %d", bill.day))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Theme.Colors.canvas, in: Capsule())
                }
                Spacer()
                Toggle(isOn: $bill.sameEveryMonth) {
                    Text(L10n.t("Same every month")).font(.system(size: 13, weight: .semibold))
                }
                .tint(Theme.Colors.positive)
                .fixedSize()
            }
        }
        .padding(12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}

/// Bills, everyday spending, savings and what's free, as one bar.
struct PlanBar: View {
    let bills: Centimes
    let everyday: Centimes
    let savings: Centimes
    let free: Centimes
    let income: Centimes

    var body: some View {
        let parts: [(String, Centimes, Color)] = [
            (L10n.t("Bills"), bills, Theme.Colors.ink),
            (L10n.t("Everyday"), everyday, Theme.Colors.brand),
            (L10n.t("Savings"), savings, Theme.Colors.positive),
            (L10n.t("Free"), free, Theme.Colors.surface)
        ]
        let total = max(1, parts.reduce(0) { $0 + max(0, $1.1) })
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts.indices, id: \.self) { i in
                        if parts[i].1 > 0 {
                            Rectangle().fill(parts[i].2)
                                .frame(width: max(4, geo.size.width * Double(parts[i].1) / Double(total)))
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 14)
            .animation(.snappy, value: [bills, everyday, savings, free])
            FlowLayout(spacing: 12) {
                ForEach(parts.indices, id: \.self) { i in
                    HStack(spacing: 6) {
                        Circle().fill(parts[i].2).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Theme.Colors.line, lineWidth: i == 3 ? 1 : 0))
                        Text(parts[i].0 + " " + Money.format(parts[i].1, privacy: .never))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.inkMuted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A category on the plan, with an editable amount and a one-line reason.
struct PlanRow: View {
    let row: OnboardingView.PlanLine
    let why: String
    @Binding var value: Centimes

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: row.symbol, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title).font(.bzBodyStrong).lineLimit(1)
                Text(why).font(.bzCaption)
                    .foregroundStyle(row.isFixed ? Theme.Colors.positive : Theme.Colors.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            MoneyTextField(value: $value, width: 130, accessibility: L10n.t("Budget for %@", row.title))
        }
        .frame(minHeight: 64)
    }
}
