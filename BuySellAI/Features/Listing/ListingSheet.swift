import SwiftUI
import UIKit
import Photos

struct ListingSheet: View {
    let context: ListingContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var store: ListingStore
    @State private var generationTask: Task<Void, Never>?
    @State private var generationTaskID = UUID()
    @State private var isEvidenceExpanded = false
    @State private var isEditingListingText = false
    @State private var isSavingPhotos = false
    @State private var sharePayload: ListingSharePayload?
    @FocusState private var isListingEditorFocused: Bool

    init(context: ListingContext) {
        self.context = context
        _store = State(initialValue: ListingStore(
            item: context.item,
            marketplace: context.marketplace,
            details: context.details,
            marketplaceComparison: context.marketplaceComparison,
            identificationProfile: context.analysis?.identificationProfile,
            imageData: context.imageData,
            existingListingText: context.existingListingText,
            existingListingDraft: context.existingListingDraft
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }

                phaseSections
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
            .navigationTitle("Ready to copy".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeListingButton
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
            .background(Color.clear)
        }
        .background(Color.clear)
        .task {
            await store.generateIfNeeded(accessToken: await appStore.authenticatedAccessToken())
        }
        .onChange(of: store.entitlementSnapshot) { _, snapshot in
            appStore.updateEntitlementSnapshot(snapshot)
        }
        .onDisappear {
            cancelGenerationTask()
        }
        .sheet(item: $sharePayload) { payload in
            ListingShareSheet(items: payload.items)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            MarketplaceIcon(marketplace: context.marketplace)
            headerTitle
        }
        .padding(.vertical, Spacing.xs)
        .accessibilitySortPriority(4)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(String.localizedFormat("Listing for %@", context.marketplace.displayName))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
            Text(context.marketplace.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeListingButton: some View {
        Button {
            Haptics.impact(.light)
            appStore.closeFlow()
        } label: {
            Label("Close listing".localized, systemImage: "xmark")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Close listing".localized)
    }

    @ViewBuilder
    private var phaseSections: some View {
        switch store.phase {
        case .idle, .loading:
            Section {
                loading
            }
        case .success:
            Section("Generated listing text".localized) {
                listingText
            }
            Section("Do this next".localized) {
                ForEach(listingNextSteps) { step in
                    listingNextStepRow(step)
                }
            }
            Section {
                listingRecommendationSummary
            }
            Section("Details".localized) {
                if copyableListingFields.isEmpty == false {
                    copyPiecesDisclosure
                }
                if hasPostingBlockers {
                    postingChecklistDisclosure
                }
                photosDisclosure
                pricePlanDisclosure
                if hasCompRange {
                    soldCompsDisclosure
                }
                evidenceDisclosure
                quickTipsDisclosure
            }
        case .failed(let message):
            Section {
                error(message)
            }
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Label("Writing your listing…".localized, systemImage: AppSymbol.Action.composeListing)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                listingLoadingStepRow(
                    title: "Matches the marketplace",
                    detail: String.localizedFormat("Uses the style and fields %@ expects.".localized, context.marketplace.displayName),
                    systemImage: context.marketplace.iconSystemName
                )
                listingLoadingStepRow(
                    title: "Checks the price plan",
                    detail: "Uses sold evidence, fees, and a lowest offer.".localized,
                    systemImage: "dollarsign.circle.fill"
                )
                listingLoadingStepRow(
                    title: "Builds the photo list",
                    detail: "Marks the photos still needed before posting.".localized,
                    systemImage: "camera.viewfinder"
                )
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonLine(width: skeletonLineWidth(for: index))
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Writing your listing…".localized)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilitySortPriority(3)
    }

    private func listingLoadingStepRow(title: String, detail: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text(detail.localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .brandSymbol(.controlIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail.localized))
    }

    private var listingRecommendationSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(recommendationLabel.localized, systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String.localizedFormat("Ready for %@", context.marketplace.displayName))
                    .font(.headline)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(recommendationReason)
                    .font(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            recommendationTakeHome
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@, %@", recommendationLabel.localized, String.localizedFormat("Ready for %@", context.marketplace.displayName), recommendationReason))
        .accessibilityValue(String.localizedFormat("%@, %@", "Take-home estimate".localized, pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode)))
        .accessibilityIdentifier("Listing.RecommendationSummary")
        .accessibilitySortPriority(3)
    }

    private var copyPiecesDisclosure: some View {
        DisclosureGroup {
            ForEach(copyableListingFields) { field in
                copyFieldRow(field)
            }
        } label: {
            Label("Copy pieces".localized, systemImage: "doc.on.doc")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.CopyPiecesDisclosure")
        .accessibilityHint("Shows individual fields you can copy.".localized)
    }

    private var postingChecklistDisclosure: some View {
        DisclosureGroup {
            if let missingInfoWarnings = joinedDraftValues(store.draft?.missingInfoWarnings) {
                marketplaceTipRow(
                    title: "Missing details",
                    systemImage: "exclamationmark.triangle.fill",
                    detail: missingInfoWarnings
                )
            }
            if let missingPhotoPrompt = store.draft?.missingPhotoPrompt {
                photoChecklistRow(
                    title: "Add one more photo",
                    systemImage: AppSymbol.Action.addPhoto,
                    detail: missingPhotoPrompt
                )
            }
            Button {
                handlePostingBlocker()
            } label: {
                Label(checkBeforePostingActionTitle, systemImage: checkBeforePostingActionSystemImage)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.brand.foregroundSecondary)
            .accessibilityLabel(checkBeforePostingActionTitle)
            .accessibilityHint(checkBeforePostingActionHint)
        } label: {
            Label("Check before posting".localized, systemImage: "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.PostingChecklistDisclosure")
        .accessibilityHint("Shows the last details or photos needed before posting.".localized)
    }

    private var photosDisclosure: some View {
        DisclosureGroup {
            listingPhotoPackageRow
            if let marketplacePhotoChecklistText {
                photoChecklistRow(
                    title: "Photos to take",
                    systemImage: "camera.viewfinder",
                    detail: marketplacePhotoChecklistText
                )
            }
            photoChecklistRow(
                title: "Best first photo",
                systemImage: AppSymbol.Flow.snapPhotoCompact,
                detail: primaryPhotoGuidance
            )
            if let missingPhotoPrompt = store.draft?.missingPhotoPrompt {
                photoChecklistRow(
                    title: "Add one more photo",
                    systemImage: AppSymbol.Action.addPhoto,
                    detail: missingPhotoPrompt
                )
                Button {
                    handlePhotoBlocker()
                } label: {
                    Label("Add missing photo".localized, systemImage: AppSymbol.Action.addPhoto)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color.brand.foregroundSecondary)
                .accessibilityLabel("Add missing photo".localized)
                .accessibilityHint("Opens the camera for the exact photo this listing needs.".localized)
            }
        } label: {
            Label("Photos".localized, systemImage: "photo.on.rectangle")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.PhotosDisclosure")
        .accessibilityHint("Shows photo guidance for this marketplace.".localized)
    }

    private var pricePlanDisclosure: some View {
        DisclosureGroup {
            listingPriceRow(
                title: "List at",
                value: pricePlan.listAt,
                detail: "Start here"
            )
            listingPriceRow(
                title: "Likely sells for",
                value: pricePlan.likelySellsFor,
                detail: "Expected sale"
            )
            listingPriceRow(
                title: "Take-home estimate",
                value: pricePlan.takeHomeEstimate,
                detail: "What you may keep"
            )
            listingPriceRow(
                title: "Lowest to take",
                value: pricePlan.negotiationFloor,
                detail: "If someone offers less"
            )
        } label: {
            Label("Price plan".localized, systemImage: "dollarsign.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.PricePlanDisclosure")
        .accessibilityHint("Shows the list price, likely sale price, take-home estimate, and lowest offer.".localized)
    }

    private var soldCompsDisclosure: some View {
        DisclosureGroup {
            if let compLowPrice = store.draft?.compLowPrice {
                listingPriceRow(
                    title: "Lowest sold",
                    value: compLowPrice,
                    detail: "Past comp"
                )
            }
            if let compMedianPrice = store.draft?.compMedianPrice {
                listingPriceRow(
                    title: "Typical sold",
                    value: compMedianPrice,
                    detail: "Past comps"
                )
            }
            if let compHighPrice = store.draft?.compHighPrice {
                listingPriceRow(
                    title: "Highest sold",
                    value: compHighPrice,
                    detail: "Past comp"
                )
            }
        } label: {
            Label("What it sells for".localized, systemImage: "chart.line.uptrend.xyaxis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.SoldCompsDisclosure")
        .accessibilityHint("Shows verified comparable sale prices when available.".localized)
    }

    private var quickTipsDisclosure: some View {
        DisclosureGroup {
            if let feeSummary = store.draft?.feeSummary {
                marketplaceTipRow(
                    title: "Selling fees",
                    systemImage: "percent",
                    detail: feeSummary
                )
            }
            if let pricingStrategy = store.draft?.pricingStrategy {
                marketplaceTipRow(
                    title: "Price move",
                    systemImage: "slider.horizontal.3",
                    detail: pricingStrategy
                )
            }
            marketplaceTipRow(
                title: "What helps here",
                systemImage: "lightbulb.fill",
                detail: store.draft?.fitReason ?? context.marketplace.optimizationProfile.featuredGuidance
            )
            marketplaceTipRow(
                title: "Shipping or pickup",
                systemImage: AppSymbol.Marketplace.package,
                detail: fulfillmentRecommendation
            )
            if let itemSpecifics = joinedDraftValues(store.draft?.itemSpecifics) {
                marketplaceTipRow(
                    title: "Details to include",
                    systemImage: "list.bullet.rectangle",
                    detail: itemSpecifics
                )
            }
            if let postingNotes = joinedDraftValues(store.draft?.postingNotes) {
                marketplaceTipRow(
                    title: "When posting",
                    systemImage: "checklist",
                    detail: postingNotes
                )
            }
            if let tags = joinedDraftValues(store.draft?.tags) {
                marketplaceTipRow(
                    title: "Tags",
                    systemImage: AppSymbol.Action.category,
                    detail: tags
                )
            }
        } label: {
            Label("Quick tips".localized, systemImage: "lightbulb.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.QuickTipsDisclosure")
        .accessibilityHint("Shows marketplace-specific posting tips.".localized)
    }

    private var listingNextSteps: [ListingNextStep] {
        [
            ListingNextStep(
                number: 1,
                title: "Copy listing".localized,
                detail: String.localizedFormat("Paste it into %@".localized, context.marketplace.displayName),
                systemImage: AppSymbol.Flow.copy
            ),
            ListingNextStep(
                number: 2,
                title: "Save photos".localized,
                detail: nextStepPhotoDetail,
                systemImage: "square.and.arrow.down"
            ),
            ListingNextStep(
                number: 3,
                title: nextStepPostTitle,
                detail: nextStepPostDetail,
                systemImage: nextStepPostSystemImage
            )
        ]
    }

    private var nextStepPhotoDetail: String {
        let photoCount = photoPackage.recommendedListingPhotos.count
        if photoCount > 0 {
            return String.localizedFormat("%d ready photo(s)".localized, photoCount)
        }
        return photoPackage.recommendation
    }

    private var nextStepPostTitle: String {
        hasPostingBlockers ? "Fix before posting".localized : postButtonTitle
    }

    private var nextStepPostDetail: String {
        if let warning = firstPostingBlocker {
            return warning
        }
        return "BuySell copies the listing before opening the marketplace.".localized
    }

    private var nextStepPostSystemImage: String {
        hasPostingBlockers ? "exclamationmark.triangle.fill" : "safari"
    }

    private var hasPostingBlockers: Bool {
        firstPostingBlocker != nil
    }

    private var firstPostingBlocker: String? {
        if let missingInfo = joinedDraftValues(store.draft?.missingInfoWarnings) {
            return missingInfo
        }
        let missingPhoto = store.draft?.missingPhotoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if missingPhoto.isEmpty == false {
            return missingPhoto
        }
        if photoPackage.recommendedListingPhotos.isEmpty {
            return "Add a real item photo before posting.".localized
        }
        return nil
    }

    private func listingNextStepRow(_ step: ListingNextStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text("\(step.number)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 26, height: 26)
                .background(Color.brand.primaryMuted.opacity(0.72), in: Circle())
                .accessibilityHidden(true)

            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(step.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: step.systemImage)
                    .brandSymbol(.controlIcon)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("Step %d, %@, %@".localized, step.number, step.title, step.detail))
    }

    @ViewBuilder
    private var recommendationTakeHome: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Take-home".localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                Text(pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Take-home".localized)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                Spacer(minLength: Spacing.md)
                Text(pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
            }
        }
    }

    private var recommendationLabel: String {
        selectedRecommendationKind.label
    }

    private var recommendationReason: String {
        store.draft?.fitReason ?? context.marketplace.recommendationReason(for: context.item)
    }

    private var selectedRecommendationKind: MarketplaceSummaryKind {
        MarketplaceSummaryPlanner
            .picks(
                from: MarketplaceEstimator.estimates(for: context.item, details: context.details),
                item: context.item,
                details: context.details
            )
            .first { $0.estimate.id == context.marketplace }?
            .kind ?? .bestOverall
    }

    private var hasCompRange: Bool {
        store.draft?.compLowPrice != nil ||
            store.draft?.compMedianPrice != nil ||
            store.draft?.compHighPrice != nil
    }

    private var evidenceDisclosure: some View {
        DisclosureGroup(isExpanded: $isEvidenceExpanded) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let evidenceSummary = store.draft?.evidenceSummary {
                    evidenceDetailRow(
                        title: "Market check",
                    systemImage: AppSymbol.Action.search,
                        detail: evidenceSummary
                    )
                }
                if let compRangeText {
                    evidenceDetailRow(
                        title: "Sold price range",
                        systemImage: "chart.line.uptrend.xyaxis",
                        detail: compRangeText
                    )
                } else {
                    evidenceDetailRow(
                        title: "Sold prices",
                        systemImage: "chart.line.uptrend.xyaxis",
                        detail: soldPriceUnavailableText
                    )
                }
                if let evidenceSources = store.draft?.evidenceSources {
                    ForEach(evidenceSources) { source in
                        evidenceSourceRow(source)
                    }
                }
                evidenceDetailRow(
                    title: "Fee source",
                    systemImage: AppSymbol.Flow.savedListing,
                    detail: context.marketplace.playbookEvidence.feeModelSourceTitle
                )
                evidenceDetailRow(
                    title: "Last checked",
                    systemImage: "calendar",
                    detail: context.marketplace.playbookEvidence.feeModelLastChecked
                )
                evidenceDetailRow(
                    title: "Fee note",
                    systemImage: "percent",
                    detail: context.marketplace.playbookEvidence.feeModelSummary
                )
                evidenceDetailRow(
                    title: "Post source",
                    systemImage: AppSymbol.Marketplace.cart,
                    detail: context.marketplace.postingDestination.sourceTitle
                )
                evidenceDetailRow(
                    title: "Post info checked",
                    systemImage: "calendar.badge.checkmark",
                    detail: context.marketplace.postingDestination.lastChecked
                )
                if let publicImageQuery = store.draft?.publicImageQuery {
                    evidenceDetailRow(
                        title: "Image search",
                        systemImage: "photo.on.rectangle",
                        detail: publicImageQuery
                    )
                }
                if let referenceImageURL {
                    evidenceDetailRow(
                        title: "Reference only",
                        systemImage: "photo.badge.checkmark",
                        detail: "Use this to check the item, not as a listing photo.".localized
                    )
                    evidenceLink(title: "Open reference image", systemImage: "safari", url: referenceImageURL)
                }
                if let feeSourceURL {
                    evidenceLink(title: "Open fee source", systemImage: "safari", url: feeSourceURL)
                }
                if let postingHelpURL = context.marketplace.postingDestination.howToURL {
                    evidenceLink(title: "Open posting help", systemImage: "questionmark.circle", url: postingHelpURL)
                }
            }
            .padding(.top, Spacing.sm)
        } label: {
            Label("Evidence".localized, systemImage: "checkmark.shield")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .accessibilityIdentifier("Listing.EvidenceDisclosure")
        .accessibilityLabel("Evidence".localized)
        .accessibilityHint("Shows the checks behind this listing.".localized)
    }

    private var listingText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                toggleListingEditing()
            } label: {
                Label(editListingButtonTitle.localized, systemImage: editListingButtonSystemImage)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.brand.foregroundSecondary)
            .accessibilityLabel(editListingButtonTitle.localized)

            if isEditingListingText {
                TextEditor(text: $store.listingText)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                    .lineSpacing(4)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: listingEditorMinHeight)
                    .focused($isListingEditorFocused)
                    .accessibilityLabel("Listing text".localized)
                    .accessibilityIdentifier("Listing.TextEditor")
            } else {
                Text(store.listingText)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Generated listing text".localized)
                    .accessibilityValue(store.listingText)
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilitySortPriority(3)
    }

    private func copyFieldRow(_ field: ListingCopyField) -> some View {
        Button {
            copyListingField(field)
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: field.systemImage)
                    .brandSymbol(.controlIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(field.title.localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)

                    Text(field.previewText)
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: AppSymbol.Flow.copy)
                    .brandSymbol(.controlIcon)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .padding(.vertical, Spacing.xxs)
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(String.localizedFormat("Copy %@".localized, field.title.localized))
        .accessibilityValue(field.accessibilityValue)
    }

    private func listingPriceRow(title: String, value: Decimal, detail: String) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(value.currency(code: context.item.currencyCode))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
                Text(detail.localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
            }
        } label: {
            Text(title.localized)
                .font(.body)
                .foregroundStyle(Color.brand.foreground)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, value.currency(code: context.item.currencyCode)))
    }

    private func marketplaceTipRow(title: String, systemImage: String, detail: String) -> some View {
        LabeledContent {
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.trailing)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Label(title.localized, systemImage: systemImage)
                .font(.body)
                .foregroundStyle(Color.brand.foreground)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail))
    }

    private func photoChecklistRow(title: String, systemImage: String, detail: String) -> some View {
        LabeledContent {
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Label(title.localized, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail))
    }

    @ViewBuilder
    private func evidenceDetailRow(title: String, systemImage: String, detail: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Label(title.localized, systemImage: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail))
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Label(title.localized, systemImage: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .frame(minWidth: 112, alignment: .leading)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail))
        }
    }

    private func evidenceLink(title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            Label(title.localized, systemImage: systemImage)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(title.localized)
    }

    private var copyableListingFields: [ListingCopyField] {
        var fields: [ListingCopyField] = []
        let draft = store.draft
        fields.appendIfPresent(
            title: "Full listing",
            value: copyableListingText,
            systemImage: "doc.on.doc"
        )
        fields.appendIfPresent(
            title: "Title",
            value: draft?.title,
            systemImage: "textformat"
        )
        fields.appendIfPresent(
            title: "Description",
            value: draft?.description,
            systemImage: "text.alignleft"
        )
        fields.append(ListingCopyField(
            title: "Category",
            value: context.item.category.display,
            systemImage: AppSymbol.Action.category
        ))
        fields.append(ListingCopyField(
            title: "Condition",
            value: context.item.condition.display,
            systemImage: "slider.horizontal.3"
        ))
        fields.append(ListingCopyField(
            title: "Price",
            value: pricePlan.listAt.currency(code: context.item.currencyCode),
            systemImage: AppSymbol.Action.category
        ))
        fields.append(ListingCopyField(
            title: "Lowest to take",
            value: pricePlan.negotiationFloor.currency(code: context.item.currencyCode),
            systemImage: "arrow.down.circle.fill"
        ))
        fields.append(ListingCopyField(
            title: "Shipping or pickup",
            value: fulfillmentRecommendation,
            systemImage: AppSymbol.Marketplace.package
        ))
        fields.appendIfPresent(
            title: "Photo checklist",
            value: photoChecklistText,
            systemImage: "camera.viewfinder"
        )
        fields.appendIfPresent(
            title: "Details",
            value: joinedDraftValues(draft?.itemSpecifics),
            systemImage: "list.bullet.rectangle"
        )
        fields.appendIfPresent(
            title: "Posting notes",
            value: joinedDraftValues(draft?.postingNotes),
            systemImage: "checklist"
        )
        fields.appendIfPresent(
            title: "Tags",
            value: joinedDraftValues(draft?.tags),
            systemImage: "number.circle.fill"
        )
        fields.appendIfPresent(
            title: "Missing details",
            value: joinedDraftValues(draft?.missingInfoWarnings),
            systemImage: "exclamationmark.triangle.fill"
        )
        return fields
    }

    private func evidenceSourceRow(_ source: ListingEvidenceSource) -> some View {
        let detail = source.detailLine(currencyCode: context.item.currencyCode)
        let sourceDetail = [
            source.title,
            detail.isEmpty ? nil : detail
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            evidenceDetailRow(
                title: source.sourceMarketplace ?? "Source",
                systemImage: "list.clipboard",
                detail: sourceDetail.isEmpty ? "Source details".localized : sourceDetail
            )
            if let urlString = source.url, let url = URL(string: urlString) {
                evidenceLink(title: "Open source", systemImage: "safari", url: url)
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 28)
            }
        }
    }

    private func joinedDraftValues(_ values: [String]?) -> String? {
        let cleanValues = values?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false } ?? []
        guard cleanValues.isEmpty == false else { return nil }
        return cleanValues.joined(separator: ", ")
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Color.brand.destructive)
                .accessibilityHidden(true)

            Text(message)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Listing.ErrorMessage")

            Button {
                Haptics.impact(.light)
                regenerateListing()
            } label: {
                Label("Regenerate".localized, systemImage: AppSymbol.Action.retry)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Regenerate".localized)

            Button {
                Haptics.impact(.light)
                retakePhoto()
            } label: {
                Label("Wrong item — retake".localized, systemImage: AppSymbol.Action.retakePhoto)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.brand.foregroundSecondary)
            .accessibilityLabel("Wrong item — retake".localized)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .accessibilitySortPriority(3)
        .task(id: message) {
            appStore.showToast(message, style: .error)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        switch store.phase {
        case .success:
            successBottomActions
        case .idle, .loading, .failed:
            EmptyView()
        }
    }

    private var successBottomActions: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                copyListing()
            } label: {
                Label("Copy listing".localized, systemImage: AppSymbol.Flow.copy)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(Color.brand.primary)
            .disabled(copyableListingText.isEmpty)
            .accessibilityLabel("Copy listing".localized)
            .accessibilitySortPriority(3)

            listingMoreMenu
        }
        .frame(maxWidth: sheetContentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xxs)
        .background(.bar)
    }

    private var listingMoreMenu: some View {
        Menu {
            Button {
                if hasListingHandoffBlockers {
                    handlePostingBlocker()
                } else {
                    postOnMarketplace()
                }
            } label: {
                Label(
                    hasListingHandoffBlockers ? checkBeforePostingActionTitle : postButtonTitle,
                    systemImage: hasListingHandoffBlockers ? checkBeforePostingActionSystemImage : "safari"
                )
            }

            Button {
                openHowToPost()
            } label: {
                Label("How to post here".localized, systemImage: "questionmark.circle")
            }

            Divider()

            Button {
                savePhotosToLibrary(scope: .recommended)
            } label: {
                Label("Save recommended to Photos".localized, systemImage: "photo.on.rectangle")
            }
            .disabled(photoPackage.recommendedListingPhotos.isEmpty)

            Button {
                savePhotosToLibrary(scope: .allListingReady)
            } label: {
                Label("Save all to Photos".localized, systemImage: "photo.stack")
            }
            .disabled(isSavingPhotos)

            Button {
                shareOrExportPhotos(scope: .recommended)
            } label: {
                Label("Share recommended to Files".localized, systemImage: "folder")
            }

            Button {
                shareOrExportPhotos(scope: .allListingReady)
            } label: {
                Label("Share all to Files".localized, systemImage: "square.and.arrow.up.on.square")
            }

            Button {
                shareListing()
            } label: {
                Label("Share listing".localized, systemImage: "square.and.arrow.up")
            }

            Button {
                chooseAnotherMarketplace()
            } label: {
                Label("Try another marketplace".localized, systemImage: "arrow.left.arrow.right")
            }

            Button {
                retakePhoto()
            } label: {
                Label("Wrong item — retake".localized, systemImage: AppSymbol.Action.retakePhoto)
            }

            Button {
                regenerateListing()
            } label: {
                Label("Regenerate".localized, systemImage: AppSymbol.Action.retry)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(Color.brand.foregroundSecondary)
        .accessibilityLabel("More".localized)
        .accessibilityHint("Shows posting, photo, sharing, and retry actions.".localized)
        .accessibilitySortPriority(2)
    }

    private var checkBeforePostingActionTitle: String {
        if joinedDraftValues(store.draft?.missingInfoWarnings) != nil {
            return "Fix missing details".localized
        }
        if listingPhotoScanRequest != nil || store.draft?.missingPhotoPrompt != nil {
            return "Add missing photo".localized
        }
        return "Add item photo".localized
    }

    private var checkBeforePostingActionSystemImage: String {
        if joinedDraftValues(store.draft?.missingInfoWarnings) != nil {
            return "questionmark.circle"
        }
        return AppSymbol.Action.addPhoto
    }

    private var checkBeforePostingActionHint: String {
        if joinedDraftValues(store.draft?.missingInfoWarnings) != nil {
            return "Asks only the remaining details for this marketplace.".localized
        }
        return "Opens the camera for the exact photo this listing needs.".localized
    }

    private var listingPhotoScanRequest: TargetedScanRequest? {
        if let prompt = store.draft?.missingPhotoPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           prompt.isEmpty == false {
            return TargetedScanRequest(
                prompt: prompt,
                benefit: TargetedScanRequest.benefit(for: prompt),
                role: TargetedScanRequest.role(for: prompt)
            )
        }
        return MarketplacePhotoScanPlaybook.targetedScanRequest(
            for: context.marketplace,
            item: context.item,
            answers: context.details ?? ItemDetailAnswers(),
            supplementalPhotos: context.supplementalPhotos
        )
    }

    private func regenerateListing() {
        generationTask?.cancel()
        let taskID = UUID()
        generationTaskID = taskID
        generationTask = Task { @MainActor in
            await store.generate(accessToken: await appStore.authenticatedAccessToken())
            guard Task.isCancelled == false, generationTaskID == taskID else { return }
            generationTask = nil
        }
    }

    private func chooseAnotherMarketplace() {
        appStore.presentMarketplacePicker(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            details: context.details,
            analysis: context.analysis
        )
    }

    private func handlePostingBlocker() {
        if joinedDraftValues(store.draft?.missingInfoWarnings) != nil {
            fixMissingDetails()
            return
        }
        handlePhotoBlocker()
    }

    private func handlePhotoBlocker() {
        guard let request = listingPhotoScanRequest else {
            appStore.showToast("Add a real item photo before posting.".localized, style: .error)
            return
        }
        startListingPhotoScan(request)
    }

    private func fixMissingDetails() {
        Haptics.impact(.medium)
        appStore.presentItemQuestions(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            preferredMarketplace: context.marketplace,
            marketplaceComparison: context.marketplaceComparison,
            listingDraft: store.draft,
            analysis: context.analysis,
            answers: context.details
        )
    }

    private func startListingPhotoScan(_ request: TargetedScanRequest) {
        let answers = context.details ?? ItemDetailAnswers()
        let questionsContext = ItemQuestionsContext(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            preferredMarketplace: context.marketplace,
            marketplaceComparison: context.marketplaceComparison,
            listingDraft: store.draft,
            analysis: context.analysis,
            answers: answers
        )
        Haptics.impact(.medium)
        appStore.startTargetedScan(
            request: request,
            context: questionsContext,
            answers: answers,
            answeredField: .targetedScan
        )
    }

    private func retakePhoto() {
        appStore.retakePhoto(keeping: context.marketplace)
    }

    private func toggleListingEditing() {
        if isEditingListingText {
            guard copyableListingText.isEmpty == false else {
                appStore.showToast("Keep a title and description before copying.".localized, style: .error)
                isListingEditorFocused = true
                return
            }
            isListingEditorFocused = false
        }

        Haptics.impact(.light)
        isEditingListingText.toggle()
        if isEditingListingText {
            isListingEditorFocused = true
        }
    }

    private func shareListing() {
        let cleanText = copyableListingText
        guard cleanText.isEmpty == false else {
            appStore.showToast(APIError.decoding.localizedDescription, style: .error)
            return
        }
        Haptics.impact(.light)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": "share_sheet"
            ]
        )
        appStore.saveListing(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            marketplace: context.marketplace,
            listingText: cleanText,
            details: context.details,
            marketplaceComparison: context.marketplaceComparison,
            listingDraft: store.draft,
            identificationProfile: context.analysis?.identificationProfile,
            replacing: context.existingHistoryEntry
        )
        sharePayload = ListingSharePayload(items: [cleanText])
    }

    private func shareOrExportPhotos(scope: ListingPhotoExportScope) {
        let exports = photoPackage.exportFiles(for: context.item, scope: scope)
        guard exports.isEmpty == false else {
            appStore.showToast("Add a real item photo before posting.".localized, style: .error)
            return
        }
        guard let exportURLs = makePhotoExportURLs(from: exports) else { return }
        Haptics.impact(.light)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": scope == .recommended ? "photo_set" : "photo_set_all",
                "photo_scope": scope.rawValue,
                "photo_count": "\(exportURLs.count)"
            ]
        )
        if copyableListingText.isEmpty == false {
            appStore.saveListing(
                item: context.item,
                imageData: context.imageData,
                supplementalPhotos: context.supplementalPhotos,
                marketplace: context.marketplace,
                listingText: copyableListingText,
                details: context.details,
                marketplaceComparison: context.marketplaceComparison,
                listingDraft: store.draft,
                identificationProfile: context.analysis?.identificationProfile,
                replacing: context.existingHistoryEntry
            )
        }
        sharePayload = ListingSharePayload(items: exportURLs)
    }

    private func savePhotosToLibrary(scope: ListingPhotoExportScope) {
        let exports = photoPackage.exportFiles(for: context.item, scope: scope)
        guard exports.isEmpty == false else {
            appStore.showToast("Add a real item photo before posting.".localized, style: .error)
            return
        }
        guard isSavingPhotos == false else { return }
        isSavingPhotos = true
        Haptics.impact(.light)
        Task {
            let result = await ListingPhotoLibrarySaver.save(exports)
            await MainActor.run {
                isSavingPhotos = false
                switch result {
                case .saved(let count):
                    Haptics.notify(.success)
                    ProductAnalytics.record(
                        .listingCopiedOrExported,
                        properties: [
                            "marketplace": context.marketplace.rawValue,
                            "category": context.item.category.rawValue,
                            "export_type": scope == .recommended ? "apple_photos" : "apple_photos_all",
                            "photo_scope": scope.rawValue,
                            "photo_count": "\(count)"
                        ]
                    )
                    if copyableListingText.isEmpty == false {
                        appStore.saveListing(
                            item: context.item,
                            imageData: context.imageData,
                            supplementalPhotos: context.supplementalPhotos,
                            marketplace: context.marketplace,
                            listingText: copyableListingText,
                            details: context.details,
                            marketplaceComparison: context.marketplaceComparison,
                            listingDraft: store.draft,
                            identificationProfile: context.analysis?.identificationProfile,
                            replacing: context.existingHistoryEntry
                        )
                    }
                    appStore.showToast(String.localizedFormat("%d photos saved", count), style: .success)
                case .denied:
                    appStore.showToast("Allow photo saving in Settings, or use Share to Files.".localized, style: .error)
                case .failed:
                    appStore.showToast("Couldn't save photos. Try again.".localized, style: .error)
                }
            }
        }
    }

    private func makePhotoExportURLs(from exports: [ListingPhotoExport]) -> [URL]? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuySell-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try exports.map { export in
                let url = directory.appendingPathComponent(export.fileName)
                try export.imageData.write(to: url, options: .atomic)
                return url
            }
        } catch {
            appStore.showToast("Couldn't save photos. Try again.".localized, style: .error)
            return nil
        }
    }

    private func postOnMarketplace() {
        guard let url = context.marketplace.postingDestination.postURL else {
            appStore.showToast("Posting link isn't available right now.".localized, style: .error)
            return
        }
        copyListingToClipboardAndSave(exportType: "post_destination_prefill", showsToast: false)
        Haptics.impact(.light)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": "post_destination"
            ]
        )
        openURL(url)
    }

    private func openHowToPost() {
        guard let url = context.marketplace.postingDestination.howToURL else {
            appStore.showToast("Posting link isn't available right now.".localized, style: .error)
            return
        }
        Haptics.impact(.light)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": "posting_help"
            ]
        )
        openURL(url)
    }

    private func copyListing() {
        copyListingToClipboardAndSave(exportType: "full_listing", showsToast: true)
    }

    private func copyListingToClipboardAndSave(exportType: String, showsToast: Bool) {
        let cleanText = copyableListingText
        guard cleanText.isEmpty == false else {
            appStore.showToast(APIError.decoding.localizedDescription, style: .error)
            return
        }
        UIPasteboard.general.string = cleanText
        if LaunchArguments.contains(LaunchArguments.uiTestingVerifyClipboard) {
            appStore.uiTestClipboardStatus = clipboardStatus(expected: cleanText)
        }
        Haptics.notify(.success)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": exportType
            ]
        )
        appStore.saveListing(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            marketplace: context.marketplace,
            listingText: cleanText,
            details: context.details,
            marketplaceComparison: context.marketplaceComparison,
            listingDraft: store.draft,
            identificationProfile: context.analysis?.identificationProfile,
            replacing: context.existingHistoryEntry
        )
        if showsToast {
            appStore.showToast(String.localizedFormat("Copied — paste it into %@", context.marketplace.displayName), style: .success)
        }
    }

    private func copyListingField(_ field: ListingCopyField) {
        let cleanValue = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.isEmpty == false else { return }
        UIPasteboard.general.string = cleanValue
        Haptics.notify(.success)
        ProductAnalytics.record(
            .listingCopiedOrExported,
            properties: [
                "marketplace": context.marketplace.rawValue,
                "category": context.item.category.rawValue,
                "export_type": "field"
            ]
        )
        appStore.showToast(String.localizedFormat("Copied %@", field.title.localized), style: .success)
    }

    private var copyableListingText: String {
        (try? ListingTextContract.validatedGenerated(store.listingText)) ?? ""
    }

    private var primaryPhotoGuidance: String {
        store.draft?.firstPhoto ?? context.marketplace.optimizationProfile.photoGuidance
    }

    private var photoPackage: ListingPhotoPackage {
        ListingPhotoPackage.makeForListing(
            item: context.item,
            marketplace: context.marketplace,
            originalImageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            referenceImageURL: store.draft?.referenceImageURL
        )
    }

    private var postButtonTitle: String {
        String.localizedFormat("Post on %@".localized, context.marketplace.displayName)
    }

    private var hasListingHandoffBlockers: Bool {
        hasPostingBlockers || photoPackage.recommendedListingPhotos.isEmpty
    }

    private var photoChecklistText: String? {
        numberedDraftValues(photoChecklistValues)
    }

    private var photoChecklistValues: [String?] {
        let marketplaceSteps = marketplacePhotoChecklistSteps.map { step -> String? in step }
        return marketplaceSteps + [
            primaryPhotoGuidance,
            store.draft?.missingPhotoPrompt
        ]
    }

    private var marketplacePhotoChecklistText: String? {
        let steps = marketplacePhotoChecklistSteps
        guard steps.isEmpty == false else { return nil }
        return steps.joined(separator: ", ")
    }

    private var marketplacePhotoChecklistSteps: [String] {
        context.marketplace.listingPlaybook.recommendedPhotoSequence
            .map { $0.displayTitle.localized }
    }

    private var fulfillmentRecommendation: String {
        let userNote = context.marketplace.savedFulfillmentNote(in: context.details)
        if userNote.isEmpty == false {
            return userNote
        }

        let profile = context.marketplace.optimizationProfile
        let localFit = profile.localPickupFit(for: context.item)
        let shippingFit = profile.shippingFit(for: context.item)
        let isLocalMarketplace = context.marketplace.prefersLocalPickup
        let needsPickup = (context.details?.isLargeOrFragile ?? false) || context.item.localPickupNeedScore >= 72

        if isLocalMarketplace || (needsPickup && localFit >= shippingFit) {
            return "Use local pickup. Add your pickup area and whether delivery is available.".localized
        }
        if shippingFit <= 48 {
            return "Prefer pickup. Shipping may be risky for this item.".localized
        }
        if shippingFit >= 76 {
            return "Shipping should work. Pack it well and show any flaws in the photos.".localized
        }
        return "Shipping is okay. Offer pickup too if it is easy.".localized
    }

    private var pricePlan: ListingPricePlan {
        ListingPricePlan(item: context.item, marketplace: context.marketplace, details: context.details, draft: store.draft)
    }

    private var compRangeText: String? {
        let draft = store.draft
        let low = draft?.compLowPrice
        let median = draft?.compMedianPrice
        let high = draft?.compHighPrice
        if let low, let high {
            let range = String.localizedFormat(
                "%@ to %@",
                low.currency(code: context.item.currencyCode),
                high.currency(code: context.item.currencyCode)
            )
            if let median {
                return String.localizedFormat(
                    "%@, typical %@",
                    range,
                    median.currency(code: context.item.currencyCode)
                )
            }
            return range
        }
        if let median {
            return String.localizedFormat("Typical %@", median.currency(code: context.item.currencyCode))
        }
        if let low {
            return String.localizedFormat("From %@", low.currency(code: context.item.currencyCode))
        }
        if let high {
            return String.localizedFormat("Up to %@", high.currency(code: context.item.currencyCode))
        }
        return nil
    }

    private var soldPriceUnavailableText: String {
        "Reliable sold prices were not available. Use the price plan as an estimate, not a confirmed sale.".localized
    }

    private var feeSourceURL: URL? {
        URL(string: context.marketplace.playbookEvidence.feeModelSourceURL)
    }

    private var referenceImageURL: URL? {
        guard let referenceImageURL = store.draft?.referenceImageURL else { return nil }
        return URL(string: referenceImageURL)
    }

    private var sheetContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 820 : .infinity
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 92 : 60
    }

    private var listingEditorMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 300 : 220
    }

    private var editListingButtonTitle: String {
        isEditingListingText ? "Done editing" : "Edit listing"
    }

    private var editListingButtonSystemImage: String {
        isEditingListingText ? "checkmark" : "pencil"
    }

    private func skeletonLineWidth(for index: Int) -> CGFloat? {
        switch index {
        case 1, 4:
            240
        case 7:
            180
        default:
            nil
        }
    }

    private func numberedDraftValues(_ values: [String?]) -> String? {
        let cleanValues = values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard cleanValues.isEmpty == false else { return nil }
        return cleanValues
            .enumerated()
            .map { index, value in "\(index + 1). \(value)" }
            .joined(separator: "\n")
    }

    private func clipboardStatus(expected cleanText: String) -> String {
        let copiedText = UIPasteboard.general.string ?? ""
        let isTrimmed = copiedText == copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPreamble = copiedText.localizedCaseInsensitiveContains("Here's your listing")
            || copiedText.localizedCaseInsensitiveContains("Here’s your listing")
        return copiedText == cleanText && isTrimmed && hasPreamble == false
            ? "Clipboard exact listing text"
            : "Clipboard mismatch"
    }

    private func cancelGenerationTask() {
        generationTask?.cancel()
        generationTask = nil
    }

    private var listingPhotoPackageRow: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            PhotoThumbnail(data: photoPackage.recommendedListingPhotos.first?.imageData, size: 56, category: context.item.category)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(photoPackage.statusTitle.localized)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text(photoPackage.recommendation)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Text("\(photoPackage.recommendedListingPhotos.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.brand.foreground)
                .frame(minWidth: 36, minHeight: 36)
                .background(Color.brand.primaryMuted, in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", photoPackage.statusTitle.localized, photoPackage.recommendation))
    }
}

