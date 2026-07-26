import Foundation

struct DetectedItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var category: Category
    var condition: Condition
    var priceEstimate: Decimal
    var currencyCode: String

    init(
        id: UUID = UUID(),
        name: String,
        category: Category,
        condition: Condition,
        priceEstimate: Decimal,
        currencyCode: String = "USD"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.condition = condition
        self.priceEstimate = priceEstimate
        self.currencyCode = currencyCode
    }
}

enum ItemPhotoSource: String, Codable, CaseIterable, Sendable, Hashable {
    case camera
    case photoLibrary
    case unknownUserPhoto
    case internetReference
    case aiEdited
}

enum ItemPhotoRole: String, Codable, CaseIterable, Sendable, Hashable {
    case cover
    case fullItem
    case label
    case condition
    case included
    case reference

    var displayTitle: String {
        switch self {
        case .cover:
            "Cover photo"
        case .fullItem:
            "Full item"
        case .label:
            "Label or model"
        case .condition:
            "Condition detail"
        case .included:
            "Included items"
        case .reference:
            "Reference only"
        }
    }

    var exportSlug: String {
        switch self {
        case .cover:
            "Cover"
        case .fullItem:
            "Full-Item"
        case .label:
            "Label"
        case .condition:
            "Condition"
        case .included:
            "Included"
        case .reference:
            "Reference"
        }
    }

    var listingPriority: Int {
        switch self {
        case .cover:
            0
        case .fullItem:
            1
        case .label:
            2
        case .included:
            3
        case .condition:
            4
        case .reference:
            99
        }
    }

    var utilityBase: Int {
        switch self {
        case .cover:
            92
        case .label:
            88
        case .fullItem:
            84
        case .condition:
            82
        case .included:
            76
        case .reference:
            0
        }
    }
}

struct ItemPhotoAsset: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let itemID: UUID
    var imageData: Data?
    var source: ItemPhotoSource
    var role: ItemPhotoRole
    var dateAdded: Date
    var verifies: String
    var isListingSafe: Bool
    var isAIEdited: Bool
    var relatedOriginalID: UUID?

    init(
        id: UUID = UUID(),
        itemID: UUID,
        imageData: Data?,
        source: ItemPhotoSource,
        role: ItemPhotoRole,
        dateAdded: Date = Date(),
        verifies: String,
        isListingSafe: Bool,
        isAIEdited: Bool = false,
        relatedOriginalID: UUID? = nil
    ) {
        self.id = id
        self.itemID = itemID
        self.imageData = imageData
        self.source = source
        self.role = role
        self.dateAdded = dateAdded
        self.verifies = Self.clean(verifies, fallback: role.displayTitle)
        self.isListingSafe = isListingSafe
        self.isAIEdited = isAIEdited
        self.relatedOriginalID = relatedOriginalID
    }

    var canExportToListing: Bool {
        isListingSafe &&
            imageData?.isEmpty == false &&
            source != .internetReference &&
            role != .reference
    }

    var photoUtilityScore: Int {
        guard canExportToListing else { return 0 }
        var score = role.utilityBase
        if source == .aiEdited, relatedOriginalID != nil {
            score += 6
        }
        if isAIEdited {
            score += 2
        }
        let lowerVerification = verifies.lowercased()
        if role == .condition,
           lowerVerification.contains("flaw") ||
            lowerVerification.contains("scratch") ||
            lowerVerification.contains("wear") ||
            lowerVerification.contains("damage") {
            score += 8
        }
        if role == .label,
           lowerVerification.contains("model") ||
            lowerVerification.contains("serial") ||
            lowerVerification.contains("tag") ||
            lowerVerification.contains("authentic") {
            score += 6
        }
        return min(max(score, 0), 100)
    }

    func listingPhotoUtility(for marketplace: Marketplace, duplicationPenalty: Int = 0) -> ListingPhotoUtility {
        ListingPhotoIntelligence.utility(
            for: listingPhotoCandidate,
            marketplace: marketplace,
            duplicationPenalty: duplicationPenalty
        )
    }

    func listingPhotoUtilityScore(for marketplace: Marketplace, duplicationPenalty: Int = 0) -> Int {
        listingPhotoUtility(for: marketplace, duplicationPenalty: duplicationPenalty).total
    }

    var listingPhotoCandidate: ListingPhotoCandidate {
        ListingPhotoCandidate(
            id: id,
            imageData: imageData ?? Data(),
            role: ListingPhotoRole(itemPhotoRole: role, source: source, verifies: verifies),
            source: ListingPhotoSource(itemPhotoSource: source),
            dateAdded: dateAdded,
            verifies: verifies
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false },
            isListingSafe: isListingSafe,
            isAIEdited: isAIEdited || source == .aiEdited,
            relatedOriginalID: relatedOriginalID,
            quality: ListingPhotoQuality(itemPhotoAsset: self),
            visualFingerprint: duplicateSignature
        )
    }

    var duplicateSignature: String? {
        guard let imageData, imageData.isEmpty == false else { return nil }
        let prefix = imageData.prefix(32).map { String(format: "%02x", $0) }.joined()
        return "\(imageData.count)-\(prefix)"
    }

    func exportFileName(for item: DetectedItem, index: Int) -> String {
        let itemName = Self.fileSlug(item.name, fallback: item.category.display)
        let number = String(format: "%02d", index)
        return "\(itemName)-\(number)-\(role.exportSlug).jpg"
    }

    static func originalUserPhoto(item: DetectedItem, imageData: Data?) -> ItemPhotoAsset? {
        guard let imageData, imageData.isEmpty == false else { return nil }
        return ItemPhotoAsset(
            itemID: item.id,
            imageData: imageData,
            source: .unknownUserPhoto,
            role: .cover,
            verifies: "The actual item photo.",
            isListingSafe: true
        )
    }

    static func targetedScan(
        item: DetectedItem,
        imageData: Data,
        request: TargetedScanRequest,
        evidence: NativeScanEvidence? = nil
    ) -> ItemPhotoAsset? {
        guard imageData.isEmpty == false else { return nil }
        let role = ItemPhotoRole(scanRole: request.role)
        return ItemPhotoAsset(
            itemID: item.id,
            imageData: imageData,
            source: .camera,
            role: role,
            verifies: Self.targetedScanVerificationSummary(request: request, evidence: evidence),
            isListingSafe: role != .reference
        )
    }

    private static func targetedScanVerificationSummary(
        request: TargetedScanRequest,
        evidence: NativeScanEvidence?
    ) -> String {
        guard let evidence else { return request.title }
        switch request.role {
        case .barcode:
            let payloads = evidence.barcodes.map(\.payload).filter { $0.isEmpty == false }
            guard payloads.isEmpty == false else { return request.title }
            return "Barcode: \(payloads.prefix(2).joined(separator: ", "))"
        case .label, .serial, .sizeTag, .authenticity:
            let candidates = evidence.modelOrSerialCandidates.isEmpty
                ? evidence.recognizedText
                : evidence.modelOrSerialCandidates
            guard let first = candidates.first, first.isEmpty == false else { return request.title }
            return "\(request.title): \(first)"
        case .accessories:
            return "Included items photo attached."
        case .condition:
            return "Condition detail photo attached."
        case .fullItem:
            return "Full item photo attached."
        }
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let cleanValue = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? fallback : String(cleanValue.prefix(120))
    }

    private static func fileSlug(_ value: String, fallback: String) -> String {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? fallback : value
        let allowed = CharacterSet.alphanumerics
        let parts = cleanValue.unicodeScalars.reduce(into: [String]()) { result, scalar in
            if allowed.contains(scalar) {
                result.append(String(scalar))
            } else if result.last != "-" {
                result.append("-")
            }
        }
        let slug = parts
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "BuySell-Item" : String(slug.prefix(64))
    }
}

struct ListingPhotoPackage: Codable, Sendable, Hashable {
    let itemID: UUID
    let marketplace: Marketplace
    var photos: [ItemPhotoAsset]
    var excludedReferenceImageURL: String?

