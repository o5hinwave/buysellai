import SwiftUI

struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        HStack(spacing: Spacing.md) {
            thumbnail

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.itemName)
                    .brandFont(.bodyLg)
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(String.localizedFormat("%@ · %@", entry.marketplace.displayName, relativeDate(entry.createdAt)))
                    .brandFont(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brand.mutedForeground)
                .accessibilityHidden(true)
        }
        .padding(Spacing.sm)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.imageThumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.brand.primaryMuted)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.brand.primary)
                }
        }
    }
}

private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
