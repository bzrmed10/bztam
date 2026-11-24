import Combine
import CoreData
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable, Identifiable {
    case home, activity, plan, insights, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.t("Home")
        case .activity: L10n.t("Activity")
        case .plan: L10n.t("Plan")
        case .insights: L10n.t("Insights")
        case .settings: L10n.t("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .activity: "list.bullet"
        case .plan: "list.bullet.clipboard"
        case .insights: "chart.pie"
        case .settings: "slider.horizontal.3"
        }
    }
}

/// How a receipt comes in.
enum ScanKind { case camera, screenshot, pdf }

/// What the Add sheet opens with.
struct AddRequest: Identifiable, Equatable {
    let id = UUID()
    var kind: EntryKind = .expense
    var categoryID: UUID?
}

/// The five tabs with the flat Wise-style tab bar, plus the Add sheet and the Undo toast.
struct MainTabView: View {
    @State private var tab: AppTab = AppTab(rawValue: LaunchOptions.startTab ?? "") ?? .home
    @State private var addRequest: AddRequest?
    @State private var undo = UndoCenter()
    @State private var scanner = ScanController()
    @State private var watcher = ScreenshotWatcher()
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var photoItem: PhotosPickerItem?
    @State private var noCamera = false
    @State private var showFiles = false
    @State private var unreadablePDF = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var subscription: SubscriptionCandidate?
    @State private var asking = false

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeView(onAdd: { addRequest = $0 }, onScan: startScan, suggestion: watcher.suggestion,
                         onSuggestionAdd: addSuggestion, onSuggestionDismiss: { watcher.clear() },
                         subscription: subscription, onSubscriptionYes: makeRecurring,
                         onSubscriptionDismiss: { SubscriptionDetector.dismiss($0.key); refreshSubscription() })
            case .activity: ActivityView(onAdd: { addRequest = AddRequest() })
            case .plan: PlanView()
            case .insights: InsightsView(onAsk: { asking = true })
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // An overlay, not a safe-area inset: pages inside a NavigationStack ignore the inset on iOS 26,
        // so each tab page adds `Theme.Size.tabBarSpace` at the end of its own scroll content instead.
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if let message = undo.message {
                    UndoToast(message: message, success: undo.success) { undo.performUndo() }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.bottom, Theme.Space.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BZTabBar(selection: $tab)
            }
            .animation(.snappy, value: undo.message)
        }
        .background(Theme.Colors.canvas)
        .environment(undo)
        .sheet(item: $addRequest) { request in
            AddEntryView(request: request, onScan: { kind in
                addRequest = nil
                after { startScan(kind) }
            })
            .environment(undo)
        }
        .sheet(isPresented: $asking) { AskView() }
        .sheet(item: Bindable(scanner).draft) { draft in
            ScanReviewView(draft: draft, onRetake: {
                after { startScan(draft.source == .camera ? .camera : .screenshot) }
            }, onDone: {
                after { Task { await scanner.openNextShared() } }
            })
        }
        .fullScreenCover(isPresented: $showCamera) {
            DocumentScannerView(onFinish: { images in
                showCamera = false
                Task { await scanner.read(images, source: .camera) }
            }, onCancel: { showCamera = false })
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { result in
            guard case .success(let url) = result else { return }
            Task {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if await !scanner.read(pdf: url, source: .share) { unreadablePDF = true }
            }
        }
        .alert(L10n.t("Can't read this PDF"), isPresented: $unreadablePDF) {
            Button(L10n.t("Cancel"), role: .cancel) {}
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await scanner.read([image], source: .screenshot)
                }
                photoItem = nil
            }
        }
        .alert(L10n.t("Camera not available"), isPresented: $noCamera) {
            Button(L10n.t("Choose an image")) { showPhotos = true }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("This device can't scan documents. You can pick a photo of the receipt instead."))
        }
        .overlay {
            if scanner.isReading { ReadingOverlay() }
        }
        // iCloud brought in data from another iPhone: fold duplicate settings and categories together.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            if CloudSync.isActive && CloudSync.mergeDuplicates(in: context) > 0 { refreshSubscription() }
        }
        .onOpenURL { url in
            switch url.host() {
            case "add": tab = .home; addRequest = AddRequest()
            case "scan": tab = .home; startScan(.camera)
            default: tab = .home
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { WidgetSync.update(context: context) }
            if phase == .active {
                runPendingAction()
                if CloudSync.isActive { CloudSync.mergeDuplicates(in: context) }
                if !LaunchOptions.demoData { RecurringEngine.run(in: context) }
                refreshSubscription()
                DartActions.scheduleReminders(context: context)
                InsightAlerts.scheduleWeekly()
                MonthEnd.scheduleNotification(payday: DataStore.settings(in: context).payday)
                Task {
                    await scanner.openNextShared()
                    await watcher.check()
                }
            }
        }
        .task {
            if !LaunchOptions.demoData { RecurringEngine.run(in: context) }
            refreshSubscription()
            WidgetSync.update(context: context)
            runPendingAction()
            if LaunchOptions.openScreen == "add" { addRequest = AddRequest() }
            if LaunchOptions.openScreen == "ask" { tab = .insights; asking = true }
            if LaunchOptions.openScreen == "dart" { tab = .plan }
            if LaunchOptions.openScreen == "scan" {
                await scanner.read([DemoReceipt.image()], source: .camera)
            }
            if LaunchOptions.openScreen == "pdf", let url = DemoBill.writeTemporaryPDF() {
                _ = await scanner.read(pdf: url, source: .share)
            }
            await scanner.openNextShared()
            await watcher.check()
        }
    }
}