    var listingReadyPhotos: [ItemPhotoAsset] {
        let validPhotos = photos
            .filter { $0.itemID == itemID && $0.canExportToListing }
        var uniquePhotos: [String: ItemPhotoAsset] = [:]

        for photo in validPhotos {
            let key = photo.duplicateSignature ?? photo.id.uuidString
            guard let existingPhoto = uniquePhotos[key] else {
                uniquePhotos[key] = photo
                continue
            }

            if photo.isBetterListingPhoto(than: existingPhoto, marketplace: marketplace) {
                uniquePhotos[key] = photo
            }
        }

        return uniquePhotos.values.sorted { lhs, rhs in
            if lhs.role.listingPriority != rhs.role.listingPriority {
                return lhs.role.listingPriority < rhs.role.listingPriority
            }
            let lhsUtility = lhs.listingPhotoUtilityScore(for: marketplace)
            let rhsUtility = rhs.listingPhotoUtilityScore(for: marketplace)
            if lhsUtility != rhsUtility {
                return lhsUtility > rhsUtility
            }
            if lhs.dateAdded != rhs.dateAdded {
                return lhs.dateAdded < rhs.dateAdded
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var recommendedListingPhotos: [ItemPhotoAsset] {
        let readyPhotos = listingReadyPhotos
        guard readyPhotos.isEmpty == false else { return [] }

        let recommendedRoles = marketplace.listingPlaybook.recommendedPhotoSequence
        var selectedPhotos: [ItemPhotoAsset] = []
        var selectedIDs = Set<UUID>()

        for role in recommendedRoles {
            guard let photo = bestPhoto(for: role, in: readyPhotos, excluding: selectedIDs) else { continue }
            selectedPhotos.append(photo)
            selectedIDs.insert(photo.id)
        }

        return selectedPhotos.isEmpty ? Array(readyPhotos.prefix(1)) : selectedPhotos
    }

    var missingRecommendedPhotoRole: ItemPhotoRole? {
        let roles = Set(listingReadyPhotos.map(\.role))
        return marketplace.listingPlaybook.recommendedPhotoSequence.first { role in
            hasEquivalentPhoto(for: role, in: roles) == false
        }
    }

    var hasReferenceOnlyImage: Bool {
        excludedReferenceImageURL != nil ||
            photos.contains { $0.source == .internetReference || $0.role == .reference }
    }

    var statusTitle: String {
        switch recommendedListingPhotos.count {
        case 0:
            "No listing photos ready"
        case 1:
            "Your photo is ready"
        default:
            String.localizedFormat("Your %d best photos are ready", recommendedListingPhotos.count)
        }
    }

    var recommendation: String {
        if recommendedListingPhotos.isEmpty {
            if hasReferenceOnlyImage {
                return "Reference image stays out. Add a real item photo before posting.".localized
            }
            return "Add a real item photo before posting.".localized
        }
        if let missingRecommendedPhotoRole {
            return String.localizedFormat(
                "Add one %@ photo for a stronger listing.".localized,
                missingRecommendedPhotoRole.displayTitle.localized.lowercased()
            )
        }
        if hasReferenceOnlyImage {
            return "Reference images stay out of your listing photos.".localized
        }
        if recommendedListingPhotos.count >= 3 {
            return String.localizedFormat("These %d photos are enough to post.".localized, recommendedListingPhotos.count)
        }
        return "This photo set is ready to save.".localized
    }

    static func makeForListing(
        item: DetectedItem,
        marketplace: Marketplace,
        originalImageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        referenceImageURL: String?
    ) -> ListingPhotoPackage {
        var photos: [ItemPhotoAsset] = []
        if let original = ItemPhotoAsset.originalUserPhoto(item: item, imageData: originalImageData) {
            photos.append(original)
        }
        photos.append(contentsOf: supplementalPhotos.filter { $0.itemID == item.id })
        return ListingPhotoPackage(
            itemID: item.id,
            marketplace: marketplace,
            photos: photos,
            excludedReferenceImageURL: referenceImageURL
        )
    }

    func exportFiles(
        for item: DetectedItem,
        scope: ListingPhotoExportScope = .recommended
    ) -> [ListingPhotoExport] {
        let selectedPhotos: [ItemPhotoAsset]
        switch scope {
        case .recommended:
            selectedPhotos = recommendedListingPhotos
        case .allListingReady:
            selectedPhotos = listingReadyPhotos
        }

        return selectedPhotos.enumerated().compactMap { index, photo in
            guard let imageData = photo.imageData, imageData.isEmpty == false else { return nil }
            return ListingPhotoExport(
                imageData: imageData,
                fileName: photo.exportFileName(for: item, index: index + 1),
                role: photo.role,
                verifies: photo.verifies
            )
        }
    }

    func exportFile(for item: DetectedItem, photoID: UUID) -> ListingPhotoExport? {
        listingReadyPhotos.enumerated().compactMap { index, photo -> ListingPhotoExport? in
            guard photo.id == photoID,
                  let imageData = photo.imageData,
                  imageData.isEmpty == false else { return nil }
            return ListingPhotoExport(
                imageData: imageData,
                fileName: photo.exportFileName(for: item, index: index + 1),
                role: photo.role,
                verifies: photo.verifies
            )
        }
        .first
    }

    private func bestPhoto(
        for role: ItemPhotoRole,
        in photos: [ItemPhotoAsset],
        excluding selectedIDs: Set<UUID>
    ) -> ItemPhotoAsset? {
        photos.first { photo in
            selectedIDs.contains(photo.id) == false && photo.role == role
        }
    }

    private func hasEquivalentPhoto(for role: ItemPhotoRole, in roles: Set<ItemPhotoRole>) -> Bool {
        if roles.contains(role) {
            return true
        }
        switch role {
        case .cover:
            return roles.contains(.fullItem)
        case .fullItem:
            return roles.contains(.cover)
        default:
            return false
        }
    }
}

enum ListingPhotoExportScope: String, Codable, Sendable, Hashable {
    case recommended
    case allListingReady
}

struct ListingPhotoExport: Codable, Sendable, Hashable {
    let imageData: Data
    let fileName: String
    let role: ItemPhotoRole
    let verifies: String
}

enum MarketplacePhotoScanPlaybook {
    static func targetedScanRequest(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers,
        supplementalPhotos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        let currentPhotos = supplementalPhotos.filter { $0.itemID == item.id }

        switch marketplace {
        case .ebay, .mercari, .amazon, .bonanza, .shopify:
            return productIdentifierScanIfNeeded(for: item, answers: answers, photos: currentPhotos)
                ?? accessoriesScanIfNeeded(answers: answers, photos: currentPhotos)
        case .facebook, .craigslist, .offerup, .nextdoor:
            return localConditionScanIfNeeded(for: item, answers: answers, photos: currentPhotos)
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy, .kidizen, .tradesy:
            return fashionTagScanIfNeeded(for: item, answers: answers, photos: currentPhotos)
                ?? conditionScanIfNeeded(answers: answers, photos: currentPhotos)
        case .stockx, .goat:
            return authenticityScanIfNeeded(for: item, answers: answers, photos: currentPhotos)
        case .swappa:
            return swappaModelScanIfNeeded(answers: answers, photos: currentPhotos)
                ?? conditionScanIfNeeded(answers: answers, photos: currentPhotos)
        case .reverb:
            return serialPlateScanIfNeeded(answers: answers, photos: currentPhotos)
                ?? conditionScanIfNeeded(answers: answers, photos: currentPhotos)
        case .etsy, .chairish, .rubylane:
            return makerMarkScanIfNeeded(for: item, answers: answers, photos: currentPhotos)
                ?? conditionScanIfNeeded(answers: answers, photos: currentPhotos)
        case .whatnot:
            return accessoriesScanIfNeeded(answers: answers, photos: currentPhotos)
                ?? conditionScanIfNeeded(answers: answers, photos: currentPhotos)
        case .tcgplayer:
            return cardDetailScanIfNeeded(answers: answers, photos: currentPhotos)
        }
    }

    private static func productIdentifierScanIfNeeded(
        for item: DetectedItem,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        let prompt = item.category == .electronics ? "Scan the model label" : "Scan the barcode"
        return TargetedScanRequest(
            prompt: prompt,
            benefit: "This can confirm the exact model.",
            role: prompt.localizedCaseInsensitiveContains("barcode") ? .barcode : .label
        )
    }

    private static func fashionTagScanIfNeeded(
        for item: DetectedItem,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard [.clothing, .shoes, .bags].contains(item.category),
              answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Scan the size tag",
            benefit: "This helps buyers trust the fit.",
            role: .sizeTag
        )
    }

    private static func authenticityScanIfNeeded(
        for item: DetectedItem,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard [.shoes, .clothing, .bags, .jewelry].contains(item.category),
              answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Show the box label or authenticity mark",
            benefit: "This helps us find closer sold listings.",
            role: .authenticity
        )
    }

    private static func swappaModelScanIfNeeded(
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Show the settings model screen",
            benefit: "This can confirm the exact model.",
            role: .label
        )
    }

    private static func serialPlateScanIfNeeded(
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Scan the serial plate",
            benefit: "This can confirm the exact model.",
            role: .serial
        )
    }

    private static func makerMarkScanIfNeeded(
        for item: DetectedItem,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard [.art, .home, .furniture, .jewelry, .collectibles].contains(item.category),
              answers.hasAnsweredOrSkipped(.labelOrBrand) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Scan the maker mark",
            benefit: "This can confirm who made it.",
            role: .label
        )
    }

    private static func localConditionScanIfNeeded(
        for item: DetectedItem,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        if [.furniture, .home, .tools].contains(item.category),
           photos.containsPhoto(role: .fullItem) == false {
            return TargetedScanRequest(
                prompt: "Show the whole item",
                benefit: "Buyers will want to see this.",
                role: .fullItem
            )
        }
        return conditionScanIfNeeded(answers: answers, photos: photos)
    }

    private static func accessoriesScanIfNeeded(
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.included) == false,
              photos.containsPhoto(role: .included) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Show everything included",
            benefit: "This may improve your price estimate.",
            role: .accessories
        )
    }

    private static func conditionScanIfNeeded(
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.flaws) == false,
              photos.containsPhoto(role: .condition) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Show the damaged area",
            benefit: "Buyers will want to see this.",
            role: .condition
        )
    }

    private static func cardDetailScanIfNeeded(
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
              photos.containsPhoto(role: .label) == false
        else { return nil }
        return TargetedScanRequest(
            prompt: "Scan the card number and set symbol",
            benefit: "This can confirm the exact card.",
            role: .label
        )
    }
}

private extension Array where Element == ItemPhotoAsset {
    func containsPhoto(role: ItemPhotoRole) -> Bool {
        contains { $0.role == role && $0.canExportToListing }
    }
}

