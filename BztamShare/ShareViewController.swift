import SwiftUI
import UIKit

/// Share extension entry point. Milestone 0 placeholder: shows a card and closes.
/// Milestone 3 saves the shared image or PDF into the App Group inbox for the app to review.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: SharePlaceholderView { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

private struct SharePlaceholderView: View {
    let done: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 44, weight: .semibold))
            Text("Bztam")
                .font(.system(.title, design: .rounded, weight: .bold))
            Button("Done", action: done)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