private struct ListingSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ListingShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ListingPhotoLibrarySaveResult {
    case saved(Int)
    case denied
    case failed
}

private enum ListingPhotoLibrarySaver {
    static func save(_ exports: [ListingPhotoExport]) async -> ListingPhotoLibrarySaveResult {
        guard exports.isEmpty == false else { return .failed }
        let status = await photoLibraryAddStatus()
        guard status == .authorized || status == .limited else { return .denied }

        do {
            try await withCheckedThrowingContinuation { continuation in
                PHPhotoLibrary.shared().performChanges {
                    for export in exports {
                        let request = PHAssetCreationRequest.forAsset()
                        let options = PHAssetResourceCreationOptions()
                        options.originalFilename = export.fileName
                        request.addResource(with: .photo, data: export.imageData, options: options)
                    }
                } completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? CocoaError(.fileWriteUnknown))
                    }
                }
            }
            return .saved(exports.count)
        } catch {
            return .failed
        }
    }

    private static func photoLibraryAddStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        default:
            return current
        }
    }
}

private struct ListingPricePlan {
    let listAt: Decimal
    let likelySellsFor: Decimal
    let takeHomeEstimate: Decimal
    let negotiationFloor: Decimal

    private static let likelySaleMultiplier = Decimal(9) / Decimal(10)
    private static let negotiationFloorMultiplier = Decimal(17) / Decimal(20)

