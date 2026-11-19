import Combine
import CoreData
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable, Identifiable {
    case home, activity, insights, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.t("Home")
        case .activity: L10n.t("Activity")
        case .insights: L10n.t("Insights")
        case .settings: L10n.t("Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .activity: "list.bullet"
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

/// The four tabs with the flat Wise-style tab bar, plus the Add sheet and the Undo toast.
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
            case .insights: InsightsView(onAsk: { asking = true })
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let message = undo.message {
                    UndoToast(message: message) { undo.performUndo() }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if CloudSync.isActive { CloudSync.mergeDuplicates(in: context) }
                if !LaunchOptions.demoData { RecurringEngine.run(in: context) }
                refreshSubscription()
                DartActions.scheduleReminders(context: context)
                Task {
                    await scanner.openNextShared()
                    await watcher.check()
                }
            }
        }
        .task {
            if !LaunchOptions.demoData { RecurringEngine.run(in: context) }
            refreshSubscription()
            if LaunchOptions.openScreen == "add" { addRequest = AddRequest() }
            if LaunchOptions.openScreen == "ask" { tab = .insights; asking = true }
            if LaunchOptions.openScreen == "dart" { tab = .settings }
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

    /// Looks for a shop paid every month that isn't recurring yet.
    func refreshSubscription() {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        var excluded = SubscriptionDetector.dismissed
        for rule in rules where rule.isActive { excluded.insert(CategoryMemory.key(rule.merchant)) }
        let records = entries.filter { $0.recurringID == nil && $0.dartID == nil }.map { EntryRecord($0) }
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
struct BZTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: active ? .semibold : .regular))
                            .frame(width: 56, height: 32)
                            .background(active ? Theme.Colors.brand : Color.clear, in: Capsule())
                        Text(tab.title)
                            .font(.system(size: 12, weight: active ? .bold : .medium))
                    }
                    .foregroundStyle(active ? Theme.Colors.ink : Theme.Colors.inkMuted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.Colors.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.line).frame(height: 1) }
    }
}
