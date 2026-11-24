import Foundation
import SwiftData

/// Builds the SwiftData container and seeds data.
enum DataStore {
    static let schema = Schema([Entry.self, BudgetCategory.self, AppSettings.self, RecurringRule.self, Dart.self, Friend.self, SplitBill.self, SplitShare.self, SavingsGoal.self, GoalMove.self, MonthClose.self])

    /// The one container of the app process, shared with Siri / Shortcuts.
    @MainActor static let shared: ModelContainer = makeContainer(inMemory: LaunchOptions.demoData || LaunchOptions.freshStart)

    /// The store lives in the App Group so the share extension can add entries later.
    /// Falls back to the app's own folder when the group is unavailable (unsigned simulator builds).
    /// With iCloud sync on, the same store is mirrored to the user's private CloudKit database.
    @MainActor
    static func makeContainer(inMemory: Bool) -> ModelContainer {
        do {
            if inMemory {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            }
            let folder: URL
            if let group = AppGroup.containerURL {
                folder = group
            } else {
                folder = URL.applicationSupportDirectory
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let url = folder.appendingPathComponent("Bztam.store")
            if CloudSync.supported && CloudSync.wanted {
                let cloud = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(CloudSync.containerID))
                if let container = try? ModelContainer(for: schema, configurations: cloud) {
                    CloudSync.isActive = true
                    SyncMonitor.shared.start()
                    return container
                }
            }
            // `.none` matters: the default would turn CloudKit on by itself whenever the entitlement is present.
            let local = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            // A broken store must never stop the app from opening: start in memory and keep going.
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }

    /// The single settings row, created on first use.
    @MainActor
    static func settings(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let s = AppSettings()
        context.insert(s)
        return s
    }

    /// Creates the default categories once, with budgets suggested from the income.
    @MainActor
    static func ensureCategories(in context: ModelContext, income: Centimes) {
        let count = (try? context.fetchCount(FetchDescriptor<BudgetCategory>())) ?? 0
        guard count == 0 else { return }
        for (index, t) in DefaultCategories.all.enumerated() {
            context.insert(BudgetCategory(key: t.key, name: t.englishName, symbol: t.symbol,
                                          budget: DefaultCategories.suggestedBudget(t, income: income),
                                          isFixed: t.isFixed, order: index))
        }
    }

    /// Demo data matching the design canvas: 8,000 DH in, 5,240 DH spent, 2,760 DH left. Payday the 25th.
    @MainActor
    static func seedDemo(in context: ModelContext, now: Date = .now) {
        let settings = settings(in: context)
        settings.payday = 25
        settings.onboardingDone = true
        settings.expectedIncome = 800_000
        settings.createdAt = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now

        let budgets: [String: Centimes] = [
            "rent": 300_000, "bills": 40_000, "phone": 20_000, "courses": 120_000,
            "transport": 50_000, "food": 60_000, "goingout": 60_000, "other": 0
        ]
        var byKey: [String: BudgetCategory] = [:]
        for (index, t) in DefaultCategories.all.enumerated() {
            let c = BudgetCategory(key: t.key, name: t.englishName, symbol: t.symbol,
                                   budget: budgets[t.key] ?? 0, isFixed: t.isFixed, order: index)
            context.insert(c)
            byKey[t.key] = c
        }

        let cal = Calendar.current
        let period = BudgetCalculator.period(containing: now, payday: 25, calendar: cal)
        func day(_ offset: Int) -> Date {
            min(cal.date(byAdding: .day, value: offset, to: period.start) ?? now, now)
        }
        func daysAgo(_ n: Int) -> Date { max(cal.date(byAdding: .day, value: -n, to: now) ?? now, period.start) }

        context.insert(Entry(kind: .income, amount: 800_000, date: day(0), merchant: "", incomeSource: .salary))
        let expenses: [(String, Centimes, String, Date, EntrySource)] = [
            ("rent", 300_000, "Rent", day(0), .manual),
            ("courses", 24_550, "Marjane", daysAgo(0), .camera),
            ("courses", 3_200, "Hanout", daysAgo(1), .manual),
            ("courses", 31_800, "Carrefour Market", daysAgo(5), .camera),
            ("courses", 15_450, "BIM", daysAgo(11), .camera),
            ("courses", 10_000, "Hanout", day(3), .manual),
            ("food", 3_800, "Café Clock", daysAgo(0), .manual),
            ("food", 11_200, "Glovo", daysAgo(1), .screenshot),
            ("food", 49_000, "Restaurants", daysAgo(8), .manual),
            ("transport", 2_000, "Petit taxi", daysAgo(0), .manual),
            ("transport", 20_000, "Tram card", daysAgo(9), .manual),
            ("phone", 20_000, "Inwi", daysAgo(1), .screenshot),
            ("bills", 31_000, "Lydec", daysAgo(6), .manual),
            ("goingout", 2_000, "Cinema", daysAgo(4), .manual)
        ]
        for (key, amount, merchant, date, source) in expenses {
            context.insert(Entry(kind: .expense, amount: amount, date: date, merchant: merchant,
                                 category: byKey[key], source: source))
        }
        // Rent and salary repeat every month; already added for this period.
        context.insert(RecurringRule(kind: .expense, amount: 300_000, merchant: "Rent", category: byKey["rent"],
                                     frequency: .monthly, startDate: day(0), lastGenerated: day(0)))
        context.insert(RecurringRule(kind: .income, amount: 800_000, incomeSource: .salary,
                                     frequency: .monthly, startDate: day(0), lastGenerated: day(0)))

        // A family dart in its second turn; the user collects third and hasn't paid this turn yet.
        let dartStart = cal.date(byAdding: .month, value: -1, to: cal.date(byAdding: .day, value: -3, to: now) ?? now) ?? now
        let dart = Dart(name: "Family", amount: 100_000, startDate: dartStart,
                        memberNames: ["Karim", "Sara", "", "Omar", "Nadia"], meIndex: 2)
        dart.paid = (0..<5).map { DartPlan.key(round: 0, member: $0) } + [0, 1, 3].map { DartPlan.key(round: 1, member: $0) }
        dart.reminders = false
        context.insert(dart)

        // Friends and two split bills: you paid dinner for four (Karim already paid back), Sara paid a pizza.
        let karim = Friend(name: "Karim"), sara = Friend(name: "Sara"), omar = Friend(name: "Omar"), nadia = Friend(name: "Nadia")
        for f in [karim, sara, omar, nadia] { context.insert(f) }
        try? context.save()
        let alerts = UserDefaults.standard.object(forKey: BudgetAlerts.enabledKey)
        UserDefaults.standard.set(false, forKey: BudgetAlerts.enabledKey)
        SplitActions.create(merchant: "Café Clock", total: 60_000, date: daysAgo(2), category: byKey["goingout"],
                            payer: nil, friends: [karim, sara, omar], includesMe: true, remind: false, context: context)
        SplitActions.friendPaidBack(karim, amount: 15_000, context: context, now: daysAgo(1))
        SplitActions.create(merchant: "Pizza Hut", total: 32_000, date: daysAgo(5), category: byKey["goingout"],
                            payer: sara, friends: [sara, nadia], includesMe: true, remind: false, context: context)
        UserDefaults.standard.set(alerts, forKey: BudgetAlerts.enabledKey)

        // The previous period, so Insights has something to compare with.
        let previous = BudgetCalculator.period(period, offset: -1, payday: 25, calendar: cal)
        func prev(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: previous.start) ?? previous.start }
        context.insert(Entry(kind: .income, amount: 800_000, date: prev(0), incomeSource: .salary))
        let earlier: [(String, Centimes, String, Int)] = [
            ("rent", 300_000, "Rent", 0), ("courses", 97_000, "Marjane", 6), ("food", 54_000, "Glovo", 9),
            ("transport", 26_000, "Petit taxi", 12), ("bills", 30_000, "Lydec", 14), ("phone", 20_000, "Inwi", 15),
            ("goingout", 34_000, "Megarama", 20)
        ]
        for (key, amount, merchant, offset) in earlier {
            context.insert(Entry(kind: .expense, amount: amount, date: prev(offset), merchant: merchant, category: byKey[key]))
        }

        // Two savings goals, money put aside last period (so this period's numbers stay as designed).
        let trip = SavingsGoal(name: "Summer trip", symbol: "airplane", target: 600_000,
                               deadline: cal.date(byAdding: .month, value: 8, to: now), order: 0)
        let eid = SavingsGoal(name: "Eid", symbol: "moon.stars", target: 300_000, monthlyPlan: 50_000, order: 1)
        context.insert(trip)
        context.insert(eid)
        context.insert(GoalMove(goalID: trip.id, amount: 150_000, date: prev(2)))
        context.insert(GoalMove(goalID: eid.id, amount: 120_000, date: prev(3)))

        // Last month ended 310 DH over. Screenshots of the month-end card leave it undecided
        // (with a freelance job for the "money left" one); otherwise it was already settled.
        switch LaunchOptions.openScreen {
        case "monthend":
            context.insert(Entry(kind: .income, amount: 95_000, date: prev(18), merchant: "Logo design", incomeSource: .freelance))
        case "monthover":
            break
        default:
            context.insert(MonthClose(period: previous, amount: -31_000, moved: 0, choice: .leave))
        }
        try? context.save()
    }
}
