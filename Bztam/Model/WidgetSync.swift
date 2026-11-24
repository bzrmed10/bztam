import Foundation
import SwiftData
import WidgetKit

/// Writes what the widgets show and asks iOS to redraw them.
@MainActor
enum WidgetSync {
    static func update(context: ModelContext, now: Date = .now) {
        let settings = DataStore.settings(in: context)
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let categories = ((try? context.fetch(FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.order)]))) ?? [])
            .filter { !$0.isArchived }
        let period = BudgetCalculator.period(containing: now, payday: settings.payday)
        let moves = (try? context.fetch(FetchDescriptor<GoalMove>())) ?? []
        let closes = (try? context.fetch(FetchDescriptor<MonthClose>())) ?? []
        let s = BudgetSnapshot.summary(entries: entries, categories: categories, period: period, expectedIncome: settings.expectedIncome,
                                       moves: moves, closes: closes)
        let lines = BudgetSnapshot.lines(entries: entries, categories: categories, period: period)
            .filter { $0.status.budget > 0 && !$0.category.isFixed }
            .sorted { $0.status.progress > $1.status.progress }

        // Widgets sit on the Home Screen: follow privacy mode when it hides amounts on open.
        let hide = UserDefaults.standard.bool(forKey: Money.hideOnOpenKey) || UserDefaults.standard.bool(forKey: Money.hiddenKey)
        func text(_ c: Centimes, _ privacy: AmountPrivacy) -> String {
            hide && (privacy == .income || !UserDefaults.standard.bool(forKey: Money.hideIncomeOnlyKey))
                ? "•••• " + Money.currencySymbol : Money.format(c, privacy: .never)
        }
        let days = Advice.daysLeft(in: period, now: now)
        let snapshot = WidgetSnapshot(
            leftText: text(s.left, .income),
            leftTitle: L10n.t("Left to spend"),
            // The first days of a month also say what came from last month.
            subtitle: s.carriedIn != 0 && Calendar.current.dateComponents([.day], from: period.start, to: now).day ?? 99 < 5
                ? L10n.t("%@ from last month", hide ? text(s.carriedIn, .income) : Money.format(s.carriedIn, sign: true, privacy: .never))
                : L10n.t("%@ spent", text(s.spent, .any)),
            daysLeftText: days == 1 ? L10n.t("Last day of the period") : L10n.t("%d days left", days),
            progress: s.progress,
            negative: s.left < 0,
            categories: lines.prefix(3).map { line in
                let over: Bool
                let left: String
                switch line.status.state {
                case .over(let x): over = true; left = L10n.t("%@ over", text(x, .any))
                case .left(let x): over = false; left = L10n.t("%@ left", text(x, .any))
                default: over = false; left = ""
                }
                return .init(name: line.category.displayName, symbol: line.category.symbol, leftText: left,
                             progress: line.status.progress, over: over)
            },
            addTitle: L10n.t("Add"),
            emptyText: L10n.t("Open Bztam to start"),
            updated: now)
        guard snapshot != WidgetSnapshot.load() else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