private extension ItemPhotoAsset {
    func isBetterListingPhoto(than other: ItemPhotoAsset, marketplace: Marketplace) -> Bool {
        if role.listingPriority != other.role.listingPriority {
            return role.listingPriority < other.role.listingPriority
        }
        let utilityScore = listingPhotoUtilityScore(for: marketplace)
        let otherUtilityScore = other.listingPhotoUtilityScore(for: marketplace)
        if utilityScore != otherUtilityScore {
            return utilityScore > otherUtilityScore
        }
        if source == .aiEdited, other.source != .aiEdited {
            return true
        }
        if source != .aiEdited, other.source == .aiEdited {
            return false
        }
        if dateAdded != other.dateAdded {
            return dateAdded < other.dateAdded
        }
        return id.uuidString < other.id.uuidString
    }
}

private extension ListingPhotoRole {
    init(itemPhotoRole: ItemPhotoRole, source: ItemPhotoSource, verifies: String) {
        let lowerVerification = verifies.lowercased()
        switch itemPhotoRole {
        case .cover:
            self = source == .aiEdited ? .enhancedCover : .fullItem
        case .fullItem:
            self = .fullItem
        case .label:
            self = lowerVerification.contains("authentic") ? .authenticityMark : .labelOrModel
        case .condition:
            self = lowerVerification.contains("flaw") ||
                lowerVerification.contains("scratch") ||
                lowerVerification.contains("wear") ||
                lowerVerification.contains("damage")
                ? .flaw
                : .conditionDetail
        case .included:
            self = lowerVerification.contains("box") || lowerVerification.contains("packaging")
                ? .packaging
                : .includedAccessories
        case .reference:
            self = .referenceOnly
        }
    }
}

private extension ListingPhotoSource {
    init(itemPhotoSource: ItemPhotoSource) {
        switch itemPhotoSource {
        case .camera:
            self = .camera
        case .photoLibrary, .unknownUserPhoto:
            self = .photoLibrary
        case .internetReference:
            self = .internetReference
        case .aiEdited:
            self = .aiEnhanced
        }
    }
}

private extension ListingPhotoQuality {
    init(itemPhotoAsset photo: ItemPhotoAsset) {
        let lowerVerification = photo.verifies.lowercased()
        self.init(
            sharpness: lowerVerification.contains("blurry") || lowerVerification.contains("blur") ? 6 : 12,
            lighting: lowerVerification.contains("dark") || lowerVerification.contains("poor light") ? 6 : 12,
            productVisibility: lowerVerification.contains("partial") || lowerVerification.contains("cropped") ? 8 : 12,
            blurPenalty: lowerVerification.contains("blurry") || lowerVerification.contains("blur") ? 12 : 0,
            clutterPenalty: lowerVerification.contains("clutter") || lowerVerification.contains("messy") ? 8 : 0,
            misleadingRisk: photo.source == .internetReference || photo.role == .reference ? 20 : 0
        )
    }
}

extension ItemPhotoRole {
    init(scanRole: TargetedScanPhotoRole) {
        switch scanRole {
        case .label, .barcode, .serial, .sizeTag, .authenticity:
            self = .label
        case .condition:
            self = .condition
        case .accessories:
            self = .included
        case .fullItem:
            self = .fullItem
        }
    }
}

enum Category: String, Codable, CaseIterable, Sendable, Hashable {
    case electronics
    case furniture
    case clothing
    case shoes
    case bags
    case jewelry
    case toys
    case kids
    case home
    case tools
    case sports
    case books
    case media
    case music
    case collectibles
    case art
    case other

    var display: String {
        displayKey.localized
    }

    var apiValue: String {
        displayKey
    }

    static func knownAPIValue(_ value: String) -> Category? {
        let normalized = normalizedAPIValue(value)
        return Category.allCases.first {
            normalizedAPIValue($0.rawValue) == normalized ||
            normalizedAPIValue($0.displayKey) == normalized
        }
    }

    private var displayKey: String {
        switch self {
        case .electronics: "Electronics"
        case .furniture: "Furniture"
        case .clothing: "Clothing"
        case .shoes: "Shoes"
        case .bags: "Bags"
        case .jewelry: "Jewelry"
        case .toys: "Toys"
        case .kids: "Kids"
        case .home: "Home"
        case .tools: "Tools"
        case .sports: "Sports"
        case .books: "Books"
        case .media: "Media"
        case .music: "Music"
        case .collectibles: "Collectibles"
        case .art: "Art"
        case .other: "Other"
        }
    }

    init(apiValue: String) {
        self = Self.knownAPIValue(apiValue) ?? .other
    }

    var placeholderSystemImage: String {
        switch self {
        case .electronics:
            "iphone"
        case .furniture, .home:
            "house.fill"
        case .clothing:
            "tshirt.fill"
        case .shoes:
            "shoeprints.fill"
        case .bags:
            "handbag.fill"
        case .jewelry:
            "diamond.fill"
        case .toys:
            "gamecontroller.fill"
        case .kids:
            "teddybear.fill"
        case .tools:
            "wrench.and.screwdriver.fill"
        case .sports:
            "basketball.fill"
        case .books:
            "books.vertical.fill"
        case .media:
            "play.rectangle.fill"
        case .music:
            "music.note"
        case .collectibles:
            "star.fill"
        case .art:
            "paintpalette.fill"
        case .other:
            "tag.fill"
        }
    }

    func next() -> Category {
        Self.allCases.next(after: self)
    }

    private static func normalizedAPIValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}

enum Condition: String, Codable, CaseIterable, Sendable, Hashable {
    case new
    case likeNew
    case good
    case fair
    case forParts

    var display: String {
        displayKey.localized
    }

    var apiValue: String {
        rawValue
    }

    static func knownAPIValue(_ value: String) -> Condition? {
        switch normalizedAPIValue(value) {
        case "new": .new
        case "likenew": .likeNew
        case "good": .good
        case "fair": .fair
        case "forparts", "parts", "notworking": .forParts
        default: nil
        }
    }

    private var displayKey: String {
        switch self {
        case .new: "New"
        case .likeNew: "Like New"
        case .good: "Good"
        case .fair: "Fair"
        case .forParts: "For parts"
        }
    }

    init(apiValue: String) {
        self = Self.knownAPIValue(apiValue) ?? .good
    }

    func next() -> Condition {
        Self.allCases.next(after: self)
    }

    private static func normalizedAPIValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}

struct MarketplaceEstimate: Codable, Identifiable, Hashable, Sendable {
    let id: Marketplace
    let payout: Decimal
    let deltaPct: Double
    var badge: EstimateBadge
    var fitScore: Int

    init(
        id: Marketplace,
        payout: Decimal,
        deltaPct: Double,
        badge: EstimateBadge,
        fitScore: Int = 0
    ) {
        self.id = id
        self.payout = payout
        self.deltaPct = deltaPct
        self.badge = badge
        self.fitScore = Self.clampedFitScore(fitScore)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Marketplace.self, forKey: .id)
        payout = try container.decode(Decimal.self, forKey: .payout)
        deltaPct = try container.decode(Double.self, forKey: .deltaPct)
        badge = try container.decode(EstimateBadge.self, forKey: .badge)
        fitScore = Self.clampedFitScore(try container.decodeIfPresent(Int.self, forKey: .fitScore) ?? 0)
    }

    var fitSummary: String? {
        guard fitScore > 0 else {
            return nil
        }

        switch fitScore {
        case 82...100:
            return "Strong fit"
        case 64..<82:
            return "Good fit"
        case 46..<64:
            return "Worth a look"
        default:
            return "More work"
        }
    }

    private static func clampedFitScore(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case payout
        case deltaPct
        case badge
        case fitScore
    }
}

struct MarketplaceComparisonResponse: Decodable, Equatable, Sendable {
    let checkedAt: String?
    let comparisons: [MarketplaceComparison]
    let entitlement: EntitlementSnapshot?

    init(
        checkedAt: String?,
        comparisons: [MarketplaceComparison],
        entitlement: EntitlementSnapshot? = nil
    ) {
        self.checkedAt = checkedAt
        self.comparisons = comparisons
        self.entitlement = entitlement?.sanitizedForUse
    }

    var comparisonByMarketplace: [Marketplace: MarketplaceComparison] {
        comparisons.reduce(into: [Marketplace: MarketplaceComparison]()) { result, comparison in
            result[comparison.marketplace] = comparison
        }
    }

