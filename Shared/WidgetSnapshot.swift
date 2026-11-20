import Foundation

/// What the widgets show, written by the app into the App Group as JSON.
/// Everything is already formatted and translated by the app, so the widgets stay tiny.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Category: Codable, Equatable, Sendable {
        var name: String
        var symbol: String
        var leftText: String
        var progress: Double
        var over: Bool
    }

    var leftText: String
    var leftTitle: String
    var subtitle: String
    var daysLeftText: String
    var progress: Double
    var negative: Bool
    var categories: [Category]
    var addTitle: String
    var emptyText: String
    var updated: Date

    static let placeholder = WidgetSnapshot(
        leftText: "2,310 DH", leftTitle: "Left to spend", subtitle: "5,690 DH spent", daysLeftText: "6 days left",
        progress: 0.7, negative: false,
        categories: [.init(name: "Groceries", symbol: "cart", leftText: "350 DH left", progress: 0.7, over: false),
                     .init(name: "Transport", symbol: "car", leftText: "280 DH left", progress: 0.44, over: false),
                     .init(name: "Café & Food", symbol: "cup.and.saucer", leftText: "40 DH over", progress: 1, over: true)],
        addTitle: "Add", emptyText: "Open Bztam to start", updated: .now)

    private static var url: URL? { AppGroup.containerURL?.appendingPathComponent("widget.json") }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(self).write(to: url, options: .atomic)
    }
}

/// Quick actions the widgets, Control Center and the Action button ask the app to do.
enum PendingAction {
    static let key = "pendingAction"
    static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    static func request(_ action: String) { defaults?.set(action, forKey: key) }

    /// Reads and clears the pending action.
    static func take() -> String? {
        guard let d = defaults, let action = d.string(forKey: key) else { return nil }
        d.removeObject(forKey: key)
        return action
    }
}
