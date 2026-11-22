import SwiftData
import SwiftUI
import UIKit

/// Settings → Savings goals, and Home's goals list: every goal with its progress.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.order) private var goals: [SavingsGoal]
    @Query private var moves: [GoalMove]
    @State private var creating = false
    var openGoalID: UUID?
    @State private var path = NavigationPath()

    var body: some View {
        let values = GoalMove.values(moves)
        let total = goals.reduce(0) { $0 + GoalMath.saved($1.id, in: values) }
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                        Spacer()
                        Button { creating = true } label: {
                            Label(L10n.t("New goal"), systemImage: "plus")
                                .font(.scaled(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.onBrand)
                                .padding(.horizontal, 16).frame(height: 40)
                                .background(Theme.Colors.brand, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("goals.new")
                    }
                    ScreenTitle(text: L10n.t("Savings goals"))
                    if goals.isEmpty {
                        EmptyState(symbol: "leaf", title: L10n.t("Save for something"),
                                   message: L10n.t("A trip, Eid, a new phone. Put money aside and watch it grow."),
                                   actionTitle: L10n.t("New goal")) { creating = true }
                            .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("Saved in total")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                            Text(Money.format(total, privacy: .income)).font(.scaled(size: 34, weight: .heavy)).tracking(-0.8)
                        }
                        VStack(spacing: 4) {
                            ForEach(goals) { g in
                                NavigationLink(value: g) {
                                    GoalRow(goal: g, saved: GoalMath.saved(g.id, in: values))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(L10n.t("Money you put aside lowers what's left to spend, but it is saved, not spent."))
                            .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SavingsGoal.self) { GoalDetailView(goal: $0) }
        }
        .foregroundStyle(Theme.Colors.ink)
        .sheet(isPresented: $creating) { GoalEditSheet(goal: nil, nextOrder: (goals.map(\.order).max() ?? 0) + 1) }
        .onAppear {
            if let id = openGoalID, let g = goals.first(where: { $0.id == id }) { path.append(g) }
        }
    }
}

struct GoalRow: View {
    let goal: SavingsGoal
    let saved: Centimes

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: goal.symbol, fill: goal.reachedAt != nil ? Theme.Colors.brand : Theme.Colors.surface,
                       tint: goal.reachedAt != nil ? Theme.Colors.onBrand : Theme.Colors.ink)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.name).font(.bzBodyStrong).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Money.format(saved, privacy: .income)).font(.bzAmount)
                }
                HStack {
                    if goal.target > 0 {
                        Text(L10n.t("of %@", Money.format(goal.target, privacy: .income)))
                    } else {
                        Text(L10n.t("No target"))
                    }
                    Spacer(minLength: 8)
                    if goal.reachedAt != nil {
                        Text(L10n.t("Reached")).foregroundStyle(Theme.Colors.positive)
                    } else if let d = goal.deadline {
                        Text(L10n.t("By %@", DateText.month(d)))
                    }
                }
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                if goal.target > 0 {
                    ProgressPill(value: GoalMath.progress(saved: saved, target: goal.target), height: 4,
                                 fill: goal.reachedAt != nil ? Theme.Colors.positive : Theme.Colors.ink)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One goal: what's saved, the plan, put aside or take out, and the history.
struct GoalDetailView: View {
    @Bindable var goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \GoalMove.date, order: .reverse) private var allMoves: [GoalMove]
    @State private var moving: GoalMoveSheet.Mode?
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        let moves = allMoves.filter { $0.goalID == goal.id }
        let saved = GoalMath.saved(goal.id, in: GoalMove.values(moves))
        let suggestion = GoalMath.suggestedMonthly(target: goal.target, saved: saved, deadline: goal.deadline)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    CircleIconButton(symbol: "chevron.backward", label: L10n.t("Back")) { dismiss() }
                    Spacer()
                    Button(L10n.t("Edit")) { editing = true }
                        .font(.scaled(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Theme.Colors.surface, in: Capsule())
                        .buttonStyle(.plain)
                }
                HStack(spacing: 12) {
                    IconCircle(symbol: goal.symbol, size: 52)
                    Text(goal.name).font(.bzTitleXL).tracking(-0.6).lineLimit(2)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(Money.format(saved, privacy: .income))
                        .font(.bzAmountHero).tracking(-1.2)
                        .contentTransition(.numericText(value: Double(saved)))
                        .animation(.snappy, value: saved)
                    if goal.target > 0 {
                        Text(goal.reachedAt != nil ? L10n.t("Goal reached") : L10n.t("%@ to go", Money.format(max(0, goal.target - saved), privacy: .income)))
                            .font(.scaled(size: 15, weight: .semibold))
                            .foregroundStyle(goal.reachedAt != nil ? Theme.Colors.positive : Theme.Colors.inkMuted)
                        ProgressPill(value: GoalMath.progress(saved: saved, target: goal.target))
                            .padding(.top, 4)
                    }
                }
                if goal.deadline != nil || goal.monthlyPlan > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        if let d = goal.deadline {
                            Label(L10n.t("By %@", DateText.month(d)), systemImage: "calendar")
                        }
                        if suggestion > 0 {
                            Label(L10n.t("Put aside %@ a month to make it", Money.format(suggestion)), systemImage: "arrow.down.to.line")
                        } else if goal.monthlyPlan > 0 {
                            Label(L10n.t("Plan: %@ a month", Money.format(goal.monthlyPlan)), systemImage: "arrow.down.to.line")
                        }
                    }
                    .font(.scaled(size: 15, weight: .medium))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                HStack(spacing: 10) {
                    Button(L10n.t("Put aside")) { moving = .putAside }
                        .buttonStyle(.pillPrimary)
                        .accessibilityIdentifier("goal.putAside")
                    Button(L10n.t("Take out")) { moving = .takeOut }
                        .buttonStyle(.pillSecondary)
                        .disabled(saved <= 0)
                        .opacity(saved <= 0 ? 0.5 : 1)
                }
                if !moves.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle(text: L10n.t("History"))
                        ForEach(moves) { m in
                            HStack {
                                Image(systemName: m.amount >= 0 ? "arrow.down.to.line" : "arrow.up.forward")
                                    .frame(width: 32).foregroundStyle(Theme.Colors.inkMuted)
                                Text(m.amount >= 0 ? L10n.t("Put aside") : L10n.t("Taken out")).font(.bzBodyStrong)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Money.format(m.amount, sign: true, privacy: .income)).font(.bzAmount)
                                        .foregroundStyle(m.amount >= 0 ? Theme.Colors.positive : Theme.Colors.ink)
                                    Text(DateText.day(m.date)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                }
                            }
                            .padding(.vertical, 8)
                            .contextMenu {
                                Button(L10n.t("Delete"), role: .destructive) { context.delete(m); try? context.save() }
                            }
                        }
                    }
                }
                Button(L10n.t("Delete goal"), role: .destructive) { confirmDelete = true }
                    .font(.scaled(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.negative)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $moving) { mode in
            GoalMoveSheet(goal: goal, mode: mode, saved: saved,
                          suggested: mode == .putAside ? (suggestion > 0 ? suggestion : goal.monthlyPlan) : 0)
        }
        .sheet(isPresented: $editing) { GoalEditSheet(goal: goal) }
        .confirmationDialog(L10n.t("Delete this goal?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("Delete goal"), role: .destructive) {
                for m in moves { context.delete(m) }
                context.delete(goal)
                try? context.save()
                dismiss()
            }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("The money you put aside goes back to what's left to spend."))
        }
    }
}

