import SwiftData
import SwiftUI

/// On Home, the first days after payday: what to do with the money left (or over) from the month that ended.
/// After a choice, a small note with Undo for a few days.
struct MonthEndSection: View {
    let payday: Int

    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.order) private var goals: [SavingsGoal]
    @Query private var goalMoves: [GoalMove]
    @Query(sort: \MonthClose.decidedAt, order: .reverse) private var closes: [MonthClose]
    @State private var picking: GoalPick?
    @State private var tick = 0
    @State private var decided = 0

    /// Screenshots of the card: the demo month may be past the days when the card is asked.
    static var screenshotMode: Bool { ["monthend", "monthover"].contains(LaunchOptions.openScreen ?? "") && LaunchOptions.demoData }

    /// How long the note with Undo stays on Home.
    static let noteDays = 3

    private var current: BudgetPeriod { BudgetCalculator.period(containing: .now, payday: payday) }
    private var previous: BudgetPeriod { BudgetCalculator.period(current, offset: -1, payday: payday) }

    var body: some View {
        let _ = tick
        Group {
            if let amount = pendingAmount, !snoozed {
                card(amount)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let close = recentClose {
                note(close)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: closes.count)
        .sensoryFeedback(.success, trigger: decided)
        .sheet(item: $picking) { pick in
            MonthEndGoalSheet(amount: pick.amount, goals: pick.goals, saved: savedByGoal) { goal in
                picking = nil
                choose(.goal, amount: pick.amount, goal: goal)
            }
        }
        .task(id: pendingAmount) { autoDecide() }
    }

    // MARK: - State

    private var pendingAmount: Centimes? {
        let summary = BudgetSnapshot.summary(entries: entries, categories: categories, period: previous,
                                             expectedIncome: 0, moves: goalMoves, closes: closes)
        return MonthEndMath.pending(previous: previous, current: current, previousSummary: summary,
                                    closes: MonthClose.values(closes), firstUse: settingsRows.first?.createdAt ?? .now,
                                    now: Self.screenshotMode ? current.start.addingTimeInterval(86_400) : .now)
    }

    private var laterKey: String { "monthEndLater-" + BudgetCategory.periodKey(previous) }

    /// "Later" hides the card for a day.
    private var snoozed: Bool {
        guard let until = UserDefaults.standard.object(forKey: laterKey) as? Date else { return false }
        return until > .now
    }

    /// The decision about last month, while it's recent enough to undo from Home.
    private var recentClose: MonthClose? {
        guard let c = closes.first(where: { Calendar.current.isDate($0.periodStart, inSameDayAs: previous.start) }),
              c.choice != .leave, c.moved != 0,
              Date.now < c.decidedAt.addingTimeInterval(Double(Self.noteDays) * 86_400) else { return nil }
        return c
    }

    private var savedByGoal: [UUID: Centimes] {
        let values = GoalMove.values(goalMoves)
        return Dictionary(uniqueKeysWithValues: goals.map { ($0.id, GoalMath.saved($0.id, in: values)) })
    }

    private var openGoals: [SavingsGoal] { goals.filter { $0.reachedAt == nil } }
    private var goalsWithMoney: [SavingsGoal] { let s = savedByGoal; return goals.filter { (s[$0.id] ?? 0) > 0 } }

    private func goalName(_ id: UUID?) -> String {
        goals.first { $0.id == id }?.name ?? L10n.t("savings")
    }

    /// "Mostly from Transport and Groceries." or "Mostly Café & Food."
    private func why(_ amount: Centimes) -> String? {
        let lines = BudgetSnapshot.lines(entries: entries, categories: categories, period: previous)
        if amount > 0 {
            let top = lines.filter { !$0.category.isFixed }
                .compactMap { line -> (String, Centimes)? in
                    if case .left(let x) = line.status.state, x > 0 { return (line.category.displayName, x) }
                    return nil
                }
                .sorted { $0.1 > $1.1 }.prefix(2).map(\.0)
            if top.count == 2 { return L10n.t("Mostly from %@ and %@.", top[0], top[1]) }
            if let one = top.first { return L10n.t("Mostly from %@.", one) }
            return nil
        }
        let worst = lines.compactMap { line -> (String, Centimes)? in
            if case .over(let x) = line.status.state { return (line.category.displayName, x) }
            return nil
        }.max { $0.1 < $1.1 }
        return worst.map { L10n.t("Mostly %@.", $0.0) + " " + L10n.t("It happens.") } ?? L10n.t("It happens.")
    }

    // MARK: - Actions

    private func choose(_ choice: MonthEndChoice, amount: Centimes, goal: SavingsGoal? = nil, automatic: Bool = false) {
        withAnimation(.snappy) {
            MonthEnd.decide(choice, amount: amount, period: previous, goal: goal, automatic: automatic, context: context)
        }
        decided += 1
    }

    private func toSavings(_ amount: Centimes) {
        let list = amount > 0 ? openGoals : goalsWithMoney
        if list.count == 1 { choose(.goal, amount: amount, goal: list[0]) } else { picking = GoalPick(amount: amount, goals: list) }
    }

    /// The "When the month ends" setting, for months with money left.
    private func autoDecide() {
        guard let amount = pendingAmount, amount > 0, Store.shared.isPlus else { return }
        switch MonthEnd.mode {
        case .ask: break
        case .nextMonth: choose(.nextMonth, amount: amount, automatic: true)
        case .leave: choose(.leave, amount: amount, automatic: true)
        case .savings: if let goal = openGoals.first { choose(.goal, amount: amount, goal: goal, automatic: true) }
        }
    }

    // MARK: - Views

    private func card(_ amount: Centimes) -> some View {
        let left = amount > 0
        let savings = left ? openGoals : goalsWithMoney
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.t("Your month is done") + " · " + DateText.period(previous))
                    .font(.scaled(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button(L10n.t("Later")) {
                    UserDefaults.standard.set(Date.now.addingTimeInterval(86_400), forKey: laterKey)
                    withAnimation(.snappy) { tick += 1 }
                }
                .font(.scaled(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                .accessibilityIdentifier("monthend.later")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(left ? L10n.t("You have %@ left", Money.format(amount, privacy: .income))
                          : L10n.t("You went %@ over", Money.format(-amount, privacy: .income)))
                    .font(.scaled(size: 26, weight: .heavy)).tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                if let why = why(amount) {
                    Text(why).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
            }
            .padding(.top, -6)
            Button {
                choose(.nextMonth, amount: amount)
            } label: {
                Text(left ? L10n.t("Add %@ to next month", Money.format(amount, privacy: .income)) : L10n.t("Take it from next month"))
                    .font(.scaled(size: 15, weight: .bold))
                    .foregroundStyle(left ? Theme.Colors.onBrand : Theme.Colors.canvas)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(left ? Theme.Colors.brand : Theme.Colors.ink, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("monthend.next")
            HStack(spacing: 8) {
                if !savings.isEmpty {
                    small(left ? L10n.t("Add to savings")
                               : (savings.count == 1 ? L10n.t("From %@", savings[0].name) : L10n.t("From savings")),
                          id: "monthend.savings") { toSavings(amount) }
                }
                small(L10n.t("Leave it"), id: "monthend.leave") { choose(.leave, amount: amount) }
            }
        }
        .padding(18)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private func small(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.scaled(size: 14, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(Theme.Colors.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.Colors.canvas, in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(id)
    }

    private func note(_ c: MonthClose) -> some View {
        let value = Money.format(abs(c.moved), privacy: .income)
        let title: String = switch (c.choice, c.moved > 0) {
        case (.nextMonth, true): L10n.t("%@ added to this month", value)
        case (.nextMonth, false): L10n.t("%@ taken from this month", value)
        case (_, true): L10n.t("%@ added to %@", value, goalName(c.goalID))
        case (_, false): L10n.t("%@ taken from %@", value, goalName(c.goalID))
        }
        return HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.scaled(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.onBrand)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.brand, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.scaled(size: 15, weight: .bold)).lineLimit(2)
                Text((c.amount > 0 ? L10n.t("Left from %@", DateText.period(previous)) : L10n.t("Over in %@", DateText.period(previous)))
                     + (c.automatic ? " · " + L10n.t("as set in Settings") : ""))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer(minLength: 8)
            Button(L10n.t("Undo")) {
                withAnimation(.snappy) { MonthEnd.undo(c, context: context) }
            }
            .font(.scaled(size: 14, weight: .bold))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Theme.Colors.canvas, in: Capsule())
            .accessibilityIdentifier("monthend.undo")
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct GoalPick: Identifiable {
    let id = UUID()
    let amount: Centimes
    let goals: [SavingsGoal]
}

/// Pick the goal for last month's money (or the goal to take the overspend from), when there are several.
struct MonthEndGoalSheet: View {
    let amount: Centimes
    let goals: [SavingsGoal]
    let saved: [UUID: Centimes]
    let onPick: (SavingsGoal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?

    private var adding: Bool { amount > 0 }

    private func change(_ g: SavingsGoal) -> Centimes {
        adding ? amount : -min(-amount, saved[g.id] ?? 0)
    }

    var body: some View {
        let chosen = goals.first { $0.id == (selected ?? goals.first?.id) }
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(adding ? L10n.t("Add %@ to savings", Money.format(amount, privacy: .income))
                            : L10n.t("Take %@ from savings", Money.format(-amount, privacy: .income)))
                    .font(.scaled(size: 22, weight: .heavy))
                Text(L10n.t("Pick a goal")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(goals) { g in row(g, isOn: g.id == chosen?.id) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            if let chosen {
                Button {
                    onPick(chosen)
                } label: {
                    Text(adding ? L10n.t("Add to %@", chosen.name) : L10n.t("Take from %@", chosen.name))
                        .font(.scaled(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.onBrand)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.Colors.brand, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("monthend.pick")
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ g: SavingsGoal, isOn: Bool) -> some View {
        let now = saved[g.id] ?? 0
        let after = now + change(g)
        return Button {
            withAnimation(.snappy) { selected = g.id }
        } label: {
            HStack(spacing: 12) {
                IconCircle(symbol: g.symbol, size: 42, fill: Theme.Colors.canvas)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(g.name).font(.scaled(size: 15, weight: .bold)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(g.target > 0 ? L10n.t("%@ of %@", Money.format(now, symbol: false, privacy: .income), Money.format(g.target, privacy: .income))
                                          : Money.format(now, privacy: .income))
                            .font(.scaled(size: 14, weight: .semibold))
                    }
                    if g.target > 0 {
                        ProgressPill(value: GoalMath.progress(saved: now, target: g.target), height: 5)
                    }
                    Text(g.target > 0
                         ? L10n.t("After: %@ · %d%%", Money.format(after, privacy: .income), Int((GoalMath.progress(saved: after, target: g.target) * 100).rounded()))
                         : L10n.t("After: %@", Money.format(after, privacy: .income)))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
            }
            .padding(12)
            .background(isOn ? Theme.Colors.brandTint : Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isOn ? Theme.Colors.ink : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Insights: how the last months ended and where the money went.
struct PastMonthsSection: View {
    let results: [MonthResult]
    let goalName: (UUID?) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L10n.t("Past months"))
            ForEach(results, id: \.period) { r in
                HStack(alignment: .firstTextBaseline) {
                    Text(DateText.period(r.period)).font(.scaled(size: 15, weight: .medium))
                    Spacer(minLength: 12)
                    Text(text(r))
                        .font(.scaled(size: 15, weight: .bold))
                        .foregroundStyle(r.left > 0 ? Theme.Colors.positive : Theme.Colors.ink)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                if r.period != results.last?.period { Divider().overlay(Theme.Colors.line) }
            }
        }
    }

    private func text(_ r: MonthResult) -> String {
        let over = Money.format(-r.left, privacy: .income)
        if let c = r.close, c.moved != 0 {
            let moved = Money.format(c.moved, sign: true, privacy: .income)
            switch (c.choice, c.moved > 0) {
            case (.nextMonth, true): return L10n.t("%@ to next month", moved)
            case (.nextMonth, false): return L10n.t("%@ over · taken from next month", over)
            case (_, true): return L10n.t("%@ to %@", moved, goalName(c.goalID))
            case (_, false): return L10n.t("%@ over · from %@", over, goalName(c.goalID))
            }
        }
        if r.left > 0 { return L10n.t("%@ left", Money.format(r.left, privacy: .income)) }
        if r.left < 0 { return L10n.t("%@ over", over) }
        return L10n.t("All spent")
    }
}
