import CloudKit
import Foundation
import SwiftData

/// iCloud sync through the user's private CloudKit database. Apple keeps the data; Bztam has no server.
enum CloudSync {
    static let containerID = "iCloud.com.bzrmed.bztam"
    static let enabledKey = "iCloudSync"

    /// The user's choice (on by default). Applied when the app starts.
    static var wanted: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// Simulator builds are not signed with the iCloud entitlement, so they never sync.
    static var supported: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    /// Whether the store was opened with sync on, for this run of the app.
    @MainActor static var isActive = false

    /// "available", "noAccount", or another status, for Settings.
    static func accountStatus() async -> CKAccountStatus {
        guard supported else { return .couldNotDetermine }
        return (try? await CKContainer(identifier: containerID).accountStatus()) ?? .couldNotDetermine
    }

    /// A second iPhone creates its own settings and default categories before iCloud data arrives,
    /// and both iPhones may add the same recurring entry. This keeps one of each and moves entries
    /// and rules onto the category kept. Safe to run any time.
    @MainActor
    @discardableResult
    static func mergeDuplicates(in context: ModelContext) -> Int {
        var removed = 0

        let settings = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        if settings.count > 1 {
            let keep = settings.min { a, b in
                a.onboardingDone != b.onboardingDone ? a.onboardingDone : a.createdAt < b.createdAt
            }!
            for s in settings where s !== keep {
                context.delete(s)
                removed += 1
            }
        }

        let categories = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
        let byKey = Dictionary(grouping: categories.filter { !$0.key.isEmpty }, by: \.key)
        for (_, group) in byKey where group.count > 1 {
            func weight(_ c: BudgetCategory) -> Int { (c.entries?.count ?? 0) + (c.rules?.count ?? 0) }
            let keep = group.min { a, b in
                if a.isArchived != b.isArchived { return !a.isArchived }
                if weight(a) != weight(b) { return weight(a) > weight(b) }
                return a.order < b.order
            }!
            for dup in group where dup !== keep {
                for entry in dup.entries ?? [] { entry.category = keep }
                for rule in dup.rules ?? [] { rule.category = keep }
                context.delete(dup)
                removed += 1
            }
        }
        // Two iPhones can both add the same recurring entry before they sync: keep one per rule and day.
        let recurring = ((try? context.fetch(FetchDescriptor<Entry>())) ?? []).filter { $0.recurringID != nil && $0.source == .recurring }
        let calendar = Calendar.current
        let byRuleAndDay = Dictionary(grouping: recurring) { e in "\(e.recurringID!.uuidString)|\(calendar.startOfDay(for: e.date).timeIntervalSince1970)" }
        for (_, group) in byRuleAndDay where group.count > 1 {
            let keep = group.min { $0.createdAt < $1.createdAt }!
            for dup in group where dup !== keep {
                context.delete(dup)
                removed += 1
            }
        }

        if removed > 0 { try? context.save() }
        return removed
    }
}
