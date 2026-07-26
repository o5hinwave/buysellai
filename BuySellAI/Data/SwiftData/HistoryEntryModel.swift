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
    var suggestedPriceRawValue: String?
    @Attribute(.externalStorage) var imageThumbnail: Data?
    var marketplaceRawValue: String
    var listingText: String
    @Attribute(.externalStorage) var itemDetailsJSON: Data?
    @Attribute(.externalStorage) var listingDraftJSON: Data?
    @Attribute(.externalStorage) var identificationProfileJSON: Data?

    init(entry: HistoryEntry) {
        self.id = entry.id
        self.createdAt = entry.createdAt
        self.itemName = entry.itemName
        self.categoryRawValue = entry.category?.rawValue
        self.conditionRawValue = entry.condition?.rawValue
        self.suggestedPrice = entry.suggestedPrice?.doubleValue
        self.suggestedPriceRawValue = entry.suggestedPrice.map(Self.decimalString)
        self.imageThumbnail = entry.imageThumbnail
        self.marketplaceRawValue = entry.marketplace.rawValue
        self.listingText = entry.listingText
        self.itemDetailsJSON = Self.encoded(entry.itemDetails)
        self.listingDraftJSON = Self.encoded(entry.listingDraft)
        self.identificationProfileJSON = Self.encoded(entry.identificationProfile)
    }

    func update(from entry: HistoryEntry) {
        id = entry.id
        createdAt = entry.createdAt
        itemName = entry.itemName
        categoryRawValue = entry.category?.rawValue
        conditionRawValue = entry.condition?.rawValue
        suggestedPrice = entry.suggestedPrice?.doubleValue
        suggestedPriceRawValue = entry.suggestedPrice.map(Self.decimalString)
        imageThumbnail = entry.imageThumbnail
        marketplaceRawValue = entry.marketplace.rawValue
        listingText = entry.listingText
        itemDetailsJSON = Self.encoded(entry.itemDetails)
        listingDraftJSON = Self.encoded(entry.listingDraft)
        identificationProfileJSON = Self.encoded(entry.identificationProfile)
    }

    var entry: HistoryEntry {
        HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: itemName,
            category: categoryRawValue.flatMap(Category.init(rawValue:)),
            condition: conditionRawValue.flatMap(Condition.init(rawValue:)),
            suggestedPrice: Self.decimal(from: suggestedPriceRawValue) ?? suggestedPrice.map { Decimal($0) },
            imageThumbnail: imageThumbnail,
            marketplace: Marketplace(rawValue: marketplaceRawValue) ?? .ebay,
            listingText: listingText,
            itemDetails: Self.decoded(ItemDetailAnswers.self, from: itemDetailsJSON)?.sanitizedForUse,
            listingDraft: Self.decoded(GeneratedListingDraft.self, from: listingDraftJSON)?.sanitizedForDisplay(),
            identificationProfile: Self.decoded(AnalyzeIdentificationProfile.self, from: identificationProfileJSON)?.sanitizedForDisplay()
        )
    }

    private static func encoded<Value: Encodable>(_ value: Value?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }

    private static func decoded<Value: Decodable>(_ value: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(value, from: data)
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func decimal(from rawValue: String?) -> Decimal? {
        guard let rawValue else { return nil }
        return Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX"))
    }
}
