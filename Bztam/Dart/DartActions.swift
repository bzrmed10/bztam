import Foundation
import SwiftData
import UserNotifications

/// Marks payments, links them to the user's money, and schedules reminders.
@MainActor
enum DartActions {
    /// Ticks or unticks a member's payment. For the user, this adds or removes the matching expense.
    static func togglePaid(_ dart: Dart, member: Int, round: Int, context: ModelContext, now: Date = .now) {
        let key = DartPlan.key(round: round, member: member)
        if dart.paid.contains(key) {
            dart.paid.removeAll { $0 == key }
            if member == dart.meIndex { removeEntries(dart, round: round, kind: .expense, context: context) }
        } else {
            dart.paid.append(key)
            if member == dart.meIndex && dart.tracksMoney {
                let categories = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
                let entry = Entry(kind: .expense, amount: dart.amount, date: entryDate(dart, round: round, now: now),
                                  note: L10n.t("Dart · %@", dart.name),
                                  category: categories.first { $0.key == dart.categoryKey && !$0.isArchived })
                entry.dartID = dart.id
                entry.dartRound = round
                context.insert(entry)
            }
        }
        try? context.save()
    }

    /// Records (or undoes) collecting the pot on the user's turn, as money in.
    static func toggleReceived(_ dart: Dart, context: ModelContext, now: Date = .now) {
        let round = dart.plan.myRound
        if dart.received.contains(round) {
            dart.received.removeAll { $0 == round }
            removeEntries(dart, round: round, kind: .income, context: context)
        } else {
            dart.received.append(round)
            if dart.tracksMoney {
                let entry = Entry(kind: .income, amount: dart.plan.pot, date: entryDate(dart, round: round, now: now),
                                  note: L10n.t("Dart · %@", dart.name), incomeSource: .other)
                entry.dartID = dart.id
                entry.dartRound = round
                context.insert(entry)
            }
        }
        try? context.save()
    }

    /// Today for the running round, else the round's own date.
    private static func entryDate(_ dart: Dart, round: Int, now: Date) -> Date {
        if case .round(let r) = dart.plan.status(on: now), r == round { return now }
        return min(now, dart.plan.date(ofRound: round))
    }

    private static func removeEntries(_ dart: Dart, round: Int, kind: EntryKind, context: ModelContext) {
        let id: UUID? = dart.id
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.dartID == id && $0.dartRound == round && $0.kindRaw == kindRaw })
        for entry in (try? context.fetch(descriptor)) ?? [] { context.delete(entry) }
    }

    /// The dart that needs the user now: a payment due this round, or their pot to collect.
    static func due(_ darts: [Dart], now: Date = .now) -> (dart: Dart, collect: Bool)? {
        for dart in darts.sorted(by: { $0.createdAt < $1.createdAt }) {
            let plan = dart.plan
            guard case .round(let r) = plan.status(on: now) else { continue }
            if r == plan.myRound, !dart.received.contains(r) { return (dart, true) }
            if !plan.hasPaid(dart.meIndex, round: r) { return (dart, false) }
        }
        return nil
    }

    // MARK: Reminders

    private nonisolated static let prefix = "dart-"

    private struct Reminder: Sendable {
        let id: String
        let title: String
        let body: String
        let date: DateComponents
    }

    /// Replaces all dart reminders: 9:00 on each of the next round days.
    static func scheduleReminders(context: ModelContext, now: Date = .now) {
        let darts = (try? context.fetch(FetchDescriptor<Dart>())) ?? []
        let cal = Calendar.current
        var reminders: [Reminder] = []
        for dart in darts where dart.reminders {
            let plan = dart.plan
            for (round, date) in plan.upcomingRounds(after: now, limit: 2) {
                var comps = cal.dateComponents([.year, .month, .day], from: date)
                comps.hour = 9
                guard let fire = cal.date(from: comps), fire > now else { continue }
                let body = plan.collector(ofRound: round) == dart.meIndex
                    ? L10n.t("Your turn: you collect %@ today.", Money.format(plan.pot))
                    : L10n.t("Pay %@ today. %@ collects.", Money.format(plan.amount), dart.displayName(plan.collector(ofRound: round)))
                reminders.append(Reminder(id: "\(prefix)\(dart.id.uuidString)-\(round)", title: dart.name, body: body, date: comps))
            }
        }
        Task { await apply(reminders) }
    }

    nonisolated private static func apply(_ reminders: [Reminder]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard !reminders.isEmpty else { return }
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if status != .authorized && status != .provisional {
            return
        }
        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: r.date, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: r.id, content: content, trigger: trigger))
        }
    }
}
