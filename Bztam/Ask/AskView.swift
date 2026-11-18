import SwiftData
import SwiftUI

/// Ask Bztam: questions about your money, answered on the phone. Numbers always come from `AskEngine`.
struct AskView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @State private var question = ""
    @State private var turns: [AskTurn] = []
    @State private var thinking = false
    @State private var speech = SpeechInput()
    @FocusState private var focused: Bool

    private var payday: Int { settingsRows.first?.payday ?? 1 }

    private var context: AskContext {
        let period = BudgetCalculator.period(containing: .now, payday: payday)
        return AskContext(records: entries.map { EntryRecord($0) },
                          categories: categories.map { AskCategory(id: $0.id, key: $0.key, name: $0.displayName, budget: $0.budget(in: period)) },
                          payday: payday)
    }

    private var suggestions: [String] {
        var list = [L10n.t("How much did I spend this month?"), L10n.t("How much is left?")]
        if let food = categories.first(where: { $0.key == "food" }) {
            list.append(L10n.t("How much on %@ last month?", food.displayName))
        }
        if let shop = context.merchants.first {
            list.append(L10n.t("How many times at %@ this month?", shop.name))
        }
        list.append(L10n.t("Where did most of my money go?"))
        list.append(L10n.t("Biggest expense this year?"))
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
                        }
                        if turns.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.t("Try")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                                ForEach(suggestions, id: \.self) { s in
                                    Button { submit(s) } label: {
                                        HStack {
                                            Text(s).font(.system(size: 15, weight: .semibold)).multilineTextAlignment(.leading)
                                            Spacer(minLength: 8)
                                            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold))
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
                            AskTurnView(turn: turn, categoryName: name).id(turn.id)
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
            if let q = UserDefaults.standard.string(forKey: "askQuestion"), LaunchOptions.demoData { submit(q) }
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
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(speech.isListening ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speech.isListening ? L10n.t("Stop") : L10n.t("Say it"))
            Button { submit(question) } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
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

    private func submit(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        question = ""
        thinking = true
        let ctx = context
        Task {
            let query = await AskAI.understand(q, context: ctx)
            let answer = query.map { AskEngine.answer($0, context: ctx) } ?? AskEngine.help()
            turns.append(AskTurn(question: q, answer: answer))
            thinking = false
        }
    }
}

struct AskTurn: Identifiable {
    let id = UUID()
    let question: String
    let answer: AskAnswer
}

private struct AskTurnView: View {
    let turn: AskTurn
    let categoryName: (UUID?) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 48)
                Text(turn.question)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18))
            }
            VStack(alignment: .leading, spacing: 10) {
                if let amount = turn.answer.amount {
                    Text(Money.format(amount))
                        .font(.system(size: 34, weight: .heavy).monospacedDigit())
                        .tracking(-0.8)
                        .foregroundStyle(amount < 0 ? Theme.Colors.negative : Theme.Colors.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("ask.amount")
                }
                Text(turn.answer.sentence).font(.bzBody)
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
                                    Text(title(e)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                    Text(DateText.day(e.date)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                }
                                Spacer()
                                Text(Money.format(e.amount, sign: e.kind == .income))
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
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.line, lineWidth: 1))
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
                Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold))
                Text(L10n.t("Ask about your money")).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
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
