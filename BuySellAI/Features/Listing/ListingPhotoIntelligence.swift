import Foundation

struct ListingPhotoCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    var imageData: Data
    var role: ListingPhotoRole
    var source: ListingPhotoSource
    var dateAdded: Date
    var verifies: [String]
    var isListingSafe: Bool
    var isAIEdited: Bool
    var relatedOriginalID: UUID?
    var quality: ListingPhotoQuality
    var visualFingerprint: String?

    init(
        id: UUID = UUID(),
        imageData: Data,
        role: ListingPhotoRole,
        source: ListingPhotoSource,
        dateAdded: Date = Date(),
        verifies: [String] = [],
        isListingSafe: Bool = true,
        isAIEdited: Bool = false,
        relatedOriginalID: UUID? = nil,
        quality: ListingPhotoQuality = .unknown,
        visualFingerprint: String? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.role = role
        self.source = source
        self.dateAdded = dateAdded
        self.verifies = verifies
        self.isListingSafe = isListingSafe
        self.isAIEdited = isAIEdited
        self.relatedOriginalID = relatedOriginalID
        self.quality = quality
        self.visualFingerprint = visualFingerprint
    }
}

enum ListingPhotoRole: String, Codable, CaseIterable, Hashable, Sendable {
    case originalIdentification
    case enhancedCover
    case fullItem
    case alternateAngle
    case labelOrModel
    case authenticityMark
    case measurement
    case includedAccessories
    case packaging
    case conditionDetail
    case flaw
    case referenceOnly

    var plainLabel: String {
        switch self {
        case .originalIdentification:
            "Original photo"
        case .enhancedCover:
            "Clean cover photo"
        case .fullItem:
            "Full item"
        case .alternateAngle:
            "Another angle"
        case .labelOrModel:
            "Label or model"
        case .authenticityMark:
            "Authenticity mark"
        case .measurement:
            "Measurement"
        case .includedAccessories:
            "Included items"
        case .packaging:
            "Box or packaging"
        case .conditionDetail:
            "Condition"
        case .flaw:
            "Visible flaw"
        case .referenceOnly:
            "Reference only"
        }
    }
}

enum ListingPhotoSource: String, Codable, Hashable, Sendable {
    case camera
    case photoLibrary
    case aiEnhanced
    case internetReference
}

struct ListingPhotoQuality: Hashable, Sendable {
    var sharpness: Int
    var lighting: Int
    var productVisibility: Int
    var blurPenalty: Int
    var clutterPenalty: Int
    var misleadingRisk: Int

    init(
        sharpness: Int,
        lighting: Int,
        productVisibility: Int,
        blurPenalty: Int = 0,
        clutterPenalty: Int = 0,
        misleadingRisk: Int = 0
    ) {
        self.sharpness = Self.clamped(sharpness)
        self.lighting = Self.clamped(lighting)
        self.productVisibility = Self.clamped(productVisibility)
        self.blurPenalty = Self.clamped(blurPenalty)
        self.clutterPenalty = Self.clamped(clutterPenalty)
        self.misleadingRisk = Self.clamped(misleadingRisk)
    }

    static let unknown = ListingPhotoQuality(
        sharpness: 8,
        lighting: 8,
        productVisibility: 8
    )

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 0), 20)
    }
}

struct ListingPhotoUtility: Hashable, Sendable {
    let identityEvidence: Int
    let buyerTrust: Int
    let marketplaceRelevance: Int
    let sharpness: Int
    let lighting: Int
    let productVisibility: Int
    let conditionDisclosure: Int
    let uniqueInformation: Int
    let blurPenalty: Int
    let clutterPenalty: Int
    let duplicationPenalty: Int
    let misleadingRisk: Int

    var total: Int {
        identityEvidence
            + buyerTrust
            + marketplaceRelevance
            + sharpness
            + lighting
            + productVisibility
            + conditionDisclosure
            + uniqueInformation
            - blurPenalty
            - clutterPenalty
            - duplicationPenalty
            - misleadingRisk
    }
}

struct ListingPhotoRecommendationPackage: Hashable, Sendable {
    let recommendedListingPhotos: [ListingPhotoCandidate]
    let excludedReferencePhotos: [ListingPhotoCandidate]
    let utilityByPhotoID: [UUID: ListingPhotoUtility]

    var recommendation: String {
        let count = recommendedListingPhotos.count
        if count == 0 {
            return "Add one photo before posting."
        }
        if count == 1 {
            return "This photo is enough to start."
        }
        return "\(count) best photos are ready."
    }
}

struct ListingPhotoEnhancementPlan: Hashable, Sendable {
    let sourcePhotoID: UUID
    let relatedOriginalID: UUID
    let targetRole: ListingPhotoRole
    let prompt: String
    let safetyRules: [String]

    var outputSource: ListingPhotoSource { .aiEnhanced }
    var outputIsAIEdited: Bool { true }
    var outputIsListingSafe: Bool { true }
}