    func sanitizedForDisplay() -> MarketplaceComparisonResponse {
        MarketplaceComparisonResponse(
            checkedAt: clean(checkedAt, maxLength: 32),
            comparisons: Array(comparisons.compactMap { $0.sanitizedForDisplay() }.prefix(10)),
            entitlement: entitlement?.sanitizedForUse
        )
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

struct MarketplaceComparison: Codable, Identifiable, Equatable, Sendable, Hashable {
    let marketplace: Marketplace
    let recommendationLabel: String?
    let marketplaceFitScore: Int?
    let listPrice: Decimal?
    let likelyRangeLow: Decimal?
    let likelyRangeHigh: Decimal?
    let takeHomeEstimate: Decimal?
    let compLowPrice: Decimal?
    let compMedianPrice: Decimal?
    let compHighPrice: Decimal?
    let expectedSpeed: String?
    let shippingExpectation: String?
    let feeSummary: String?
    let reason: String?
    let evidenceSummary: String?
    let evidenceStatus: EvidenceStatus
    let evidenceSources: [ListingEvidenceSource]?

    enum EvidenceStatus: String, Codable, Sendable, Hashable {
        case grounded
        case limited
        case unavailable

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self))?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            switch value {
            case "grounded", "verified":
                self = .grounded
            case "limited", "partial":
                self = .limited
            default:
                self = .unavailable
            }
        }
    }

    var id: Marketplace { marketplace }

    init(
        marketplace: Marketplace,
        recommendationLabel: String? = nil,
        marketplaceFitScore: Int? = nil,
        listPrice: Decimal? = nil,
        likelyRangeLow: Decimal? = nil,
        likelyRangeHigh: Decimal? = nil,
        takeHomeEstimate: Decimal? = nil,
        compLowPrice: Decimal? = nil,
        compMedianPrice: Decimal? = nil,
        compHighPrice: Decimal? = nil,
        expectedSpeed: String? = nil,
        shippingExpectation: String? = nil,
        feeSummary: String? = nil,
        reason: String? = nil,
        evidenceSummary: String? = nil,
        evidenceStatus: EvidenceStatus = .unavailable,
        evidenceSources: [ListingEvidenceSource]? = nil
    ) {
        self.marketplace = marketplace
        self.recommendationLabel = recommendationLabel
        self.marketplaceFitScore = marketplaceFitScore.map { min(max($0, 1), 100) }
        self.listPrice = listPrice
        self.likelyRangeLow = likelyRangeLow
        self.likelyRangeHigh = likelyRangeHigh
        self.takeHomeEstimate = takeHomeEstimate
        self.compLowPrice = compLowPrice
        self.compMedianPrice = compMedianPrice
        self.compHighPrice = compHighPrice
        self.expectedSpeed = expectedSpeed
        self.shippingExpectation = shippingExpectation
        self.feeSummary = feeSummary
        self.reason = reason
        self.evidenceSummary = evidenceSummary
        self.evidenceStatus = evidenceStatus
        self.evidenceSources = evidenceSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let marketplaceValue = try container.decode(String.self, forKey: .marketplace)
        guard let marketplace = Marketplace(rawValue: marketplaceValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .marketplace,
                in: container,
                debugDescription: "Unsupported marketplace"
            )
        }
        self.marketplace = marketplace
        recommendationLabel = try container.decodeIfPresent(String.self, forKey: .recommendationLabel)
        marketplaceFitScore = try container.decodeIfPresent(Int.self, forKey: .marketplaceFitScore)
        listPrice = try container.decodeIfPresent(Decimal.self, forKey: .listPrice)
        likelyRangeLow = try container.decodeIfPresent(Decimal.self, forKey: .likelyRangeLow)
        likelyRangeHigh = try container.decodeIfPresent(Decimal.self, forKey: .likelyRangeHigh)
        takeHomeEstimate = try container.decodeIfPresent(Decimal.self, forKey: .takeHomeEstimate)
        compLowPrice = try container.decodeIfPresent(Decimal.self, forKey: .compLowPrice)
        compMedianPrice = try container.decodeIfPresent(Decimal.self, forKey: .compMedianPrice)
        compHighPrice = try container.decodeIfPresent(Decimal.self, forKey: .compHighPrice)
        expectedSpeed = try container.decodeIfPresent(String.self, forKey: .expectedSpeed)
        shippingExpectation = try container.decodeIfPresent(String.self, forKey: .shippingExpectation)
        feeSummary = try container.decodeIfPresent(String.self, forKey: .feeSummary)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        evidenceSummary = try container.decodeIfPresent(String.self, forKey: .evidenceSummary)
        evidenceStatus = try container.decodeIfPresent(EvidenceStatus.self, forKey: .evidenceStatus) ?? .unavailable
        evidenceSources = try container.decodeIfPresent([ListingEvidenceSource].self, forKey: .evidenceSources)
    }

    func sanitizedForDisplay() -> MarketplaceComparison? {
        let sanitizedSources = cleanEvidenceSources(evidenceSources)
        let displayEvidenceStatus: EvidenceStatus
        if evidenceStatus == .grounded, sanitizedSources?.isEmpty != false {
            displayEvidenceStatus = .limited
        } else {
            displayEvidenceStatus = evidenceStatus
        }

        return MarketplaceComparison(
            marketplace: marketplace,
            recommendationLabel: clean(recommendationLabel, maxLength: 32),
            marketplaceFitScore: marketplaceFitScore.map { min(max($0, 1), 100) },
            listPrice: positive(listPrice),
            likelyRangeLow: positive(likelyRangeLow),
            likelyRangeHigh: positive(likelyRangeHigh),
            takeHomeEstimate: positive(takeHomeEstimate),
            compLowPrice: positive(compLowPrice),
            compMedianPrice: positive(compMedianPrice),
            compHighPrice: positive(compHighPrice),
            expectedSpeed: clean(expectedSpeed, maxLength: 80),
            shippingExpectation: clean(shippingExpectation, maxLength: 100),
            feeSummary: clean(feeSummary, maxLength: 180),
            reason: clean(reason, maxLength: 180),
            evidenceSummary: clean(evidenceSummary, maxLength: 220),
            evidenceStatus: displayEvidenceStatus,
            evidenceSources: sanitizedSources
        )
    }

    func rowSignal(currencyCode: String) -> String? {
        guard evidenceStatus != .unavailable else { return nil }
        let price = listPrice.map { String.localizedFormat("List around %@", $0.currency(code: currencyCode)) }
        let range = soldPriceSignal(currencyCode: currencyCode)
        let speed = clean(expectedSpeed, maxLength: 80)
        let shipping = clean(shippingExpectation, maxLength: 100)
        let parts = [price, range, speed, shipping].compactMap { $0 }
        guard parts.isEmpty == false else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    func soldPriceSignal(currencyCode: String) -> String {
        soldPriceRange(currencyCode: currencyCode) ?? "No sold prices found".localized
    }

    func soldPriceRange(currencyCode: String) -> String? {
        if let low = compLowPrice, let high = compHighPrice {
            return String.localizedFormat("Sold prices %@ to %@", low.currency(code: currencyCode), high.currency(code: currencyCode))
        }
        if let median = compMedianPrice {
            return String.localizedFormat("Typical sold price %@", median.currency(code: currencyCode))
        }
        return nil
    }

    func accessibilitySignal(currencyCode: String) -> String? {
        rowSignal(currencyCode: currencyCode)?.replacingOccurrences(of: " · ", with: ", ")
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.isEmpty == false,
              collapsed.contains("```") == false
        else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanEvidenceSources(_ values: [ListingEvidenceSource]?) -> [ListingEvidenceSource]? {
        let cleaned = (values ?? [])
            .compactMap { $0.sanitizedForDisplay() }
            .reduce(into: [ListingEvidenceSource]()) { result, value in
                guard result.contains(where: { $0.id == value.id }) == false, result.count < 4 else { return }
                result.append(value)
            }
        return cleaned.isEmpty ? nil : cleaned
    }

    private enum CodingKeys: String, CodingKey {
        case marketplace
        case recommendationLabel
        case marketplaceFitScore
        case listPrice
        case likelyRangeLow
        case likelyRangeHigh
        case takeHomeEstimate
        case compLowPrice
        case compMedianPrice
        case compHighPrice
        case expectedSpeed
        case shippingExpectation
        case feeSummary
        case reason
        case evidenceSummary
        case evidenceStatus
        case evidenceSources
    }
}

enum EstimateBadge: String, Codable, Sendable {
    case best
    case lowest
    case none
}

struct HistoryEntry: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let createdAt: Date
    let itemName: String
    let category: Category?
    let condition: Condition?
    let suggestedPrice: Decimal?
    let imageThumbnail: Data?
    let marketplace: Marketplace
    let listingText: String
    let itemDetails: ItemDetailAnswers?
    let marketplaceComparison: MarketplaceComparison?
    let listingDraft: GeneratedListingDraft?
    let identificationProfile: AnalyzeIdentificationProfile?
    let supplementalPhotos: [ItemPhotoAsset]

    init(
        id: UUID,
        createdAt: Date,
        itemName: String,
        category: Category?,
        condition: Condition?,
        suggestedPrice: Decimal?,
        imageThumbnail: Data?,
        marketplace: Marketplace,
        listingText: String,
        itemDetails: ItemDetailAnswers? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        listingDraft: GeneratedListingDraft? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil,
        supplementalPhotos: [ItemPhotoAsset] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.itemName = itemName
        self.category = category
        self.condition = condition
        self.suggestedPrice = suggestedPrice
        self.imageThumbnail = imageThumbnail
        self.marketplace = marketplace
        self.listingText = listingText
        self.itemDetails = itemDetails?.sanitizedForUse
        self.marketplaceComparison = marketplaceComparison?.sanitizedForDisplay()
        self.listingDraft = listingDraft?.sanitizedForDisplay()
        self.identificationProfile = identificationProfile?.sanitizedForDisplay()
        self.supplementalPhotos = Self.sanitizedSupplementalPhotos(supplementalPhotos)
    }

    func sanitizedForHistory() -> HistoryEntry? {
        let cleanItemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanListingText = (try? ListingTextContract.validatedStored(listingText))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanItemName.isEmpty == false, cleanListingText.isEmpty == false else {
            return nil
        }

        let cleanSuggestedPrice = suggestedPrice.flatMap { $0 > 0 ? $0 : nil }
        return HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: cleanItemName,
            category: category,
            condition: condition,
            suggestedPrice: cleanSuggestedPrice,
            imageThumbnail: imageThumbnail,
            marketplace: marketplace,
            listingText: cleanListingText,
            itemDetails: itemDetails?.sanitizedForUse,
            marketplaceComparison: marketplaceComparison?.sanitizedForDisplay(),
            listingDraft: listingDraft?.sanitizedForDisplay(),
            identificationProfile: identificationProfile?.sanitizedForDisplay(),
            supplementalPhotos: Self.sanitizedSupplementalPhotos(supplementalPhotos)
        )
    }

    private static func sanitizedSupplementalPhotos(_ photos: [ItemPhotoAsset]) -> [ItemPhotoAsset] {
        var seen = Set<String>()
        var sanitized: [ItemPhotoAsset] = []
        for photo in photos {
            guard photo.canExportToListing,
                  let imageData = photo.imageData,
                  imageData.isEmpty == false
            else { continue }
            let key = photo.duplicateSignature ?? photo.id.uuidString
            guard seen.insert(key).inserted else { continue }
            sanitized.append(photo)
            if sanitized.count == 8 { break }
        }
        return sanitized
    }
}

