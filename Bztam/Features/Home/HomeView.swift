import SwiftData
import SwiftUI
import UIKit

/// Home: what's left this period, quick actions and the categories.
struct HomeView: View {
    let onAdd: (AddRequest) -> Void
    let onScan: (ScanKind) -> Void
    var suggestion: UIImage?
    var onSuggestionAdd: () -> Void = {}
    var onSuggestionDismiss: () -> Void = {}
    var subscription: SubscriptionCandidate?
    var onSubscriptionYes: (SubscriptionCandidate) -> Void = { _ in }
    var onSubscriptionDismiss: (SubscriptionCandidate) -> Void = { _ in }

    @Query private var entries: [Entry]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @Query private var darts: [Dart]
    @AppStorage(Money.hiddenKey) private var amountsHidden = false
    @Namespace private var zoom
    // Watched so the friends card refreshes after a split or a payback.
    @Query private var splitShares: [SplitShare]
    @State private var showFriends = LaunchOptions.openScreen == "friends"
    @State private var splitDemo: SplitDraft? = LaunchOptions.openScreen == "split"
        ? SplitDraft(amount: 60_000, merchant: "Café Clock") : nil
    @Environment(\.modelContext) private var context
    @State private var offset = 0
    @State private var path = NavigationPath()

    private var payday: Int { settingsRows.first?.payday ?? 1 }

    private var period: BudgetPeriod {
        let current = BudgetCalculator.period(containing: .now, payday: payday)
        return offset == 0 ? current : BudgetCalculator.period(current, offset: offset, payday: payday)
    }

    var body: some View {
        let summary = BudgetSnapshot.summary(entries: entries, categories: categories, period: period,
                                             expectedIncome: settingsRows.first?.expectedIncome ?? 0)
        let lines = BudgetSnapshot.lines(entries: entries, categories: categories, period: period)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero(summary)
                    quickActions
                    if offset == 0 {
                        let cards = forYouCards(categories: categories)
                        ForYouRow(cards: cards)
                            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: cards.map(\.id))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionTitle(text: L10n.t("Categories"))
                            Spacer()
                            if summary.notPlanned > 0 && offset == 0 {
                                TagPill(text: L10n.t("%@ not planned", Money.format(summary.notPlanned)))
                            }
                        }
                        ForEach(lines) { line in
                            NavigationLink(value: line.category) {
                                CategoryRow(line: line)
                                    .matchedTransitionSource(id: line.category.id, in: zoom)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.l + Theme.Size.tabBarSpace)
            }
            .background(Theme.Colors.canvas)
            .statusBarFade()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFriends) { FriendsView() }
            .sheet(item: $splitDemo) { SplitSheet(draft: $0) }
            .navigationDestination(for: BudgetCategory.self) { category in
                CategoryDetailView(category: category, period: period, onAdd: onAdd)
                    .navigationTransition(.zoom(sourceID: category.id, in: zoom))
            }
            .onAppear {
                if LaunchOptions.openScreen == "category", let first = lines.first {
                    path.append(first.category)
                }
            }
        }
    }

    /// Everything that needs you now, one card at a time.
    private func forYouCards(categories: [BudgetCategory]) -> [ForYouCard] {
        var cards: [ForYouCard] = []
        if let suggestion {
            cards.append(ForYouCard(id: "screenshot", view: AnyView(
                ScreenshotSuggestionCard(image: suggestion, onAdd: onSuggestionAdd, onDismiss: onSuggestionDismiss))))
        }
        if let due = DartActions.due(darts) {
            cards.append(ForYouCard(id: "dart", view: AnyView(DartCard(dart: due.dart, collect: due.collect) {
                if due.collect {
                    DartActions.toggleReceived(due.dart, context: context)
                } else if case .round(let r) = due.dart.plan.status() {
                    DartActions.togglePaid(due.dart, member: due.dart.meIndex, round: r, context: context)
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            })))
        }
        if !splitShares.isEmpty {
            let balances = SplitActions.balances(context: context)
            let owed = balances.reduce(0) { $0 + $1.owesYou }
            let owe = balances.reduce(0) { $0 + $1.youOwe }
            if owed > 0 || owe > 0 {
                cards.append(ForYouCard(id: "friends", view: AnyView(FriendsCard(owed: owed, owe: owe) { showFriends = true })))
            }
        }
        if let subscription {
            cards.append(ForYouCard(id: "subscription", view: AnyView(
                SubscriptionCard(candidate: subscription, onYes: { onSubscriptionYes(subscription) },
                                 onDismiss: { onSubscriptionDismiss(subscription) }))))
        }
        if let warning = Advice.paceWarnings(categories: categories.map { BudgetSnapshot.value($0, period: period) },
                                             entries: BudgetSnapshot.values(entries), period: period).first,
           let category = categories.first(where: { $0.id == warning.categoryID }) {
            cards.append(ForYouCard(id: "pace", view: AnyView(
                PaceCard(text: L10n.t("At this pace, %@ runs out around %@.", category.displayName, DateText.short(warning.runOut))))))
        }
        return cards
    }

    private func hero(_ s: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(L10n.t("Left to spend") + " · " + DateText.period(period))
                    .font(.bzCaption)
                    .foregroundStyle(Theme.Colors.inkMuted)
                Spacer()
                Button { amountsHidden.toggle() } label: {
                    Image(systemName: amountsHidden ? "eye.slash" : "eye").frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.selection, trigger: amountsHidden)
                .accessibilityLabel(amountsHidden ? L10n.t("Show amounts") : L10n.t("Hide amounts"))
                .accessibilityIdentifier("home.privacy")
                Button { offset -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                }
                .accessibilityLabel(L10n.t("Previous period"))
                Button { offset += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36)
                }
                .disabled(offset >= 0)
                .opacity(offset >= 0 ? 0.3 : 1)
                .accessibilityLabel(L10n.t("Next period"))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Colors.ink)

            Text(Money.format(s.left, privacy: .income))
                .contentTransition(.numericText(value: Double(s.left)))
                .animation(.snappy, value: s.left)
                .font(.bzAmountHero)
                .tracking(-1.2)
                .foregroundStyle(s.left < 0 ? Theme.Colors.negative : Theme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("home.left")

            (Text(Money.format(s.moneyIn, sign: true, privacy: .income) + " " + L10n.t("in")).foregroundColor(Theme.Colors.positive).fontWeight(.semibold)
             + Text(" · " + Money.format(s.spent) + " " + L10n.t("spent")).foregroundColor(Theme.Colors.inkMuted))
                .font(.system(size: 15, weight: .medium))

            ProgressPill(value: s.progress)
                .padding(.top, 10)
        }
    }

    private var quickActions: some View {
        HStack(alignment: .top, spacing: 8) {
            QuickAction(title: L10n.t("Add"), symbol: "plus", highlighted: true) { onAdd(AddRequest()) }
            QuickAction(title: L10n.t("Scan"), symbol: "camera") { onScan(.camera) }
            QuickAction(title: L10n.t("Screenshot"), symbol: "photo") { onScan(.screenshot) }
            QuickAction(title: L10n.t("Money in"), symbol: "arrow.down.to.line") { onAdd(AddRequest(kind: .income)) }
        }
    }
}

