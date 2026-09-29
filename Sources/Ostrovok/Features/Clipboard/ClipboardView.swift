import SwiftUI

struct ClipboardView: View {
    @ObservedObject var model: ClipboardStore
    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.items.isEmpty {
                EmptyState(L10n.text("clipboard.empty", settings.language), symbol: "doc.on.clipboard")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(model.items) { item in
                            ClipboardRow(item: item, onCopy: { model.copy(item) })
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Button(L10n.text("clipboard.clear", settings.language)) { model.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(item.text)
                .font(.system(size: 12))
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }
}