extension MainTabView {
    func startScan(_ kind: ScanKind) {
        switch kind {
        case .camera:
            if DocumentScannerView.isAvailable { showCamera = true } else { noCamera = true }
        case .screenshot:
            showPhotos = true
        case .pdf:
            showFiles = true
        }
    }

    func addSuggestion() {
        guard let image = watcher.suggestion else { return }
        watcher.clear()
        Task { await scanner.read([image], source: .screenshot) }
    }

    /// Widgets, Control Center and the Action button leave a request in the App Group; links use bztam://.
    func runPendingAction() {
        switch PendingAction.take() {
        case "add": tab = .home; addRequest = AddRequest()
        case "scan": tab = .home; startScan(.camera)
        default: break
        }
    }

    /// Looks for a shop paid every month that isn't recurring yet.
    func refreshSubscription() {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        var excluded = SubscriptionDetector.dismissed
        for rule in rules where rule.isActive { excluded.insert(CategoryMemory.key(rule.merchant)) }
        let records = entries.filter { $0.recurringID == nil && $0.dartID == nil && $0.splitID == nil }.map { EntryRecord($0) }
        subscription = SubscriptionDetector.candidates(records, excluding: excluded).first
    }

    /// Turns a detected subscription into a monthly rule, starting from its last payment.
    func makeRecurring(_ candidate: SubscriptionCandidate) {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []
        let rule = RecurringRule(kind: .expense, amount: candidate.amount, merchant: candidate.merchant,
                                 category: categories.first { $0.id == candidate.categoryID },
                                 frequency: .monthly, startDate: candidate.lastDate, lastGenerated: candidate.lastDate)
        context.insert(rule)
        entries.first { CategoryMemory.key($0.merchant) == candidate.key && $0.date == candidate.lastDate }?.recurringID = rule.id
        try? context.save()
        refreshSubscription()
    }

    /// Runs an action once the current sheet has finished closing.
    func after(_ action: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            action()
        }
    }
}

/// Flat tab bar: icon in a lime pill when active, label below.
/// Floating Liquid Glass tab bar (iOS 26). Content scrolls underneath; the selected tab sits in a lime bubble
/// that slides between tabs. With Reduce Transparency on, iOS shows the glass as a solid surface.
struct BZTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var bubble

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.symbol)
                            .font(.scaled(size: 18, weight: active ? .semibold : .regular))
                            .symbolEffect(.bounce, value: active)
                            .frame(height: 24)
                        Text(tab.title)
                            .font(.scaled(size: 11, weight: active ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(active ? Theme.Colors.onBrand : Theme.Colors.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if active {
                            Capsule()
                                .fill(Theme.Colors.brand)
                                .matchedGeometryEffect(id: "bubble", in: bubble)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(5)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
