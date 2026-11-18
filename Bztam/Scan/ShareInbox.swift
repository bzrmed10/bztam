import Foundation

/// Files the share extension dropped in the App Group, oldest first.
enum ShareInbox {
    static func pending() -> [URL] {
        guard let inbox = AppGroup.inboxURL,
              let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
        else { return [] }
        return files
            .filter { ["pdf", "image"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
