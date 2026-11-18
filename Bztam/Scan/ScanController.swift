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

    /// A PDF bill: embedded text first, text recognition for scanned pages.
    func read(pdf url: URL, source: EntrySource) async -> Bool {
        isReading = true
        guard let result = await PDFImporter.read(url), !result.pages.isEmpty else {
            isReading = false
            return false
        }
        let receipt = ReceiptParser.parse(lines: result.lines)
        isReading = false
        draft = ScanDraft(images: result.pages, source: source, receipt: receipt)
        return true
    }

    /// Opens the oldest file shared from another app, if any, and removes it from the inbox.
    func openNextShared() async {
        guard draft == nil, !isReading, let url = ShareInbox.pending().first else { return }
        defer { ShareInbox.remove(url) }
        if url.pathExtension.lowercased() == "pdf" {
            _ = await read(pdf: url, source: .share)
        } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            await read([image], source: .share)
        }
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
