import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var model: ShelfStore
    @EnvironmentObject private var settings: Settings

    var body: some View {
        if model.items.isEmpty {
            EmptyState(L10n.text("shelf.empty", settings.language), symbol: "tray")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(model.items) { item in
                            ShelfRow(
                                item: item,
                                thumbnail: model.thumbnail(for: item),
                                onRemove: { model.remove(item) }
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Text("\(model.items.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Button(L10n.text("shelf.clear", settings.language)) { model.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .foregroundStyle(.white)
        }
    }
}

private struct ShelfRow: View {
    let item: ShelfItem
    let thumbnail: NSImage?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: item.isDirectory ? "folder" : "doc")
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.white.opacity(0.6))
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            Text(item.name)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
