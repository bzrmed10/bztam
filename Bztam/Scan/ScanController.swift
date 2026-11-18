import SwiftUI
import UIKit

/// A scanned receipt or bill waiting for the user to confirm it.
struct ScanDraft: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let source: EntrySource
    let receipt: ReceiptDraft
}

/// Runs text recognition and parsing, then hands a draft to the review screen.
@MainActor
@Observable
final class ScanController {
    var isReading = false
    var draft: ScanDraft?

    func read(_ images: [UIImage], source: EntrySource) async {
        guard !images.isEmpty else { return }
        isReading = true
        var lines: [String] = []
        for image in images {
            lines += await TextRecognizer.lines(in: image)
        }
        let receipt = ReceiptParser.parse(lines: lines)
        isReading = false
        draft = ScanDraft(images: images, source: source, receipt: receipt)
    }
}

/// "Reading…" card shown while text recognition runs.
struct ReadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(Theme.Colors.ink)
                Text(L10n.t("Reading the receipt…")).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink)
            }
            .padding(28)
            .background(Theme.Colors.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        }
        .accessibilityElement(children: .combine)
    }
}
