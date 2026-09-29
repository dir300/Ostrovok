import AppKit
import Combine
import SwiftUI
import QuickLookThumbnailing

struct ShelfItem: Identifiable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool

    var name: String { url.lastPathComponent }
}

/// Drag & drop file shelf: drop files onto the island, keep them here, then
/// drag them back out into another app or reveal them in Finder.
///
/// Thumbnails are generated asynchronously via QuickLook and cached by item id.
@MainActor
final class ShelfStore: ObservableObject, Feature {
    let id = "shelf"
    let titleKey = "feature.shelf"
    let symbolName = "tray"

    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]
    private let maxItems = 30

    func add(_ urls: [URL]) {
        for url in urls {
            guard !items.contains(where: { $0.url == url }) else { continue }
            let item = Self.makeItem(url)
            items.insert(item, at: 0)
            loadThumbnail(for: item)
        }
        if items.count > maxItems {
            let dropped = Array(items.dropFirst(maxItems))
            items = Array(items.prefix(maxItems))
            for item in dropped { thumbnails.removeValue(forKey: item.id) }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        thumbnails.removeValue(forKey: item.id)
    }

    func clear() {
        items.removeAll()
        thumbnails.removeAll()
    }

    func thumbnail(for item: ShelfItem) -> NSImage? {
        thumbnails[item.id]
    }

    private static func makeItem(_ url: URL) -> ShelfItem {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return ShelfItem(url: url, isDirectory: isDir)
    }

    private func loadThumbnail(for item: ShelfItem) {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 44, height: 44),
            scale: 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let representation else { return }
            let image = representation.nsImage
            Task { @MainActor in
                guard let self else { return }
                if self.items.contains(where: { $0.id == item.id }) {
                    self.thumbnails[item.id] = image
                }
            }
        }
    }

    var expandedView: AnyView { AnyView(ShelfView(model: self)) }
}
