import Foundation
import SwiftUI
import UIKit
import Observation
import StoreKit
import UserNotifications

/// Why the Plus screen was opened: the matching benefit is shown first.
enum PaywallReason: String, Identifiable, CaseIterable, Sendable {
    case general, goals, scan, monthEnd, export
    var id: String { rawValue }
}

/// Bztam Plus (StoreKit 2, no server): a lifetime purchase, a yearly subscription, and a free 14-day trial item
/// that never charges by itself. iCloud sync, Face ID, notifications, widgets and Siri are never part of Plus
/// (App Review 4.10).
@MainActor
@Observable
final class Store {
    static let shared = Store()

    static let lifetimeID = "com.bzrmed.bztam.plus.lifetime"
    static let yearlyID = "com.bzrmed.bztam.plus.yearly"
    static let trialID = "com.bzrmed.bztam.plus.trial"
    static let trialDays = 14
    /// Savings goals included without Plus.
    static let freeGoals = 1

    private(set) var lifetime: Product?
    private(set) var yearly: Product?
    private(set) var trialProduct: Product?
    private(set) var productsFailed = false
    private(set) var ownsLifetime = false
    private(set) var yearlyActive = false
    private(set) var trialStart: Date?
    private(set) var busy = false

    private let args = ProcessInfo.processInfo.arguments
    /// `-paywallShot`: screenshot of the Plus screen for App Review (sample prices, no StoreKit).
    var paywallShot: Bool { args.contains("-paywallShot") }
    /// Demo data and UI tests have everything unlocked, unless they test the free version.
    private var demo: Bool { (args.contains("-demoData") || args.contains("-plusUnlocked")) && !paywallShot && !args.contains("-freeUser") }
    private var updates: Task<Void, Never>?

    private init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
    }

    // MARK: State

    var trialEnd: Date? { trialStart.map { $0.addingTimeInterval(Double(Self.trialDays) * 86_400) } }
    var trialActive: Bool { trialEnd.map { Date.now < $0 } ?? false }
    var trialUsed: Bool { trialStart != nil }
    var owns: Bool { ownsLifetime || yearlyActive }
    var isPlus: Bool { !testAsFree && (demo || owns || trialActive) }

    /// TestFlight builds only: pretend nothing was bought, to try the free version and the Plus screen again.
    static var isTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }
    var testAsFree: Bool = Store.isTestFlight && UserDefaults.standard.bool(forKey: "testAsFreeUser") {
        didSet { UserDefaults.standard.set(testAsFree, forKey: "testAsFreeUser") }
    }

    var canStartTrial: Bool { paywallShot || (!(testAsFree ? false : trialUsed) && trialProduct != nil && !owns) }

    var lifetimePrice: String? { lifetime?.displayPrice ?? (paywallShot ? "$24.99" : nil) }
    var yearlyPrice: String? { yearly?.displayPrice ?? (paywallShot ? "$9.99" : nil) }

    /// Runs `action` with Plus, otherwise opens the Plus screen for `reason`.
    func require(_ reason: PaywallReason, _ action: () -> Void) {
        if isPlus { action() } else { PlusPresenter.show(reason) }
    }

    // MARK: StoreKit

    func start() async {
        if paywallShot {
            try? await Task.sleep(for: .seconds(1))
            PlusPresenter.show(.general)
            return
        }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeID, Self.yearlyID, Self.trialID])
            lifetime = products.first { $0.id == Self.lifetimeID }
            yearly = products.first { $0.id == Self.yearlyID }
            trialProduct = products.first { $0.id == Self.trialID }
            productsFailed = lifetime == nil && yearly == nil
        } catch {
            productsFailed = true
        }
    }

    /// Reads what this Apple ID owns right now.
    func refresh() async {
        var life = false, year = false
        var trial: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            switch t.productID {
            case Self.lifetimeID: life = true
            case Self.yearlyID: year = (t.expirationDate ?? .distantFuture) > .now
            case Self.trialID: trial = t.purchaseDate
            default: break
            }
        }
        ownsLifetime = life
        yearlyActive = year
        trialStart = trial
    }

    @discardableResult
    func buy(_ product: Product?) async -> Bool {
        guard let product, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await product.purchase()
            guard case .success(let verification) = result, case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            await refresh()
            if transaction.productID == Self.trialID { scheduleTrialReminder() }
            if testAsFree { testAsFree = false }
            return isPlus
        } catch {
            return false
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
    }

    /// One reminder the day before the free trial ends. The trial never charges by itself.
    private func scheduleTrialReminder() {
        guard let end = trialEnd else { return }
        let fire = end.addingTimeInterval(-86_400)
        guard fire > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.t("Your Bztam Plus trial ends tomorrow")
        content.body = L10n.t("Your goals, scans and exports stay safe. Keep Plus to keep using them.")
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(identifier: "bztamPlusTrialEnds", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}

enum LegalLinks {
    static let site = URL(string: "https://bztam.netlify.app/")!
    static var terms: URL { URL(string: "https://bztam.netlify.app/" + prefix + "terms.html")! }
    static var privacy: URL { URL(string: "https://bztam.netlify.app/" + prefix + "privacy.html")! }
    private static var prefix: String { L10n.code == "en" ? "" : L10n.code + "/" }
}

/// Shows the Plus screen above whatever is on screen (a sheet, the Add screen…), from anywhere.
@MainActor
enum PlusPresenter {
    static func show(_ reason: PaywallReason) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        guard !(top is PaywallHost) else { return }
        let host = PaywallHost(rootView: AnyView(EmptyView()))
        host.rootView = AnyView(PaywallView(reason: reason) { [weak host] in host?.dismiss(animated: true) })
        host.modalPresentationStyle = .pageSheet
        top.present(host, animated: true)
    }
}

final class PaywallHost: UIHostingController<AnyView> {}
