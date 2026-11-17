import SwiftUI

/// Placeholder screen for Milestone 0. It proves the pipeline: build, test, sign, upload.
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Bztam")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Where your money goes.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("placeholder")
    }
}

#Preview {
    RootView()
}
