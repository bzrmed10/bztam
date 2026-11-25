import StoreKit
import SwiftUI

/// The Bztam Plus screen: a free 14-day trial, then Lifetime (pay once) or Yearly.
struct PaywallView: View {
    let reason: PaywallReason
    /// Closes the screen when it was shown from UIKit (see `PlusPresenter`).
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismissAction
    @Environment(\.openURL) private var openURL
    @State private var store = Store.shared
    @State private var plan: Plan = .lifetime
    @State private var redeeming = false
    @State private var unlocked = false

    enum Plan { case lifetime, yearly }

    private struct Benefit: Identifiable {
        let id: PaywallReason
        let symbol: String
        let title: String
        let detail: String
    }

    private var benefits: [Benefit] {
        let all = [
            Benefit(id: .goals, symbol: "target", title: L10n.t("Unlimited savings goals"),
                    detail: L10n.t("A trip, Eid, a new phone: save for all of them.")),
            Benefit(id: .scan, symbol: "doc.viewfinder", title: L10n.t("Scan receipts and bills"),
                    detail: L10n.t("Snap a receipt or import a PDF bill: Bztam fills it in.")),
            Benefit(id: .monthEnd, symbol: "arrow.uturn.forward", title: L10n.t("Month end on autopilot"),
                    detail: L10n.t("What's left goes where you chose, every payday.")),
            Benefit(id: .export, symbol: "square.and.arrow.up", title: L10n.t("Export and backups"),
                    detail: L10n.t("Your expenses as a spreadsheet, or a full backup file."))
        ]
        guard let i = all.firstIndex(where: { $0.id == reason }) else { return all }
        var sorted = all
        sorted.insert(sorted.remove(at: i), at: 0)
        return sorted
    }

