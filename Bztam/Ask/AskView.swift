import SwiftData
import SwiftUI

/// Ask Bztam: questions about your money, answered on the phone. Numbers always come from `AskEngine`.
struct AskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [Entry]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.order) private var goals: [SavingsGoal]
    @Query private var goalMoves: [GoalMove]
    @Query(sort: \Dart.createdAt) private var darts: [Dart]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive }) private var rules: [RecurringRule]
    @State private var store = Store.shared
    @State private var freeUsed = AskAllowance.used()
    @State private var question = ""
    @State private var turns: [AskTurn] = []
    @State private var thinking = false
    @State private var speech = SpeechInput()
    @FocusState private var focused: Bool

    private var payday: Int { settingsRows.first?.payday ?? 1 }

    private var context: AskContext {
        let period = BudgetCalculator.period(containing: .now, payday: payday)
        let balances = SplitActions.balances(context: modelContext)
        let moves = GoalMove.values(goalMoves)
        let now = Date.now
        let askDarts = darts.map { d -> AskDart in
            let plan = d.plan
            let upcoming = plan.upcomingRounds(after: now, limit: plan.count).map { r in
                let who = plan.collector(ofRound: r.round)
                return (date: r.date, collector: d.displayName(who), isMe: who == d.meIndex)
            }
            let mine = upcoming.first(where: \.isMe)?.date
            return AskDart(name: d.name, amount: d.amount, pot: plan.pot, upcoming: Array(upcoming.prefix(3)), myTurn: mine)
        }
        let askBills = rules.filter { $0.kind == .expense }.flatMap { rule in
            RecurringEngine.occurrences(frequency: rule.frequency, start: rule.startDate, after: rule.lastGenerated, through: period.end, limit: 3)
                .filter { $0 >= period.start }
                .map { AskBill(name: rule.merchant.isEmpty ? (rule.category?.displayName ?? L10n.t("Bill")) : rule.merchant,
                               amount: rule.amount, date: $0, categoryID: rule.category?.id) }
        }
        return AskContext(records: entries.map { EntryRecord($0) },
                          categories: categories.map { AskCategory(id: $0.id, key: $0.key, name: $0.displayName, budget: $0.budget(in: period)) },
                          payday: payday,
                          owedToMe: balances.map { AskDebt(name: $0.name, amount: $0.owesYou) },
                          iOwe: balances.map { AskDebt(name: $0.name, amount: $0.youOwe) },
                          goals: goals.map { AskGoal(id: $0.id, name: $0.name, saved: GoalMath.saved($0.id, in: moves), target: $0.target,
                                                     deadline: $0.deadline) },
                          darts: askDarts, bills: askBills)
    }

    private var suggestions: [String] {
        var list = [L10n.t("How much did I spend this month?"), L10n.t("How much is left?")]
        if let food = categories.first(where: { $0.key == "food" }) {
            list.append(L10n.t("How much on %@ last month?", food.displayName))
        }
        if let shop = context.merchants.first {
            list.append(L10n.t("How many times at %@ this month?", shop.name))
        }
        list.append(L10n.t("Did I spend more than last month?"))
        list.append(L10n.t("Will I finish the month?"))
        if let goal = goals.first { list.append(L10n.t("How much have I saved for %@?", goal.name)) }
        list.append(L10n.t("Where did most of my money go?"))
        if !SplitActions.balances(context: modelContext).filter({ $0.owesYou > 0 || $0.youOwe > 0 }).isEmpty {
            list.insert(L10n.t("Who owes me?"), at: 2)
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            ScreenTitle(text: L10n.t("Ask Bztam"))
                            Label(L10n.t("Answered on your iPhone. Your data stays on it."), systemImage: "lock")
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                            if !store.isPlus {
                                Button { PlusPresenter.show(.ask) } label: {
                                    Text(freeLeft == 0 ? L10n.t("No free questions left this month · Get Plus")
                                         : freeLeft == 1 ? L10n.t("1 free question left this month")
                                         : L10n.t("%d free questions left this month", freeLeft))
                                        .font(.scaled(size: 13, weight: .bold))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Theme.Colors.brandTint, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("ask.freeLeft")
                            }
                        }
                        if turns.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.t("Try")).font(.scaled(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                                ForEach(suggestions, id: \.self) { s in
                                    Button { submit(s) } label: {
                                        HStack {
                                            Text(s).font(.scaled(size: 15, weight: .semibold)).multilineTextAlignment(.leading)
                                            Spacer(minLength: 8)
                                            Image(systemName: "arrow.up.right").font(.scaled(size: 13, weight: .bold))
                                                .foregroundStyle(Theme.Colors.inkMuted)
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        ForEach(turns) { turn in
                            AskTurnView(turn: turn, categoryName: name, onSuggestion: { submit($0) }).id(turn.id)
                        }
                        if thinking {
                            ProgressView().tint(Theme.Colors.ink).padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: turns.count) { _, _ in
                    if let last = turns.last { withAnimation { proxy.scrollTo(last.id, anchor: .top) } }
                }
            }

            inputBar
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .onChange(of: speech.transcript) { _, text in question = text }
        .onChange(of: speech.isListening) { was, now in
            if was && !now && !question.trimmingCharacters(in: .whitespaces).isEmpty { submit(question) }
        }
        .onDisappear { speech.stop() }
        .alert(L10n.t("Microphone or speech access is off"), isPresented: Bindable(speech).denied) {
            Button(L10n.t("OK"), role: .cancel) {}
        }
        .task {
            // The test runner escapes spaces in launch arguments ("ce\\ mois").
            if let q = UserDefaults.standard.string(forKey: "askQuestion"), LaunchOptions.demoData {
                submit(q.replacingOccurrences(of: "\\", with: ""))
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(L10n.t("Ask about your money"), text: $question)
                .font(.bzBody)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { submit(question) }
                .accessibilityIdentifier("ask.field")
            Button { Task { await speech.toggle() } } label: {
                Image(systemName: speech.isListening ? "stop.fill" : "mic")
                    .symbolEffect(.pulse, isActive: speech.isListening)
                    .font(.scaled(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(speech.isListening ? Theme.Colors.onBrand : Theme.Colors.ink)
                    .background(speech.isListening ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speech.isListening ? L10n.t("Stop") : L10n.t("Say it"))
            Button { submit(question) } label: {
                Image(systemName: "arrow.up")
                    .font(.scaled(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(Theme.Colors.onBrand)
                    .background(Theme.Colors.brand, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            .accessibilityLabel(L10n.t("Ask"))
        }
        .foregroundStyle(Theme.Colors.ink)
        .padding(.leading, 18).padding(.trailing, 6).padding(.vertical, 6)
        .background(Theme.Colors.surface, in: Capsule())
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
    }

    private func name(_ id: UUID?) -> String {
        categories.first { $0.id == id }?.displayName ?? L10n.t("Other")
    }

    private var freeLeft: Int { max(0, AskAllowance.free - freeUsed) }

    private func submit(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        // Free users: 3 questions a month; the next one opens Bztam Plus.
        if !store.isPlus && freeLeft == 0 {
            PlusPresenter.show(.ask)
            return
        }
        question = ""
        thinking = true
        let ctx = context
        let previous = turns.last(where: { $0.query != nil })?.query
        Task {
            let query = await AskAI.understand(q, context: ctx, previous: previous)
            var answer = query.map { AskEngine.answer($0, context: ctx) } ?? AskEngine.help()
            if query == nil { answer.suggestions = AskParser.suggestions(for: q, context: ctx) }
            turns.append(AskTurn(question: q, answer: answer, query: query))
            // Only answered questions count.
            if query != nil && !store.isPlus { freeUsed = AskAllowance.use() }
            thinking = false
        }
    }
}

struct AskTurn: Identifiable {
    let id = UUID()
    let question: String
    let answer: AskAnswer
    var query: AskQuery? = nil
}

/// Free users get a few questions each calendar month (counted on this iPhone).
enum AskAllowance {
    static let free = 3
    private static var key: String {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return "askUsed-\(c.year ?? 0)-\(c.month ?? 0)"
    }
    static func used() -> Int { UserDefaults.standard.integer(forKey: key) }
    @discardableResult
    static func use() -> Int {
        let n = used() + 1
        UserDefaults.standard.set(n, forKey: key)
        return n
    }
}

private struct AskTurnView: View {
    let turn: AskTurn
    let categoryName: (UUID?) -> String
    var onSuggestion: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 48)
                Text(turn.question)
                    .font(.scaled(size: 15, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18))
            }
            VStack(alignment: .leading, spacing: 10) {
                if let amount = turn.answer.amount {
                    Text(Money.format(amount, privacy: turn.answer.sensitive ? .income : .any))
                        .font(.scaled(size: 34, weight: .heavy).monospacedDigit())
                        .tracking(-0.8)
                        .foregroundStyle(amount < 0 ? Theme.Colors.negative : Theme.Colors.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("ask.amount")
                }
                Text(turn.answer.sentence).font(.bzBody)
                if !turn.answer.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(turn.answer.suggestions, id: \.self) { s in
                            Button { onSuggestion(s) } label: {
                                HStack(spacing: 6) {
                                    Text(s).font(.scaled(size: 14, weight: .semibold)).multilineTextAlignment(.leading)
                                    Image(systemName: "arrow.up.right").font(.scaled(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Theme.Colors.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !turn.answer.understood.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(turn.answer.understood, id: \.self) { TagPill(text: $0) }
                    }
                }
                if !turn.answer.entries.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(turn.answer.entries.enumerated()), id: \.offset) { item in
                            let e = item.element
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title(e)).font(.scaled(size: 15, weight: .semibold)).lineLimit(1)
                                    Text(DateText.day(e.date)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                }
                                Spacer()
                                Text(Money.format(e.amount, sign: e.kind == .income, privacy: e.kind == .income ? .income : .any))
                                    .font(.bzAmount)
                                    .foregroundStyle(e.kind == .income ? Theme.Colors.positive : Theme.Colors.ink)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Colors.line, lineWidth: 1))
        }
    }

    private func title(_ e: EntryRecord) -> String {
        let m = e.merchant.trimmingCharacters(in: .whitespaces)
        if !m.isEmpty { return m }
        return e.kind == .income ? L10n.t("Money in") : categoryName(e.categoryID)
    }
}

/// The "Ask Bztam" field at the top of Insights.
struct AskField: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.scaled(size: 16, weight: .semibold))
                Text(L10n.t("Ask about your money")).font(.scaled(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                Spacer()
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(Theme.Colors.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("insights.ask")
    }
}
