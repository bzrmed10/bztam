import Foundation
import SwiftData
import UserNotifications

/// Local notifications when a category reaches 80% and 100% of its budget, once per period.
enum BudgetAlerts {
    static let enabledKey = "budgetAlerts"
    static let thresholds = [80, 100]

    /// On unless the user turned it off.
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// Thresholds (in percent) passed by going from `before` to `after` spent.
    static func crossed(before: Centimes, after: Centimes, budget: Centimes) -> [Int] {
        guard budget > 0, after > before else { return [] }
        return thresholds.filter { t in before * 100 < budget * t && after * 100 >= budget * t }
    }

    /// Call after adding an expense. Sends at most one notification per threshold, category and period.
    @MainActor
    static func afterAdding(_ entry: Entry, context: ModelContext) {
        guard isEnabled, entry.kind == .expense, let category = entry.category else { return }
        let payday = DataStore.settings(in: context).payday
        let period = BudgetCalculator.period(containing: .now, payday: payday)
        let budget = category.budget(in: period)
        guard budget > 0, period.contains(entry.date) else { return }
        let all = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let after = all.filter { $0.kind == .expense && $0.category?.id == category.id && period.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
        let before = after - entry.amount
        guard let top = crossed(before: before, after: after, budget: budget).last else { return }

        let key = "alert-\(category.id.uuidString)-\(Int(period.start.timeIntervalSince1970))-\(top)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let name = category.displayName
        let title = top >= 100 ? L10n.t("%@ budget used up", name) : L10n.t("%@: %d%% spent", name, top)
        let body = top >= 100
            ? L10n.t("You've spent %@ of %@ this month.", Money.format(after, symbol: false), Money.format(budget))
            : L10n.t("%@ left until %@.", Money.format(budget - after), DateText.short(period.end))
        Task { await send(title: title, body: body, id: key) }
    }

    private static func send(title: String, body: String, id: String) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if status != .authorized && status != .provisional {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
