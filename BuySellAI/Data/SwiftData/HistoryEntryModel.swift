import Foundation
import SwiftData

@Model
final class HistoryEntryModel {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var itemName: String
    var categoryRawValue: String?
    var conditionRawValue: String?
    var suggestedPrice: Double?
    @Attribute(.externalStorage) var imageThumbnail: Data?
    var marketplaceRawValue: String
    var listingText: String

    init(entry: HistoryEntry) {
        self.id = entry.id
        self.createdAt = entry.createdAt
        self.itemName = entry.itemName
        self.categoryRawValue = entry.category?.rawValue
        self.conditionRawValue = entry.condition?.rawValue
        self.suggestedPrice = entry.suggestedPrice?.doubleValue
        self.imageThumbnail = entry.imageThumbnail
        self.marketplaceRawValue = entry.marketplace.rawValue
        self.listingText = entry.listingText
    }

    var entry: HistoryEntry {
        HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: itemName,
            category: categoryRawValue.flatMap(Category.init(rawValue:)),
            condition: conditionRawValue.flatMap(Condition.init(rawValue:)),
            suggestedPrice: suggestedPrice.map { Decimal($0) },
            imageThumbnail: imageThumbnail,
            marketplace: Marketplace(rawValue: marketplaceRawValue) ?? .ebay,
            listingText: listingText
        )
    }
}
