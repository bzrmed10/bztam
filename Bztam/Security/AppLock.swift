import LocalAuthentication
import SwiftUI

/// Optional Face ID / passcode lock when the app opens or comes back from the background.
@MainActor
@Observable
final class AppLock {
    static let enabledKey = "faceIDLock"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    var locked: Bool
    private var authenticating = false

    init() {
        locked = Self.isEnabled && !LaunchOptions.demoData && !LaunchOptions.freshStart
    }

    func lockIfNeeded() {
        if Self.isEnabled { locked = true }
    }

    func unlock() async {
        guard locked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        if await Self.authenticate(reason: L10n.t("Unlock Bztam")) { locked = false }
    }

    /// Face ID, Touch ID or the device passcode. True when the device has none set (nothing to protect with).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { @Sendable ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }
}

/// Covers the app while locked.
struct LockView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            IconCircle(symbol: "lock.fill", size: 72, fill: Theme.Colors.brand, tint: Theme.Colors.onBrand)
            Text(L10n.t("Bztam is locked")).font(.bzTitleXL)
            Text(L10n.t("Use Face ID or your passcode to open it.")).font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Button(L10n.t("Unlock"), action: unlock).buttonStyle(.pillPrimary)
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
    }
}