private struct QuickAction: View {
    let title: String
    let symbol: String
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(highlighted ? Theme.Colors.onBrand : Theme.Colors.ink)
                    .frame(width: Theme.Size.quickAction, height: Theme.Size.quickAction)
                    .background(highlighted ? Theme.Colors.brand : Theme.Colors.surface, in: Circle())
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick.\(symbol)")
    }
}

/// A category with what's left, over or paid.
struct CategoryRow: View {
    let line: CategoryLine

    private var right: (String, Color) {
        switch line.status.state {
        case .left(let x): (Money.format(x), Theme.Colors.ink)
        case .over(let x): (Money.format(x), Theme.Colors.negative)
        case .paid: (L10n.t("Paid"), Theme.Colors.positive)
        case .noBudget: (Money.format(line.status.spent), Theme.Colors.ink)
        }
    }

    private var caption: (String, Color) {
        switch line.status.state {
        case .left: (L10n.t("left"), Theme.Colors.inkMuted)
        case .over: (L10n.t("over"), Theme.Colors.negative)
        case .paid: (Money.format(line.status.budget), Theme.Colors.inkMuted)
        case .noBudget: (L10n.t("spent"), Theme.Colors.inkMuted)
        }
    }

    private var sub: String {
        if case .noBudget = line.status.state { return L10n.t("No budget") }
        return L10n.t("%@ of %@", Money.format(line.status.spent, symbol: false), Money.format(line.status.budget))
    }

    private var barColor: Color {
        switch line.status.state {
        case .over: Theme.Colors.negative
        case .paid: Theme.Colors.positive
        default: Theme.Colors.ink
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: line.category.symbol)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(line.category.displayName).font(.bzBodyStrong).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(right.0).font(.bzAmount).foregroundStyle(right.1)
                }
                HStack {
                    Text(sub)
                    Spacer(minLength: 8)
                    Text(caption.0).foregroundStyle(caption.1)
                }
                .font(.bzCaption)
                .foregroundStyle(Theme.Colors.inkMuted)
                ProgressPill(value: line.status.progress, height: 4, fill: barColor)
                    .padding(.top, 2)
            }
            .foregroundStyle(Theme.Colors.ink)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "At this pace, Going out runs out around 18 Nov."
struct PaceCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Theme.Colors.canvas, in: Circle())
                .accessibilityHidden(true)
            Text(text).font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(12)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .accessibilityElement(children: .combine)
    }
}