    private var headline: String {
        switch reason {
        case .general: L10n.t("Get more from your money.")
        case .goals: L10n.t("Save for everything you want.")
        case .scan: L10n.t("Snap it, it's added.")
        case .monthEnd: L10n.t("Payday, sorted by itself.")
        case .export: L10n.t("Take your data anywhere.")
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    benefitList
                    plans
                    actions
                    footer
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, 34)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                .accessibilityIdentifier("plus.close")
                .padding(16)
        }
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .overlay { if unlocked { success } }
        .offerCodeRedemption(isPresented: $redeeming) { _ in
            Task { await store.refresh(); if store.isPlus { celebrate() } }
        }
        .task { if store.lifetime == nil && !store.paywallShot { await store.loadProducts() } }
    }

    // MARK: Pieces

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("Bztam ")
                Text("Plus").foregroundStyle(Theme.Colors.onBrand)
                    .padding(.horizontal, 10).padding(.vertical, 2)
                    .background(Theme.Colors.brand, in: Capsule())
            }
            .font(.scaled(size: 30, weight: .heavy))
            Text(headline).font(.scaled(size: 22, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("Your budget, expenses, iCloud sync, widgets and Face ID stay free."))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
        }
        .padding(.trailing, 44)
    }

    private var benefitList: some View {
        VStack(spacing: 0) {
            ForEach(benefits) { b in
                HStack(spacing: 14) {
                    IconCircle(symbol: b.symbol, size: 42, fill: b.id == reason ? Theme.Colors.brand : Theme.Colors.canvas,
                               tint: b.id == reason ? Theme.Colors.onBrand : Theme.Colors.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.title).font(.scaled(size: 16, weight: .bold))
                        Text(b.detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 4)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var plans: some View {
        VStack(spacing: 10) {
            planCard(.lifetime, title: L10n.t("Lifetime"), detail: L10n.t("Pay once. Yours forever. Family Sharing included."),
                     price: store.lifetimePrice, badge: L10n.t("Best value"))
            planCard(.yearly, title: L10n.t("Yearly"), detail: L10n.t("Renews every year. Cancel anytime."),
                     price: store.yearlyPrice.map { L10n.t("%@ a year", $0) }, badge: nil)
        }
    }

    private func planCard(_ p: Plan, title: String, detail: String, price: String?, badge: String?) -> some View {
        let on = plan == p
        return Button {
            withAnimation(.snappy) { plan = p }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.scaled(size: 22))
                    .foregroundStyle(on ? Theme.Colors.positive : Theme.Colors.line)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.scaled(size: 17, weight: .heavy))
                        if let badge {
                            Text(badge).font(.scaled(size: 11, weight: .heavy))
                                .foregroundStyle(Theme.Colors.onBrand)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.Colors.brand, in: Capsule())
                        }
                    }
                    Text(detail).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Group {
                    if let price { Text(price) } else if store.productsFailed { Image(systemName: "wifi.exclamationmark") } else { ProgressView() }
                }
                .font(.scaled(size: 17, weight: .heavy))
            }
            .padding(16)
            .background(on ? Theme.Colors.brandTint : Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(on ? Theme.Colors.ink : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(p == .lifetime ? "plus.lifetime" : "plus.yearly")
    }

    private var chosen: Product? { plan == .lifetime ? store.lifetime : store.yearly }
    private var chosenPrice: String? { plan == .lifetime ? store.lifetimePrice : store.yearlyPrice }

    private var actions: some View {
        VStack(spacing: 10) {
            if store.productsFailed && chosenPrice == nil {
                Text(L10n.t("Couldn't reach the App Store. Check your connection."))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).multilineTextAlignment(.center)
                Button(L10n.t("Try again")) { Task { await store.loadProducts() } }.buttonStyle(.pillSecondary)
            } else {
                if store.canStartTrial {
                    Button { purchase(store.trialProduct) } label: { label(L10n.t("Try Plus free for %d days", Store.trialDays)) }
                        .buttonStyle(.pillPrimary)
                        .accessibilityIdentifier("plus.trial")
                    Text(L10n.t("Free for 14 days. No automatic charge, nothing to cancel."))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).multilineTextAlignment(.center)
                }
                Button { purchase(chosen) } label: {
                    label(chosenPrice.map { plan == .lifetime ? L10n.t("Get Lifetime · %@", $0) : L10n.t("Get Yearly · %@", $0) }
                          ?? L10n.t("Get Bztam Plus"))
                }
                .buttonStyle(PillButtonStyle(kind: store.canStartTrial ? .secondary : .primary))
                .accessibilityIdentifier("plus.buy")
                if plan == .yearly, let price = store.yearlyPrice {
                    Text(L10n.t("%@ a year, renews automatically until you cancel. Cancel anytime in Settings → your name → Subscriptions, at least 24 hours before it renews.", price))
                        .font(.scaled(size: 11, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted).multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(store.busy)
    }

    private func label(_ title: String) -> some View {
        HStack(spacing: 8) {
            if store.busy { ProgressView() }
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button(L10n.t("Restore purchases")) { Task { await store.restore(); if store.isPlus { celebrate() } } }
                Button(L10n.t("Redeem code")) { redeeming = true }
            }
            .font(.scaled(size: 14, weight: .bold))
            HStack(spacing: 18) {
                Button(L10n.t("Terms of Use")) { openURL(LegalLinks.terms) }
                Button(L10n.t("Privacy Policy")) { openURL(LegalLinks.privacy) }
            }
            .font(.scaled(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Colors.inkMuted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var success: some View {
        ZStack {
            Theme.Colors.canvas.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 12) {
                IconCircle(symbol: "checkmark", size: 80, fill: Theme.Colors.brand, tint: Theme.Colors.onBrand)
                Text(L10n.t("Bztam Plus is on")).font(.scaled(size: 26, weight: .heavy))
                Text(store.trialActive && !store.owns ? L10n.t("Enjoy everything free for %d days.", Store.trialDays)
                                                      : L10n.t("Thank you for supporting Bztam."))
                    .font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .transition(.opacity)
    }

    // MARK: Actions

    private func dismiss() {
        if let onClose { onClose() } else { dismissAction() }
    }

    private func purchase(_ product: Product?) {
        Task {
            // Cancelled or failed: nothing was charged, the screen stays.
            if await store.buy(product) { celebrate() }
        }
    }

    private func celebrate() {
        withAnimation(.smooth) { unlocked = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }
}

/// Top of Settings: your plan when you have Plus, or an invitation to try it.
struct PlusCard: View {
    let store: Store
    let manage: () -> Void

    private var plan: String {
        if store.testAsFree { return L10n.t("Free") }
        if store.ownsLifetime || store.demo { return L10n.t("Lifetime") }
        if store.yearlyActive { return L10n.t("Yearly") }
        if store.trialActive, let end = store.trialEnd {
            let days = max(1, Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 1)
            return days == 1 ? L10n.t("Trial · 1 day left") : L10n.t("Trial · %d days left", days)
        }
        return L10n.t("Free")
    }

    var body: some View {
        let plus = store.isPlus
        Button {
            if store.yearlyActive { manage() } else if !store.ownsLifetime || store.testAsFree { PlusPresenter.show(.general) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 0) {
                    Text("Bztam ")
                    Text("Plus").foregroundStyle(Theme.Colors.onBrand)
                        .padding(.horizontal, 8).padding(.vertical, 1)
                        .background(plus ? Theme.Colors.canvas : Theme.Colors.brand, in: Capsule())
                    Spacer(minLength: 8)
                    Text(plan)
                        .font(.scaled(size: 13, weight: .heavy))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(plus ? Theme.Colors.canvas.opacity(0.7) : Theme.Colors.canvas, in: Capsule())
                }
                .font(.scaled(size: 20, weight: .heavy))
                if plus {
                    Text(store.trialActive && !store.owns
                         ? L10n.t("Everything is on during your trial: goals, scans, autopilot and exports.")
                         : L10n.t("Everything is on: unlimited goals, scans, month-end autopilot and exports."))
                        .font(.bzCaption)
                    if store.yearlyActive {
                        Text(L10n.t("Manage subscription")).font(.scaled(size: 14, weight: .bold)).underline()
                    } else if store.trialActive && !store.owns {
                        Text(L10n.t("Keep Plus")).font(.scaled(size: 14, weight: .bold)).underline()
                    }
                } else {
                    Text(L10n.t("Unlimited goals, receipt scanning, month-end autopilot and exports."))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    Text(store.canStartTrial ? L10n.t("Try Plus free for %d days", Store.trialDays) : L10n.t("Get Bztam Plus"))
                        .font(.scaled(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.onBrand)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.Colors.brand, in: Capsule())
                }
            }
            .foregroundStyle(plus ? Theme.Colors.onBrand : Theme.Colors.ink)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(plus ? Theme.Colors.brand : Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("settings.plus")
    }
}