enum ListingPhotoIntelligence {
    static func enhancementPlan(
        for candidate: ListingPhotoCandidate,
        item: DetectedItem,
        marketplace: Marketplace,
        targetRole: ListingPhotoRole = .enhancedCover,
        confirmedFacts: [String] = [],
        visibleConditionNotes: [String] = [],
        qualityProblems: [String] = []
    ) -> ListingPhotoEnhancementPlan? {
        guard candidate.imageData.isEmpty == false,
              candidate.isListingSafe,
              candidate.isAIEdited == false,
              candidate.role != .referenceOnly,
              candidate.source != .internetReference
        else { return nil }

        let safetyRules = enhancementSafetyRules()
        let sourceFacts = cleanList(candidate.verifies + confirmedFacts, fallback: ["actual user photo"])
        let conditionNotes = cleanList(visibleConditionNotes, fallback: [item.condition.display])
        let photoIssues = cleanList(qualityProblems, fallback: ["make only gentle listing-photo improvements"])
        let targetPhotoLabel = targetRole.plainLabel.lowercased()

        let promptLines = [
            "Improve this user-owned BuySell listing photo into a \(targetPhotoLabel) for \(marketplace.displayName).",
            "Item: \(cleanText(item.name, fallback: item.category.display)). Category: \(item.category.display). Condition: \(item.condition.display).",
            "Verified details to preserve: \(sourceFacts.joined(separator: "; ")).",
            "Visible condition to preserve: \(conditionNotes.joined(separator: "; ")).",
            "Allowed edits: improve exposure, white balance, careful sharpness, straightening, crop, background cleanup, marketplace-appropriate aspect ratio, and a realistic contact shadow.",
            "Photo issues to address: \(photoIssues.joined(separator: "; ")).",
            "Marketplace photo guidance: \(marketplace.optimizationProfile.photoGuidance)",
            "Safety rules:",
        ] + safetyRules + [
            "Return one realistic edited image derived from the provided photo. Do not generate a different item."
        ]

        return ListingPhotoEnhancementPlan(
            sourcePhotoID: candidate.id,
            relatedOriginalID: candidate.id,
            targetRole: targetRole,
            prompt: promptLines.joined(separator: "\n"),
            safetyRules: safetyRules
        )
    }

    static func recommendedPackage(
        for marketplace: Marketplace,
        candidates: [ListingPhotoCandidate],
        maximumCount: Int? = nil
    ) -> ListingPhotoRecommendationPackage {
        var seenFingerprints = Set<String>()
        let utilities = candidates.reduce(into: [UUID: ListingPhotoUtility]()) { result, candidate in
            let duplicationPenalty = duplicationPenalty(
                for: candidate,
                seenFingerprints: &seenFingerprints
            )
            result[candidate.id] = utility(
                for: candidate,
                marketplace: marketplace,
                duplicationPenalty: duplicationPenalty
            )
        }

        let safeCandidates = candidates.filter { candidate in
            candidate.isListingSafe &&
                candidate.role != .referenceOnly &&
                candidate.source != .internetReference
        }
        let limit = maximumCount ?? recommendedPhotoLimit(for: marketplace)
        let recommended = safeCandidates
            .sorted { left, right in
                let leftUtility = utilities[left.id]?.total ?? Int.min
                let rightUtility = utilities[right.id]?.total ?? Int.min
                guard leftUtility == rightUtility else {
                    return leftUtility > rightUtility
                }
                let leftOrder = roleSequenceRank(left.role, marketplace: marketplace)
                let rightOrder = roleSequenceRank(right.role, marketplace: marketplace)
                guard leftOrder == rightOrder else {
                    return leftOrder < rightOrder
                }
                return left.dateAdded < right.dateAdded
            }
            .prefix(limit)

        return ListingPhotoRecommendationPackage(
            recommendedListingPhotos: Array(recommended),
            excludedReferencePhotos: candidates.filter {
                $0.role == .referenceOnly || $0.source == .internetReference
            },
            utilityByPhotoID: utilities
        )
    }

    static func utility(
        for candidate: ListingPhotoCandidate,
        marketplace: Marketplace,
        duplicationPenalty: Int = 0
    ) -> ListingPhotoUtility {
        ListingPhotoUtility(
            identityEvidence: identityEvidence(for: candidate.role),
            buyerTrust: buyerTrust(for: candidate.role),
            marketplaceRelevance: marketplaceRelevance(for: candidate.role, marketplace: marketplace),
            sharpness: candidate.quality.sharpness,
            lighting: candidate.quality.lighting,
            productVisibility: candidate.quality.productVisibility,
            conditionDisclosure: conditionDisclosure(for: candidate.role),
            uniqueInformation: uniqueInformation(for: candidate),
            blurPenalty: candidate.quality.blurPenalty,
            clutterPenalty: candidate.quality.clutterPenalty,
            duplicationPenalty: duplicationPenalty,
            misleadingRisk: misleadingRisk(for: candidate)
        )
    }

    private static func duplicationPenalty(
        for candidate: ListingPhotoCandidate,
        seenFingerprints: inout Set<String>
    ) -> Int {
        guard let fingerprint = candidate.visualFingerprint?.trimmingCharacters(in: .whitespacesAndNewlines),
              fingerprint.isEmpty == false
        else { return 0 }
        if seenFingerprints.contains(fingerprint) {
            return 28
        }
        seenFingerprints.insert(fingerprint)
        return 0
    }

