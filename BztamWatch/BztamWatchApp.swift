import SwiftUI

@main
struct BztamWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}

/// Placeholder for Milestone 0. Milestone 6 shows what is left and adds quick add.
struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wallet.bifold")
                .font(.title2)
            Text("Bztam")
                .font(.system(.headline, design: .rounded))
        }
    }
}
