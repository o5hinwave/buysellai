import SwiftUI

enum HistoryRowLayout {
    static let thumbnailSize: CGFloat = 56
    static let rowMinHeight: CGFloat = 72
    static let accessibilityRowMinHeight: CGFloat = 112
}

struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        rowContent
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: rowMinHeight)
    }

    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityRowContent
        } else {
            regularRowContent
        }
    }

    private var regularRowContent: some View {
        HStack(spacing: Spacing.md) {
            thumbnail

            historyCopy(itemLineLimit: 1, metaLineLimit: 1)

            Spacer(minLength: Spacing.sm)
            chevron
        }
    }

    private var accessibilityRowContent: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            thumbnail
            historyCopy(itemLineLimit: 3, metaLineLimit: 2)
                .padding(.trailing, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            chevron
        }
    }

    private func historyCopy(itemLineLimit: Int, metaLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(entry.itemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(itemLineLimit)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)

            Text(String.localizedFormat("%@ · %@", entry.marketplace.displayName, relativeDate(entry.createdAt)))
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(metaLineLimit)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.leading)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .brandSymbol(.chevron)
            .foregroundStyle(Color.brand.mutedForeground)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.imageThumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: HistoryRowLayout.thumbnailSize, height: HistoryRowLayout.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.brand.primaryMuted)
                .frame(width: HistoryRowLayout.thumbnailSize, height: HistoryRowLayout.thumbnailSize)
                .overlay {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Color.brand.primaryText)
                }
        }
    }

    private var rowMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? HistoryRowLayout.accessibilityRowMinHeight : HistoryRowLayout.rowMinHeight
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

enum HistoryAccessibilityText {
    static func rowLabel(for entry: HistoryEntry, relativeDate: String) -> String {
        String.localizedFormat(
            "%@, %@, %@, %@",
            entry.itemName,
            entry.marketplace.displayName,
            relativeDate,
            thumbnailStatus(for: entry.imageThumbnail)
        )
    }

    static func thumbnailStatus(for data: Data?) -> String {
        guard let data, UIImage(data: data) != nil else {
            return "no photo".localized
        }
        return "photo attached".localized
    }
}
