import SwiftUI

// The screens of the onboarding, one per step.
extension OnboardingView {

    // MARK: Shared pieces

    /// A binding to one bill found by id. Unlike `ForEach($bills)`, it can't crash when the bill is removed
    /// (Skip, the x, or a tile tapped again) while its field is still on screen.
    func billBinding(_ id: UUID) -> Binding<BillCatalog.Bill> {
        Binding(
            get: { bills.first { $0.id == id } ?? BillCatalog.Bill(id: id, kindID: "", day: 1, sameEveryMonth: false) },
            set: { new in if let i = bills.firstIndex(where: { $0.id == id }) { bills[i] = new } })
    }

    func extraBinding(_ id: UUID) -> Binding<ExtraIncome> {
        Binding(
            get: { extras.first { $0.id == id } ?? ExtraIncome(id: id) },
            set: { new in if let i = extras.firstIndex(where: { $0.id == id }) { extras[i] = new } })
    }

    func header(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenTitle(text: title)
            Text(detail).font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The step's main button. Hidden while the keyboard is open, so the field you type in stays visible.
    @ViewBuilder
    func continueButton(_ title: String = L10n.t("Continue"), action: (() -> Void)? = nil) -> some View {
        if !keyboardShown {
            Button(title) { if let action { action() } else { next() } }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.continue")
                .transition(.opacity)
        }
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
                    .font(.scaled(size: 22))
                    .foregroundStyle(selected ? Theme.Colors.positive : Theme.Colors.line)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(12)
            .background(Theme.Colors.surface.opacity(selected ? 1 : 0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(selected ? Theme.Colors.ink : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.Colors.ink)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func levels(_ title: String, _ options: [String], selection: Binding<BudgetPlanner.Level>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.scaled(size: 17, weight: .bold))
            HStack(spacing: 8) {
                ForEach(BudgetPlanner.Level.allCases, id: \.rawValue) { level in
                    let on = selection.wrappedValue == level
                    Button { withAnimation(.snappy) { selection.wrappedValue = level } } label: {
                        Text(options[level.rawValue])
                            .font(.scaled(size: 15, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(on ? Theme.Colors.onInk : Theme.Colors.ink)
                            .background(on ? Theme.Colors.ink : Theme.Colors.surface, in: Capsule())
                    }
                    .buttonStyle(.pressable)
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
                    .font(.scaled(size: 40, weight: .heavy)).tracking(-1)
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
                    .font(.scaled(size: 15, weight: .semibold))
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
            SearchField(placeholder: L10n.t("Search currencies"), text: $currencyQuery)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Currency.sorted().filter { $0.matches(currencyQuery) }) { c in
                        CurrencyRow(currency: c, isRegion: c == Currency.ofRegion,
                                    selected: (pickedCurrency?.rawValue ?? currency) == c.rawValue) {
                            withAnimation(.snappy) { pickedCurrency = c }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            continueButton {
                if let pickedCurrency { currency = pickedCurrency.rawValue }
                hideKeyboard()
                next()
            }
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
                            .font(.scaled(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundStyle(day == payday ? Theme.Colors.onInk : Theme.Colors.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(day == payday ? Theme.Colors.ink : Theme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.pressable)
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
                    ForEach(extras) { extra in
                        HStack(spacing: 8) {
                            TextField(L10n.t("Freelance, rent…"), text: extraBinding(extra.id).name)
                                .font(.bzBodyStrong)
                                .padding(.horizontal, 14).frame(height: 44)
                                .background(Theme.Colors.surface, in: Capsule())
                            MoneyTextField(value: extraBinding(extra.id).amount, width: 130, accessibility: L10n.t("Amount"))
                            Button {
                                withAnimation(.snappy) { extras.removeAll { $0.id == extra.id } }
                            } label: {
                                Image(systemName: "xmark").font(.scaled(size: 13, weight: .bold)).frame(width: 32, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.t("Remove"))
                        }
                    }
                    Button {
                        withAnimation(.snappy) { extras.append(ExtraIncome()) }
                    } label: {
                        Label(L10n.t("Other money in every month"), systemImage: "plus")
                            .font(.scaled(size: 15, weight: .semibold))
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
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(BillCatalog.shown()) { kind in
                            let on = bills.contains { $0.kindID == kind.id }
                            billTile(L10n.t(kind.title), symbol: kind.symbol, on: on) {
                                toggle(kind)
                                // Bring the new card into view, above the number pad.
                                if let added = bills.last, added.kindID == kind.id, !on {
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(300))
                                        withAnimation(.snappy) { proxy.scrollTo(added.id, anchor: .center) }
                                    }
                                }
                            }
                                .accessibilityIdentifier("bill.\(kind.id)")
                        }
                        billTile(L10n.t("Something else"), symbol: "plus", on: false) {
                            let bill = BillCatalog.Bill(kindID: "", day: payday, sameEveryMonth: true)
                            withAnimation(.snappy) { bills.append(bill) }
                            // Bring the new card into view; its name field gets the keyboard.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                withAnimation(.snappy) { proxy.scrollTo(bill.id, anchor: .center) }
                            }
                        }
                        .accessibilityIdentifier("bill.custom")
                    }
                    if !bills.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(bills) { bill in
                                BillCard(bill: billBinding(bill.id), focusName: bill.isCustom && bill.customName.isEmpty) {
                                    hideKeyboard()
                                    withAnimation(.snappy) { bills.removeAll { $0.id == bill.id } }
                                }
                                .id(bill.id)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        let total = bills.reduce(0) { $0 + $1.amount }
                        if total > 0 {
                            HStack {
                                Text(L10n.t("Fixed bills each month")).font(.scaled(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                                Spacer()
                                Text(Money.format(total)).font(.bzAmount)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            }
            continueButton()
        }
    }

    private func toggle(_ kind: BillCatalog.Kind) {
        if bills.contains(where: { $0.kindID == kind.id }) { hideKeyboard() }
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
                    .font(.scaled(size: 20, weight: .medium))
                    .foregroundStyle(on ? Theme.Colors.onBrand : Theme.Colors.ink)
                    .frame(width: 44, height: 44)
                    .background(on ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
                Text(title)
                    .font(.scaled(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .top)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.surface.opacity(on ? 1 : 0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(on ? Theme.Colors.ink : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.pressable)
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
                        Text(L10n.t("Saving for something?")).font(.scaled(size: 17, weight: .bold))
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
                                    .font(.scaled(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
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
                                Text(L10n.t("%@ left over", Money.format(base.leftover, privacy: .never)))
                                    .font(.scaled(size: 15, weight: .bold))
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
        let extrasIn = extras.filter { $0.amount > 0 }
        let name = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasGoal = !name.isEmpty || (planSavings > 0 && !trackFirst)
        return VStack(alignment: .leading, spacing: 18) {
            header(L10n.t("You're set"), L10n.t("Here's what Bztam set up. You can change all of it later."))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard(L10n.t("Your month")) {
                        summaryLine("calendar", L10n.t("Payday"), L10n.t("Day %d of the month", payday))
                        if salary.centimes > 0 {
                            summaryLine("arrow.down.to.line", L10n.t("Salary"),
                                        salaryRepeats ? L10n.t("Every month on payday") : L10n.t("This month only"),
                                        amount: salary.centimes)
                        }
                        ForEach(extrasIn) { e in
                            let title = e.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            summaryLine("plus.circle", title.isEmpty ? L10n.t("Other") : title, L10n.t("Every month on payday"), amount: e.amount)
                        }
                    }
                    if !repeating.isEmpty {
                        summaryCard(L10n.t("Added every month")) {
                            ForEach(repeating) { bill in
                                VStack(alignment: .leading, spacing: 8) {
                                    summaryLine(bill.symbol, billTitle(bill), L10n.t("Day %d of the month", bill.day), amount: bill.amount)
                                    if BillCatalog.hasPassed(day: bill.day, period: period) {
                                        HStack(spacing: 10) {
                                            Text(L10n.t("Already paid this month"))
                                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                            Spacer(minLength: 8)
                                            Toggle(L10n.t("Already paid this month"), isOn: billBinding(bill.id).paidThisMonth)
                                                .labelsHidden()
                                                .tint(Theme.Colors.positive)
                                        }
                                        .padding(.leading, 50)
                                    }
                                }
                            }
                        }
                    }
                    summaryCard(L10n.t("Your plan")) {
                        ForEach(variable) { bill in
                            summaryLine(bill.symbol, billTitle(bill), L10n.t("Budget, it changes each month"), amount: bill.amount)
                        }
                        if hasGoal {
                            summaryLine("leaf", name.isEmpty ? L10n.t("Savings") : name,
                                        planSavings > 0 && !trackFirst ? L10n.t("%@ a month", Money.format(planSavings)) : L10n.t("Savings goal"))
                        }
                        summaryLine("square.grid.2x2", trackFirst
                                    ? L10n.t("Budgets for your bills")
                                    : L10n.t("%d categories with a budget", planBudgets.values.filter { $0 > 0 }.count),
                                    trackFirst ? L10n.t("After a month, Bztam suggests the rest.") : L10n.t("Change them any time in Settings"))
                    }
                    Button {
                        askNotifications()
                    } label: {
                        HStack(spacing: 14) {
                            IconCircle(symbol: notificationsAsked ? "checkmark" : "bell", size: 40, fill: Theme.Colors.brandTint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(notificationsAsked ? L10n.t("Reminders are set") : L10n.t("Turn on reminders")).font(.bzBodyStrong)
                                Text(L10n.t("Budget alerts, bills and your Monday recap")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    .buttonStyle(.pressable)
                    .disabled(notificationsAsked)
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            Button(L10n.t("Start using Bztam")) { finish() }
                .buttonStyle(.pillPrimary)
                .accessibilityIdentifier("onboarding.finish")
        }
    }

    private func billTitle(_ bill: BillCatalog.Bill) -> String {
        if bill.isCustom {
            let name = bill.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? L10n.t("Bill") : name
        }
        return L10n.t(bill.kind?.title ?? "")
    }

    /// A titled group on the summary page.
    private func summaryCard<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.scaled(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    /// Icon, title and detail, with an amount on the trailing side.
    private func summaryLine(_ symbol: String, _ title: String, _ detail: String, amount: Centimes? = nil) -> some View {
        HStack(spacing: 12) {
            IconCircle(symbol: symbol, size: 38, fill: Theme.Colors.canvas)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bzBodyStrong).lineLimit(2)
                Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(2)
            }
            Spacer(minLength: 8)
            if let amount {
                Text(Money.format(amount, privacy: .never)).font(.bzAmount).lineLimit(1).fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One bill you picked: amount, day, and whether it is the same every month.
struct BillCard: View {
    @Binding var bill: BillCatalog.Bill
    var focusName = false
    let onRemove: () -> Void
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconCircle(symbol: bill.symbol, size: 40, fill: Theme.Colors.canvas)
                if bill.isCustom {
                    TextField(L10n.t("Name of the bill"), text: $bill.customName)
                        .font(.bzBodyStrong)
                        .submitLabel(.done)
                        .onSubmit { bill.customName = bill.customName.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .focused($nameFocused)
                        .onAppear {
                            guard focusName else { return }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                nameFocused = true
                            }
                        }
                } else {
                    Text(L10n.t(bill.kind?.title ?? "")).font(.bzBodyStrong).lineLimit(1)
                }
                Spacer(minLength: 4)
                MoneyTextField(value: $bill.amount, width: 124, accessibility: L10n.t("Amount"))
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.scaled(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
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
                        Text(L10n.t("Day %d", bill.day))
                        Image(systemName: "chevron.up.chevron.down").font(.scaled(size: 10, weight: .semibold))
                    }
                    .font(.scaled(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Theme.Colors.canvas, in: Capsule())
                }
                Spacer()
                Toggle(isOn: $bill.sameEveryMonth) {
                    Text(L10n.t("Same every month")).font(.scaled(size: 13, weight: .semibold))
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
                            .overlay(Circle().strokeBorder(Theme.Colors.line, lineWidth: i == 3 ? 1 : 0))
                        Text(parts[i].0 + " " + Money.format(parts[i].1, privacy: .never))
                            .font(.scaled(size: 12, weight: .semibold))
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
