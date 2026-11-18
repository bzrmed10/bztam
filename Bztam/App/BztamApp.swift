import SwiftData
import SwiftUI

/// Launch arguments used by UI tests and screenshots.
enum LaunchOptions {
    /// `-demoData` starts with the design's sample month in memory.
    static var demoData: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }
    /// `-freshStart` starts empty in memory (onboarding).
    static var freshStart: Bool { ProcessInfo.processInfo.arguments.contains("-freshStart") }
    /// `-startTab activity|insights|settings`
    static var startTab: String? { UserDefaults.standard.string(forKey: "startTab") }
    /// `-openScreen add|category`
    static var openScreen: String? { UserDefaults.standard.string(forKey: "openScreen") }
}

@main
struct BztamApp: App {
    let container: ModelContainer

    init() {
        let inMemory = LaunchOptions.demoData || LaunchOptions.freshStart
        container = DataStore.makeContainer(inMemory: inMemory)
        if LaunchOptions.demoData {
            DataStore.seedDemo(in: container.mainContext)
        } else {
            let names = Set(((try? container.mainContext.fetch(FetchDescriptor<Entry>())) ?? []).compactMap(\.attachmentName))
            AttachmentStore.removeOrphans(keeping: names)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, L10n.locale)
                .tint(Theme.Colors.ink)
        }
        .modelContainer(container)
    }
}

/// Shows onboarding until it is done, then the main tabs.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        Group {
            if settingsRows.first?.onboardingDone == true {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .background(Theme.Colors.canvas)
        .onAppear {
            if settingsRows.isEmpty { _ = DataStore.settings(in: context) }
        }
    }
}
