import SwiftUI
import UIKit

struct SnapResultSheet: View {
    let context: SnapResultContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var store: SnapResultStore
    @State private var isEditingName = false
    @State private var automaticCancellationRetryCount = 0
    @State private var analysisTask: Task<Void, Never>?
    @State private var analysisTaskID = UUID()
    @State private var isSheetVisible = true
    @State private var showsUncertaintyHelp = false
    @State private var showsDetailCorrection = false
    @FocusState private var focusedField: Field?

    init(context: SnapResultContext) {
        self.context = context
        _store = State(initialValue: SnapResultStore(imageData: context.imageData))
    }

    var body: some View {
        NavigationStack {
            List {
                switch store.phase {
                case .idle, .loading:
                    Section {
                        loadingView
                    }
                case .success:
                    if let item = store.item {
                        resultView(item: item)
                    }
                case .failed(let message):
                    Section {
                        errorView(message: message)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, listBottomContentInset, for: .scrollContent)
            .navigationTitle("Confirm item".localized)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if case .success = store.phase, let item = store.item {
                    decisionBar(item: item)
                }
            }
        }
        .background(pearlSheetBackground)
        .task {
            isSheetVisible = true
            await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())
        }
        .onDisappear {
            isSheetVisible = false
            cancelAnalysisTask()
        }
        .onChange(of: store.phase) { oldPhase, newPhase in
            retryVisibleAnalysisIfCancelled(from: oldPhase, to: newPhase)
        }
        .onChange(of: store.showStillWorking) { _, isShowing in
            announceStillWorkingAlertIfNeeded(isShowing)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done".localized) {
                        store.commitEdits()
                        isEditingName = false
                        focusedField = nil
                    }
                    .accessibilityLabel("Done".localized)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            PhotoThumbnail(data: context.imageData, size: 112, category: store.item?.category)
            ProgressView()
                .tint(Color.brand.primary)
            Text("Analyzing your photo…".localized)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
            if store.showStillWorking || (store.phase == .idle && automaticCancellationRetryCount > 0) {
                VStack(spacing: Spacing.sm) {
                    Text("Still working… tap Retry to try again.".localized)
                        .font(.caption)
                        .foregroundStyle(Color.brand.destructive)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("SnapResult.StillWorkingAlert")
                        .accessibilityLabel("Still working… tap Retry to try again.".localized)
                    Button {
                        Haptics.impact(.light)
                        retryAnalysis()
                    } label: {
                        Label("Retry".localized, systemImage: AppSymbol.Action.retry)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Retry".localized)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(3)
    }

    private func retryVisibleAnalysisIfCancelled(from oldPhase: SnapResultStore.Phase, to newPhase: SnapResultStore.Phase) {
        guard isSheetVisible,
              automaticCancellationRetryCount == 0,
              oldPhase == .loading,
              newPhase == .idle else { return }
        automaticCancellationRetryCount += 1
        analyzeIfNeeded()
    }

    private func announceStillWorkingAlertIfNeeded(_ isShowing: Bool) {
        guard isShowing else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: "Still working… tap Retry to try again.".localized
        )
    }

    @ViewBuilder
    private func resultView(item: DetectedItem) -> some View {
        Section {
            confirmationCard(item: item)
                .frame(maxWidth: sheetContentMaxWidth, alignment: .leading)
                .accessibilitySortPriority(5)
                .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

        if showsUncertaintyHelp {
            Section {
                uncertaintyHelp(details: store.analysisDetails)
                    .accessibilitySortPriority(4)
            }
        }

        if showsDetailCorrection {
            Section("Fix this".localized) {
                correctionControls(item: item)
                    .accessibilitySortPriority(3)
            }
        }

        if let details = store.analysisDetails {
            Section("What we found".localized) {
                analysisDetailRows(details)
            }
            .accessibilitySortPriority(2)
        }
    }

    private var pearlSheetBackground: some View {
        LinearGradient(
            colors: [
                Color.brand.background,
                Color.brand.backgroundSubtle,
                Color.brand.primaryMuted.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func confirmationCard(item: DetectedItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            confirmationHero(item: item)
            itemFactPills(item: item)
            confirmationChoiceRow
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(confirmationCardFill)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color.brand.primaryForeground.opacity(0.64), lineWidth: 1)
                        .blendMode(.plusLighter)
                        .frame(height: 1)
                        .padding(.horizontal, Spacing.lg)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(Color.brand.border.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color.brand.shadow.opacity(0.055), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func confirmationHero(item: DetectedItem) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.md) {
                PhotoThumbnail(data: context.imageData, size: 112, category: item.category)
                confirmationSummary(item: item)
            }
        } else {
            HStack(alignment: .center, spacing: Spacing.md) {
                PhotoThumbnail(data: context.imageData, size: 96, category: item.category)
                confirmationSummary(item: item)
            }
        }
    }

    private func confirmationSummary(item: DetectedItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("We think this is".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(1)

            itemNameControl

            HStack(spacing: Spacing.xs) {
                Text("Worth around".localized)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                priceEditor
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private func itemFactPills(item: DetectedItem) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.sm) {
                    itemCategoryPill(item)
                    itemConditionPill(item)
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    itemCategoryPill(item)
                    itemConditionPill(item)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func itemCategoryPill(_ item: DetectedItem) -> SnapResultFactPill {
        SnapResultFactPill(
            label: "Category",
            value: item.category.display,
            systemImage: categoryMenuItemIcon(for: item.category)
        )
    }

    private func itemConditionPill(_ item: DetectedItem) -> SnapResultFactPill {
        SnapResultFactPill(
            label: "Condition",
            value: item.condition.display,
            systemImage: conditionMenuItemIcon(for: item.condition)
        )
    }

    @ViewBuilder
    private var confirmationChoiceRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                notSureButton
                changeDetailsButton
            }
        } else {
            HStack(spacing: Spacing.sm) {
                notSureButton
                changeDetailsButton
            }
        }
    }

    private var notSureButton: some View {
        Button {
            Haptics.impact(.light)
            showsUncertaintyHelp = true
            showsDetailCorrection = false
        } label: {
            Label("Not sure".localized, systemImage: "questionmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Not sure".localized)
        .accessibilityHint("Shows simple ways to check the item".localized)
    }

    private var changeDetailsButton: some View {
        Button {
            Haptics.impact(.light)
            showsDetailCorrection = true
            showsUncertaintyHelp = false
            isEditingName = true
            focusedField = .name
        } label: {
            Label("Change details".localized, systemImage: "pencil.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Change details".localized)
        .accessibilityHint("Lets you edit the name, category, condition, or price".localized)
    }

    private var confirmationCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.brand.surface,
                Color.brand.surfaceElevated,
                Color.brand.primaryMuted.opacity(0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func analysisDetailRows(_ details: AnalyzeIntelligence) -> some View {
        ForEach(Array(details.itemFacts.prefix(3).enumerated()), id: \.offset) { _, fact in
            analysisFactRow(fact)
        }

        if let guidance = details.photoGuidance {
            analysisPhotoGuidanceRow(guidance)
        } else if let guidance = details.detailGuidance {
            analysisDetailGuidanceRow(guidance)
        }
    }

    private func uncertaintyHelp(details: AnalyzeIntelligence?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("No problem".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)

                Text(details?.uncertaintyPrompt ?? "Try a closer photo of any logo, label, or model number.".localized)
                    .font(.body)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let referenceImages = details?.referenceImages, referenceImages.isEmpty == false {
                referenceImagesSection(referenceImages)
            }

            if let matches = details?.likelyMatches, matches.isEmpty == false {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Which one looks closest?".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.mutedForeground)

                    ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                        likelyMatchButton(match)
                    }
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.sm) {
                    retryButton
                    retakeButton
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    retryButton
                    retakeButton
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func referenceImagesSection(_ images: [AnalyzeReferenceImage]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reference images".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)

                Spacer(minLength: Spacing.sm)

                Text("For checking only".localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
            }

            Text("Use these to check the item. Keep your own photos for the listing.".localized)
                .font(.caption)
                .foregroundStyle(Color.brand.foregroundSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        referenceImageCard(image)
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func referenceImageCard(_ image: AnalyzeReferenceImage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: image.urlValue) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(Color.brand.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo.on.rectangle")
                            .brandSymbol(.rowIcon)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 118, height: 92)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                Text("For checking only".localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 3)
                    .background(Color.brand.foreground.opacity(0.72), in: Capsule(style: .continuous))
                    .padding(Spacing.xs)
            }

            Text(image.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let source = image.source {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 118, alignment: .leading)
        .padding(Spacing.xs)
        .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.brand.border.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(referenceImageAccessibilityLabel(image))
        .accessibilityHint("Use this to check the item, not as a listing photo.".localized)
    }

    private func referenceImageAccessibilityLabel(_ image: AnalyzeReferenceImage) -> String {
        if let source = image.source {
            return String.localizedFormat("%@, %@, %@, %@", "Reference image".localized, "For checking only".localized, image.title, source)
        }
        return String.localizedFormat("%@, %@, %@", "Reference image".localized, "For checking only".localized, image.title)
    }

    private func likelyMatchButton(_ match: AnalyzeLikelyMatch) -> some View {
        Button {
            Haptics.impact(.light)
            store.selectLikelyMatch(match)
            showsUncertaintyHelp = false
            showsDetailCorrection = true
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(match.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    if match.distinguishingQuestion.isEmpty == false {
                        Text(match.distinguishingQuestion)
                            .font(.caption)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Spacing.sm)

                Text(match.closenessLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.brand.primaryMuted, in: Capsule(style: .continuous))
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(String.localizedFormat("%@, %@", match.closenessLabel, match.name))
        .optionalAccessibilityHint(match.distinguishingQuestion.isEmpty ? nil : match.distinguishingQuestion)
    }

    private func analysisFactRow(_ fact: AnalyzeItemFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: AppSymbol.Flow.complete)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(fact.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(1)

                Text(fact.value)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", fact.label, fact.value))
    }

    private func analysisPhotoGuidanceRow(_ guidance: String) -> some View {
        analysisGuidanceRow(
            title: "Add one more photo",
            guidance: guidance,
            systemImage: AppSymbol.Action.addPhoto
        )
    }

    private func analysisDetailGuidanceRow(_ guidance: String) -> some View {
        analysisGuidanceRow(
            title: "Could help",
            guidance: guidance,
            systemImage: AppSymbol.Action.edit
        )
    }

    private func analysisGuidanceRow(title: String, guidance: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(1)

                Text(guidance)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, guidance))
    }

    private func decisionBar(item: DetectedItem) -> some View {
        VStack(spacing: Spacing.xs) {
            Button {
                proceedWithItem(item)
            } label: {
                Label("Yes, that's it".localized, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Yes, that's it".localized)
            .accessibilitySortPriority(3)

            Text("Next: a few easy questions.".localized)
                .font(.caption)
                .foregroundStyle(Color.brand.foregroundSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: sheetContentMaxWidth)
        .frame(maxWidth: .infinity)
        .nativeMaterialBar(tintOpacity: 0.9, showsTopDivider: true)
    }

    private func proceedWithItem(_ fallbackItem: DetectedItem) {
        Haptics.impact(.medium)
        store.commitEdits()
        let item = store.item ?? fallbackItem
        appStore.presentItemQuestions(
            item: item,
            imageData: context.imageData,
            preferredMarketplace: context.preferredMarketplace,
            analysis: store.analysisDetails
        )
    }

    @ViewBuilder
    private func correctionControls(item: DetectedItem) -> some View {
        VStack(spacing: Spacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ChipButton(
                        title: item.category.display,
                        accessibilityLabel: ChipAccessibilityText.valueLabel("Category", value: item.category.display),
                        accessibilityHint: "Changes the category"
                    ) {
                        store.cycleCategory()
                    }
                    ChipButton(
                        title: item.condition.display,
                        accessibilityLabel: ChipAccessibilityText.valueLabel("Condition", value: item.condition.display),
                        accessibilityHint: "Changes the condition"
                    ) {
                        store.cycleCondition()
                    }
                }
            }
            .accessibilitySortPriority(4)

            secondaryActions(item: item)
        }
    }

    @ViewBuilder
    private func secondaryActions(item: DetectedItem) -> some View {
        if usesRegularSecondaryActionGrid {
            LazyVGrid(columns: secondaryActionColumns, spacing: Spacing.sm) {
                retakeButton
                retryButton
                categoryMenuButton(selected: item.category)
                conditionMenuButton(selected: item.condition)
            }
        } else {
            VStack(spacing: Spacing.sm) {
                LazyVGrid(columns: compactQuickActionColumns, spacing: Spacing.sm) {
                    retakeButton
                    retryButton
                }
                categoryMenuButton(selected: item.category)
                conditionMenuButton(selected: item.condition)
            }
        }
    }

    private var retakeButton: some View {
        Button {
            Haptics.impact(.light)
            appStore.retakePhoto(keeping: context.preferredMarketplace)
        } label: {
            Label("Wrong item — retake".localized, systemImage: AppSymbol.Action.retakePhoto)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Wrong item — retake".localized)
    }

    private var retryButton: some View {
        Button {
            Haptics.impact(.light)
            retryAnalysis()
        } label: {
            Label("Try again".localized, systemImage: AppSymbol.Action.retry)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Try again".localized)
    }

    private var priceEditor: some View {
        HStack(spacing: 0) {
            Text("~$")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
            TextField("Price".localized, text: Binding(
                get: { store.priceText },
                set: { store.priceText = $0 }
            ))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .price)
                .onSubmit { store.commitEdits() }
                .accessibilityLabel("Estimated price".localized)
        }
        .focusedInputChrome(
            isFocused: focusedField == .price,
            horizontalPadding: Spacing.sm,
            verticalPadding: Spacing.xxs
        )
    }

    private func categoryMenuButton(selected: Category) -> some View {
        Menu {
            ForEach(Category.allCases, id: \.self) { category in
                Button {
                    Haptics.impact(.light)
                    store.selectCategory(category)
                } label: {
                    menuItemLabel(
                        title: category.display,
                        systemImage: categoryMenuItemIcon(for: category),
                        isSelected: category == selected
                    )
                }
                .accessibilityLabel(category.display)
            }
        } label: {
            SnapResultMenuLabel(title: "Change category", systemImage: AppSymbol.Action.category, maxWidth: sheetContentMaxWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .simultaneousGesture(TapGesture().onEnded {
            Haptics.impact(.light)
        })
        .accessibilityLabel("Change category".localized)
        .accessibilityValue(Text(selected.display.localized))
        .accessibilityHint("Opens category choices".localized)
    }

    private func conditionMenuButton(selected: Condition) -> some View {
        Menu {
            ForEach(Condition.allCases, id: \.self) { condition in
                Button {
                    Haptics.impact(.light)
                    store.selectCondition(condition)
                } label: {
                    menuItemLabel(
                        title: condition.display,
                        systemImage: conditionMenuItemIcon(for: condition),
                        isSelected: condition == selected
                    )
                }
                .accessibilityLabel(condition.display)
            }
        } label: {
            SnapResultMenuLabel(title: "Change condition", systemImage: "slider.horizontal.3", maxWidth: sheetContentMaxWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .simultaneousGesture(TapGesture().onEnded {
            Haptics.impact(.light)
        })
        .accessibilityLabel("Change condition".localized)
        .accessibilityValue(Text(selected.display.localized))
        .accessibilityHint("Opens condition choices".localized)
    }

    @ViewBuilder
    private func menuItemLabel(title: String, systemImage: String, isSelected: Bool) -> some View {
        Label {
            Text(title.localized)
        } icon: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
        }
    }

    private func categoryMenuItemIcon(for category: Category) -> String {
        category.placeholderSystemImage
    }

    private func conditionMenuItemIcon(for condition: Condition) -> String {
        switch condition {
        case .new: AppSymbol.Condition.newItem
        case .likeNew: AppSymbol.Condition.likeNew
        case .good: AppSymbol.Condition.good
        case .fair: AppSymbol.Condition.fair
        case .forParts: AppSymbol.Condition.forParts
        }
    }

    @ViewBuilder
    private var itemNameControl: some View {
        if isEditingName {
            TextField("Item name".localized, text: Binding(
                get: { store.nameText },
                set: { store.nameText = $0 }
            ), axis: .vertical)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(1...2)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($focusedField, equals: .name)
                .focusedInputChrome(
                    isFocused: focusedField == .name,
                    horizontalPadding: Spacing.sm,
                    verticalPadding: Spacing.xxs
                )
                .submitLabel(.done)
                .onSubmit {
                    store.commitEdits()
                    isEditingName = false
                    focusedField = nil
                }
                .accessibilityLabel("Item name".localized)
        } else {
            Button {
                Haptics.impact(.light)
                isEditingName = true
                focusedField = .name
            } label: {
                Text(readableItemName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(PressButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityLabel("Item name".localized)
                .accessibilityValue(store.nameText)
                .accessibilityHint("Double-tap to edit the item name".localized)
        }
    }

    private var readableItemName: String {
        let fallback = "Item name".localized
        let name = store.nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return fallback }
        guard name.count > 20, name.contains("\n") == false else { return name }

        let words = name.split(separator: " ").map(String.init)
        guard words.count > 1 else { return name }

        let bestSplit = (1..<words.count).min { lhs, rhs in
            let lhsScore = splitBalanceScore(words, at: lhs)
            let rhsScore = splitBalanceScore(words, at: rhs)
            return lhsScore == rhsScore
                ? lineLength(words, endIndex: lhs) < lineLength(words, endIndex: rhs)
                : lhsScore < rhsScore
        } ?? words.count - 1

        return words[..<bestSplit].joined(separator: " ")
            + "\n"
            + words[bestSplit...].joined(separator: " ")
    }

    private func splitBalanceScore(_ words: [String], at index: Int) -> Int {
        abs(lineLength(words, endIndex: index) - lineLength(words, startIndex: index))
    }

    private func lineLength(_ words: [String], startIndex: Int = 0, endIndex: Int? = nil) -> Int {
        let endIndex = endIndex ?? words.count
        guard startIndex < endIndex else { return 0 }
        return words[startIndex..<endIndex].joined(separator: " ").count
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            PhotoThumbnail(data: context.imageData, size: 156, category: store.item?.category)
            Text(message)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.destructive)
                .multilineTextAlignment(.center)
            Button {
                Haptics.impact(.light)
                appStore.retakePhoto(keeping: context.preferredMarketplace)
            } label: {
                Label("Retake photo".localized, systemImage: AppSymbol.Action.retakePhoto)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Retake photo".localized)
            Button {
                Haptics.impact(.light)
                retryAnalysis()
            } label: {
                Label("Try again".localized, systemImage: AppSymbol.Action.retry)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Try again".localized)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .task(id: message) {
            appStore.showToast(message, style: .error)
        }
        .accessibilitySortPriority(3)
    }

    private enum Field {
        case name
        case price
    }

    private var sheetContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 760 : .infinity
    }

    private var listBottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 144 : 96
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var secondaryActionColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var compactQuickActionColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var usesRegularSecondaryActionGrid: Bool {
        (usesRegularWidthLayout || UIScreen.main.bounds.width >= 430)
            && dynamicTypeSize.isAccessibilitySize == false
    }

    private func retryAnalysis() {
        startAnalysisTask(retry: true)
    }

    private func analyzeIfNeeded() {
        startAnalysisTask(retry: false)
    }

    private func startAnalysisTask(retry: Bool) {
        cancelAnalysisTask()
        let taskID = UUID()
        analysisTaskID = taskID
        analysisTask = Task { @MainActor in
            if retry {
                await store.analyze(accessToken: await appStore.authenticatedAccessToken())
            } else {
                await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())
            }
            guard Task.isCancelled == false, analysisTaskID == taskID else { return }
            analysisTask = nil
        }
    }

    private func cancelAnalysisTask() {
        analysisTask?.cancel()
        analysisTask = nil
    }
}

private struct SnapResultMenuLabel: View {
    let title: String
    let systemImage: String
    var maxWidth: CGFloat?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(title.localized)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(minimumScaleFactor)
                .layoutPriority(1)

            Spacer(minLength: Spacing.xs)

            Image(systemName: "chevron.down")
                .brandSymbol(.smallChevron)
                .foregroundStyle(Color.brand.mutedForeground)
                .accessibilityHidden(true)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.brand.foreground)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: maxWidth ?? .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }

    private var lineLimit: Int {
        2
    }

    private var minimumScaleFactor: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0.82 : 0.8
    }
}

private struct SnapResultFactPill: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(label.localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(1)

                Text(value.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color.brand.primaryMuted.opacity(0.54), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.brand.primaryText.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ChipAccessibilityText.valueLabel(label, value: value))
    }
}

struct PhotoThumbnail: View {
    let data: Data?
    var size: CGFloat
    var category: Category? = nil

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Item photo".localized)
            } else {
                photoPlaceholder
                    .accessibilityLabel("Item photo placeholder".localized)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var photoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.brand.surfaceElevated,
                    Color.brand.primaryMuted.opacity(0.66)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: placeholderSpacing) {
                Image(systemName: category?.placeholderSystemImage ?? AppSymbol.Flow.snapPhotoCompact)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.brand.primaryText)
                    .accessibilityHidden(true)

                Text("No photo".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .padding(.horizontal, Spacing.xs)

                if showsPlaceholderBadge {
                    Text("Placeholder".localized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brand.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.brand.primaryMuted.opacity(0.8), in: Capsule(style: .continuous))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.brand.border.opacity(0.7), lineWidth: 1)
        }
    }

    private var iconSize: CGFloat {
        max(20, min(size * 0.36, 44))
    }

    private var placeholderSpacing: CGFloat {
        size < 72 ? 2 : Spacing.xxs
    }

    private var showsPlaceholderBadge: Bool {
        size >= 84
    }
}
