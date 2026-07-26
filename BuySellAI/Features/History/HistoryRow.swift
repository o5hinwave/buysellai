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

            Text(HistoryAccessibilityText.savedPackageStatus(for: entry))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
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
            HistoryPhotoPlaceholder(category: entry.category)
        }
    }

    private var rowMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? HistoryRowLayout.accessibilityRowMinHeight : HistoryRowLayout.rowMinHeight
    }
}

private struct HistoryPhotoPlaceholder: View {
    let category: Category?

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(placeholderFill)
            .frame(width: HistoryRowLayout.thumbnailSize, height: HistoryRowLayout.thumbnailSize)
            .overlay {
                VStack(spacing: 1) {
                    Image(systemName: category?.placeholderSystemImage ?? AppSymbol.Flow.snapPhotoCompact)
                        .brandSymbol(.controlIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.brand.primaryText)
                        .accessibilityHidden(true)

                    Text("Placeholder".localized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .padding(.horizontal, 3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(Color.brand.border.opacity(0.7), lineWidth: 1)
            }
            .accessibilityLabel("Item photo placeholder".localized)
    }

    private var placeholderFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.brand.surfaceElevated,
                Color.brand.primaryMuted.opacity(0.62)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
            "%@, %@, %@, %@, %@",
            entry.itemName,
            entry.marketplace.displayName,
            relativeDate,
            thumbnailStatus(for: entry.imageThumbnail),
            savedPackageStatus(for: entry)
        )
    }

    static func thumbnailStatus(for data: Data?) -> String {
        guard let data, UIImage(data: data) != nil else {
            return "photo placeholder".localized
        }
        return "photo attached".localized
    }

    static func savedPackageStatus(for entry: HistoryEntry) -> String {
        var parts = ["Listing saved".localized]
        if entry.itemDetails != nil {
            parts.append("Answers saved".localized)
        }
        if entry.listingDraft != nil {
            parts.append("Post details saved".localized)
        }
        if entry.listingDraft?.evidenceSources?.isEmpty == false {
            parts.append("Evidence saved".localized)
        }
        return parts.joined(separator: " · ")
    }
}