/// New goal or edit: name, icon, target, date and monthly plan, all optional except the name.
struct GoalEditSheet: View {
    let goal: SavingsGoal?
    var nextOrder = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var symbol = "leaf"
    @State private var target: Centimes = 0
    @State private var hasDate = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var monthly: Centimes = 0
    @State private var loaded = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        let suggestion = GoalMath.suggestedMonthly(target: target, saved: 0, deadline: hasDate ? deadline : nil)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: goal == nil ? L10n.t("New goal") : L10n.t("Edit goal"))
                field(L10n.t("What are you saving for?")) {
                    TextField(L10n.t("Summer trip, Eid, new phone…"), text: $name)
                        .font(.bzBodyStrong)
                        .submitLabel(.done)
                        .accessibilityIdentifier("goal.name")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(GoalMath.symbols, id: \.self) { s in
                        Button { symbol = s } label: {
                            Image(systemName: s)
                                .font(.scaled(size: 18, weight: .medium))
                                .foregroundStyle(s == symbol ? Theme.Colors.onInk : Theme.Colors.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(s == symbol ? Theme.Colors.ink : Theme.Colors.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(s == symbol ? .isSelected : [])
                    }
                }
                HStack {
                    Text(L10n.t("Target")).font(.bzBodyStrong)
                    Text(L10n.t("optional")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    Spacer()
                    MoneyTextField(value: $target, width: 150, accessibility: L10n.t("Target"))
                }
                Toggle(isOn: $hasDate.animation(.snappy)) {
                    Text(L10n.t("By a date")).font(.bzBodyStrong)
                }
                .tint(Theme.Colors.positive)
                if hasDate {
                    DatePicker(L10n.t("Date"), selection: $deadline, in: Date.now..., displayedComponents: .date)
                        .font(.bzBody)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("Each month")).font(.bzBodyStrong)
                        if suggestion > 0 {
                            Text(L10n.t("%@ a month gets you there", Money.format(suggestion)))
                                .font(.bzCaption).foregroundStyle(Theme.Colors.positive)
                        }
                    }
                    Spacer()
                    MoneyTextField(value: $monthly, width: 150, accessibility: L10n.t("Each month"))
                }
                Button(L10n.t("Save")) { save() }
                    .buttonStyle(.pillPrimary)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .accessibilityIdentifier("goal.save")
            }
            .padding(Theme.Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .keyboardDoneButton()
        .presentationDetents([.large])
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let g = goal {
                name = g.name; symbol = g.symbol; target = g.target; monthly = g.monthlyPlan
                if let d = g.deadline { hasDate = true; deadline = d }
            }
        }
    }

    private func field<Content: View>(_ caption: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.scaled(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func save() {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = monthly > 0 ? monthly : GoalMath.suggestedMonthly(target: target, saved: 0, deadline: hasDate ? deadline : nil)
        if let g = goal {
            g.name = text; g.symbol = symbol; g.target = target; g.deadline = hasDate ? deadline : nil; g.monthlyPlan = plan
            if target == 0 || target > 0 && g.reachedAt != nil { g.reachedAt = nil }
        } else {
            context.insert(SavingsGoal(name: text, symbol: symbol, target: target, deadline: hasDate ? deadline : nil,
                                       monthlyPlan: plan, order: nextOrder))
        }
        try? context.save()
        dismiss()
    }
}

/// Put money aside, or take some out, with the keypad.
struct GoalMoveSheet: View {
    enum Mode: String, Identifiable { case putAside, takeOut; var id: String { rawValue } }

    let goal: SavingsGoal
    let mode: Mode
    let saved: Centimes
    var suggested: Centimes = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @State private var amount = AmountInput()

    private var valid: Bool { amount.centimes > 0 && (mode == .putAside || amount.centimes <= saved) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            ScreenTitle(text: mode == .putAside ? L10n.t("Put aside for %@", goal.name) : L10n.t("Take out of %@", goal.name))
            Text(mode == .putAside
                 ? L10n.t("It comes off what's left to spend this month.")
                 : L10n.t("It goes back to what's left to spend. %@ saved.", Money.format(saved, privacy: .income)))
                .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            AmountField(caption: L10n.t("Amount"), text: amount.display())
            if mode == .takeOut && amount.centimes > saved {
                Text(L10n.t("That's more than you saved.")).font(.bzCaption).foregroundStyle(Theme.Colors.negative)
            }
            Spacer(minLength: 0)
            KeypadView { amount.press($0) }
            Button(mode == .putAside ? L10n.t("Put aside") : L10n.t("Take out")) { save() }
                .buttonStyle(.pillPrimary)
                .disabled(!valid)
                .opacity(valid ? 1 : 0.5)
                .accessibilityIdentifier("goal.moveSave")
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .onAppear { if suggested > 0 { amount = AmountInput(centimes: suggested) } }
    }

    private func save() {
        let value = mode == .putAside ? amount.centimes : -amount.centimes
        let move = GoalMove(goalID: goal.id, amount: value)
        context.insert(move)
        let total = saved + value
        let wasReached = goal.reachedAt != nil
        if goal.target > 0 {
            goal.reachedAt = total >= goal.target ? (goal.reachedAt ?? .now) : nil
        }
        try? context.save()
        WidgetSync.update(context: context)
        let ctx = context
        let g = goal
        let message = !wasReached && goal.reachedAt != nil
            ? L10n.t("You reached %@!", goal.name)
            : mode == .putAside ? L10n.t("Put aside %@", Money.format(amount.centimes)) : L10n.t("Took out %@", Money.format(amount.centimes))
        undo?.show(message, success: true) {
            ctx.delete(move)
            if !wasReached { g.reachedAt = nil }
            try? ctx.save()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Home "For you": "Put 500 DH aside for Summer trip".
struct GoalCard: View {
    let goal: SavingsGoal
    let amount: Centimes
    let onPutAside: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.symbol)
                .font(.scaled(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Theme.Colors.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("Put %@ aside", Money.format(amount))).font(.scaled(size: 15, weight: .semibold)).lineLimit(1)
                Text(L10n.t("For %@", goal.name)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(L10n.t("Put aside"), action: onPutAside)
                .font(.scaled(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.onBrand)
                .padding(.horizontal, 14).frame(height: 36)
                .background(Theme.Colors.brand, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(12)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}
