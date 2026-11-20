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
        let receipt = await ReceiptAI.improve(ReceiptParser.parse(lines: lines), lines: lines)
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
        let receipt = await ReceiptAI.improve(ReceiptParser.parse(lines: result.lines), lines: result.lines)
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

/// "Reading…" card shown while text recognition runs: a receipt with a lime line scanning down it.
struct ReadingOverlay: View {
    @State private var down = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.surface).frame(width: 64, height: 84)
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule().fill(Theme.Colors.line).frame(width: i == 4 ? 26 : 40, height: 5)
                        }
                    }
                    .padding(.top, 14)
                    Capsule().fill(Theme.Colors.brand).frame(width: 76, height: 4)
                        .shadow(color: Theme.Colors.brand.opacity(0.7), radius: 6)
                        .offset(y: down ? 80 : 0)
                }
                .frame(width: 76, height: 84)
                .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { down = true } }
                .accessibilityHidden(true)
                Text(L10n.t("Reading the receipt…")).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink)
            }
            .padding(28)
            .background(Theme.Colors.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.large))
        }
        .accessibilityElement(children: .combine)
    }
}
