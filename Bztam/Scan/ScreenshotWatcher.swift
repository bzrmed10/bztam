import Photos
import SwiftUI
import UIKit

/// When turned on in Settings, looks at the newest screenshot each time the app opens.
/// If it was taken in the last 10 minutes and reads like a bill, Home offers to add it.
@MainActor
@Observable
final class ScreenshotWatcher {
    static let enabledKey = "suggestScreenshots"
    private static let lastOfferedKey = "lastOfferedScreenshot"

    /// The screenshot to offer, if any.
    var suggestion: UIImage?
    private var suggestionID: String?

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks for photo access; returns true when the feature can work.
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func check() async {
        guard Self.isEnabled else { suggestion = nil; return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject,
              let created = asset.creationDate, created > Date.now.addingTimeInterval(-600),
              asset.localIdentifier != UserDefaults.standard.string(forKey: Self.lastOfferedKey) else { return }

        let id = asset.localIdentifier
        guard let image = await Self.loadImage(AssetBox(asset: asset)) else { return }
        let lines = await TextRecognizer.lines(in: image)
        guard ReceiptParser.parse(lines: lines).looksLikeBill else { return }
        suggestion = image
        suggestionID = id
    }

    /// Called when the user adds or dismisses the suggestion: it is never offered again.
    func clear() {
        if let id = suggestionID { UserDefaults.standard.set(id, forKey: Self.lastOfferedKey) }
        suggestion = nil
        suggestionID = nil
    }

    private struct AssetBox: @unchecked Sendable { let asset: PHAsset }

    nonisolated private static func loadImage(_ box: AssetBox) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: box.asset, targetSize: CGSize(width: 1600, height: 1600),
                                                  contentMode: .aspectFit, options: options) { @Sendable image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

/// Home card: "This screenshot looks like a bill".
struct ScreenshotSuggestionCard: View {
    let image: UIImage
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("New screenshot")).font(.bzBodyStrong)
                Text(L10n.t("It looks like a bill. Add it?")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer(minLength: 4)
            Button(L10n.t("Add"), action: onAdd)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Theme.Colors.brand, in: Capsule())
                .buttonStyle(.plain)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("Dismiss"))
        }
        .padding(12)
        .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .foregroundStyle(Theme.Colors.ink)
    }
}
