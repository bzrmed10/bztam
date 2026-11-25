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
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system.rawValue
    @AppStorage(Money.hiddenKey) private var amountsHidden = false
    @Environment(\.scenePhase) private var phase
    @State private var lock = AppLock()

    @Environment(\.dynamicTypeSize) private var typeSize
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
            // Rebuilt when the language, currency, privacy or the iPhone's text size changes.
            .id(language + currency + (amountsHidden ? "·hidden" : "") + "\(typeSize)")
            .environment(\.layoutDirection, L10n.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, L10n.locale)
            .environment(\.locale, L10n.locale)

            if lock.locked {
                LockView(faceIDDenied: lock.faceIDDenied) { Task { await lock.unlock() } }
                    .transition(.opacity)
            }
        }
        .background(Theme.Colors.canvas)
        .preferredColorScheme((Appearance(rawValue: appearance) ?? .system).scheme)
        // The app switcher never shows your numbers.
        .overlay {
            if phase != .active && !lock.locked {
                ZStack {
                    Theme.Colors.canvas
                    Image("AppIconImage").resizable().frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .onChange(of: phase) { _, now in
            if now == .background && UserDefaults.standard.bool(forKey: Money.hideOnOpenKey) { amountsHidden = true }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: Money.hideOnOpenKey) { amountsHidden = true }
            if settingsRows.isEmpty { _ = DataStore.settings(in: context) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: lock.lockIfNeeded()
            case .active:
                Task { @MainActor in
                    // Let the app finish coming on screen before Face ID.
                    try? await Task.sleep(for: .milliseconds(300))
                    await lock.unlock()
                }
            default: break
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            await lock.unlock()
        }
        .task { await Store.shared.start() }
    }
}
