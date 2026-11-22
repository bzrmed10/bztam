import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// Weekly recap and unusual-spending alerts: settings, dismissals and notifications.
@MainActor
enum InsightAlerts {
    static let weeklyKey = "weeklyRecap"
    static let unusualKey = "unusualAlerts"
    private static let dismissedKey = "dismissedInsights"
    private nonisolated static let weeklyID = "weekly-recap"

    static var weeklyOn: Bool { UserDefaults.standard.object(forKey: weeklyKey) as? Bool ?? true }
    static var unusualOn: Bool { UserDefaults.standard.object(forKey: unusualKey) as? Bool ?? true }

    static func isDismissed(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []).contains(key)
    }

    static func dismiss(_ key: String) {
        var list = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        list.append(key)
        UserDefaults.standard.set(Array(list.suffix(200)), forKey: dismissedKey)
    }

    static func recapKey(_ r: WeeklyRecap) -> String { "recap-\(Int(r.weekStart.timeIntervalSince1970))" }
    static func unusualKey(_ u: UnusualSpending, period: BudgetPeriod) -> String { "\(u.id)-\(BudgetCategory.periodKey(period))" }

    static func title(_ u: UnusualSpending, categoryName: (UUID) -> String) -> String {
        switch u.kind {
        case .bill(let merchant): L10n.t("%@ is %d%% higher than usual", merchant, u.percent)
        case .category(let id): L10n.t("%@ is %d%% above usual", categoryName(id), u.percent)
        }
    }

    static func detail(_ u: UnusualSpending) -> String {
        switch u.kind {
        case .bill: L10n.t("%@ this time, usually %@.", Money.format(u.amount), Money.format(u.usual))
        case .category: L10n.t("%@ so far, usually %@ at this point.", Money.format(u.amount), Money.format(u.usual))
        }
    }

    static func recapTitle(_ r: WeeklyRecap) -> String { L10n.t("Last week: %@", Money.format(r.spent)) }

    static func recapDetail(_ r: WeeklyRecap, categoryName: (UUID) -> String) -> String {
        var parts: [String] = []
        if let c = r.change {
            parts.append(c < -4 ? L10n.t("%d%% less than usual", -c) : c > 4 ? L10n.t("%d%% more than usual", c) : L10n.t("About as usual"))
        }
        if let id = r.topCategoryID { parts.append(L10n.t("most on %@", categoryName(id))) }
        return parts.joined(separator: " · ")
    }

    /// Monday 9:00, every week, while the setting is on.
    static func scheduleWeekly() {
        let on = weeklyOn
        let title = L10n.t("Your week in Bztam")
        let body = L10n.t("See how last week went.")
        Task.detached {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
            guard on else { return }
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            var when = DateComponents()
            when.weekday = 2
            when.hour = 9
            try? await center.add(UNNotificationRequest(identifier: weeklyID, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        }
    }

    /// Right after adding a bill that's well above its usual amount.
    static func afterAdding(_ entry: Entry, context: ModelContext) {
        guard unusualOn, entry.kind == .expense, entry.amount > 0, !CategoryMemory.key(entry.merchant).isEmpty else { return }
        let payday = DataStore.settings(in: context).payday
        let period = BudgetCalculator.period(containing: entry.date, payday: payday)
        let records = ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).map { EntryRecord($0) }
        let key = CategoryMemory.key(entry.merchant)
        guard let alert = UnusualSpending.billAlerts(records, period: period, calendar: .current)
            .first(where: { if case .bill(let m) = $0.kind { return CategoryMemory.key(m) == key } else { return false } }) else { return }
        let title = InsightAlerts.title(alert) { _ in "" }
        let body = InsightAlerts.detail(alert)
        Task.detached {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// A For you card for insights: icon, one line, a detail and a dismiss button.

struct InsightCard: View {
    let symbol: String
    let title: String
    let detail: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.scaled(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Theme.Colors.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.scaled(size: 15, weight: .semibold)).lineLimit(2)
                if !detail.isEmpty {
                    Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.scaled(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("Dismiss"))
        }
        .padding(12)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}
