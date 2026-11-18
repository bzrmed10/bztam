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
    /// `-openScreen add|category|scan|pdf|ask|dart` (`-askQuestion "..."` asks it right away with demo data)
    static var openScreen: String? { UserDefaults.standard.string(forKey: "openScreen") }
}

@main
struct BztamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        container = DataStore.shared
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
                .tint(Theme.Colors.ink)
        }
        .modelContainer(container)
    }
}

/// Shows onboarding until it is done, then the main tabs.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [AppSettings]
    @AppStorage(L10n.storageKey) private var language = AppLanguage.system.rawValue
    @AppStorage(Money.currencyKey) private var currency = Currency.mad.rawValue
    @State private var lock = AppLock()

    var body: some View {
        ZStack {
            Group {
                if settingsRows.first?.onboardingDone == true {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            // Changing the language or currency in Settings redraws every screen with the new text.
            .id(language + currency)
            .environment(\.locale, L10n.locale)

            if lock.locked {
                LockView { Task { await lock.unlock() } }
                    .transition(.opacity)
            }
        }
        .background(Theme.Colors.canvas)
        .onAppear {
            if settingsRows.isEmpty { _ = DataStore.settings(in: context) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: lock.lockIfNeeded()
            case .active: Task { await lock.unlock() }
            default: break
            }
        }
        .task { await lock.unlock() }
    }
}
