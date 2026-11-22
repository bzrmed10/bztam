import CloudKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Settings: money, alerts, receipts, privacy and app.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }) private var categories: [BudgetCategory]

    @AppStorage(ScreenshotWatcher.enabledKey) private var suggestScreenshots = false
    @AppStorage(BudgetAlerts.enabledKey) private var budgetAlerts = true
    @AppStorage(AppLock.enabledKey) private var faceIDLock = false
    @AppStorage(Money.hideOnOpenKey) private var hideOnOpen = false
    @AppStorage(InsightAlerts.weeklyKey) private var weeklyRecap = true
    @AppStorage(InsightAlerts.unusualKey) private var unusualAlerts = true
    @AppStorage(Money.hideIncomeOnlyKey) private var hideIncomeOnly = false
    @AppStorage(L10n.storageKey) private var language = AppLanguage.system.rawValue
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system.rawValue
    @AppStorage(Money.currencyKey) private var currency = Currency.mad.rawValue
    @State private var photosDenied = false
    @State private var showCategories = false
    @State private var showRecurring = false
    @State private var showExport = false
    @State private var restartNeeded = false
    @State private var confirmReset = false
    @State private var importing = false
    @State private var restorePreview: BackupImport.Preview?
    @State private var restoreNew = 0
    @State private var restoreMessage: String?
    @Environment(\.openURL) private var openURL
    @State private var cloudStatus: CKAccountStatus = .couldNotDetermine
    @AppStorage(CloudSync.enabledKey) private var iCloudSync = true
    @State private var showDart = LaunchOptions.openScreen == "dart"
    @State private var showFriends = false
    @State private var showGoals = false
    @State private var showSetup = false
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }) private var goalRows: [SavingsGoal]
    @Query private var friendRows: [Friend]
    @Query private var darts: [Dart]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive }) private var rules: [RecurringRule]

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        let settings = settingsRows.first
        let planned = categories.reduce(0) { $0 + $1.budget }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ScreenTitle(text: L10n.t("Settings"))

                    section(L10n.t("Money")) {
                        Menu {
                            Picker(L10n.t("Payday"), selection: Binding(
                                get: { settings?.payday ?? 1 },
                                set: { settings?.payday = $0; try? context.save() }
                            )) {
                                ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                            }
                        } label: {
                            SettingsRow(symbol: "calendar", title: L10n.t("Payday"),
                                        value: L10n.t("Day %d of the month", settings?.payday ?? 1))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Picker(L10n.t("Currency"), selection: $currency) {
                                ForEach(Currency.allCases) { Text($0.title).tag($0.rawValue) }
                            }
                        } label: {
                            SettingsRow(symbol: "banknote", title: L10n.t("Currency"),
                                        value: (Currency(rawValue: currency) ?? .mad).title)
                        }
                        .buttonStyle(.plain)

                        Button { showCategories = true } label: {
                            SettingsRow(symbol: "square.grid.2x2", title: L10n.t("Categories and budgets"),
                                        value: L10n.t("%d categories · %@ planned", categories.count, Money.format(planned)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.categories")

                        Button { showGoals = true } label: {
                            SettingsRow(symbol: "leaf", title: L10n.t("Savings goals"),
                                        value: goalRows.isEmpty ? L10n.t("Save for a trip, Eid, a new phone") : goalRows.map(\.name).joined(separator: ", "))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.goals")

                        Button { showSetup = true } label: {
                            SettingsRow(symbol: "wand.and.stars", title: L10n.t("Plan my month again"),
                                        value: L10n.t("Income, bills and a suggested plan"))
                        }
                        .buttonStyle(.plain)

                        Button { showRecurring = true } label: {
                            SettingsRow(symbol: "arrow.triangle.2.circlepath", title: L10n.t("Recurring"),
                                        value: rules.isEmpty ? L10n.t("Rent, salary, subscriptions") : L10n.t("%d active", rules.count))
                        }
                        .buttonStyle(.plain)

                        Button { showDart = true } label: {
                            SettingsRow(symbol: "person.3", title: L10n.t("Dart"),
                                        value: darts.isEmpty ? L10n.t("Track your dart (tontine)") : darts.map(\.name).joined(separator: ", "))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.dart")

                        Button { showFriends = true } label: {
                            SettingsRow(symbol: "person.2", title: L10n.t("Friends"),
                                        value: friendRows.isEmpty ? L10n.t("Split bills with friends") : L10n.t("%d friends", friendRows.count))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.friends")
                    }

                    section(L10n.t("Alerts")) {
                        ToggleRow(symbol: "bell", title: L10n.t("Budget alerts"),
                                  detail: L10n.t("A notification at 80% and 100% of a category"), isOn: $budgetAlerts)
                        ToggleRow(symbol: "calendar", title: L10n.t("Weekly recap"),
                                  detail: L10n.t("Monday morning: last week in one line"), isOn: $weeklyRecap)
                            .onChange(of: weeklyRecap) { _, _ in InsightAlerts.scheduleWeekly() }
                        ToggleRow(symbol: "exclamationmark.triangle", title: L10n.t("Unusual spending"),
                                  detail: L10n.t("When a bill or a category is well above usual"), isOn: $unusualAlerts)
                    }

                    section(L10n.t("Receipts")) {
                        ToggleRow(symbol: "photo.on.rectangle", title: L10n.t("Offer new screenshots"),
                                  detail: L10n.t("When you open Bztam after screenshotting a bill"),
                                  isOn: Binding(get: { suggestScreenshots }, set: { on in
                                      guard on else { suggestScreenshots = false; return }
                                      Task {
                                          let ok = await ScreenshotWatcher.requestAccess()
                                          suggestScreenshots = ok
                                          photosDenied = !ok
                                      }
                                  }))
                    }

                    section(L10n.t("Data")) {
                        ToggleRow(symbol: "icloud", title: L10n.t("iCloud sync"), detail: cloudDetail,
                                  isOn: Binding(get: { iCloudSync }, set: { on in
                                      iCloudSync = on
                                      restartNeeded = on != CloudSync.isActive
                                  }))
                        if CloudSync.isActive, let error = SyncMonitor.shared.lastError {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(L10n.t("iCloud sync isn't working yet"), systemImage: "exclamationmark.icloud")
                                    .font(.scaled(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.negative)
                                Text(error).font(.scaled(size: 11).monospaced()).foregroundStyle(Theme.Colors.inkMuted).lineLimit(6)
                                Button(L10n.t("Copy details")) { UIPasteboard.general.string = error }
                                    .font(.scaled(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.link)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                        }
                        Button { showExport = true } label: {
                            SettingsRow(symbol: "square.and.arrow.up", title: L10n.t("Export"), value: L10n.t("PDF report or CSV for spreadsheets"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.export")
                        Button { importing = true } label: {
                            SettingsRow(symbol: "square.and.arrow.down", title: L10n.t("Restore from a backup"),
                                        value: L10n.t("A CSV exported from Bztam"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.restore")
                        Button { confirmReset = true } label: {
                            HStack(spacing: Theme.Space.m) {
                                IconCircle(symbol: "trash", size: 44)
                                Text(L10n.t("Delete all data")).font(.bzBodyStrong).foregroundStyle(Theme.Colors.negative)
                                Spacer()
                            }
                            .frame(minHeight: Theme.Size.row)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.reset")
                    }

                    section(L10n.t("Privacy")) {
                        ToggleRow(symbol: "eye.slash", title: L10n.t("Hide amounts when Bztam opens"),
                                  detail: L10n.t("Tap the eye on Home to show them"), isOn: $hideOnOpen)
                        ToggleRow(symbol: "banknote", title: L10n.t("Only hide money in"),
                                  detail: L10n.t("Your salary and what's left stay private; expenses stay visible"), isOn: $hideIncomeOnly)
                        ToggleRow(symbol: "faceid", title: L10n.t("Lock with Face ID"),
                                  detail: L10n.t("Asks for Face ID or your passcode when Bztam opens"),
                                  isOn: Binding(get: { faceIDLock }, set: { on in
                                      Task {
                                          // Confirm it's really the owner before turning the lock on or off.
                                          if await AppLock.authenticate(reason: L10n.t("Confirm to change the lock")) { faceIDLock = on }
                                      }
                                  }))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(CloudSync.isActive ? L10n.t("Your data stays yours") : L10n.t("Your data stays on this iPhone"))
                                .font(.scaled(size: 15, weight: .bold))
                            Text(CloudSync.isActive
                                 ? L10n.t("No Bztam account, no bank connection, no ads. Receipts are read on your phone, and sync goes to your own iCloud.")
                                 : L10n.t("No account, no bank connection, no ads. Receipts are read on your phone."))
                                .font(.scaled(size: 14)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                        .padding(.top, 8)
                    }

                    section(L10n.t("App")) {
                        Menu {
                            Picker(L10n.t("Language"), selection: $language) {
                                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0.rawValue) }
                            }
                        } label: {
                            SettingsRow(symbol: "globe", title: L10n.t("Language"),
                                        value: (AppLanguage(rawValue: language) ?? .system).nativeName)
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Picker(L10n.t("Appearance"), selection: $appearance) {
                                ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                            }
                        } label: {
                            SettingsRow(symbol: "circle.lefthalf.filled", title: L10n.t("Appearance"),
                                        value: (Appearance(rawValue: appearance) ?? .system).title)
                        }
                        .buttonStyle(.plain)
                        Button { sendFeedback() } label: {
                            SettingsRow(symbol: "envelope", title: L10n.t("Send feedback"),
                                        value: L10n.t("Ideas, bugs, anything: we read every message"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.feedback")
                        SettingsRow(symbol: "info.circle", title: L10n.t("About Bztam"),
                                    value: L10n.t("Version %@", version), chevron: false)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.l + Theme.Size.tabBarSpace)
                .foregroundStyle(Theme.Colors.ink)
            }
            .background(Theme.Colors.canvas)
            .statusBarFade()
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                readBackup(result)
            }
            .confirmationDialog(L10n.t("Restore from a backup"), isPresented: Binding(get: { restorePreview != nil }, set: { if !$0 { restorePreview = nil } }),
                                titleVisibility: .visible) {
                if restoreNew > 0 {
                    Button(L10n.t("Add %d entries", restoreNew)) {
                        if let rows = restorePreview?.rows {
                            let added = BackupImport.apply(rows, in: context)
                            WidgetSync.update(context: context)
                            restoreMessage = L10n.t("%d entries added.", added)
                        }
                        restorePreview = nil
                    }
                }
                Button(L10n.t("Cancel"), role: .cancel) { restorePreview = nil }
            } message: {
                if let p = restorePreview {
                    let skipped = p.rows.count - restoreNew
                    Text(restoreNew == 0 ? L10n.t("Everything in this file is already in Bztam.")
                         : skipped > 0 ? L10n.t("%d are already in Bztam and are skipped.", skipped)
                         : L10n.t("Nothing in Bztam is changed or deleted."))
                }
            }
            .alert(restoreMessage ?? "", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
                Button(L10n.t("OK"), role: .cancel) {}
            }
            .alert(L10n.t("Photo access is off"), isPresented: $photosDenied) {
                Button(L10n.t("Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button(L10n.t("Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.t("Allow Bztam to see your photos in the Settings app to get new screenshots offered."))
            }
            .confirmationDialog(L10n.t("Delete all data?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L10n.t("Delete everything"), role: .destructive) {
                    Task {
                        // Same protection as the lock: only the owner can wipe Bztam.
                        if faceIDLock {
                            let confirmed = await AppLock.authenticate(reason: L10n.t("Confirm to delete all data"))
                            guard confirmed else { return }
                        }
                        ResetData.deleteEverything(in: context)
                    }
                }
                Button(L10n.t("Cancel"), role: .cancel) {}
            } message: {
                Text(CloudSync.isActive
                     ? L10n.t("Every expense, money in, category, dart and friend is deleted from this iPhone and from your iCloud. This can't be undone. Export first if you want a copy.")
                     : L10n.t("Every expense, money in, category, dart and friend is deleted from this iPhone. This can't be undone. Export first if you want a copy."))
            }
            .sheet(isPresented: $showRecurring) { RecurringListView() }
            .sheet(isPresented: $showExport) { ExportView() }
            .alert(L10n.t("Restart Bztam to apply"), isPresented: $restartNeeded) {
                Button(L10n.t("OK"), role: .cancel) {}
            } message: {
                Text(L10n.t("Close Bztam from the app switcher and open it again."))
            }
            .task { cloudStatus = await CloudSync.accountStatus() }
            .sheet(isPresented: $showDart) { DartListView() }
            .sheet(isPresented: $showFriends) { FriendsView() }
            .sheet(isPresented: $showGoals) { GoalsView() }
            .fullScreenCover(isPresented: $showSetup) { OnboardingView(setupMode: true) }
            .sheet(isPresented: $showCategories) {
                CategoriesEditorView(income: settings?.expectedIncome ?? 0)
            }
        }
    }

    private var cloudDetail: String {
        if !CloudSync.supported { return L10n.t("Not available on this device") }
        if iCloudSync && cloudStatus == .noAccount { return L10n.t("Sign in to iCloud in the Settings app to sync") }
        if iCloudSync != CloudSync.isActive { return L10n.t("Applies when Bztam opens again") }
        if let synced = SyncMonitor.shared.lastSuccess {
            return L10n.t("Synced %@", synced.formatted(.relative(presentation: .named)))
        }
        return iCloudSync ? L10n.t("Your data on all your iPhones. Receipt photos stay on this one.")
                          : L10n.t("Off: your data is only on this iPhone")
    }

    private func readBackup(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            restoreMessage = L10n.t("This file couldn't be read.")
            return
        }
        do {
            let preview = try BackupImport.preview(text)
            let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
            let existing = Set(entries.map { BackupImport.key(kind: $0.kind, amount: $0.amount, date: $0.date, title: $0.displayTitle) })
            restoreNew = BackupImport.newRows(preview.rows, existing: existing).count
            restorePreview = preview
        } catch {
            restoreMessage = L10n.t("This isn't a Bztam backup. Export a CSV from Settings → Export first.")
        }
    }

    /// An email to support with the versions filled in, so a bug report says which build it's about.
    private func sendFeedback() {
        let info = Bundle.main.infoDictionary
        let app = (info?["CFBundleShortVersionString"] as? String ?? "") + " (" + (info?["CFBundleVersion"] as? String ?? "") + ")"
        let body = "\n\n\n—\nBztam \(app) · iOS \(UIDevice.current.systemVersion) · \(L10n.code)"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "support@healus-ai.com"
        c.queryItems = [URLQueryItem(name: "subject", value: L10n.t("Bztam feedback")), URLQueryItem(name: "body", value: body)]
        if let url = c.url { openURL(url) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.scaled(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
    }
}

struct SettingsRow: View {
    let symbol: String
    let title: String
    let value: String
    var chevron = true

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink)
                Text(value).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.forward").font(.scaled(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ToggleRow: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Theme.Space.m) {
                IconCircle(symbol: symbol, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bzBodyStrong)
                    Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
            }
        }
        .tint(Theme.Colors.positive)
        .frame(minHeight: Theme.Size.row)
    }
}
