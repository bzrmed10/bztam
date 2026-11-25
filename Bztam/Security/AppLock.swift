import LocalAuthentication
import SwiftUI

/// Optional Face ID / passcode lock when the app opens or comes back from the background.
@MainActor
@Observable
final class AppLock {
    static let enabledKey = "faceIDLock"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    var locked: Bool
    /// Face ID is turned off for Bztam in the iPhone's Settings (only the passcode works).
    var faceIDDenied = false
    private var authenticating = false

    init() {
        locked = Self.isEnabled && !LaunchOptions.demoData && !LaunchOptions.freshStart
    }

    func lockIfNeeded() {
        if Self.isEnabled { locked = true }
    }

    /// Asks only once the app is really on screen: Face ID can't run while the app is still opening,
    /// and iOS then goes straight to the passcode.
    func unlock() async {
        guard locked, !authenticating, UIApplication.shared.applicationState == .active else { return }
        authenticating = true
        defer { authenticating = false }
        faceIDDenied = Self.biometryDenied
        if await Self.authenticate(reason: L10n.t("Unlock Bztam")) { locked = false }
    }

    /// The user said "Don't Allow" to Face ID for Bztam, or turned it off in Settings → Bztam.
    static var biometryDenied: Bool {
        var error: NSError?
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { return false }
        return (error as? LAError)?.code == .biometryNotAvailable && context.biometryType != .none
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
    var faceIDDenied = false
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            IconCircle(symbol: "lock.fill", size: 72, fill: Theme.Colors.brand, tint: Theme.Colors.onBrand)
            Text(L10n.t("Bztam is locked")).font(.bzTitleXL)
            Text(L10n.t("Use Face ID or your passcode to open it.")).font(.bzBody).foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
            if faceIDDenied {
                Button(L10n.t("Face ID is off for Bztam. Turn it on in Settings.")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.bzCaption)
                .foregroundStyle(Theme.Colors.link)
                .multilineTextAlignment(.center)
            }
            Spacer()
            Button(L10n.t("Unlock"), action: unlock).buttonStyle(.pillPrimary)
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
    }
}
