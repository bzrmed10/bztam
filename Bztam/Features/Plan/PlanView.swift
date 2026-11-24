import SwiftData
import SwiftUI

/// The Plan tab: everything you set up ahead (budgets, goals, what comes every month, dart, friends),
/// so Settings only holds settings.
struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }) private var categories: [BudgetCategory]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.order) private var goals: [SavingsGoal]
    @Query private var moves: [GoalMove]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive }) private var rules: [RecurringRule]
    @Query(sort: \Dart.createdAt) private var darts: [Dart]
    @Query private var friends: [Friend]
    // Watched so friend balances refresh.
    @Query private var shares: [SplitShare]

    @State private var showCategories = false
    @State private var showGoals = false
    @State private var openGoalID: UUID?
    @State private var newGoal = false
    @State private var showRecurring = false
    @State private var showDart = LaunchOptions.openScreen == "dart"
    @State private var showFriends = false
    @State private var showSetup = false

    var body: some View {
        let settings = settingsRows.first
        let income = settings?.expectedIncome ?? 0
        let planned = categories.reduce(0) { $0 + $1.budget }
        let values = GoalMove.values(moves)
        let balances = SplitActions.balances(context: context)
        let owed = balances.reduce(0) { $0 + $1.owesYou }
        let owe = balances.reduce(0) { $0 + $1.youOwe }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle(text: L10n.t("Plan"))

                    Button { showCategories = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L10n.t("Budgets")).font(.bzBodyStrong)
                                Spacer()
                                Text(L10n.t("Edit")).font(.scaled(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.link)
                            }
                            (Text(Money.format(planned, symbol: false, privacy: .income)).font(.scaled(size: 28, weight: .heavy))
                             + Text(" " + (income > 0 ? L10n.t("of %@ planned", Money.format(income, privacy: .income)) : Money.currencySymbol))
                                .font(.scaled(size: 15, weight: .semibold)).foregroundColor(Theme.Colors.inkMuted))
                            if income > 0 {
                                ProgressPill(value: min(1, Double(planned) / Double(max(1, income))), height: 8)
                            }
                            Text(income > planned
                                 ? L10n.t("%d categories · %@ without a budget", categories.count, Money.format(income - planned, privacy: .income))
                                 : L10n.t("%d categories", categories.count))
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(Theme.Colors.ink)
                    .accessibilityIdentifier("plan.budgets")

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SectionTitle(text: L10n.t("Savings goals"))
                            Spacer()
                            Button(goals.isEmpty ? L10n.t("New goal") : L10n.t("See all")) {
                                if goals.isEmpty { newGoal = true } else { openGoalID = nil; showGoals = true }
                            }
                            .font(.scaled(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.link)
                            .accessibilityIdentifier("plan.goals")
                        }
                        if goals.isEmpty {
                            Text(L10n.t("A trip, Eid, a new phone. Put money aside and watch it grow."))
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        ForEach(goals.prefix(3)) { g in
                            Button {
                                openGoalID = g.id
                                showGoals = true
                            } label: {
                                GoalRow(goal: g, saved: GoalMath.saved(g.id, in: values))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        SectionTitle(text: L10n.t("More"))
                        link("square.grid.2x2", L10n.t("Categories"), L10n.t("Add, rename, reorder or hide categories"),
                             value: String(categories.count), id: "plan.categories") { showCategories = true }
                        link("arrow.triangle.2.circlepath", L10n.t("Every month"),
                             rules.isEmpty ? L10n.t("Rent, salary, subscriptions") : rules.prefix(3).map(\.displayTitle).joined(separator: ", "),
                             value: rules.isEmpty ? nil : L10n.t("%d active", rules.count), id: "plan.recurring") { showRecurring = true }
                        link("person.3", L10n.t("Dart"),
                             darts.isEmpty ? L10n.t("Track your dart (tontine)") : darts.map(\.name).joined(separator: ", "),
                             id: "plan.dart") { showDart = true }
                        link("person.2", L10n.t("Friends"),
                             friends.isEmpty ? L10n.t("Split bills with friends")
                                : owed > 0 ? L10n.t("%@ owed to you", Money.format(owed))
                                : owe > 0 ? L10n.t("You owe %@", Money.format(owe)) : L10n.t("All settled"),
                             id: "plan.friends") { showFriends = true }
                        link("wand.and.stars", L10n.t("Plan my month again"), L10n.t("Income, bills and a suggested plan"),
                             id: "plan.again") { showSetup = true }
                    }

                    Color.clear.frame(height: Theme.Size.tabBarSpace)
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)
            }
            .statusBarFade()
            .background(Theme.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
        .foregroundStyle(Theme.Colors.ink)
        .sheet(isPresented: $showCategories) { CategoriesEditorView(income: income) }
        .sheet(isPresented: $showGoals, onDismiss: { openGoalID = nil }) { GoalsView(openGoalID: openGoalID) }
        .sheet(isPresented: $newGoal) { GoalEditSheet(goal: nil, nextOrder: 0) }
        .sheet(isPresented: $showRecurring) { RecurringListView() }
        .sheet(isPresented: $showDart) { DartListView() }
        .sheet(isPresented: $showFriends) { FriendsView() }
        .fullScreenCover(isPresented: $showSetup) { OnboardingView(setupMode: true) }
    }

    private func link(_ symbol: String, _ title: String, _ detail: String, value: String? = nil, id: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.m) {
                IconCircle(symbol: symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bzBodyStrong)
                    Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let value { Text(value).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted) }
                Image(systemName: "chevron.forward")
                    .font(.scaled(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkMuted.opacity(0.6))
            }
            .frame(minHeight: Theme.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
