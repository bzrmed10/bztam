import CoreData
import Foundation
import Observation

/// Watches iCloud sync events so Settings can say "Synced 2 min ago" or show the error.
/// The error text is what's needed to fix a CloudKit schema problem, so it can be copied.
@MainActor @Observable
final class SyncMonitor {
    static let shared = SyncMonitor()

    private(set) var lastSuccess: Date?
    private(set) var lastError: String?
    private(set) var inProgress = false
    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let finished = event.endDate
            let succeeded = event.succeeded
            let message = event.error.map { SyncMonitor.describe($0) }
            MainActor.assumeIsolated {
                SyncMonitor.shared.record(finished: finished, succeeded: succeeded, error: message)
            }
        }
    }

    private func record(finished: Date?, succeeded: Bool, error: String?) {
        guard let finished else { inProgress = true; return }
        inProgress = false
        if succeeded {
            lastSuccess = finished
            lastError = nil
        } else if let error {
            lastError = error
        }
    }

    /// The CloudKit server message is buried in the underlying errors; keep everything.
    nonisolated static func describe(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["\(ns.domain) \(ns.code): \(ns.localizedDescription)"]
        if let partial = ns.userInfo["CKPartialErrors"] as? [AnyHashable: Error] {
            for e in partial.values.prefix(3) { parts.append(describe(e)) }
        }
        if let server = ns.userInfo["ServerErrorDescription"] as? String { parts.append(server) }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { parts.append(describe(underlying)) }
        return parts.joined(separator: "\n")
    }
}
