import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// "Delete all data": removes every entry, category, rule, dart, friend and split, the receipt photos,
/// scheduled reminders and the widget snapshot, then shows onboarding again.
/// With iCloud sync on, the deletions sync too, so the other iPhones are emptied as well.
/// Language, appearance, currency and lock stay as they are.
enum ResetData {
    @MainActor
    static func deleteEverything(in context: ModelContext) {
        // One by one rather than a batch delete, so iCloud sync sees every deletion.
        func wipe<T: PersistentModel>(_ type: T.Type) {
            for object in (try? context.fetch(FetchDescriptor<T>())) ?? [] { context.delete(object) }
        }
        wipe(SplitShare.self)
        wipe(SplitBill.self)
        wipe(Friend.self)
        wipe(Dart.self)
        wipe(RecurringRule.self)
        wipe(Entry.self)
        wipe(BudgetCategory.self)
        wipe(AppSettings.self)
        // A fresh settings row, so onboarding shows again.
        context.insert(AppSettings())
        try? context.save()

        try? FileManager.default.removeItem(at: AttachmentStore.folder)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        let defaults = UserDefaults.standard
        for key in ["dismissedInsights", "dismissedSubscriptions", "lastOfferedScreenshot", Money.hiddenKey] {
            defaults.removeObject(forKey: key)
        }

        if let url = AppGroup.containerURL?.appendingPathComponent("widget.json") {
            try? FileManager.default.removeItem(at: url)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