enum EntitlementState: String, Codable, CaseIterable, Sendable, Hashable {
    case earlyAccess
    case free
    case plus
    case usagePack
}

struct EntitlementSnapshot: Codable, Equatable, Sendable, Hashable {
    let state: EntitlementState
    let completeFeatureAccess: Bool
    let futurePaidAccessEnabled: Bool
    let remainingAnalyses: Int
    let remainingAiActions: Int

    init(
        state: EntitlementState = .earlyAccess,
        completeFeatureAccess: Bool = true,
        futurePaidAccessEnabled: Bool = false,
        remainingAnalyses: Int = 0,
        remainingAiActions: Int = 0
    ) {
        self.state = state
        self.completeFeatureAccess = completeFeatureAccess
        self.futurePaidAccessEnabled = futurePaidAccessEnabled
        self.remainingAnalyses = max(remainingAnalyses, 0)
        self.remainingAiActions = max(remainingAiActions, 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stateValue = try container.decodeIfPresent(String.self, forKey: .state) ?? EntitlementState.earlyAccess.rawValue
        self.init(
            state: EntitlementState(rawValue: stateValue) ?? .earlyAccess,
            completeFeatureAccess: try container.decodeIfPresent(Bool.self, forKey: .completeFeatureAccess) ?? true,
            futurePaidAccessEnabled: try container.decodeIfPresent(Bool.self, forKey: .futurePaidAccessEnabled) ?? false,
            remainingAnalyses: try container.decodeIfPresent(Int.self, forKey: .remainingAnalyses) ?? 0,
            remainingAiActions: try container.decodeIfPresent(Int.self, forKey: .remainingAiActions) ?? 0
        )
    }

    var sanitizedForUse: EntitlementSnapshot {
        EntitlementSnapshot(
            state: state,
            completeFeatureAccess: completeFeatureAccess,
            futurePaidAccessEnabled: futurePaidAccessEnabled,
            remainingAnalyses: remainingAnalyses,
            remainingAiActions: remainingAiActions
        )
    }

    var analyticsProperties: [String: String] {
        [
            "entitlement_state": state.rawValue,
            "complete_feature_access": completeFeatureAccess ? "true" : "false",
            "future_paid_access_enabled": futurePaidAccessEnabled ? "true" : "false",
            "remaining_analyses": "\(remainingAnalyses)",
            "remaining_ai_actions": "\(remainingAiActions)"
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case completeFeatureAccess
        case futurePaidAccessEnabled
        case remainingAnalyses
        case remainingAiActions
    }
}

struct GeneratedListing: Sendable, Equatable {
    let listing: String
    let draft: GeneratedListingDraft?
    let entitlement: EntitlementSnapshot?

    init(
        listing: String,
        draft: GeneratedListingDraft? = nil,
        entitlement: EntitlementSnapshot? = nil
    ) {
        self.listing = listing
        self.draft = draft
        self.entitlement = entitlement?.sanitizedForUse
    }
}

struct ListingEvidenceSource: Codable, Identifiable, Sendable, Equatable, Hashable {
    var sourceMarketplace: String? = nil
    var title: String? = nil
    var url: String? = nil
    var dateChecked: String? = nil
    var listingStatus: String? = nil
    var conditionAndVariant: String? = nil
    var comparability: String? = nil
    var price: Decimal? = nil

    var id: String {
        [
            sourceMarketplace,
            title,
            url,
            dateChecked,
            listingStatus,
            conditionAndVariant,
            comparability,
            price.map { NSDecimalNumber(decimal: $0).stringValue }
        ]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    func sanitizedForDisplay() -> ListingEvidenceSource? {
        let sanitized = ListingEvidenceSource(
            sourceMarketplace: clean(sourceMarketplace, maxLength: 48),
            title: clean(title, maxLength: 120),
            url: cleanReferenceURL(url),
            dateChecked: clean(dateChecked, maxLength: 32),
            listingStatus: clean(listingStatus, maxLength: 32),
            conditionAndVariant: clean(conditionAndVariant, maxLength: 100),
            comparability: clean(comparability, maxLength: 72),
            price: positive(price)
        )

        guard sanitized.sourceMarketplace != nil ||
            sanitized.title != nil ||
            sanitized.url != nil ||
            sanitized.dateChecked != nil ||
            sanitized.listingStatus != nil ||
            sanitized.conditionAndVariant != nil ||
            sanitized.comparability != nil ||
            sanitized.price != nil
        else {
            return nil
        }

        return sanitized
    }

    func detailLine(currencyCode: String) -> String {
        [
            listingStatus,
            price.map { $0.currency(code: currencyCode) },
            conditionAndVariant,
            comparability,
            dateChecked.map { String.localizedFormat("Checked %@", $0) }
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var hasSourceReference: Bool {
        let reference = url ?? title
        return reference?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var isSoldOrCompleted: Bool {
        let status = listingStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return status == "sold" ||
            status == "completed" ||
            status == "ended" ||
            status.contains("sold")
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let collapsedWhitespace = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsedWhitespace.isEmpty == false,
              collapsedWhitespace.contains("```") == false
        else { return nil }
        return String(collapsedWhitespace.prefix(maxLength))
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanReferenceURL(_ value: String?) -> String? {
        guard let cleanURL = clean(value, maxLength: 500),
              let url = URL(string: cleanURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return cleanURL
    }

}

enum ItemDetailFieldKey: String, Codable, Sendable, Hashable {
    case labelOrBrand
    case sizeOrModel
    case flaws
    case included
    case extraDetails
    case marketplaceNotes
    case largeOrFragile
    case targetedScan
    case marketplaceTargetedScan
}

struct ItemDetailAnswers: Codable, Equatable, Sendable, Hashable {
    var labelOrBrand: String
    var sizeOrModel: String
    var flaws: String
    var included: String
    var extraDetails: String
    var marketplaceNotes: [Marketplace: String]
    var isLargeOrFragile: Bool
    var answeredFieldKeys: [ItemDetailFieldKey]
    var answeredMarketplaces: [Marketplace]

    init(
        labelOrBrand: String = "",
        sizeOrModel: String = "",
        flaws: String = "",
        included: String = "",
        extraDetails: String = "",
        marketplaceNotes: [Marketplace: String] = [:],
        isLargeOrFragile: Bool = false,
        answeredFieldKeys: [ItemDetailFieldKey] = [],
        answeredMarketplaces: [Marketplace] = []
    ) {
        self.labelOrBrand = labelOrBrand
        self.sizeOrModel = sizeOrModel
        self.flaws = flaws
        self.included = included
        self.extraDetails = extraDetails
        self.marketplaceNotes = Self.cleanedMarketplaceNotes(marketplaceNotes)
        self.isLargeOrFragile = isLargeOrFragile
        self.answeredFieldKeys = Self.uniqueFieldKeys(answeredFieldKeys)
        self.answeredMarketplaces = Self.uniqueMarketplaces(answeredMarketplaces)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMarketplaceNotes = Self.cleanedMarketplaceNotes(
            try container.decodeIfPresent([Marketplace: String].self, forKey: .marketplaceNotes) ?? [:]
        )
        let decodedAnsweredMarketplaces = try container.decodeIfPresent([Marketplace].self, forKey: .answeredMarketplaces) ?? []
        let answerMarketplaces = decodedAnsweredMarketplaces.isEmpty
            ? Array(decodedMarketplaceNotes.keys)
            : decodedAnsweredMarketplaces

        self.init(
            labelOrBrand: try container.decodeIfPresent(String.self, forKey: .labelOrBrand) ?? "",
            sizeOrModel: try container.decodeIfPresent(String.self, forKey: .sizeOrModel) ?? "",
            flaws: try container.decodeIfPresent(String.self, forKey: .flaws) ?? "",
            included: try container.decodeIfPresent(String.self, forKey: .included) ?? "",
            extraDetails: try container.decodeIfPresent(String.self, forKey: .extraDetails) ?? "",
            marketplaceNotes: decodedMarketplaceNotes,
            isLargeOrFragile: try container.decodeIfPresent(Bool.self, forKey: .isLargeOrFragile) ?? false,
            answeredFieldKeys: try container.decodeIfPresent([ItemDetailFieldKey].self, forKey: .answeredFieldKeys) ?? [],
            answeredMarketplaces: answerMarketplaces
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(labelOrBrand, forKey: .labelOrBrand)
        try container.encode(sizeOrModel, forKey: .sizeOrModel)
        try container.encode(flaws, forKey: .flaws)
        try container.encode(included, forKey: .included)
        try container.encode(extraDetails, forKey: .extraDetails)
        try container.encode(marketplaceNotes, forKey: .marketplaceNotes)
        try container.encode(isLargeOrFragile, forKey: .isLargeOrFragile)
        try container.encode(answeredFieldKeys, forKey: .answeredFieldKeys)
        try container.encode(answeredMarketplaces, forKey: .answeredMarketplaces)
    }

    var sanitizedForUse: ItemDetailAnswers? {
        let clean = ItemDetailAnswers(
            labelOrBrand: Self.clean(labelOrBrand, maxLength: 80),
            sizeOrModel: Self.clean(sizeOrModel, maxLength: 96),
            flaws: Self.clean(flaws, maxLength: 140),
            included: Self.clean(included, maxLength: 120),
            extraDetails: Self.clean(extraDetails, maxLength: 180),
            marketplaceNotes: Self.cleanedMarketplaceNotes(marketplaceNotes),
            isLargeOrFragile: isLargeOrFragile,
            answeredFieldKeys: Self.uniqueFieldKeys(answeredFieldKeys),
            answeredMarketplaces: Self.uniqueMarketplaces(answeredMarketplaces)
        )
        return clean.hasUsefulDetails ? clean : nil
    }

    var hasUsefulDetails: Bool {
        hasListingPayloadDetails ||
            answeredFieldKeys.isEmpty == false ||
            answeredMarketplaces.isEmpty == false
    }

    var hasListingPayloadDetails: Bool {
        isLargeOrFragile ||
            labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    var displayValues: [String] {
        var values: [String] = []
        appendDisplayValue(labelOrBrand, prefix: "Brand", to: &values)
        appendDisplayValue(sizeOrModel, prefix: "Size/model", to: &values)
        appendDisplayValue(flaws, prefix: "Flaws", to: &values)
        appendDisplayValue(included, prefix: "Includes", to: &values)
        appendDisplayValue(extraDetails, prefix: "Other", to: &values)
        appendMarketplaceNotes(to: &values)
        if isLargeOrFragile {
            values.append("Large or fragile")
        }
        answeredFieldKeys.forEach { field in
            appendHandledValue(field, to: &values)
        }
        return values
    }

    var marketplaceFactQualityBonus: Int {
        min(confirmedDetailCount * 4, 16)
    }

    var localPickupBoost: Int {
        isLargeOrFragile ? 18 : 0
    }

    var shippingPenalty: Int {
        isLargeOrFragile ? 18 : 0
    }

    mutating func markAnswered(_ field: ItemDetailFieldKey) {
        guard answeredFieldKeys.contains(field) == false else { return }
        answeredFieldKeys.append(field)
    }

    mutating func clearAnswered(_ field: ItemDetailFieldKey) {
        answeredFieldKeys.removeAll { $0 == field }
    }

    func seedingConfirmedAnalysisFacts(
        from analysis: AnalyzeIntelligence?,
        category: Category
    ) -> ItemDetailAnswers {
        guard let analysis else { return self }
        var seededAnswers = self
        let userProvidedFields = Set(
            ItemDetailFieldKey.analysisSeedableFields.filter { hasConcreteValue(for: $0) }
        )
        analysis.itemFacts
            .compactMap { ItemDetailAnalysisSeed(fact: $0, category: category) }
            .forEach { seed in
                guard userProvidedFields.contains(seed.field) == false else { return }
                seededAnswers.mergeScannedValue(seed.value, into: seed.keyPath, field: seed.field)
            }
        return seededAnswers
    }

    mutating func applyTargetedScanEvidence(
        _ evidence: NativeScanEvidence?,
        request: TargetedScanRequest,
        answeredField: ItemDetailFieldKey = .targetedScan
    ) {
        markAnswered(answeredField)

        switch request.role {
        case .barcode:
            guard let barcodeSummary = Self.scanBarcodeSummary(from: evidence) else { return }
            mergeScannedValue(barcodeSummary, into: \.sizeOrModel, field: .sizeOrModel)
        case .label, .serial, .sizeTag, .authenticity:
            guard let detailSummary = Self.scanTextSummary(from: evidence) else { return }
            mergeScannedValue(detailSummary, into: \.sizeOrModel, field: .sizeOrModel)
        case .accessories:
            mergeScannedValue("Included items photo attached.", into: \.included, field: .included)
        case .condition:
            mergeScannedValue("Condition detail photo attached.", into: \.flaws, field: .flaws)
        case .fullItem:
            mergeScannedValue("Full item photo attached.", into: \.extraDetails, field: .extraDetails)
        }
    }

    mutating func setMarketplaceNote(_ value: String, for marketplace: Marketplace) {
        let cleanValue = Self.clean(value, maxLength: 220)
        if cleanValue.isEmpty {
            marketplaceNotes[marketplace] = nil
            answeredMarketplaces.removeAll { $0 == marketplace }
        } else {
            marketplaceNotes[marketplace] = cleanValue
            markMarketplaceAnswered(marketplace)
        }
    }

    mutating func markMarketplaceAnswered(_ marketplace: Marketplace) {
        guard answeredMarketplaces.contains(marketplace) == false else { return }
        answeredMarketplaces.append(marketplace)
    }

    func hasAnsweredOrSkipped(_ field: ItemDetailFieldKey) -> Bool {
        let hasConcreteAnswer: Bool
        switch field {
        case .labelOrBrand:
            hasConcreteAnswer = labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .sizeOrModel:
            hasConcreteAnswer = sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .flaws:
            hasConcreteAnswer = flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .included:
            hasConcreteAnswer = included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .extraDetails:
            hasConcreteAnswer = extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .marketplaceNotes:
            hasConcreteAnswer = marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        case .largeOrFragile:
            hasConcreteAnswer = false
        case .targetedScan, .marketplaceTargetedScan:
            hasConcreteAnswer = false
        }
        return hasConcreteAnswer || answeredFieldKeys.contains(field)
    }

    func marketplaceNote(for marketplace: Marketplace) -> String {
        marketplaceNotes[marketplace] ?? ""
    }

    func hasMarketplaceNoteOrSkipped(_ marketplace: Marketplace) -> Bool {
        marketplaceNote(for: marketplace).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            answeredMarketplaces.contains(marketplace)
    }

    private var confirmedDetailCount: Int {
        [
            labelOrBrand,
            sizeOrModel,
            flaws,
            included,
            extraDetails
        ]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .count + marketplaceNotes.values.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count +
            (isLargeOrFragile ? 1 : 0)
    }

    private static func clean(_ value: String, maxLength: Int) -> String {
        let collapsedWhitespace = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsedWhitespace.prefix(maxLength))
    }

    private mutating func mergeScannedValue(
        _ value: String,
        into keyPath: WritableKeyPath<ItemDetailAnswers, String>,
        field: ItemDetailFieldKey
    ) {
        let cleanValue = Self.clean(value, maxLength: 140)
        guard cleanValue.isEmpty == false else { return }
        let existingValue = self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
        if existingValue.isEmpty {
            self[keyPath: keyPath] = cleanValue
        } else if existingValue.localizedCaseInsensitiveContains(cleanValue) == false {
            self[keyPath: keyPath] = Self.clean("\(existingValue); \(cleanValue)", maxLength: 180)
        }
        markAnswered(field)
    }

    private static func scanBarcodeSummary(from evidence: NativeScanEvidence?) -> String? {
        guard let evidence else { return nil }
        let payloads = evidence.barcodes.map(\.payload).filter { $0.isEmpty == false }
        guard payloads.isEmpty == false else { return nil }
        return "Barcode \(payloads.prefix(2).joined(separator: ", "))"
    }

    private static func scanTextSummary(from evidence: NativeScanEvidence?) -> String? {
        guard let evidence else { return nil }
        let candidates = evidence.modelOrSerialCandidates.isEmpty
            ? evidence.recognizedText
            : evidence.modelOrSerialCandidates
        guard candidates.isEmpty == false else { return nil }
        return candidates.prefix(3).joined(separator: "; ")
    }

    private static func uniqueFieldKeys(_ values: [ItemDetailFieldKey]) -> [ItemDetailFieldKey] {
        values.reduce(into: [ItemDetailFieldKey]()) { result, value in
            guard result.contains(value) == false else { return }
            result.append(value)
        }
    }

    private static func uniqueMarketplaces(_ values: [Marketplace]) -> [Marketplace] {
        values.reduce(into: [Marketplace]()) { result, value in
            guard result.contains(value) == false else { return }
            result.append(value)
        }
    }

    private static func cleanedMarketplaceNotes(_ values: [Marketplace: String]) -> [Marketplace: String] {
        values.reduce(into: [Marketplace: String]()) { result, entry in
            let cleanValue = clean(entry.value, maxLength: 220)
            guard cleanValue.isEmpty == false else { return }
            result[entry.key] = cleanValue
        }
    }

    private func appendDisplayValue(_ value: String, prefix: String, to values: inout [String]) {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.isEmpty == false else { return }
        values.append("\(prefix): \(cleanValue)")
    }

    private func appendMarketplaceNotes(to values: inout [String]) {
        Marketplace.allCases.forEach { marketplace in
            let cleanValue = marketplaceNote(for: marketplace).trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanValue.isEmpty == false {
                values.append("\(marketplace.displayName): \(cleanValue)")
            } else if answeredMarketplaces.contains(marketplace) {
                values.append("\(marketplace.displayName): \("I don't know".localized)")
            }
        }
    }

    private func appendHandledValue(_ field: ItemDetailFieldKey, to values: inout [String]) {
        guard hasConcreteValue(for: field) == false else { return }
        let value = field == .largeOrFragile ? "No".localized : "I don't know".localized
        values.append("\(displayPrefix(for: field)): \(value)")
    }

    private func hasConcreteValue(for field: ItemDetailFieldKey) -> Bool {
        switch field {
        case .labelOrBrand:
            labelOrBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .sizeOrModel:
            sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .flaws:
            flaws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .included:
            included.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .extraDetails:
            extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .marketplaceNotes:
            marketplaceNotes.values.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        case .largeOrFragile:
            isLargeOrFragile
        case .targetedScan, .marketplaceTargetedScan:
            false
        }
    }

    private func displayPrefix(for field: ItemDetailFieldKey) -> String {
        switch field {
        case .labelOrBrand:
            "Brand"
        case .sizeOrModel:
            "Size/model"
        case .flaws:
            "Flaws"
        case .included:
            "Includes"
        case .extraDetails:
            "Other"
        case .marketplaceNotes:
            "Marketplace"
        case .largeOrFragile:
            "Large or fragile"
        case .targetedScan:
            "Extra scan"
        case .marketplaceTargetedScan:
            "Marketplace scan"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case labelOrBrand
        case sizeOrModel
        case flaws
        case included
        case extraDetails
        case marketplaceNotes
        case isLargeOrFragile
        case answeredFieldKeys
        case answeredMarketplaces
    }
}

private extension ItemDetailFieldKey {
    static var analysisSeedableFields: [ItemDetailFieldKey] {
        [.labelOrBrand, .sizeOrModel, .flaws, .included, .extraDetails]
    }
}

private struct ItemDetailAnalysisSeed {
    let value: String
    let keyPath: WritableKeyPath<ItemDetailAnswers, String>
    let field: ItemDetailFieldKey

    init?(fact: AnalyzeItemFact, category: Category) {
        guard fact.confidence >= 0.78 else { return nil }
        let cleanLabel = Self.clean(fact.label, maxLength: 40)
        let cleanValue = Self.clean(fact.value, maxLength: 80)
        guard cleanLabel.isEmpty == false, cleanValue.isEmpty == false else { return nil }

        let searchable = "\(cleanLabel) \(cleanValue)".lowercased()
        let seededValue = "\(cleanLabel): \(cleanValue)"

        if Self.matches(searchable, [
            "brand", "brand label", "maker", "artist", "designer", "manufacturer", "logo", "signature"
        ]) {
            self.init(value: seededValue, keyPath: \.labelOrBrand, field: .labelOrBrand)
            return
        }

        if Self.matches(searchable, [
            "model", "serial", "sku", "style", "size", "storage", "capacity", "dimension",
            "measurement", "material", "color", "edition", "set", "year", "number", "variant"
        ]) {
            self.init(value: seededValue, keyPath: \.sizeOrModel, field: .sizeOrModel)
            return
        }

        if Self.matches(searchable, [
            "box", "charger", "case", "remote", "cable", "accessory", "accessories",
            "included", "packaging", "certificate", "paperwork", "manual"
        ]) {
            self.init(value: seededValue, keyPath: \.included, field: .included)
            return
        }

        if Self.matches(searchable, [
            "flaw", "damage", "scratch", "stain", "wear", "broken", "missing", "condition",
            "tested", "working", "works", "turns on", "power"
        ]) {
            self.init(value: seededValue, keyPath: \.flaws, field: .flaws)
            return
        }

        if Self.shouldKeepAsExtra(searchable, category: category) {
            self.init(value: seededValue, keyPath: \.extraDetails, field: .extraDetails)
            return
        }

        return nil
    }

    private init(
        value: String,
        keyPath: WritableKeyPath<ItemDetailAnswers, String>,
        field: ItemDetailFieldKey
    ) {
        self.value = value
        self.keyPath = keyPath
        self.field = field
    }

    private static func shouldKeepAsExtra(_ searchable: String, category: Category) -> Bool {
        matches(searchable, ["authentic", "signed", "numbered", "rare", "vintage", "sealed", "handmade", "era"]) ||
            ([.art, .collectibles, .jewelry, .home, .furniture, .music].contains(category) &&
                matches(searchable, ["mark", "origin", "period", "finish", "wood", "metal", "stone"]))
    }

    private static func matches(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func clean(_ value: String, maxLength: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(maxLength))
    }
}

struct GeneratedListingDraft: Codable, Sendable, Equatable, Hashable {
    var title: String?
    var description: String?
    var listPrice: Decimal?
    var likelySalePrice: Decimal?
    var takeHomeEstimate: Decimal?
    var firstPhoto: String?
    var missingPhotoPrompt: String?
    var missingInfoWarnings: [String]? = nil
    var fitReason: String?
    var postingNotes: [String]?
    var itemSpecifics: [String]?
    var tags: [String]?
    var compLowPrice: Decimal? = nil
    var compHighPrice: Decimal? = nil
    var compMedianPrice: Decimal? = nil
    var feeSummary: String? = nil
    var pricingStrategy: String? = nil
    var evidenceSummary: String? = nil
    var referenceImageURL: String? = nil
    var publicImageQuery: String? = nil
    var evidenceSources: [ListingEvidenceSource]? = nil

    var copyableListingText: String? {
        guard let title = clean(title, maxLength: 120),
              let description = clean(description, maxLength: 1_500)
        else { return nil }
        return """
        TITLE:
        \(title)

        DESCRIPTION:
        \(description)
        """
    }

    func sanitizedForDisplay() -> GeneratedListingDraft? {
        let sanitizedSources = cleanEvidenceSources(evidenceSources)
        let hasVerifiedSoldEvidence = Self.hasVerifiedSoldEvidence(in: sanitizedSources)
        let sanitized = GeneratedListingDraft(
            title: clean(title, maxLength: 120),
            description: clean(description, maxLength: 1_500),
            listPrice: positive(listPrice),
            likelySalePrice: positive(likelySalePrice),
            takeHomeEstimate: positive(takeHomeEstimate),
            firstPhoto: clean(firstPhoto, maxLength: 180),
            missingPhotoPrompt: clean(missingPhotoPrompt, maxLength: 140),
            missingInfoWarnings: cleanList(missingInfoWarnings, maxItems: 4, maxLength: 120),
            fitReason: clean(fitReason, maxLength: 220),
            postingNotes: cleanList(postingNotes, maxItems: 3, maxLength: 160),
            itemSpecifics: cleanList(itemSpecifics, maxItems: 6, maxLength: 80),
            tags: cleanList(tags, maxItems: 8, maxLength: 40),
            compLowPrice: hasVerifiedSoldEvidence ? positive(compLowPrice) : nil,
            compHighPrice: hasVerifiedSoldEvidence ? positive(compHighPrice) : nil,
            compMedianPrice: hasVerifiedSoldEvidence ? positive(compMedianPrice) : nil,
            feeSummary: clean(feeSummary, maxLength: 180),
            pricingStrategy: clean(pricingStrategy, maxLength: 220),
            evidenceSummary: clean(evidenceSummary, maxLength: 260),
            referenceImageURL: cleanReferenceURL(referenceImageURL),
            publicImageQuery: clean(publicImageQuery, maxLength: 140),
            evidenceSources: sanitizedSources
        )

        if sanitized.title == nil,
           sanitized.description == nil,
           sanitized.listPrice == nil,
           sanitized.likelySalePrice == nil,
           sanitized.takeHomeEstimate == nil,
           sanitized.compLowPrice == nil,
           sanitized.compHighPrice == nil,
           sanitized.compMedianPrice == nil,
           sanitized.firstPhoto == nil,
           sanitized.missingPhotoPrompt == nil,
           sanitized.missingInfoWarnings?.isEmpty ?? true,
           sanitized.fitReason == nil,
           sanitized.feeSummary == nil,
           sanitized.pricingStrategy == nil,
           sanitized.evidenceSummary == nil,
           sanitized.referenceImageURL == nil,
           sanitized.publicImageQuery == nil,
           sanitized.evidenceSources?.isEmpty ?? true,
           sanitized.postingNotes?.isEmpty ?? true,
           sanitized.itemSpecifics?.isEmpty ?? true,
           sanitized.tags?.isEmpty ?? true {
            return nil
        }

        return sanitized
    }

    func sanitizedForMarketplace(_ marketplace: Marketplace, item: DetectedItem) -> GeneratedListingDraft? {
        guard var sanitized = sanitizedForDisplay() else { return nil }

        if let title = sanitized.title {
            sanitized.title = Self.truncatedTitle(
                title,
                maxCharacters: marketplace.optimizationProfile.titleMaxCharacters
            )
        }

        let warnings = marketplace.requiredListingWarnings(for: item, draft: sanitized)
        if warnings.isEmpty == false {
            sanitized.missingInfoWarnings = Self.mergedWarnings(
                sanitized.missingInfoWarnings,
                warnings,
                maxItems: 4
            )
        }

        return sanitized.sanitizedForDisplay()
    }

    private func clean(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed.contains("```") == false,
              trimmed.range(of: #"^(TITLE|DESCRIPTION)\s*:"#, options: [.regularExpression, .caseInsensitive]) == nil
        else {
            return nil
        }
        return String(trimmed.prefix(maxLength))
    }

    private func cleanList(_ values: [String]?, maxItems: Int, maxLength: Int) -> [String]? {
        let cleaned = (values ?? [])
            .compactMap { clean($0, maxLength: maxLength) }
            .reduce(into: [String]()) { result, value in
                guard result.contains(value) == false, result.count < maxItems else { return }
                result.append(value)
        }
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cleanEvidenceSources(_ values: [ListingEvidenceSource]?) -> [ListingEvidenceSource]? {
        let cleaned = (values ?? [])
            .compactMap { $0.sanitizedForDisplay() }
            .reduce(into: [ListingEvidenceSource]()) { result, value in
                guard result.contains(where: { $0.id == value.id }) == false, result.count < 4 else { return }
                result.append(value)
            }
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func hasVerifiedSoldEvidence(in sources: [ListingEvidenceSource]?) -> Bool {
        (sources ?? []).contains { source in
            source.price != nil &&
                source.dateChecked != nil &&
                source.hasSourceReference &&
                source.isSoldOrCompleted
        }
    }

    private func positive(_ value: Decimal?) -> Decimal? {
        guard let value, value > 0 else { return nil }
        return value.rounded(scale: 2)
    }

    private func cleanReferenceURL(_ value: String?) -> String? {
        guard let cleanURL = clean(value, maxLength: 500),
              let url = URL(string: cleanURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else { return nil }
        return cleanURL
    }

    private static func truncatedTitle(_ title: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, title.count > maxCharacters else { return title }
        let prefix = String(title.prefix(maxCharacters))
        let wordBoundary = prefix.split(separator: " ").dropLast().joined(separator: " ")
        return wordBoundary.isEmpty ? prefix : wordBoundary
    }

    private static func mergedWarnings(
        _ existingWarnings: [String]?,
        _ newWarnings: [String],
        maxItems: Int
    ) -> [String]? {
        let values = (existingWarnings ?? []) + newWarnings
        let cleaned = values.reduce(into: [String]()) { result, value in
            let cleanValue = value
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanValue.isEmpty == false,
                  result.contains(cleanValue) == false,
                  result.count < maxItems
            else { return }
            result.append(String(cleanValue.prefix(120)))
        }
        return cleaned.isEmpty ? nil : cleaned
    }
}

private extension Marketplace {
    func requiredListingWarnings(for item: DetectedItem, draft: GeneratedListingDraft) -> [String] {
        let searchableText = [
            item.name,
            draft.title,
            draft.description,
            draft.firstPhoto,
            draft.missingPhotoPrompt,
            draft.itemSpecifics?.joined(separator: " "),
            draft.postingNotes?.joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        func lacksAny(_ values: [String]) -> Bool {
            values.contains { searchableText.contains($0.lowercased()) } == false
        }

        switch self {
        case .ebay:
            if [.electronics, .tools, .music, .media].contains(item.category),
               lacksAny(["model", "serial", "part number", "mpn", "sku"]) {
                return ["Add model number before posting on eBay."]
            }
        case .facebook, .craigslist, .offerup, .nextdoor:
            if [.furniture, .home, .tools, .sports, .other].contains(item.category),
               lacksAny(["pickup", "delivery", "meet", "porch", "local"]) {
                return ["Add pickup or delivery details before posting locally."]
            }
        case .poshmark, .depop, .grailed, .vinted, .curtsy:
            if [.clothing, .shoes, .bags].contains(item.category),
               lacksAny(["size", "measurement", "tagged", "fit"]) {
                return ["Add size or measurements before posting."]
            }
        case .etsy:
            if lacksAny(["vintage", "handmade", "supply", "material"]) {
                return ["Confirm vintage, handmade, supply, or material details before posting on Etsy."]
            }
        case .stockx, .goat:
            if lacksAny(["sku", "style code", "size", "box"]) {
                return ["Add size, style code, and box condition before posting."]
            }
        case .reverb:
            if lacksAny(["model", "year", "working", "tested", "serial"]) {
                return ["Add model, year, and working condition before posting on Reverb."]
            }
        case .swappa:
            if lacksAny(["carrier", "unlocked", "battery", "storage", "imei"]) {
                return ["Add carrier, storage, and battery details before posting on Swappa."]
            }
        case .chairish:
            if lacksAny(["dimension", "height", "width", "depth", "material"]) {
                return ["Add dimensions and materials before posting on Chairish."]
            }
        case .tcgplayer:
            if lacksAny(["set", "card number", "language", "foil", "condition"]) {
                return ["Add set, card number, finish, language, and condition before posting."]
            }
        default:
            break
        }
        return []
    }
}

enum ListingTextContract {
    static func validatedGenerated(_ text: String) throws -> String {
        try validated(text, requiresSections: true)
    }

    static func validatedStored(_ text: String) throws -> String {
        try validated(text, requiresSections: true)
    }

    private static func validated(_ text: String, requiresSections: Bool) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              startsWithTitle(trimmed),
              hasMarkdownFence(trimmed) == false,
              hasPreamble(trimmed) == false
        else {
            throw APIError.decoding
        }

        if requiresSections {
            guard hasRequiredListingSections(trimmed) else {
                throw APIError.decoding
            }
        }

        return trimmed
    }

    private static func hasMarkdownFence(_ text: String) -> Bool {
        text.contains("```")
    }

    private static func startsWithTitle(_ text: String) -> Bool {
        text.range(of: #"^TITLE\s*:"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func hasPreamble(_ text: String) -> Bool {
        let normalized = text
            .prefix(96)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
        return normalized.range(
            of: #"^here(?:'s| is)\s+(?:your\s+)?listing\s*[:\-]"#,
            options: .regularExpression
        ) != nil
    }

    private static func hasRequiredListingSections(_ text: String) -> Bool {
        guard let titleRange = text.range(
            of: #"(?m)^TITLE\s*:"#,
            options: [.regularExpression, .caseInsensitive]
        ),
            let descriptionRange = text[titleRange.upperBound...].range(
                of: #"(?m)^DESCRIPTION\s*:"#,
                options: [.regularExpression, .caseInsensitive]
            )
        else {
            return false
        }

        let titleBody = text[titleRange.upperBound..<descriptionRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionBody = text[descriptionRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return titleBody.isEmpty == false && descriptionBody.isEmpty == false
    }
}

#if DEBUG
enum ListingFixtureText {
    static func sample(
        for item: DetectedItem,
        marketplace: Marketplace = .ebay,
        currencyCode: String? = nil
    ) -> String {
        return """
        TITLE:
        \(MarketplaceListingOptimizer.title(for: item, marketplace: marketplace))

        DESCRIPTION:
        \(MarketplaceListingOptimizer.description(for: item, marketplace: marketplace, currencyCode: currencyCode))
        """
    }
}
#endif

struct AuthSession: Codable, Identifiable, Sendable, Hashable {
    let userID: String
    var email: String?
    var accessToken: String?
    var refreshToken: String?
    var appleUserID: String?

    var id: String { userID }

    init(
        userID: String,
        email: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        appleUserID: String? = nil
    ) {
        self.userID = userID
        self.email = email
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.appleUserID = appleUserID
    }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var display: String {
        displayKey.localized
    }

    private var displayKey: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct SnapResultContext: Identifiable, Equatable {
    let id = UUID()
    let imageData: Data
    var preferredMarketplace: Marketplace?
}

struct ItemQuestionsContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let supplementalPhotos: [ItemPhotoAsset]
    let preferredMarketplace: Marketplace?
    let marketplaceComparison: MarketplaceComparison?
    let listingDraft: GeneratedListingDraft?
    let analysis: AnalyzeIntelligence?
    let answers: ItemDetailAnswers?

    init(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        preferredMarketplace: Marketplace?,
        marketplaceComparison: MarketplaceComparison? = nil,
        listingDraft: GeneratedListingDraft? = nil,
        analysis: AnalyzeIntelligence?,
        answers: ItemDetailAnswers?
    ) {
        self.item = item
        self.imageData = imageData
        self.supplementalPhotos = supplementalPhotos.filter { $0.itemID == item.id }
        self.preferredMarketplace = preferredMarketplace
        self.marketplaceComparison = marketplaceComparison?.sanitizedForDisplay()
        self.listingDraft = listingDraft?.sanitizedForDisplay()
        self.analysis = analysis
        self.answers = answers
    }
}

struct MarketplacePickerContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let supplementalPhotos: [ItemPhotoAsset]
    let details: ItemDetailAnswers?
    let analysis: AnalyzeIntelligence?

    init(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        details: ItemDetailAnswers?,
        analysis: AnalyzeIntelligence?
    ) {
        self.item = item
        self.imageData = imageData
        self.supplementalPhotos = supplementalPhotos.filter { $0.itemID == item.id }
        self.details = details
        self.analysis = analysis
    }
}

struct ListingContext: Identifiable, Equatable {
    let id = UUID()
    let item: DetectedItem
    let imageData: Data?
    let supplementalPhotos: [ItemPhotoAsset]
    let marketplace: Marketplace
    let details: ItemDetailAnswers?
    let marketplaceComparison: MarketplaceComparison?
    let analysis: AnalyzeIntelligence?
    let existingListingText: String?
    let existingListingDraft: GeneratedListingDraft?
    let existingHistoryEntry: HistoryEntry?

    init(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        marketplace: Marketplace,
        details: ItemDetailAnswers?,
        marketplaceComparison: MarketplaceComparison? = nil,
        analysis: AnalyzeIntelligence? = nil,
        existingListingText: String?,
        existingListingDraft: GeneratedListingDraft? = nil,
        existingHistoryEntry: HistoryEntry?
    ) {
        self.item = item
        self.imageData = imageData
        self.supplementalPhotos = supplementalPhotos.filter { $0.itemID == item.id }
        self.marketplace = marketplace
        self.details = details?.sanitizedForUse
        self.marketplaceComparison = marketplaceComparison?.sanitizedForDisplay()
        self.analysis = analysis
        self.existingListingText = existingListingText
        self.existingListingDraft = existingListingDraft?.sanitizedForDisplay()
        self.existingHistoryEntry = existingHistoryEntry
    }
}

extension Array where Element: Equatable {
    func next(after element: Element) -> Element {
        guard let index = firstIndex(of: element) else { return self[0] }
        let nextIndex = self.index(after: index)
        return nextIndex == endIndex ? self[0] : self[nextIndex]
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    func currency(code: String = "USD", fractionLength: Int = 0) -> String {
        formatted(
            .currency(code: code)
                .precision(.fractionLength(fractionLength))
        )
    }

    func rounded(scale: Int = 0) -> Decimal {
        var input = self
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }
}
