import AppKit
import Combine
import SwiftUI

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let date: Date
}

/// Clipboard history: polls `NSPasteboard.changeCount` on the shared mouse timer
/// and keeps a small ring buffer of recent text entries.
///
/// Currently text-only. Images/files would extend `ClipboardItem` with a kind
/// enum and read `NSPasteboard.PasteboardType.png` / `.fileURL`.
@MainActor
final class ClipboardStore: ObservableObject, Feature {
    let id = "clipboard"
    let titleKey = "feature.clipboard"
    let symbolName = "doc.on.clipboard"

    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 50
    private var lastChangeCount = NSPasteboard.general.changeCount

    func tick() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        guard items.first?.text != text else { return }
        items.insert(ClipboardItem(text: text, date: Date()), at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    func copy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        // Move to top.
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let moved = items.remove(at: index)
            items.insert(moved, at: 0)
        }
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    // MARK: - Feature

    var expandedView: AnyView { AnyView(ClipboardView(model: self)) }
}
