import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Share to Bztam": saves the shared image or PDF into the App Group inbox.
/// The next time Bztam opens, it reads the file and shows the review screen.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareCard(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        let boxes = providers.map(ShareImporter.ProviderBox.init)
        Task { @MainActor in
            var saved = false
            for box in boxes where !saved {
                saved = await ShareImporter.save(box)
            }
            model.state = saved ? .saved : .failed
        }
    }
}

@MainActor
@Observable
final class ShareModel {
    enum State { case saving, saved, failed }
    var state: State = .saving
}

/// Copies a shared item into the inbox. Runs off the main thread.
enum ShareImporter {
    struct ProviderBox: @unchecked Sendable {
        let provider: NSItemProvider
    }

    nonisolated static func save(_ box: ProviderBox) async -> Bool {
        guard let inbox = AppGroup.inboxURL else { return false }
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let provider = box.provider
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            guard let data = await loadData(provider, type: UTType.pdf.identifier) else { return false }
            return write(data, ext: "pdf", to: inbox)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            guard let data = await loadData(provider, type: UTType.image.identifier) else { return false }
            return write(data, ext: "image", to: inbox)
        }
        return false
    }

    nonisolated private static func loadData(_ provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type) { @Sendable data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    nonisolated private static func write(_ data: Data, ext: String, to inbox: URL) -> Bool {
        let url = inbox.appendingPathComponent("\(Int(Date.now.timeIntervalSince1970))-\(UUID().uuidString).\(ext)")
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

/// The small card shown in the share sheet.
private struct ShareCard: View {
    let model: ShareModel
    let done: () -> Void

    private static let fr = Locale.preferredLanguages.first?.hasPrefix("fr") == true
    private func t(_ en: String, _ fr: String) -> String { Self.fr ? fr : en }

    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { scheme == .dark }
    private func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    private var ink: Color { rgb(dark ? 0xE9F2E3 : 0x14290B) }
    private var lime: Color { rgb(0xA6E36F) }
    private var onLime: Color { rgb(0x14290B) }
    private var surface: Color { rgb(dark ? 0x1D261A : 0xEEF2EA) }
    private var muted: Color { rgb(dark ? 0x9DAA95 : 0x586452) }
    private var card: Color { rgb(dark ? 0x0F140D : 0xFFFFFF) }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                switch model.state {
                case .saving:
                    ProgressView().controlSize(.large).tint(ink)
                    Text(t("Adding to Bztam…", "Ajout à Bztam…")).font(.system(size: 17, weight: .semibold))
                case .saved:
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(onLime)
                        .frame(width: 64, height: 64)
                        .background(lime, in: Circle())
                    Text(t("Sent to Bztam", "Envoyé à Bztam")).font(.system(size: 22, weight: .heavy))
                    Text(t("Open Bztam to check the amount and save it.", "Ouvrez Bztam pour vérifier le montant et l'enregistrer."))
                        .font(.system(size: 15)).foregroundStyle(muted).multilineTextAlignment(.center)
                case .failed:
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 26, weight: .bold))
                        .frame(width: 64, height: 64)
                        .background(surface, in: Circle())
                    Text(t("Can't add this", "Impossible d'ajouter ceci")).font(.system(size: 22, weight: .heavy))
                    Text(t("Bztam can read images and PDF files.", "Bztam lit les images et les fichiers PDF."))
                        .font(.system(size: 15)).foregroundStyle(muted).multilineTextAlignment(.center)
                }
                Button(action: done) {
                    Text(t("Done", "OK"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(model.state == .failed ? ink : onLime)
                        .background(model.state == .failed ? surface : lime, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(model.state == .saving)
                .opacity(model.state == .saving ? 0.4 : 1)
            }
            .foregroundStyle(ink)
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(card, in: RoundedRectangle(cornerRadius: 28))
            .padding(16)
        }
        .background(Color.black.opacity(0.2).ignoresSafeArea())
    }
}
