import UIKit

/// Receipt and bill images, saved as compressed JPEG files in the App Group. The database keeps only the file name.
enum AttachmentStore {
    static var folder: URL {
        let base = AppGroup.containerURL ?? URL.applicationSupportDirectory
        let url = base.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for name: String) -> URL { folder.appendingPathComponent(name) }

    /// Saves an image (longest side 1600 px, JPEG quality 0.7) and returns its file name.
    static func save(_ image: UIImage) -> String? {
        let resized = resize(image, maxSide: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: name).path)
    }

    /// Removes files no entry points to any more (older than a day, so Undo still works).
    static func removeOrphans(keeping names: Set<String>) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date.now.addingTimeInterval(-86_400)
        for file in files where !names.contains(file.lastPathComponent) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
            if modified < cutoff { try? fm.removeItem(at: file) }
        }
    }

    static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
