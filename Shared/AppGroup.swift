import Foundation

/// Identifiers shared by the app and the share extension.
enum AppGroup {
    static let identifier = "group.com.bzrmed.bztam"

    /// Container directory shared between the app and its extensions.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Folder where the share extension drops files for the app to review.
    static var inboxURL: URL? {
        containerURL?.appendingPathComponent("Inbox", isDirectory: true)
    }
}