    private static func identityEvidence(for role: ListingPhotoRole) -> Int {
        switch role {
        case .labelOrModel, .authenticityMark:
            34
        case .originalIdentification, .fullItem, .enhancedCover:
            26
        case .measurement, .packaging:
            18
        case .alternateAngle, .includedAccessories:
            14
        case .conditionDetail, .flaw:
            8
        case .referenceOnly:
            0
        }
    }

    private static func buyerTrust(for role: ListingPhotoRole) -> Int {
        switch role {
        case .fullItem, .enhancedCover:
            24
        case .alternateAngle, .includedAccessories, .packaging:
            20
        case .conditionDetail, .flaw, .labelOrModel, .authenticityMark:
            18
        case .measurement:
            16
        case .originalIdentification:
            14
        case .referenceOnly:
            0
        }
    }

    private static func marketplaceRelevance(for role: ListingPhotoRole, marketplace: Marketplace) -> Int {
        switch marketplace {
        case .facebook, .craigslist, .offerup, .nextdoor, .chairish:
            switch role {
            case .fullItem, .measurement, .flaw, .conditionDetail:
                return 24
            default:
                return 8
            }
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed:
            switch role {
            case .enhancedCover, .fullItem, .labelOrModel, .conditionDetail:
                return 24
            default:
                return 10
            }
        case .stockx, .goat, .tcgplayer, .swappa:
            switch role {
            case .labelOrModel, .authenticityMark, .packaging, .conditionDetail:
                return 26
            default:
                return 10
            }
        default:
            switch role {
            case .enhancedCover, .fullItem, .labelOrModel, .includedAccessories, .flaw:
                return 20
            default:
                return 10
            }
        }
    }

    private static func conditionDisclosure(for role: ListingPhotoRole) -> Int {
        switch role {
        case .flaw:
            28
        case .conditionDetail:
            22
        case .alternateAngle:
            10
        default:
            0
        }
    }

    private static func uniqueInformation(for candidate: ListingPhotoCandidate) -> Int {
        let verificationBonus = min(candidate.verifies.count * 5, 20)
        switch candidate.role {
        case .labelOrModel, .authenticityMark, .measurement, .includedAccessories, .packaging, .flaw:
            return 18 + verificationBonus
        case .alternateAngle, .conditionDetail:
            return 12 + verificationBonus
        case .enhancedCover, .fullItem, .originalIdentification:
            return 8 + verificationBonus
        case .referenceOnly:
            return 0
        }
    }

    private static func misleadingRisk(for candidate: ListingPhotoCandidate) -> Int {
        if candidate.role == .referenceOnly || candidate.source == .internetReference {
            return 100
        }
        if candidate.isAIEdited && candidate.relatedOriginalID == nil {
            return 44
        }
        return candidate.quality.misleadingRisk
    }

    private static func recommendedPhotoLimit(for marketplace: Marketplace) -> Int {
        switch marketplace {
        case .facebook, .craigslist, .offerup, .nextdoor:
            6
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal:
            8
        case .chairish, .reverb:
            10
        case .stockx, .goat, .tcgplayer, .swappa:
            7
        default:
            8
        }
    }

    private static func roleSequenceRank(_ role: ListingPhotoRole, marketplace: Marketplace) -> Int {
        let sequence: [ListingPhotoRole]
        switch marketplace {
        case .stockx, .goat, .tcgplayer, .swappa:
            sequence = [.fullItem, .labelOrModel, .authenticityMark, .packaging, .conditionDetail, .flaw]
        case .facebook, .craigslist, .offerup, .nextdoor, .chairish:
            sequence = [.fullItem, .alternateAngle, .measurement, .conditionDetail, .flaw, .includedAccessories]
        default:
            sequence = [.enhancedCover, .fullItem, .alternateAngle, .labelOrModel, .includedAccessories, .packaging, .conditionDetail, .flaw]
        }
        return sequence.firstIndex(of: role) ?? 99
    }

    private static func enhancementSafetyRules() -> [String] {
        [
            "Preserve the exact product, shape, color, materials, proportions, labels, serial marks, included parts, wear, damage, and condition.",
            "Preserve visible defects, scratches, stains, dents, chips, missing parts, patina, wear, and damage.",
            "Do not change colors, materials, logos, labels, serial numbers, authenticity marks, model numbers, sizes, text, or packaging details.",
            "Do not invent accessories, boxes, certificates, features, rarity, authenticity, or a newer-looking condition.",
            "Do not make a used item appear new, unused, sealed, or more valuable than the original photo supports."
        ]
    }

    private static func cleanList(_ values: [String], fallback: [String]) -> [String] {
        let cleaned = values
            .map { cleanText($0, fallback: "") }
            .filter { $0.isEmpty == false }
        return cleaned.isEmpty ? fallback : Array(cleaned.prefix(5))
    }

    private static func cleanText(_ value: String, fallback: String) -> String {
        let cleanValue = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue.isEmpty ? fallback : String(cleanValue.prefix(180))
    }
}
