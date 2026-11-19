import Foundation
import SwiftData
import UserNotifications

/// Creating splits, paying back, balances, messages and reminders.
@MainActor
enum SplitActions {
    struct Line: Identifiable {
        let id = UUID()
        let name: String
        let amount: Centimes
        let isPayer: Bool
    }

    // MARK: Create

    /// Saves a split. When you paid, the whole bill is added as spent now (like your bank).
    /// When a friend paid, only your debt is recorded; it becomes spent when you pay them.
    @discardableResult
    static func create(merchant: String, total: Centimes, date: Date, category: BudgetCategory?,
                       payer: Friend?, friends: [Friend], includesMe: Bool, remind: Bool,
                       context: ModelContext) -> (bill: SplitBill, lines: [Line]) {
        let meIn = payer == nil ? includesMe : true
        let bill = SplitBill(merchant: merchant, total: total, date: date, categoryID: category?.id,
                             payerID: payer?.id, memberIDs: friends.map(\.id), includesMe: meIn)
        context.insert(bill)

        // People in order: you first (if sharing), then friends.
        let people: [Friend?] = (meIn ? [nil] : []) + friends.map { Optional($0) }
        let payerIndex = payer == nil ? (meIn ? 0 : nil) : people.firstIndex { $0?.id == payer?.id }
        let amounts = SplitMath.equalShares(total: total, people: people.count, payerIndex: payerIndex)

        var lines: [Line] = []
        for (person, amount) in zip(people, amounts) {
            lines.append(Line(name: person?.name ?? L10n.t("You"), amount: amount,
                              isPayer: person?.id == payer?.id && (person != nil || payer == nil)))
            if payer == nil, let friend = person {
                context.insert(SplitShare(billID: bill.id, friendID: friend.id, amount: amount))
            } else if payer != nil, person == nil {
                context.insert(SplitShare(billID: bill.id, friendID: nil, amount: amount))
            }
        }

        if payer == nil {
            let entry = Entry(kind: .expense, amount: total, date: date, merchant: merchant,
                              note: L10n.t("Split with %d", friends.count), category: category)
            entry.splitID = bill.id
            context.insert(entry)
            try? context.save()
            BudgetAlerts.afterAdding(entry, context: context)
            if remind {
                let owed = total - (meIn ? (amounts.first ?? 0) : 0)
                scheduleReminder(bill: bill, owed: owed, names: friends.map(\.name))
            }
        }
        try? context.save()
        return (bill, lines)
    }

    // MARK: Paying back

    /// A friend paid you back. The money comes back into the bill's category, like a refund.
    static func friendPaidBack(_ friend: Friend, amount: Centimes, context: ModelContext, now: Date = .now) {
        let open = openShares(owedBy: friend, context: context)
        for (i, take) in SplitMath.allocate(amount, over: open.map(\.share.open)) {
            let (share, bill) = open[i]
            share.settled += take
            share.lastSettledAt = now
            let entry = Entry(kind: .expense, amount: -take, date: now,
                              note: L10n.t("%@ paid back · %@", friend.name, bill.merchant.isEmpty ? DateText.short(bill.date) : bill.merchant),
                              category: category(bill, context: context))
            entry.splitID = bill.id
            context.insert(entry)
            if allSettled(bill, context: context) { cancelReminder(bill) }
        }
        try? context.save()
    }

    /// You paid a friend back: now it leaves your money, in the bill's category.
    static func youPaidBack(_ friend: Friend, amount: Centimes, context: ModelContext, now: Date = .now) {
        let open = openShares(owedTo: friend, context: context)
        for (i, take) in SplitMath.allocate(amount, over: open.map(\.share.open)) {
            let (share, bill) = open[i]
            share.settled += take
            share.lastSettledAt = now
            let entry = Entry(kind: .expense, amount: take, date: now,
                              note: L10n.t("Paid %@ back · %@", friend.name, bill.merchant.isEmpty ? DateText.short(bill.date) : bill.merchant),
                              category: category(bill, context: context))
            entry.splitID = bill.id
            context.insert(entry)
        }
        try? context.save()
    }

    /// Lets the rest go, in one direction. Nothing is added to your money: with bank-style counting,
    /// money a friend never pays back simply never comes back.
    static func forget(_ friend: Friend, owedToMe: Bool, context: ModelContext, now: Date = .now) {
        let open = owedToMe ? openShares(owedBy: friend, context: context) : openShares(owedTo: friend, context: context)
        for (share, bill) in open {
            share.settled = share.amount
            share.lastSettledAt = now
            if owedToMe, allSettled(bill, context: context) { cancelReminder(bill) }
        }
        try? context.save()
    }

    // MARK: Reading

