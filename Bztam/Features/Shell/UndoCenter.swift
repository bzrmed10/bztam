import SwiftUI

/// Shows "Deleted · Undo" for a few seconds after a delete and runs the undo action if tapped.
@MainActor
@Observable
final class UndoCenter {
    private(set) var message: String?
    /// "Added" toasts show a check; "Deleted" ones an undo arrow.
    private(set) var success = false
    private var action: (() -> Void)?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, success: Bool = false, undo: @escaping () -> Void) {
        self.message = message
        self.success = success
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
    var success = false
    let undo: () -> Void
    @State private var shown = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: success ? "checkmark.circle.fill" : "trash")
                .font(.scaled(size: 18, weight: .semibold))
                .foregroundStyle(success ? Theme.Colors.brand : .white.opacity(0.8))
                .symbolEffect(.bounce, value: shown)
            Text(message)
                .font(.bzBodyStrong)
                .foregroundStyle(.white)
            Spacer()
            Button(L10n.t("Undo"), action: undo)
                .font(.scaled(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.brand)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Theme.Colors.toast, in: Capsule())
        .accessibilityElement(children: .contain)
        .onAppear { shown = true }
    }
}