    init(item: DetectedItem, marketplace: Marketplace, details: ItemDetailAnswers?, draft: GeneratedListingDraft?) {
        let localTakeHomeEstimate = MarketplaceEstimator.estimates(for: item, details: details)
            .first { $0.id == marketplace }?
            .payout ?? item.priceEstimate * marketplace.feeMultiplier - marketplace.fixedDeduction

        listAt = max((draft?.listPrice ?? item.priceEstimate).rounded(scale: 0), Decimal(1))
        likelySellsFor = max(
            (draft?.likelySalePrice ?? item.priceEstimate * Self.likelySaleMultiplier).rounded(scale: 0),
            Decimal(1)
        )
        takeHomeEstimate = max((draft?.takeHomeEstimate ?? localTakeHomeEstimate).rounded(scale: 0), Decimal(1))
        negotiationFloor = max(
            min(
                listAt * Self.negotiationFloorMultiplier,
                likelySellsFor
            ).rounded(scale: 0),
            Decimal(1)
        )
    }
}

private extension Marketplace {
    var prefersLocalPickup: Bool {
        switch self {
        case .facebook, .craigslist, .offerup, .nextdoor:
            true
        default:
            false
        }
    }

    func savedFulfillmentNote(in details: ItemDetailAnswers?) -> String {
        details?.marketplaceNote(for: self).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private struct ListingNextStep: Identifiable, Hashable {
    let number: Int
    let title: String
    let detail: String
    let systemImage: String

    var id: Int { number }
}

private struct ListingCopyField: Identifiable, Hashable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { "\(title)-\(value)" }

    var accessibilityValue: String {
        String(value.prefix(160))
    }

    var previewText: String {
        let singleLine = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(singleLine.prefix(140))
    }
}

private extension Array where Element == ListingCopyField {
    mutating func appendIfPresent(title: String, value: String?, systemImage: String) {
        let cleanValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanValue.isEmpty == false else { return }
        append(ListingCopyField(title: title, value: cleanValue, systemImage: systemImage))
    }
}
