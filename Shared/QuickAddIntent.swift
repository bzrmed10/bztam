import AppIntents
import Foundation

/// Opens Bztam on the Add sheet. Used by the widget button, the Control Center control and the Action button.
struct QuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Add an expense"
    static let description = IntentDescription("Opens Bztam ready to add an expense.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingAction.request("add")
        return .result()
    }
}

/// Opens Bztam on the receipt scanner.
struct QuickScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a receipt"
    static let description = IntentDescription("Opens Bztam on the receipt scanner.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PendingAction.request("scan")
        return .result()
    }
}