    static func balances(context: ModelContext) -> [FriendBalance] {
        let friends = (try? context.fetch(FetchDescriptor<Friend>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let bills = Dictionary(((try? context.fetch(FetchDescriptor<SplitBill>())) ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let shares = (try? context.fetch(FetchDescriptor<SplitShare>())) ?? []
        var map: [UUID: FriendBalance] = [:]
        for f in friends { map[f.id] = FriendBalance(friendID: f.id, name: f.name, owesYou: 0, youOwe: 0) }
        for s in shares where s.open > 0 {
            guard let bill = bills[s.billID] else { continue }
            if bill.paidByMe, let fid = s.friendID { map[fid]?.owesYou += s.open }
            if !bill.paidByMe, s.friendID == nil, let pid = bill.payerID { map[pid]?.youOwe += s.open }
        }
        return friends.compactMap { map[$0.id] }
    }

    /// Money friends still owe you for bills in this category and period (used so alerts don't fire on money coming back).
    static func comingBack(categoryID: UUID, in period: BudgetPeriod, context: ModelContext) -> Centimes {
        let bills = ((try? context.fetch(FetchDescriptor<SplitBill>())) ?? [])
            .filter { $0.paidByMe && $0.categoryID == categoryID && period.contains($0.date) }
        guard !bills.isEmpty else { return 0 }
        let ids = Set(bills.map(\.id))
        let shares = (try? context.fetch(FetchDescriptor<SplitShare>())) ?? []
        return shares.filter { ids.contains($0.billID) && $0.friendID != nil }.reduce(0) { $0 + $1.open }
    }

    /// Open bills with a friend, newest first, for the friend screen.
    static func openBills(with friend: Friend, context: ModelContext) -> [(bill: SplitBill, owesYou: Centimes, youOwe: Centimes)] {
        let a = openShares(owedBy: friend, context: context).map { ($0.bill, $0.share.open, Centimes(0)) }
        let b = openShares(owedTo: friend, context: context).map { ($0.bill, Centimes(0), $0.share.open) }
        return (a + b).sorted { $0.0.date > $1.0.date }.map { (bill: $0.0, owesYou: $0.1, youOwe: $0.2) }
    }

    private static func openShares(owedBy friend: Friend, context: ModelContext) -> [(share: SplitShare, bill: SplitBill)] {
        let fid: UUID? = friend.id
        let shares = (try? context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.friendID == fid }))) ?? []
        return pair(shares.filter { $0.open > 0 }, context: context).filter { $0.bill.paidByMe }
    }

    private static func openShares(owedTo friend: Friend, context: ModelContext) -> [(share: SplitShare, bill: SplitBill)] {
        let shares = (try? context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.friendID == nil }))) ?? []
        return pair(shares.filter { $0.open > 0 }, context: context).filter { $0.bill.payerID == friend.id }
    }

    /// Oldest bill first, so paying back clears the oldest debts first.
    private static func pair(_ shares: [SplitShare], context: ModelContext) -> [(share: SplitShare, bill: SplitBill)] {
        let bills = Dictionary(((try? context.fetch(FetchDescriptor<SplitBill>())) ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return shares.compactMap { s in bills[s.billID].map { (share: s, bill: $0) } }
            .sorted { $0.bill.date != $1.bill.date ? $0.bill.date < $1.bill.date : $0.bill.createdAt < $1.bill.createdAt }
    }

    private static func allSettled(_ bill: SplitBill, context: ModelContext) -> Bool {
        let id = bill.id
        let shares = (try? context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.billID == id }))) ?? []
        return shares.allSatisfy { $0.open == 0 }
    }

    private static func category(_ bill: SplitBill, context: ModelContext) -> BudgetCategory? {
        guard let id = bill.categoryID else { return nil }
        return (try? context.fetch(FetchDescriptor<BudgetCategory>()))?.first { $0.id == id }
    }

    // MARK: Messages

    /// The WhatsApp message for a new split.
    static func message(merchant: String, total: Centimes, date: Date, lines: [Line], paidByMe: Bool, payerName: String?) -> String {
        var out = [(merchant.isEmpty ? L10n.t("Our bill") : merchant) + " · " + Money.format(total) + " · " + DateText.short(date)]
        for l in lines where !(paidByMe && l.isPayer && l.name == L10n.t("You")) {
            out.append("• \(l.name == L10n.t("You") ? L10n.t("Me") : l.name): \(Money.format(l.amount))")
        }
        out.append(paidByMe ? L10n.t("I paid, you can send me your share 🙂") : L10n.t("Paid by %@. I'll send you my share.", payerName ?? ""))
        out.append(L10n.t("Split with Bztam"))
        return out.joined(separator: "\n")
    }

    /// A friendly reminder of everything a friend still owes you.
    static func reminderMessage(for friend: Friend, context: ModelContext) -> String {
        let open = openShares(owedBy: friend, context: context)
        let total = open.reduce(0) { $0 + $1.share.open }
        var out = [L10n.t("Hi %@, a quick reminder: %@ for", friend.name, Money.format(total))]
        for (share, bill) in open {
            out.append("• \(bill.merchant.isEmpty ? L10n.t("Our bill") : bill.merchant) (\(DateText.short(bill.date))): \(Money.format(share.open))")
        }
        out.append(L10n.t("Thanks! 🙏"))
        return out.joined(separator: "\n")
    }

    // MARK: Reminders

    private nonisolated static func reminderID(_ billID: UUID) -> String { "split-\(billID.uuidString)" }

    private static func scheduleReminder(bill: SplitBill, owed: Centimes, names: [String], days: Int = 3) {
        guard owed > 0, let day = Calendar.current.date(byAdding: .day, value: days, to: .now) else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = 10
        let title = bill.merchant.isEmpty ? L10n.t("Split bill") : bill.merchant
        let body = L10n.t("%@ still owe you %@. Send them a reminder?", ListFormatter.localizedString(byJoining: names), Money.format(owed))
        let id = reminderID(bill.id)
        Task.detached {
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
            try? await center.add(UNNotificationRequest(identifier: id, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    private static func cancelReminder(_ bill: SplitBill) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID(bill.id)])
    }
}
