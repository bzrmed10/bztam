import SwiftUI

/// Shows "Deleted · Undo" for a few seconds after a delete and runs the undo action if tapped.
@MainActor
@Observable
final class UndoCenter {
    private(set) var message: String?
    private var action: (() -> Void)?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, undo: @escaping () -> Void) {
        self.message = message
        action = undo
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func performUndo() {
        action?()
        dismiss()
    }

    func dismiss() {
        message = nil
        action = nil
    }
}

struct UndoToast: View {
    let message: String
    let undo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.bzBodyStrong)
                .foregroundStyle(.white)
            Spacer()
            Button(L10n.t("Undo"), action: undo)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.brand)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Theme.Colors.toast, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
