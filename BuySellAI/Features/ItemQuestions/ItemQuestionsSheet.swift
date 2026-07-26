import SwiftUI
import UIKit

struct ItemQuestionsSheet: View {
    let context: ItemQuestionsContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var answers: ItemDetailAnswers
    @State private var questions: [DetailQuestion]
    @State private var currentQuestionIndex = 0
    @State private var showsReferenceExamples = false
    @FocusState private var focusedField: Field?

    init(context: ItemQuestionsContext) {
        self.context = context
        let initialAnswers = (context.answers ?? ItemDetailAnswers())
            .seedingConfirmedAnalysisFacts(from: context.analysis, category: context.item.category)
        _answers = State(initialValue: initialAnswers)
        _questions = State(initialValue: Self.makeQuestions(context: context, answers: initialAnswers))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    itemHeader
                }

                if let assistantState = assistantState,
                   shouldShowAssistantState {
                    Section {
                        assistantStateCard(assistantState)
                    } header: {
                        Text("What BuySell is checking".localized)
                    } footer: {
                        Text("This stays short so you only answer the next useful thing.".localized)
                    }
                    .accessibilitySortPriority(4)
                }

                if let targetedScanRequest {
                    Section {
                        targetedScanCard(targetedScanRequest)
                    } header: {
                        Text("One better scan".localized)
                    } footer: {
                        Text("Skip if you do not want another photo.".localized)
                    }
                    .accessibilitySortPriority(4)
                } else if visibleQuestions.isEmpty == false {
                    Section {
                        questionBatchCards(visibleQuestions)
                    } header: {
                        Text(questionSectionTitle.localized)
                    } footer: {
                        Text(questionSectionFooter.localized)
                    }
                    .accessibilitySortPriority(3)
                } else {
                    Section {
                        readyCard
                    }
                    .accessibilitySortPriority(3)
                }

                if targetedScanRequest == nil && savedDetailRows.isEmpty == false {
                    Section {
                        savedDetailsRows
                    } header: {
                        Text("Saved so far".localized)
                    } footer: {
                        Text("Tap any detail to fix it.".localized)
                    }
                    .accessibilitySortPriority(2)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if targetedScanRequest == nil {
                        Button("Skip all".localized) {
                            continueWithoutDetails()
                        }
                        .accessibilityLabel("Skip all".localized)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done".localized) {
                            focusedField = nil
                        }
                        .accessibilityLabel("Done".localized)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomAction
            }
            .background(Color.clear)
        }
        .background(Color.clear)
    }

    private var itemHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            PhotoThumbnail(data: context.imageData, size: 64, category: context.item.category)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("We think this is".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                Text(context.item.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(headerDetailText.localized)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", "We think this is".localized, context.item.name))
        .accessibilitySortPriority(4)
    }

    private var assistantState: AssistantState? {
        Self.assistantState(
            context: context,
            answers: answers,
            currentQuestion: currentQuestion,
            targetedScanRequest: targetedScanRequest
        )
    }

    private func assistantStateCard(_ state: AssistantState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            assistantStateRow(
                title: "Likely",
                value: state.likely,
                systemImage: "checkmark.seal.fill",
                tint: Color.brand.primaryText
            )
            assistantStateRow(
                title: "Still checking",
                value: state.stillChecking,
                systemImage: "questionmark.circle.fill",
                tint: Color.brand.foregroundSecondary
            )
            assistantStateRow(
                title: "Next clue",
                value: state.nextClue,
                systemImage: "sparkle.magnifyingglass",
                tint: Color.brand.primaryText
            )
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func assistantStateRow(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .textCase(.uppercase)

                Text(value.localized)
                    .font(.callout)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func targetedScanCard(_ request: TargetedScanRequest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(request.title.localized)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(request.benefit.localized)
                        .font(.body)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: request.systemImage)
                    .brandSymbol(.controlIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.brand.primaryText)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.sm) {
                    targetedScanButton(request)
                    skipTargetedScanButton
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    targetedScanButton(request)
                    skipTargetedScanButton
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func targetedScanButton(_ request: TargetedScanRequest) -> some View {
        Button {
            startTargetedScan(request)
        } label: {
            Label("Scan it".localized, systemImage: AppSymbol.Flow.snapPhotoCompact)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel("Scan it".localized)
        .accessibilityHint(request.benefit.localized)
    }

    private var skipTargetedScanButton: some View {
        Button {
            skipTargetedScan()
        } label: {
            Text("Skip".localized)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Skip".localized)
    }

    private func questionBatchCards(_ questions: [DetailQuestion]) -> some View {
        VStack(alignment: .leading, spacing: questions.count > 1 ? Spacing.md : Spacing.lg) {
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                questionCard(
                    question,
                    isPrimary: index == 0,
                    showsProgress: index == 0,
                    isCompact: questions.count > 1
                )

                if index < questions.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func questionCard(
        _ question: DetailQuestion,
        isPrimary: Bool = true,
        showsProgress: Bool = true,
        isCompact: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? Spacing.md : Spacing.lg) {
            VStack(alignment: .leading, spacing: isCompact ? Spacing.xs : Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: question.systemImage)
                        .brandSymbol(.controlIcon)
                        .foregroundStyle(Color.brand.primaryText)
                        .accessibilityHidden(true)

                    Text(question.contextLabel.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.mutedForeground)

                    Spacer(minLength: 0)
                }

                if isCompact == false,
                   let assistantCue = assistantConversationCue(for: question) {
                    assistantCueRow(assistantCue)
                }

                Text(question.title.localized)
                    .font(isCompact ? .headline : .title2.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                if isCompact == false || isPrimary {
                    Text(question.detail.localized)
                        .font(isCompact ? .callout : .body)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isCompact {
                    compactQuestionImpactLine(for: question)
                } else {
                    questionImpactStrip(for: question)
                }

                if isCompact == false,
                   let evidenceSummary = question.evidenceSummary {
                    questionEvidenceSummary(evidenceSummary)
                }

                if shouldShowExamplesControl(for: question) {
                    referenceExamplesControl
                }

                if showsReferenceExamples {
                    referenceExamplesSection(referenceImages)
                }
            }

            questionInput(question)

            if question.choices.isEmpty == false {
                choiceGrid(for: question)
            }

            if isCompact,
               isPrimary == false,
               question.choices.contains(where: \.isUnknown) == false {
                questionUnknownButton(question)
            }

            if showsProgress {
                ProgressView(value: questionProgress)
                    .tint(Color.brand.primary)
                    .accessibilityLabel("Question progress".localized)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
        .opacity(isPrimary ? 1 : 0.92)
    }

    private func shouldShowExamplesControl(for question: DetailQuestion) -> Bool {
        question.allowsReferenceExamples && referenceImages.isEmpty == false
    }

    private var referenceImages: [AnalyzeReferenceImage] {
        context.analysis?.referenceImages ?? []
    }

    private var referenceExamplesControl: some View {
        Button {
            Haptics.impact(.light)
            showsReferenceExamples.toggle()
        } label: {
            Label(
                showsReferenceExamples ? "Hide examples".localized : "Show examples".localized,
                systemImage: "photo.on.rectangle.angled"
            )
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color.brand.foregroundSecondary)
        .accessibilityLabel(showsReferenceExamples ? "Hide examples".localized : "Show examples".localized)
        .accessibilityHint("Shows reference images for checking only.".localized)
    }

    private func referenceExamplesSection(_ images: [AnalyzeReferenceImage]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Examples".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)

                Spacer(minLength: Spacing.sm)

                Text("For checking only".localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brand.primaryText)
            }

            Text("Use these to compare the item. Your listing will use your own photos.".localized)
                .font(.caption)
                .foregroundStyle(Color.brand.foregroundSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(images.prefix(3).enumerated()), id: \.offset) { _, image in
                        referenceExampleCard(image)
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func referenceExampleCard(_ image: AnalyzeReferenceImage) -> some View {
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

                Text("Reference".localized)
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
                    .font(.caption)
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
        .accessibilityLabel(referenceExampleAccessibilityLabel(image))
        .accessibilityHint("Use this to check the item, not as a listing photo.".localized)
    }

    private func referenceExampleAccessibilityLabel(_ image: AnalyzeReferenceImage) -> String {
        if let source = image.source {
            return String.localizedFormat("%@, %@, %@, %@", "Reference image".localized, "For checking only".localized, image.title, source)
        }
        return String.localizedFormat("%@, %@, %@", "Reference image".localized, "For checking only".localized, image.title)
    }

    private func assistantCueRow(_ cue: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text(cue.localized)
                .font(.callout)
                .foregroundStyle(Color.brand.foregroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(Color.brand.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func assistantConversationCue(for question: DetailQuestion) -> String? {
        Self.assistantConversationCue(
            for: question,
            item: context.item,
            marketplace: context.preferredMarketplace
        )
    }

    private func compactQuestionImpactLine(for question: DetailQuestion) -> some View {
        let impact = Self.compactQuestionImpactText(for: question, context: context, answers: answers)
        return Label {
            Text(impact.localized)
                .font(.footnote)
                .foregroundStyle(Color.brand.foregroundSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
        .padding(.top, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(impact.localized)
        .accessibilityIdentifier("ItemQuestions.CompactImpactLine")
    }

    private func questionEvidenceSummary(_ summary: QuestionEvidenceSummary) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: summary.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(summary.title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .textCase(.uppercase)

                Text(summary.value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = summary.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(Color.brand.primaryMuted.opacity(0.45), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Color.brand.primary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func questionImpactStrip(for question: DetailQuestion) -> some View {
        let rows = Self.questionImpactRows(for: question, context: context, answers: answers)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: row.systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.brand.primaryText)
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title.localized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brand.mutedForeground)
                            .textCase(.uppercase)

                        Text(row.detail.localized)
                            .font(.footnote)
                            .foregroundStyle(Color.brand.foregroundSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(Color.brand.primaryMuted.opacity(0.28), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .stroke(Color.brand.primary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Ready to write".localized)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                    Text(readyCardDetail.localized)
                        .font(.body)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .brandSymbol(.controlIcon)
                    .foregroundStyle(Color.brand.primaryText)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(assistantSummaryRows) { row in
                    assistantSummaryRow(row)
                }
            }

            if let keepCheckingQuestion = assistantKeepCheckingQuestion {
                Button {
                    startAssistantKeepChecking(keepCheckingQuestion)
                } label: {
                    Label("Keep checking".localized, systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color.brand.foregroundSecondary)
                .accessibilityLabel("Keep checking".localized)
                .accessibilityHint("Asks one more simple question if you are not sure.".localized)
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .contain)
    }

    private var readyCardDetail: String {
        context.preferredMarketplace == nil
            ? "BuySell has enough to search real marketplace results next."
            : "BuySell has enough details to write this listing."
    }

    private func assistantSummaryRow(_ row: AssistantSummaryRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: row.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(row.tint)
                .frame(width: 24, height: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(row.title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .textCase(.uppercase)

                Text(row.value)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var assistantSummaryRows: [AssistantSummaryRow] {
        Self.assistantSummaryRows(
            context: context,
            answers: answers,
            savedRows: savedDetailRows
        )
    }

    private var assistantKeepCheckingQuestion: DetailQuestion? {
        Self.assistantKeepCheckingQuestion(context: context, answers: answers)
    }

    @ViewBuilder
    private func questionInput(_ question: DetailQuestion) -> some View {
        switch question.kind {
        case .text(let field):
            TextField(question.placeholder.localized, text: binding(for: field), axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: field)
                .focusedInputChrome(isFocused: focusedField == field)
                .submitLabel(isLastQuestion ? .done : .next)
                .onSubmit {
                    moveToQuestion(question)
                    advanceOrContinue()
                }
                .accessibilityLabel(question.title.localized)
        case .largeOrFragile:
            EmptyView()
        }
    }

    private func choiceGrid(for question: DetailQuestion) -> some View {
        LazyVGrid(columns: choiceColumns, spacing: Spacing.sm) {
            ForEach(question.choices) { choice in
                Button {
                    applyChoice(choice, for: question)
                } label: {
                    choiceButtonContent(choice)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(Color.brand.foregroundSecondary)
                .accessibilityLabel(choice.displayTitle)
            }
        }
    }

    private func choiceButtonContent(_ choice: DetailChoice) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: choice.systemImage)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text(choice.displayTitle)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func questionUnknownButton(_ question: DetailQuestion) -> some View {
        Button {
            moveToQuestion(question)
            skipQuestion()
        } label: {
            Label("I don't know".localized, systemImage: "questionmark.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(Color.brand.foregroundSecondary)
        .accessibilityLabel("I don't know".localized)
        .accessibilityHint("Skips this question.".localized)
    }

    private var choiceColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: count)
    }

    private var savedDetailsRows: some View {
        ForEach(savedDetailRows) { row in
            Button {
                editSavedDetail(row)
            } label: {
                HStack(alignment: .center, spacing: Spacing.md) {
                    Image(systemName: row.systemImage)
                        .brandSymbol(.controlIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.brand.primaryText)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(row.title.localized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brand.mutedForeground)
                            .lineLimit(1)

                        Text(row.value)
                            .font(.body)
                            .foregroundStyle(Color.brand.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.sm)

                    Image(systemName: "pencil.circle.fill")
                        .brandSymbol(.controlIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Spacing.xxs)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String.localizedFormat("%@, %@, %@", row.title.localized, row.value, "Fix this".localized))
        }
    }

    private var savedDetailRows: [SavedDetailRow] {
        var rows: [SavedDetailRow] = []
        appendSavedTextRow(title: "Brand", value: answers.labelOrBrand, field: .labelOrBrand, systemImage: AppSymbol.Action.category, to: &rows)
        appendSavedTextRow(title: "Size/model", value: answers.sizeOrModel, field: .sizeOrModel, systemImage: "ruler", to: &rows)
        appendSavedTextRow(title: "Flaws", value: answers.flaws, field: .flaws, systemImage: AppSymbol.Condition.fair, to: &rows)
        appendSavedTextRow(title: "Includes", value: answers.included, field: .included, systemImage: AppSymbol.Marketplace.package, to: &rows)
        appendSavedTextRow(title: "Other", value: answers.extraDetails, field: .extraDetails, systemImage: AppSymbol.Flow.answer, to: &rows)
        appendSavedMarketplaceRows(to: &rows)

        if answers.isLargeOrFragile || answers.answeredFieldKeys.contains(.largeOrFragile) {
            rows.append(SavedDetailRow(
                title: "Large or fragile",
                value: answers.isLargeOrFragile ? "Yes".localized : "No".localized,
                systemImage: AppSymbol.Marketplace.package,
                target: .largeOrFragile
            ))
        }
        return rows
    }

    private func appendSavedTextRow(
        title: String,
        value: String,
        field: Field,
        systemImage: String,
        to rows: inout [SavedDetailRow]
    ) {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailKey = field.detailKey
        if cleanValue.isEmpty == false {
            rows.append(SavedDetailRow(title: title, value: cleanValue, systemImage: systemImage, target: .field(field)))
        } else if answers.answeredFieldKeys.contains(detailKey) {
            rows.append(SavedDetailRow(title: title, value: "I don't know".localized, systemImage: systemImage, target: .field(field)))
        }
    }

    private func appendSavedMarketplaceRows(to rows: inout [SavedDetailRow]) {
        Marketplace.allCases.forEach { marketplace in
            let cleanValue = answers.marketplaceNote(for: marketplace).trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanValue.isEmpty == false {
                rows.append(SavedDetailRow(
                    title: marketplace.displayName,
                    value: cleanValue,
                    systemImage: marketplace.iconSystemName,
                    target: .field(.marketplaceNote(marketplace))
                ))
            } else if answers.answeredMarketplaces.contains(marketplace) {
                rows.append(SavedDetailRow(
                    title: marketplace.displayName,
                    value: "I don't know".localized,
                    systemImage: marketplace.iconSystemName,
                    target: .field(.marketplaceNote(marketplace))
                ))
            }
        }
    }

    @ViewBuilder
    private var bottomAction: some View {
        if targetedScanRequest == nil {
            VStack(spacing: Spacing.xs) {
                bottomButtonStack

                Text(bottomHelperText.localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xxs)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var bottomButtonStack: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                previousQuestionButton
                if currentQuestion != nil {
                    unknownButton
                }
                nextButton
            }
        } else {
            HStack(spacing: Spacing.sm) {
                previousQuestionButton
                if currentQuestion != nil {
                    unknownButton
                }
                nextButton
            }
        }
    }

    @ViewBuilder
    private var previousQuestionButton: some View {
        if currentQuestionIndex > 0 {
            Button {
                previousQuestion()
            } label: {
                Label("Back".localized, systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityLabel("Back".localized)
        }
    }

    private var unknownButton: some View {
        Button {
            skipQuestion()
        } label: {
            Text("I don't know".localized)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel("I don't know".localized)
    }

    private var nextButton: some View {
        Button {
            advanceOrContinue()
        } label: {
            Label(primaryActionTitle.localized, systemImage: primaryActionSystemImage)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(Color.brand.primary)
        .accessibilityLabel(primaryActionTitle.localized)
    }

    private var currentQuestion: DetailQuestion? {
        guard questions.isEmpty == false else { return nil }
        return questions[min(currentQuestionIndex, questions.count - 1)]
    }

    private var shouldShowAssistantState: Bool {
        targetedScanRequest == nil && visibleQuestions.isEmpty
    }

    private var visibleQuestions: [DetailQuestion] {
        guard targetedScanRequest == nil,
              questions.isEmpty == false
        else {
            return []
        }
        if dynamicTypeSize.isAccessibilitySize {
            return currentQuestion.map { [$0] } ?? []
        }
        let lowerBound = min(currentQuestionIndex, questions.count - 1)
        let remaining = questions[lowerBound..<questions.endIndex]
        return Array(remaining.prefix(visibleQuestionLimit))
    }

    private var visibleQuestionLimit: Int {
        context.preferredMarketplace == nil ? 3 : 2
    }

    private var targetedScanRequest: TargetedScanRequest? {
        if let marketplace = context.preferredMarketplace {
            guard answers.hasAnsweredOrSkipped(.marketplaceTargetedScan) == false else { return nil }
            return MarketplacePhotoScanPlaybook.targetedScanRequest(
                for: marketplace,
                item: context.item,
                answers: answers,
                supplementalPhotos: context.supplementalPhotos
            ) ?? Self.adaptiveTargetedScanRequest(
                context: context,
                answers: answers,
                currentQuestion: currentQuestion
            )
        }
        guard answers.hasAnsweredOrSkipped(.targetedScan) == false else { return nil }
        return Self.adaptiveTargetedScanRequest(
            context: context,
            answers: answers,
            currentQuestion: currentQuestion
        )
    }

    private var targetedScanAnsweredField: ItemDetailFieldKey {
        context.preferredMarketplace == nil ? .targetedScan : .marketplaceTargetedScan
    }

    private var questionProgress: Double {
        guard questions.isEmpty == false else { return 1 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }

    private var isLastQuestion: Bool {
        guard questions.isEmpty == false else { return true }
        return currentQuestionIndex >= questions.count - 1
    }

    private var primaryActionTitle: String {
        if isLastQuestion {
            return context.preferredMarketplace == nil ? "Find best place" : "Write listing"
        }
        return "Next"
    }

    private var primaryActionSystemImage: String {
        if isLastQuestion {
            return context.preferredMarketplace == nil ? AppSymbol.Action.search : AppSymbol.Action.composeListing
        }
        return "chevron.right"
    }

    private var bottomHelperText: String {
        if isLastQuestion {
            return context.preferredMarketplace == nil
                ? "BuySell searches real marketplace info next."
                : "BuySell checks this place and writes the post."
        }
        return dynamicTypeSize.isAccessibilitySize
            ? "Tap the closest answer. BuySell asks the next useful clue."
            : "Answer the quick ones you know. BuySell skips what does not matter."
    }

    private var bottomContentInset: CGFloat {
        if targetedScanRequest != nil {
            return dynamicTypeSize.isAccessibilitySize ? 64 : 32
        }
        return dynamicTypeSize.isAccessibilitySize ? 196 : 112
    }

    private var navigationTitle: String {
        if let marketplace = context.preferredMarketplace {
            return String.localizedFormat("For %@".localized, marketplace.displayName)
        }
        return "Quick details".localized
    }

    private var questionSectionTitle: String {
        if visibleQuestions.count > 1 {
            return context.preferredMarketplace == nil ? "A few quick things" : "For this post"
        }
        if let currentQuestion {
            return currentQuestion.contextLabel
        }
        return context.preferredMarketplace == nil ? "One quick thing" : "For this post"
    }

    private var questionSectionFooter: String {
        visibleQuestions.count > 1
            ? "Answer any that you know. Every one has an I don't know option."
            : "Answer if you know it. Skip if you don't."
    }

    private var headerDetailText: String {
        context.preferredMarketplace == nil ? "Answer only what you know." : "Only what helps this post."
    }

    private func binding(for field: Field) -> Binding<String> {
        Binding(
            get: { answer(for: field) },
            set: { setAnswer($0, for: field) }
        )
    }

    private func answer(for field: Field) -> String {
        switch field {
        case .labelOrBrand:
            answers.labelOrBrand
        case .sizeOrModel:
            answers.sizeOrModel
        case .flaws:
            answers.flaws
        case .included:
            answers.included
        case .extraDetails:
            answers.extraDetails
        case .marketplaceNote(let marketplace):
            answers.marketplaceNote(for: marketplace)
        }
    }

    private func setAnswer(_ value: String, for field: Field) {
        switch field {
        case .labelOrBrand:
            answers.labelOrBrand = value
        case .sizeOrModel:
            answers.sizeOrModel = value
        case .flaws:
            answers.flaws = value
        case .included:
            answers.included = value
        case .extraDetails:
            answers.extraDetails = value
        case .marketplaceNote(let marketplace):
            answers.setMarketplaceNote(value, for: marketplace)
            return
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answers.clearAnswered(field.detailKey)
        } else {
            answers.markAnswered(field.detailKey)
        }
    }

    private func applyChoice(_ choice: DetailChoice, for question: DetailQuestion) {
        Haptics.impact(.light)
        moveToQuestion(question)
        if case .targetedScan(let request) = choice.value {
            startTargetedScan(request)
            return
        }
        if case .clueScan(let request, let notedAnswer) = choice.value {
            recordClueScanOpened(question: question, notedAnswer: notedAnswer)
            startTargetedScan(request)
            return
        }

        switch (question.kind, choice.value) {
        case (.text(let field), .text(let value)):
            setAnswer(value, for: field)
        case (.text, .unknown):
            if insertUnknownFollowUp(after: question) {
                recordFollowUpQuestionAnswered(question, skipped: true)
                return
            }
            markQuestionHandled(question)
        case (.text, .largeFragile):
            break
        case (.text, .targetedScan):
            break
        case (.text, .clueScan):
            break
        case (.largeOrFragile, .largeFragile(let value)):
            answers.isLargeOrFragile = value
            answers.markAnswered(.largeOrFragile)
        case (.largeOrFragile, .unknown):
            answers.isLargeOrFragile = false
            answers.markAnswered(.largeOrFragile)
        case (.largeOrFragile, .text):
            break
        case (.largeOrFragile, .targetedScan):
            break
        case (.largeOrFragile, .clueScan):
            break
        }
        advanceOrContinue(emitsFeedback: false)
    }

    private func advanceOrContinue(emitsFeedback: Bool = true) {
        focusedField = nil
        showsReferenceExamples = false
        let handledQuestion = currentQuestion
        let handledIndex = currentQuestionIndex
        if let handledQuestion, handledQuestion.isAnswered(in: answers) {
            recordFollowUpQuestionAnswered(handledQuestion, skipped: false)
        }
        if emitsFeedback {
            Haptics.impact(isLastQuestion ? .medium : .light)
        }
        if let handledQuestion, handledQuestion.isAnswered(in: answers) {
            refreshQuestionsAfterHandling(from: handledIndex)
            guard questions.isEmpty == false else {
                continueWithDetails()
                return
            }
            return
        }
        if isLastQuestion {
            continueWithDetails()
        } else {
            currentQuestionIndex = min(currentQuestionIndex + 1, questions.count - 1)
        }
    }

    private func skipQuestion() {
        focusedField = nil
        showsReferenceExamples = false
        Haptics.impact(.light)
        if let currentQuestion {
            if insertUnknownFollowUp(after: currentQuestion) {
                recordFollowUpQuestionAnswered(currentQuestion, skipped: true)
                return
            }
            let handledIndex = currentQuestionIndex
            markQuestionHandled(currentQuestion)
            recordFollowUpQuestionAnswered(currentQuestion, skipped: true)
            refreshQuestionsAfterHandling(from: handledIndex)
        }
        if questions.isEmpty {
            continueWithDetails()
        } else {
            currentQuestionIndex = min(currentQuestionIndex, questions.count - 1)
        }
    }

    private func startAssistantKeepChecking(_ question: DetailQuestion) {
        focusedField = nil
        Haptics.impact(.light)
        if let existingIndex = questions.firstIndex(where: { $0.id == question.id }) {
            currentQuestionIndex = existingIndex
        } else {
            questions.insert(question, at: 0)
            currentQuestionIndex = 0
        }
        ProductAnalytics.record(
            .followUpQuestionAnswered,
            properties: [
                "category": context.item.category.rawValue,
                "question_kind": "keep_checking",
                "answer_state": "opened",
                "marketplace": context.preferredMarketplace?.rawValue ?? "none"
            ]
        )
    }

    private func refreshQuestionsAfterHandling(from handledIndex: Int) {
        var refreshedQuestions: [DetailQuestion] = []
        pendingUnknownFollowUps.forEach { appendQuestion($0, to: &refreshedQuestions) }
        Self.makeQuestions(context: context, answers: answers).forEach { appendQuestion($0, to: &refreshedQuestions) }
        questions = refreshedQuestions
        currentQuestionIndex = nextQuestionIndexAfterRefresh(
            handledIndex: handledIndex,
            refreshedCount: refreshedQuestions.count
        )
    }

    private func nextQuestionIndexAfterRefresh(handledIndex _: Int, refreshedCount: Int) -> Int {
        guard refreshedCount > 0 else { return 0 }
        return 0
    }

    private var pendingUnknownFollowUps: [DetailQuestion] {
        questions.filter { question in
            question.isUnknownFollowUp && question.isAnswered(in: answers) == false
        }
    }

    private func appendQuestion(_ question: DetailQuestion, to questions: inout [DetailQuestion]) {
        guard question.isAnswered(in: answers) == false else { return }
        guard questions.contains(where: { existingQuestion in
            existingQuestion.id == question.id || existingQuestion.kind == question.kind
        }) == false else { return }
        questions.append(question)
    }

    private func insertUnknownFollowUp(after question: DetailQuestion) -> Bool {
        guard question.isUnknownFollowUp == false,
              let followUp = unknownFollowUpQuestion(after: question)
        else {
            return false
        }

        if let existingIndex = questions.firstIndex(where: { $0.id == followUp.id }) {
            currentQuestionIndex = existingIndex
            return true
        }

        let insertionIndex = min(currentQuestionIndex + 1, questions.count)
        questions.insert(followUp, at: insertionIndex)
        currentQuestionIndex = insertionIndex
        return true
    }

    private func unknownFollowUpQuestion(after question: DetailQuestion) -> DetailQuestion? {
        if let serverFollowUp = question.unknownFollowUp {
            return serverFollowUp.makeQuestion()
        }
        return Self.defaultUnknownFollowUp(after: question, item: context.item, marketplace: context.preferredMarketplace)
    }

    private func startTargetedScan(_ request: TargetedScanRequest) {
        focusedField = nil
        Haptics.impact(.medium)
        appStore.startTargetedScan(
            request: request,
            context: context,
            answers: answers,
            answeredField: targetedScanAnsweredField
        )
    }

    private func recordClueScanOpened(question: DetailQuestion, notedAnswer: String) {
        ProductAnalytics.record(
            .followUpQuestionAnswered,
            properties: [
                "category": context.item.category.rawValue,
                "question_kind": "\(question.analyticsKind)_clue_scan",
                "answer_state": "scan_opened",
                "answer_hint": notedAnswer,
                "marketplace": context.preferredMarketplace?.rawValue ?? "none"
            ]
        )
    }

    private func skipTargetedScan() {
        focusedField = nil
        Haptics.impact(.light)
        answers.markAnswered(targetedScanAnsweredField)
        ProductAnalytics.record(
            .followUpQuestionAnswered,
            properties: [
                "category": context.item.category.rawValue,
                "question_kind": "targeted_scan",
                "answer_state": "unknown",
                "marketplace": context.preferredMarketplace?.rawValue ?? "none"
            ]
        )
    }

    private func markQuestionHandled(_ question: DetailQuestion) {
        switch question.kind {
        case .text(let field):
            clearAnswer(for: field)
            switch field {
            case .marketplaceNote(let marketplace):
                answers.markMarketplaceAnswered(marketplace)
            default:
                answers.markAnswered(field.detailKey)
            }
        case .largeOrFragile:
            answers.markAnswered(.largeOrFragile)
        }
    }

    private func clearAnswer(for field: Field) {
        switch field {
        case .labelOrBrand:
            answers.labelOrBrand = ""
        case .sizeOrModel:
            answers.sizeOrModel = ""
        case .flaws:
            answers.flaws = ""
        case .included:
            answers.included = ""
        case .extraDetails:
            answers.extraDetails = ""
        case .marketplaceNote(let marketplace):
            answers.setMarketplaceNote("", for: marketplace)
        }
    }

    private func previousQuestion() {
        focusedField = nil
        showsReferenceExamples = false
        Haptics.impact(.light)
        currentQuestionIndex = max(currentQuestionIndex - 1, 0)
    }

    private func moveToQuestion(_ question: DetailQuestion) {
        guard let index = questions.firstIndex(where: { $0.id == question.id }) else { return }
        currentQuestionIndex = index
    }

    private func editSavedDetail(_ row: SavedDetailRow) {
        focusedField = nil
        Haptics.impact(.light)
        let question = editableQuestion(for: row.target)
        if let existingIndex = questions.firstIndex(where: { $0.kind == question.kind }) {
            questions[existingIndex] = question
            currentQuestionIndex = existingIndex
        } else {
            let insertionIndex = questions.isEmpty ? 0 : min(currentQuestionIndex, questions.count)
            questions.insert(question, at: insertionIndex)
            currentQuestionIndex = insertionIndex
        }
        if case .text(let field) = question.kind {
            focusedField = field
        }
    }

    private func editableQuestion(for target: SavedDetailTarget) -> DetailQuestion {
        switch target {
        case .field(.labelOrBrand):
            Self.brandQuestion(for: context.item.category)
        case .field(.sizeOrModel):
            Self.specQuestion(for: context.item.category, marketplace: context.preferredMarketplace)
        case .field(.flaws):
            Self.flawQuestion
        case .field(.included):
            Self.includedQuestion(for: context.item.category)
        case .field(.extraDetails):
            Self.extraDetailQuestion(for: context.item.category)
        case .field(.marketplaceNote(let marketplace)):
            Self.marketplaceQuestion(for: marketplace, item: context.item, answers: answers)
        case .largeOrFragile:
            Self.largeOrFragileQuestion(for: context.item.category)
        }
    }

    private func continueWithDetails() {
        continueForward(details: answers.sanitizedForUse)
    }

    private func continueWithoutDetails() {
        focusedField = nil
        continueForward(details: nil)
    }

    private func continueForward(details: ItemDetailAnswers?) {
        Haptics.impact(.medium)
        let enrichedAnalysis = AnalyzeIntelligence.enriching(
            context.analysis,
            with: details,
            item: context.item,
            marketplace: context.preferredMarketplace
        )
        ProductAnalytics.record(
            .followUpQuestionsCompleted,
            properties: [
                "category": context.item.category.rawValue,
                "question_count": "\(questions.count)",
                "answered_count": "\(details?.answeredFieldKeys.count ?? 0)",
                "marketplace": context.preferredMarketplace?.rawValue ?? "none"
            ]
        )
        if let preferredMarketplace = context.preferredMarketplace {
            appStore.presentListing(
                item: context.item,
                imageData: context.imageData,
                supplementalPhotos: context.supplementalPhotos,
                marketplace: preferredMarketplace,
                details: details,
                marketplaceComparison: context.marketplaceComparison,
                analysis: enrichedAnalysis
            )
        } else {
            appStore.presentMarketplacePicker(
                item: context.item,
                imageData: context.imageData,
                supplementalPhotos: context.supplementalPhotos,
                details: details,
                analysis: enrichedAnalysis
            )
        }
    }

    private func recordFollowUpQuestionAnswered(_ question: DetailQuestion, skipped: Bool) {
        ProductAnalytics.record(
            .followUpQuestionAnswered,
            properties: [
                "category": context.item.category.rawValue,
                "question_kind": question.analyticsKind,
                "answer_state": skipped ? "unknown" : "answered",
                "marketplace": context.preferredMarketplace?.rawValue ?? "none"
            ]
        )
    }

    private static func makeQuestions(context: ItemQuestionsContext, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        var usedKinds = Set<QuestionKind>()
        let missingFacts = context.analysis?.missingFacts ?? []
        let knownFacts = context.analysis?.itemFacts ?? []

        func add(_ question: DetailQuestion?) {
            guard let question else { return }
            guard question.isAnswered(in: answers) == false else { return }
            guard usedKinds.contains(question.kind) == false else { return }
            usedKinds.insert(question.kind)
            questions.append(question)
        }

        if let marketplace = context.preferredMarketplace {
            add(draftWarningQuestion(for: context, marketplace: marketplace, answers: answers))
            add(likelyMatchQuestion(for: context, answers: answers))
            add(profileDrivenQuestion(for: context, answers: answers))
            add(identityClueQuestion(for: context, answers: answers))
            add(valuableVersionQuestion(for: context, answers: answers))
            add(marketplaceEvidenceQuestion(for: context, marketplace: marketplace, answers: answers))
            add(marketplacePlaybookQuestion(for: marketplace, item: context.item, answers: answers))
            marketplaceQuestions(for: marketplace, item: context.item, answers: answers).forEach { add($0) }
            prioritizedValueQuestions(from: context.analysis?.valueQuestions ?? [])
                .filter(isIdentityValueQuestion)
                .forEach { add(valueQuestion($0, item: context.item)) }
            prioritizedValueQuestions(from: context.analysis?.valueQuestions ?? [])
                .filter { isIdentityValueQuestion($0) == false }
                .forEach { add(valueQuestion($0, item: context.item)) }
            add(analysisQuestion(for: context))
            if shouldAskLargeOrFragile(for: context.item.category, marketplace: marketplace) {
                add(largeOrFragileQuestion(for: context.item.category))
            }
            return Array(rankedAdaptiveQuestions(questions, context: context, answers: answers).prefix(questionLimit(for: context)))
        }
        add(likelyMatchQuestion(for: context, answers: answers))
        add(profileDrivenQuestion(for: context, answers: answers))
        prioritizedValueQuestions(from: context.analysis?.valueQuestions ?? [])
            .forEach { add(valueQuestion($0, item: context.item)) }
        add(identityClueQuestion(for: context, answers: answers))
        add(valuableVersionQuestion(for: context, answers: answers))
        add(analysisQuestion(for: context))
        if shouldAskBrand(for: context.item.category, missingFacts: missingFacts, knownFacts: knownFacts) {
            add(brandQuestion(for: context.item.category))
        }
        if shouldAskSpecs(for: context.item.category, missingFacts: missingFacts, knownFacts: knownFacts) {
            add(specQuestion(for: context.item.category, marketplace: context.preferredMarketplace))
        }
        if shouldAskFlaws(missingFacts: missingFacts, knownFacts: knownFacts) {
            add(flawQuestion)
        }
        if shouldAskIncluded(for: context.item.category, missingFacts: missingFacts, knownFacts: knownFacts) {
            add(includedQuestion(for: context.item.category))
        }
        if shouldAskLargeOrFragile(for: context.item.category, marketplace: context.preferredMarketplace) {
            add(largeOrFragileQuestion(for: context.item.category))
        }

        return Array(rankedAdaptiveQuestions(questions, context: context, answers: answers).prefix(questionLimit(for: context)))
    }

    private static func rankedAdaptiveQuestions(
        _ questions: [DetailQuestion],
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        questions.enumerated()
            .sorted { left, right in
                let leftScore = adaptiveQuestionScore(for: left.element, context: context, answers: answers)
                let rightScore = adaptiveQuestionScore(for: right.element, context: context, answers: answers)
                guard leftScore.total == rightScore.total else {
                    return leftScore.total > rightScore.total
                }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    private static func adaptiveQuestionScore(
        for question: DetailQuestion,
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> AdaptiveQuestionScore {
        let searchText = question.searchText
        let identityInformationGain = identityInformationGain(
            for: question,
            context: context,
            searchText: searchText
        )
        let valuableVariantDetection = valuableVariantDetection(
            for: question,
            category: context.item.category,
            searchText: searchText
        )
        let likelyMatchDisambiguation = likelyMatchDisambiguation(
            for: question,
            context: context,
            searchText: searchText
        )
        let pricingImpact = pricingImpact(for: question, searchText: searchText)
        let marketplaceEligibilityImpact = marketplaceEligibilityImpact(
            for: question,
            marketplace: context.preferredMarketplace,
            searchText: searchText
        )
        let buyerTrustImpact = buyerTrustImpact(for: question, searchText: searchText)
        let userEffort = userEffort(for: question)
        let answerDifficulty = answerDifficulty(for: question, searchText: searchText)
        let repetitionPenalty = question.isAnswered(in: answers) ? 100 : 0

        return AdaptiveQuestionScore(
            identityInformationGain: identityInformationGain,
            valuableVariantDetection: valuableVariantDetection,
            likelyMatchDisambiguation: likelyMatchDisambiguation,
            pricingImpact: pricingImpact,
            marketplaceEligibilityImpact: marketplaceEligibilityImpact,
            buyerTrustImpact: buyerTrustImpact,
            userEffort: userEffort,
            answerDifficulty: answerDifficulty,
            repetitionPenalty: repetitionPenalty
        )
    }

    private static func identityInformationGain(
        for question: DetailQuestion,
        context: ItemQuestionsContext,
        searchText: String
    ) -> Int {
        if question.id == "analysis-likely-match" {
            return 85
        }
        if question.id.contains("draft-warning") {
            return 82
        }
        if question.id.contains("identity-clue") {
            return 76
        }
        if question.id.contains("analysis-value") && question.kind.isIdentityField {
            return 68
        }
        if question.id.contains("analysis-") && question.kind.isIdentityField {
            return 64
        }
        if question.kind.isIdentityField,
           shouldAskMoreIdentificationHelp(for: context) {
            return 58
        }
        if question.kind.isIdentityField {
            return 44
        }
        if searchText.containsAny(of: ["exact", "match", "version", "variant"]) {
            return 34
        }
        return 12
    }

    private static func valuableVariantDetection(
        for question: DetailQuestion,
        category: Category,
        searchText: String
    ) -> Int {
        let variantSignals = [
            "edition", "limited", "numbered", "signed", "signature", "serial",
            "maker", "mark", "stamp", "hallmark", "authentic", "certificate",
            "vintage", "year", "first", "sku", "style code", "model", "material",
            "sterling", "leather", "wool", "oled", "storage", "capacity"
        ]
        guard searchText.containsAny(of: variantSignals) else { return 0 }
        return isHighDetailCategory(category) ? 44 : 30
    }

    private static func likelyMatchDisambiguation(
        for question: DetailQuestion,
        context: ItemQuestionsContext,
        searchText: String
    ) -> Int {
        let matches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        guard matches.count > 1 else { return 0 }
        if question.id == "analysis-likely-match" {
            return 54
        }
        let distinguishingText = matches
            .map(\.distinguishingQuestion)
            .joined(separator: " ")
            .lowercased()
        let disambiguationSignals = [
            "which", "label", "model", "serial", "stamp", "mark", "tag",
            "size", "material", "edition", "number", "year", "shape",
            "handle", "screen", "logo", "barcode", "sku", "version"
        ]
        let matchesCurrentQuestion = disambiguationSignals.contains { signal in
            searchText.contains(signal) && distinguishingText.contains(signal)
        }
        return matchesCurrentQuestion ? 36 : 10
    }

    private static func pricingImpact(for question: DetailQuestion, searchText: String) -> Int {
        switch question.kind {
        case .largeOrFragile:
            return 34
        case .text(let field):
            switch field {
            case .sizeOrModel:
                return 46
            case .labelOrBrand:
                return 42
            case .flaws:
                return 38
            case .included:
                return 34
            case .extraDetails:
                return searchText.containsAny(of: ["rare", "limited", "edition", "serial", "material"]) ? 40 : 24
            case .marketplaceNote:
                return 28
            }
        }
    }

    private static func marketplaceEligibilityImpact(
        for question: DetailQuestion,
        marketplace: Marketplace?,
        searchText: String
    ) -> Int {
        guard marketplace != nil else { return 0 }
        if question.id.contains("marketplace-evidence") {
            return 52
        }
        if question.id.contains("marketplace-playbook") {
            return 46
        }
        if case .text(.marketplaceNote) = question.kind {
            return 42
        }
        if searchText.containsAny(of: ["pickup", "shipping", "box", "authentic", "required", "needs"]) {
            return 28
        }
        return 12
    }

    private static func buyerTrustImpact(for question: DetailQuestion, searchText: String) -> Int {
        switch question.kind {
        case .largeOrFragile:
            return 20
        case .text(let field):
            switch field {
            case .flaws:
                return 44
            case .included:
                return 34
            case .labelOrBrand, .sizeOrModel:
                return 26
            case .extraDetails:
                return searchText.containsAny(of: ["proof", "certificate", "authentic", "working", "tested"]) ? 30 : 16
            case .marketplaceNote:
                return 18
            }
        }
    }

    private static func userEffort(for question: DetailQuestion) -> Int {
        if question.choices.contains(where: \.isTargetedScan) {
            return 22
        }
        if question.choices.isEmpty {
            return 24
        }
        if question.choices.count <= 4 {
            return 6
        }
        return 12
    }

    private static func answerDifficulty(for question: DetailQuestion, searchText: String) -> Int {
        var difficulty = 0
        if searchText.containsAny(of: ["serial", "sku", "barcode", "upc", "model number"]) {
            difficulty += 8
        }
        if searchText.containsAny(of: ["measure", "dimension", "weight", "material"]) {
            difficulty += 6
        }
        if question.choices.isEmpty {
            difficulty += 8
        }
        return difficulty
    }

    private static func isIdentityValueQuestion(_ question: AnalyzeValueQuestion) -> Bool {
        switch question.answerField {
        case .brand, .spec, .extra:
            return true
        case .condition, .included:
            return false
        }
    }

    private static func prioritizedValueQuestions(from questions: [AnalyzeValueQuestion]) -> [AnalyzeValueQuestion] {
        questions.enumerated()
            .sorted { lhs, rhs in
                let lhsPriority = valueQuestionPriority(lhs.element)
                let rhsPriority = valueQuestionPriority(rhs.element)
                guard lhsPriority == rhsPriority else {
                    return lhsPriority > rhsPriority
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func valueQuestionPriority(_ question: AnalyzeValueQuestion) -> Int {
        let searchableText = [
            question.question,
            question.reason,
            question.unknownFollowUpQuestion ?? "",
            question.choices.joined(separator: " "),
            question.unknownFollowUpChoices.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        let identitySignals = [
            "model", "serial", "sku", "style code", "barcode", "upc",
            "edition", "numbered", "signed", "maker", "mark", "stamp",
            "label", "tag", "hallmark", "authentic", "certificate",
            "year", "vintage", "material", "sterling", "leather", "wool",
            "capacity", "storage", "carrier", "size"
        ]
        if identitySignals.contains(where: { searchableText.contains($0) }) {
            return 3
        }
        if [.brand, .spec, .extra].contains(question.answerField) {
            return 2
        }
        if [.condition, .included].contains(question.answerField) {
            return 1
        }
        return 0
    }

    private static func valueQuestion(_ question: AnalyzeValueQuestion, item: DetectedItem) -> DetailQuestion? {
        guard let cleanQuestion = question.sanitizedForDisplay() else { return nil }
        let field = field(for: cleanQuestion.answerField)
        let valueChoices = cleanQuestion.choices.filter {
            $0.localizedCaseInsensitiveCompare("I don't know") != .orderedSame
        }
        let choices = choicesWithUnknown(valueChoices.map {
            DetailChoice(title: $0, value: .text($0), localizesTitle: false)
        })

        return DetailQuestion(
            id: "analysis-value-\(cleanQuestion.answerField.rawValue)-\(cleanQuestion.question)",
            contextLabel: "Worth check",
            title: cleanQuestion.question,
            detail: cleanQuestion.reason,
            placeholder: placeholder(for: cleanQuestion.answerField),
            systemImage: symbol(for: cleanQuestion.answerField),
            kind: .text(field),
            choices: choices,
            unknownFollowUp: aiUnknownFollowUp(for: cleanQuestion, field: field, item: item)
        )
    }

    private static func profileDrivenQuestion(
        for context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard let profile = context.analysis?.identificationProfile?.sanitizedForDisplay() else {
            return nil
        }

        if let matchQuestion = profilePossibleMatchQuestion(
            profile: profile,
            context: context,
            answers: answers
        ) {
            return matchQuestion
        }

        guard let clue = profileDrivenClue(profile: profile, item: context.item) else {
            return nil
        }
        guard answers.hasAnsweredOrSkipped(clue.field.detailKey) == false else {
            return nil
        }

        return DetailQuestion(
            id: "profile-clue-\(clue.field.detailKey.rawValue)-\(clue.idSuffix)",
            contextLabel: "Worth check",
            title: clue.title,
            detail: clue.detail,
            placeholder: clue.placeholder,
            systemImage: clue.systemImage,
            kind: .text(clue.field),
            choices: choicesWithOptionalScan(clue.choices, scanRequest: clue.scanRequest),
            evidenceSummary: QuestionEvidenceSummary(
                title: "AI clue",
                value: clue.source,
                detail: "This could change the search or the selling price.",
                systemImage: "sparkle.magnifyingglass"
            ),
            unknownFollowUp: DetailQuestionFallback(
                id: "profile-clue-help-\(clue.idSuffix)",
                contextLabel: "Look closer",
                title: clue.followUpTitle,
                detail: "Pick the closest thing you can see. Skip if nothing fits.",
                placeholder: clue.placeholder,
                systemImage: clue.systemImage,
                kind: .text(clue.field),
                choices: choicesWithOptionalScan(clue.followUpChoices, scanRequest: clue.scanRequest)
            )
        )
    }

    private static func profilePossibleMatchQuestion(
        profile: AnalyzeIdentificationProfile,
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false else { return nil }
        let matches = profile.possibleMatches
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard matches.count > 1 else { return nil }

        return DetailQuestion(
            id: "profile-match-\(context.item.category.rawValue)",
            contextLabel: "Figure it out",
            title: "Which one looks closest?",
            detail: "BuySell found a few possible matches. Pick one only if it really looks like yours.",
            placeholder: "Exact name, model, or version...",
            systemImage: "scope",
            kind: .text(.sizeOrModel),
            choices: choicesWithUnknown(matches.prefix(3).map {
                DetailChoice(title: $0, value: .text($0), localizesTitle: false)
            }),
            allowsReferenceExamples: true,
            evidenceSummary: QuestionEvidenceSummary(
                title: "Possible matches",
                value: matches.prefix(2).joined(separator: " or "),
                detail: "This helps BuySell avoid searching the wrong sold listings.",
                systemImage: "scope"
            ),
            unknownFollowUp: DetailQuestionFallback(
                id: "profile-match-help-\(context.item.category.rawValue)",
                contextLabel: "Look closer",
                title: identityClueFollowUpTitle(for: context.item.category),
                detail: "A label, size, material, edition, or mark can separate similar items.",
                placeholder: identityCluePlaceholder(for: context.item.category),
                systemImage: identityClueSymbol(for: context.item.category),
                kind: .text(.extraDetails),
                choices: choicesWithOptionalScan(
                    likelyMatchClueChoices(for: context.item.category),
                    scanRequest: unknownFallbackScanRequest(
                        for: .sizeOrModel,
                        category: context.item.category,
                        marketplace: context.preferredMarketplace
                    )
                )
            )
        )
    }

    private static func profileDrivenClue(
        profile: AnalyzeIdentificationProfile,
        item: DetectedItem
    ) -> ProfileDrivenQuestionSeed? {
        let candidates = profile.potentiallyValuableVariants
            + profile.evidenceNeeded
            + profile.unknownDetails.map { "Check \($0)" }
        guard let source = candidates
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.isEmpty == false })
        else {
            return nil
        }

        let field = profileQuestionField(for: source)
        let choices = profileQuestionChoices(
            for: source,
            field: field,
            category: item.category,
            itemName: item.name
        )
        let scanRequest = profileScanRequest(
            for: source,
            field: field,
            category: item.category
        )

        return ProfileDrivenQuestionSeed(
            idSuffix: stableQuestionSuffix(from: source),
            source: String(source.prefix(90)),
            field: field,
            title: profileQuestionTitle(for: source, field: field),
            detail: profileQuestionDetail(for: source),
            placeholder: profileQuestionPlaceholder(for: field, category: item.category),
            systemImage: profileQuestionSymbol(for: source, field: field, category: item.category),
            choices: choices,
            followUpTitle: profileQuestionFollowUpTitle(for: source, field: field, category: item.category),
            followUpChoices: choices,
            scanRequest: scanRequest
        )
    }

    private static func profileQuestionField(for clue: String) -> Field {
        let lowercased = clue.lowercased()
        if lowercased.containsAny(of: ["brand", "maker", "manufacturer", "artist", "logo", "signature", "signed", "hallmark"]) {
            return .labelOrBrand
        }
        if lowercased.containsAny(of: ["model", "serial", "sku", "style code", "barcode", "upc", "size", "storage", "capacity", "carrier"]) {
            return .sizeOrModel
        }
        if lowercased.containsAny(of: ["condition", "flaw", "damage", "scratch", "wear", "working", "tested", "broken"]) {
            return .flaws
        }
        if lowercased.containsAny(of: ["included", "accessory", "box", "case", "charger", "paperwork", "certificate", "receipt", "parts"]) {
            return .included
        }
        return .extraDetails
    }

    private static func profileQuestionTitle(for clue: String, field: Field) -> String {
        let lowercased = clue.lowercased()
        if lowercased.containsAny(of: ["edition", "limited", "numbered", "year", "vintage", "antique", "1920", "1930"]) {
            return "Any special version clue?"
        }
        if lowercased.containsAny(of: ["maker", "mark", "stamp", "hallmark", "signature", "signed"]) {
            return "Do you see a mark or signature?"
        }
        if lowercased.containsAny(of: ["model", "serial", "sku", "barcode", "upc"]) {
            return "Can you find the exact model or number?"
        }
        if lowercased.containsAny(of: ["box", "certificate", "paperwork", "accessory", "included"]) {
            return "What comes with it?"
        }
        if lowercased.containsAny(of: ["condition", "flaw", "damage", "wear", "working"]) {
            return "What condition clue can you see?"
        }

        switch field {
        case .labelOrBrand:
            return "What name or mark can you see?"
        case .sizeOrModel:
            return "What exact detail can you see?"
        case .flaws:
            return "What condition clue can you see?"
        case .included:
            return "What comes with it?"
        case .extraDetails, .marketplaceNote:
            return "What clue should BuySell check?"
        }
    }

    private static func profileQuestionDetail(for clue: String) -> String {
        let source = String(clue.prefix(90))
        return "BuySell flagged \"\(source)\" because it can change what to search and what it sells for."
    }

    private static func profileQuestionPlaceholder(for field: Field, category: Category) -> String {
        switch field {
        case .labelOrBrand:
            return brandPlaceholder(for: category)
        case .sizeOrModel:
            return sizePlaceholder(for: category)
        case .flaws:
            return "No flaws, light wear, broken part..."
        case .included:
            return includedPlaceholder(for: category)
        case .extraDetails:
            return extraDetailPlaceholder(for: category)
        case .marketplaceNote:
            return "Pickup, shipping, offers..."
        }
    }

    private static func profileQuestionSymbol(
        for clue: String,
        field: Field,
        category: Category
    ) -> String {
        let lowercased = clue.lowercased()
        if lowercased.containsAny(of: ["maker", "mark", "stamp", "hallmark", "signature", "signed", "certificate"]) {
            return "seal.fill"
        }
        if lowercased.containsAny(of: ["edition", "limited", "numbered", "vintage", "antique", "year"]) {
            return "sparkle.magnifyingglass"
        }
        switch field {
        case .labelOrBrand:
            return AppSymbol.Action.category
        case .sizeOrModel:
            return specQuestionSymbol(for: category)
        case .flaws:
            return AppSymbol.Condition.fair
        case .included:
            return AppSymbol.Marketplace.package
        case .extraDetails:
            return "sparkle.magnifyingglass"
        case .marketplaceNote:
            return "tag.fill"
        }
    }

    private static func profileQuestionChoices(
        for clue: String,
        field: Field,
        category: Category,
        itemName: String
    ) -> [DetailChoice] {
        let lowercased = clue.lowercased()
        let specificChoices = itemSpecificFallbackChoices(
            for: field,
            category: category,
            itemName: itemName,
            clueText: clue,
            marketplace: nil
        )
        if specificChoices.isEmpty == false {
            return specificChoices
        }
        if lowercased.containsAny(of: ["edition", "limited", "numbered", "year", "vintage", "antique", "1920", "1930"]) {
            return [
                DetailChoice(title: "From older era", value: .text("Looks older or vintage")),
                DetailChoice(title: "Special edition", value: .text("Special edition clue visible")),
                DetailChoice(title: "No date shown", value: .text("No date or edition visible"))
            ]
        }
        if lowercased.containsAny(of: ["maker", "mark", "stamp", "hallmark", "signature", "signed"]) {
            return [
                DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                DetailChoice(title: "No mark", value: .text("No visible mark"))
            ]
        }
        if lowercased.containsAny(of: ["model", "serial", "sku", "barcode", "upc"]) {
            return [
                DetailChoice(title: "Model label", value: .text("Model label visible")),
                DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                DetailChoice(title: "No label", value: .text("No visible label"))
            ]
        }
        if lowercased.containsAny(of: ["box", "certificate", "paperwork", "accessory", "included"]) {
            return [
                DetailChoice(title: "Original box", value: .text("Original box included")),
                DetailChoice(title: "Paperwork", value: .text("Paperwork or certificate included")),
                DetailChoice(title: "Item only", value: .text("Item only"))
            ]
        }
        if lowercased.containsAny(of: ["condition", "flaw", "damage", "wear", "working"]) {
            return [
                DetailChoice(title: "No obvious flaws", value: .text("No obvious flaws")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "Needs work", value: .text("Needs work or repair"))
            ]
        }
        return extraFallbackChoices(for: category).filter { $0.isUnknown == false }
    }

    private static func profileQuestionFollowUpTitle(
        for clue: String,
        field: Field,
        category: Category
    ) -> String {
        let lowercased = clue.lowercased()
        if lowercased.containsAny(of: ["maker", "mark", "stamp", "hallmark", "signature", "signed"]) {
            return "Check the bottom, back, clasp, tag, or frame"
        }
        if lowercased.containsAny(of: ["model", "serial", "sku", "barcode", "upc"]) {
            return "Check the back, bottom, battery area, or label"
        }
        if lowercased.containsAny(of: ["edition", "limited", "numbered", "year", "vintage", "antique"]) {
            return "Check the back, package, corner, or paperwork"
        }
        switch field {
        case .labelOrBrand:
            return fallbackTitle(for: .labelOrBrand, category: category, marketplace: nil)
        case .sizeOrModel:
            return fallbackTitle(for: .sizeOrModel, category: category, marketplace: nil)
        case .flaws:
            return "Look at the worst spot"
        case .included:
            return "Check the box, case, charger, or paperwork"
        case .extraDetails, .marketplaceNote:
            return identityClueFollowUpTitle(for: category)
        }
    }

    private static func profileScanRequest(
        for clue: String,
        field: Field,
        category: Category
    ) -> TargetedScanRequest? {
        let lowercased = clue.lowercased()
        if lowercased.containsAny(of: ["barcode", "upc", "qr"]) {
            return TargetedScanRequest(
                prompt: "Scan the barcode.",
                benefit: "This can confirm the exact product.",
                role: .barcode
            )
        }
        if lowercased.containsAny(of: ["serial", "model", "sku"]) {
            return TargetedScanRequest(
                prompt: "Scan the model or serial plate.",
                benefit: "This can confirm the exact model.",
                role: .serial
            )
        }
        if lowercased.containsAny(of: ["maker", "mark", "stamp", "hallmark", "signature", "signed", "certificate"]) {
            return TargetedScanRequest(
                prompt: "Scan the mark or certificate.",
                benefit: "This may improve your price estimate.",
                role: .authenticity
            )
        }
        if lowercased.containsAny(of: ["tag", "size", "style code", "material"]) {
            return TargetedScanRequest(
                prompt: "Scan the tag or material label.",
                benefit: "This helps us match closer sold listings.",
                role: .sizeTag
            )
        }
        if lowercased.containsAny(of: ["box", "included", "accessory", "paperwork"]) {
            return TargetedScanRequest(
                prompt: "Show everything included.",
                benefit: "Buyers will want to see this.",
                role: .accessories
            )
        }
        if lowercased.containsAny(of: ["flaw", "damage", "scratch", "wear", "condition"]) {
            return TargetedScanRequest(
                prompt: "Show the damaged area.",
                benefit: "Buyers will want to see this.",
                role: .condition
            )
        }
        return unknownFallbackScanRequest(for: field, category: category, marketplace: nil)
    }

    private static func stableQuestionSuffix(from value: String) -> String {
        let normalized = value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .prefix(5)
            .joined(separator: "-")
        return normalized.isEmpty ? "detail" : normalized
    }

    private static func questionImpactRows(
        for question: DetailQuestion,
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> [QuestionImpactRow] {
        let score = adaptiveQuestionScore(for: question, context: context, answers: answers)
        var rows: [QuestionImpactRow] = []

        func append(_ row: QuestionImpactRow) {
            guard rows.contains(where: { $0.title == row.title }) == false else { return }
            rows.append(row)
        }

        if score.identityInformationGain >= 50 || score.likelyMatchDisambiguation >= 30 {
            append(QuestionImpactRow(
                title: "Narrow ID",
                detail: "This helps BuySell choose the closest match.",
                systemImage: "scope"
            ))
        }

        if score.valuableVariantDetection >= 30 {
            append(QuestionImpactRow(
                title: "Special version",
                detail: "Some versions sell differently, so BuySell checks the visible clue.",
                systemImage: "sparkle.magnifyingglass"
            ))
        }

        if score.pricingImpact >= 38 {
            append(QuestionImpactRow(
                title: "Price",
                detail: "This can change which sold listings are comparable.",
                systemImage: "chart.line.uptrend.xyaxis"
            ))
        }

        if score.marketplaceEligibilityImpact >= 40 {
            let marketplaceName = context.preferredMarketplace?.displayName ?? "marketplace"
            append(QuestionImpactRow(
                title: "Marketplace fit",
                detail: String.localizedFormat("This helps the %@ post use the right details.".localized, marketplaceName),
                systemImage: "checklist"
            ))
        }

        if score.buyerTrustImpact >= 34 {
            append(QuestionImpactRow(
                title: "Buyer trust",
                detail: "This keeps the post honest and avoids guessing.",
                systemImage: "checkmark.shield.fill"
            ))
        }

        if rows.isEmpty {
            append(QuestionImpactRow(
                title: "Next clue",
                detail: "One easy answer helps BuySell keep checking.",
                systemImage: "sparkles"
            ))
        }

        return Array(rows.prefix(2))
    }

    private static func compactQuestionImpactText(
        for question: DetailQuestion,
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> String {
        let score = adaptiveQuestionScore(for: question, context: context, answers: answers)
        if score.identityInformationGain >= 50 || score.likelyMatchDisambiguation >= 30 {
            return "Narrows what BuySell searches next."
        }
        if score.valuableVariantDetection >= 30 {
            return "Checks if this is a version worth more."
        }
        if score.pricingImpact >= 38 {
            return "Helps compare the right sold prices."
        }
        if score.marketplaceEligibilityImpact >= 40 {
            if let marketplace = context.preferredMarketplace {
                return String.localizedFormat("Helps the %@ post use the right fields.".localized, marketplace.displayName)
            }
            return "Helps choose the right marketplace."
        }
        if score.buyerTrustImpact >= 34 {
            return "Keeps the listing honest without guessing."
        }
        return "One clue is enough. Skip if you do not know."
    }

    private static func aiUnknownFollowUp(
        for question: AnalyzeValueQuestion,
        field: Field,
        item: DetectedItem
    ) -> DetailQuestionFallback? {
        guard let title = question.unknownFollowUpQuestion else { return nil }
        let serverChoices = question.unknownFollowUpChoices.map {
            DetailChoice(title: $0, value: .text($0), localizesTitle: false)
        }
        let scanRequest = unknownFallbackScanRequest(for: field, category: item.category, marketplace: nil)
        let fallbackChoices = unknownFallbackChoices(
            for: field,
            category: item.category,
            itemName: item.name,
            clueText: "\(question.question) \(question.reason) \(title)",
            marketplace: nil
        )
        return DetailQuestionFallback(
            id: "analysis-value-help-\(question.answerField.rawValue)-\(title)",
            contextLabel: "Look closer",
            title: title,
            detail: "Pick the closest thing you can see. If none fits, skip it.",
            placeholder: placeholder(for: question.answerField),
            systemImage: symbol(for: question.answerField),
            kind: .text(field),
            choices: serverChoices.isEmpty
                ? choicesWithOptionalScan(fallbackChoices, scanRequest: scanRequest)
                : choicesWithOptionalScan(serverChoices, scanRequest: scanRequest)
        )
    }

    private static func choicesWithUnknown(_ choices: [DetailChoice]) -> [DetailChoice] {
        let uniqueChoices = choices.reduce(into: [DetailChoice]()) { result, choice in
            guard result.contains(where: {
                $0.displayTitle.localizedCaseInsensitiveCompare(choice.displayTitle) == .orderedSame
            }) == false else { return }
            result.append(choice)
        }

        if uniqueChoices.contains(where: \.isUnknown) {
            return Array(uniqueChoices.prefix(4))
        }
        return Array(uniqueChoices.prefix(3)) + [DetailChoice(title: "I don't know", value: .unknown)]
    }

    private static func questionLimit(for context: ItemQuestionsContext) -> Int {
        if context.preferredMarketplace != nil {
            return 4
        }
        if shouldAskMoreIdentificationHelp(for: context) || isHighDetailCategory(context.item.category) {
            return 5
        }
        return 4
    }

    private static func adaptiveTargetedScanRequest(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers,
        currentQuestion: DetailQuestion?
    ) -> TargetedScanRequest? {
        let photos = context.supplementalPhotos
        if let currentQuestion,
           let request = targetedScanRequest(for: currentQuestion, context: context),
           scanWouldAddNewEvidence(request, photos: photos) {
            return request
        }
        if let request = context.analysis?.targetedScanRequest,
           scanWouldAddNewEvidence(request, photos: photos) {
            return request
        }
        return highValueIdentityScanRequest(context: context, answers: answers, photos: photos)
    }

    private static func targetedScanRequest(
        for question: DetailQuestion,
        context: ItemQuestionsContext
    ) -> TargetedScanRequest? {
        if question.id == "analysis-likely-match" {
            return unknownFallbackScanRequest(
                for: .sizeOrModel,
                category: context.item.category,
                marketplace: context.preferredMarketplace
            )
        }
        if question.id.contains("identity-clue") || question.id.contains("valuable-version") {
            return valuableVersionScanRequest(for: context.item.category)
                ?? unknownFallbackScanRequest(
                    for: .extraDetails,
                    category: context.item.category,
                    marketplace: context.preferredMarketplace
                )
        }
        guard question.id.contains("analysis-") ||
            question.id.contains("marketplace-evidence") ||
            question.id.contains("marketplace-playbook")
        else { return nil }

        guard case .text(let field) = question.kind else { return nil }
        return unknownFallbackScanRequest(
            for: field,
            category: context.item.category,
            marketplace: context.preferredMarketplace
        )
    }

    private static func highValueIdentityScanRequest(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers,
        photos: [ItemPhotoAsset]
    ) -> TargetedScanRequest? {
        let likelyMatches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        if likelyMatches.count > 1,
           answers.hasAnsweredOrSkipped(.sizeOrModel) == false,
           let request = unknownFallbackScanRequest(
            for: .sizeOrModel,
            category: context.item.category,
            marketplace: context.preferredMarketplace
           ),
           scanWouldAddNewEvidence(request, photos: photos) {
            return request
        }

        if let missingFact = context.analysis?.highestImpactMissingFact,
           answers.hasAnsweredOrSkipped(detailFieldKey(for: missingFact.detailKind)) == false,
           let request = targetedScanRequest(for: missingFact, context: context),
           scanWouldAddNewEvidence(request, photos: photos) {
            return request
        }

        if shouldAskMoreIdentificationHelp(for: context),
           answers.hasAnsweredOrSkipped(.extraDetails) == false,
           let request = valuableVersionScanRequest(for: context.item.category),
           scanWouldAddNewEvidence(request, photos: photos) {
            return request
        }
        return nil
    }

    private static func targetedScanRequest(
        for missingFact: PrioritizedMissingFact,
        context: ItemQuestionsContext
    ) -> TargetedScanRequest? {
        switch missingFact.detailKind {
        case .brand:
            return unknownFallbackScanRequest(
                for: .labelOrBrand,
                category: context.item.category,
                marketplace: context.preferredMarketplace
            )
        case .spec:
            return unknownFallbackScanRequest(
                for: .sizeOrModel,
                category: context.item.category,
                marketplace: context.preferredMarketplace
            )
        case .included:
            return unknownFallbackScanRequest(
                for: .included,
                category: context.item.category,
                marketplace: context.preferredMarketplace
            )
        case .condition:
            return unknownFallbackScanRequest(
                for: .flaws,
                category: context.item.category,
                marketplace: context.preferredMarketplace
            )
        case .shipping:
            return TargetedScanRequest(
                prompt: "Show the whole item.",
                benefit: "This helps decide whether local pickup beats shipping.",
                role: .fullItem
            )
        }
    }

    private static func scanWouldAddNewEvidence(
        _ request: TargetedScanRequest,
        photos: [ItemPhotoAsset]
    ) -> Bool {
        let role = ItemPhotoRole(scanRole: request.role)
        return photos.contains { $0.role == role && $0.canExportToListing } == false
    }

    private static func valuableVersionQuestion(
        for context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard answers.hasAnsweredOrSkipped(.extraDetails) == false else { return nil }
        guard shouldAskValuableVersionQuestion(for: context) else { return nil }
        let prompt = valuableVersionPrompt(for: context.item.category)
        return DetailQuestion(
            id: "valuable-version-\(context.item.category.rawValue)",
            contextLabel: "Worth check",
            title: prompt.title,
            detail: prompt.detail,
            placeholder: prompt.placeholder,
            systemImage: prompt.systemImage,
            kind: .text(.extraDetails),
            choices: choicesWithOptionalScan(
                prompt.choices,
                scanRequest: valuableVersionScanRequest(for: context.item.category)
            ),
            unknownFollowUp: DetailQuestionFallback(
                id: "valuable-version-help-\(context.item.category.rawValue)",
                contextLabel: "Look closer",
                title: prompt.followUpTitle,
                detail: "Pick the closest clue you can see. Skip if nothing fits.",
                placeholder: prompt.placeholder,
                systemImage: prompt.systemImage,
                kind: .text(.extraDetails),
                choices: choicesWithOptionalScan(
                    prompt.followUpChoices,
                    scanRequest: valuableVersionScanRequest(for: context.item.category)
                )
            )
        )
    }

    private static func shouldAskValuableVersionQuestion(for context: ItemQuestionsContext) -> Bool {
        if isHighDetailCategory(context.item.category) {
            return true
        }
        if shouldAskMoreIdentificationHelp(for: context) {
            return true
        }
        return context.analysis?.missingFacts.containsFact(namedLike: [
            "rare", "limited", "edition", "signed", "signature", "numbered",
            "vintage", "antique", "year", "maker", "mark", "stamp", "hallmark",
            "material", "serial", "certificate", "authentic"
        ]) ?? false
    }

    private static func valuableVersionPrompt(for category: Category) -> ValuableVersionPrompt {
        switch category {
        case .collectibles, .toys, .media, .books:
            return ValuableVersionPrompt(
                title: "Could it be a special version?",
                detail: "Editions, years, sealed boxes, signatures, and numbers can change the sold-price search.",
                placeholder: "First edition, numbered, sealed, signed...",
                systemImage: "sparkle.magnifyingglass",
                choices: [
                    DetailChoice(title: "Sealed", value: .text("Sealed")),
                    DetailChoice(title: "Signed or numbered", value: .text("Signed or numbered")),
                    DetailChoice(title: "Year shown", value: .text("Year visible"))
                ],
                followUpTitle: "Check the package corners, back, or certificate",
                followUpChoices: [
                    DetailChoice(title: "Edition shown", value: .text("Edition visible")),
                    DetailChoice(title: "Certificate", value: .text("Certificate included")),
                    DetailChoice(title: "No special mark", value: .text("No special mark visible"))
                ]
            )
        case .jewelry:
            return ValuableVersionPrompt(
                title: "Do you see a metal stamp or hallmark?",
                detail: "Sterling, gold marks, maker stamps, and certificates can separate costume from valuable.",
                placeholder: "925, 14K, maker mark, certificate...",
                systemImage: "seal.fill",
                choices: [
                    DetailChoice(title: "925 or sterling", value: .text("925 or sterling mark visible")),
                    DetailChoice(title: "Gold mark", value: .text("Gold mark visible")),
                    DetailChoice(title: "Certificate", value: .text("Certificate included"))
                ],
                followUpTitle: "Check the clasp, inside band, or back",
                followUpChoices: [
                    DetailChoice(title: "Metal stamp", value: .text("Metal stamp visible")),
                    DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                    DetailChoice(title: "No stamp", value: .text("No stamp visible"))
                ]
            )
        case .art, .home, .furniture:
            return ValuableVersionPrompt(
                title: "Any signature, maker mark, or age clue?",
                detail: "Marks, materials, signatures, and older construction can change where this should sell.",
                placeholder: "Signature, maker mark, brass, walnut...",
                systemImage: "signature",
                choices: [
                    DetailChoice(title: "Signed", value: .text("Signature visible")),
                    DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                    DetailChoice(title: "Older style", value: .text("Looks older or vintage"))
                ],
                followUpTitle: "Check the back, bottom, underside, or frame",
                followUpChoices: [
                    DetailChoice(title: "Underneath mark", value: .text("Underneath maker mark visible")),
                    DetailChoice(title: "Material clue", value: .text("Material clue visible")),
                    DetailChoice(title: "No mark", value: .text("No visible mark"))
                ]
            )
        case .electronics, .tools, .music:
            return ValuableVersionPrompt(
                title: "Can you find the exact model or serial?",
                detail: "Small model differences can change sold comps, parts value, and buyer trust.",
                placeholder: "Model, serial, storage, tested...",
                systemImage: specQuestionSymbol(for: category),
                choices: [
                    DetailChoice(title: "Model plate", value: .text("Model plate visible")),
                    DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                    DetailChoice(title: "Powers on", value: .text("Powers on"))
                ],
                followUpTitle: "Check the back, bottom, battery area, or settings",
                followUpChoices: [
                    DetailChoice(title: "Back label", value: .text("Back label visible")),
                    DetailChoice(title: "Settings screen", value: .text("Settings screen visible")),
                    DetailChoice(title: "No label", value: .text("No visible label"))
                ]
            )
        case .clothing, .shoes, .bags, .kids:
            return ValuableVersionPrompt(
                title: "Any size, material, or style code?",
                detail: "Tags, style codes, materials, and box labels help find closer sold matches.",
                placeholder: "Size, material, style code, box label...",
                systemImage: AppSymbol.Action.category,
                choices: [
                    DetailChoice(title: "Size tag", value: .text("Size tag visible")),
                    DetailChoice(title: "Style code", value: .text("Style code visible")),
                    DetailChoice(title: "Material tag", value: .text("Material tag visible"))
                ],
                followUpTitle: "Check the inside tag, sole, pocket, or box label",
                followUpChoices: [
                    DetailChoice(title: "Inside tag", value: .text("Inside tag visible")),
                    DetailChoice(title: "Box label", value: .text("Box label visible")),
                    DetailChoice(title: "No tag", value: .text("No visible tag"))
                ]
            )
        default:
            return ValuableVersionPrompt(
                title: "Any clue that could make it worth more?",
                detail: "A stamp, label, number, material, age clue, or special mark can improve the search.",
                placeholder: "Stamp, label, number, material...",
                systemImage: "sparkle.magnifyingglass",
                choices: [
                    DetailChoice(title: "Tag or sticker", value: .text("Tag or sticker visible")),
                    DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                    DetailChoice(title: "Material clue", value: .text("Material clue visible"))
                ],
                followUpTitle: "Check the bottom, back, tag, or sticker",
                followUpChoices: [
                    DetailChoice(title: "Number shown", value: .text("Number visible")),
                    DetailChoice(title: "Special mark", value: .text("Special mark visible")),
                    DetailChoice(title: "No clue", value: .text("No exact clue visible"))
                ]
            )
        }
    }

    private static func valuableVersionScanRequest(for category: Category) -> TargetedScanRequest? {
        switch category {
        case .collectibles, .toys, .media, .books:
            return TargetedScanRequest(
                prompt: "Scan the edition, number, or certificate.",
                benefit: "This helps us find closer sold listings.",
                role: .authenticity
            )
        case .jewelry:
            return TargetedScanRequest(
                prompt: "Scan the hallmark or metal stamp.",
                benefit: "This can confirm the material or maker.",
                role: .authenticity
            )
        case .art, .home, .furniture:
            return TargetedScanRequest(
                prompt: "Scan the signature or maker mark.",
                benefit: "This may improve your price estimate.",
                role: .label
            )
        case .electronics, .tools, .music:
            return TargetedScanRequest(
                prompt: "Scan the model or serial plate.",
                benefit: "This can confirm the exact model.",
                role: .serial
            )
        case .clothing, .shoes, .bags, .kids:
            return TargetedScanRequest(
                prompt: "Scan the tag or box label.",
                benefit: "This helps us match closer sold listings.",
                role: .sizeTag
            )
        default:
            return TargetedScanRequest(
                prompt: "Scan the best visible clue.",
                benefit: "This may improve your price estimate.",
                role: .label
            )
        }
    }

    private static func identityClueQuestion(
        for context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard answers.hasAnsweredOrSkipped(.extraDetails) == false,
              shouldAskIdentityClue(for: context)
        else { return nil }

        return DetailQuestion(
            id: "identity-clue",
            contextLabel: "Figure it out",
            title: identityClueTitle(for: context.item.category),
            detail: identityClueDetail(for: context.item.category, itemName: context.item.name),
            placeholder: identityCluePlaceholder(for: context.item.category),
            systemImage: identityClueSymbol(for: context.item.category),
            kind: .text(.extraDetails),
            choices: identityClueChoices(for: context.item.category),
            unknownFollowUp: DetailQuestionFallback(
                id: "identity-clue-visible-help",
                contextLabel: "Look closer",
                title: identityClueFollowUpTitle(for: context.item.category),
                detail: "Pick the closest visible clue. Skip if nothing stands out.",
                placeholder: identityCluePlaceholder(for: context.item.category),
                systemImage: identityClueSymbol(for: context.item.category),
                kind: .text(.extraDetails),
                choices: identityClueFollowUpChoices(for: context.item.category)
            )
        )
    }

    private static func shouldAskIdentityClue(for context: ItemQuestionsContext) -> Bool {
        guard shouldAskMoreIdentificationHelp(for: context) else { return false }
        let matches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        return matches.isEmpty
    }

    private static func shouldAskMoreIdentificationHelp(for context: ItemQuestionsContext) -> Bool {
        if context.item.category == .other {
            return true
        }
        if isVagueItemName(context.item.name) {
            return true
        }
        let confidentFacts = context.analysis?.itemFacts.filter { $0.confidence >= 0.7 } ?? []
        let hasMissingIdentityFacts = context.analysis?.missingFacts.containsFact(namedLike: [
            "brand", "maker", "model", "serial", "edition", "label", "mark", "material", "size"
        ]) ?? false
        return confidentFacts.count < 2 && hasMissingIdentityFacts
    }

    private static func isVagueItemName(_ name: String) -> Bool {
        let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lowerName.isEmpty == false else { return true }
        return [
            "unknown",
            "unidentified",
            "item",
            "object",
            "thing",
            "misc",
            "assorted"
        ].contains { lowerName.contains($0) }
    }

    private static func isHighDetailCategory(_ category: Category) -> Bool {
        [.electronics, .shoes, .bags, .jewelry, .music, .collectibles, .art].contains(category)
    }

    private static func identityClueTitle(for category: Category) -> String {
        switch category {
        case .electronics:
            return "What clue can you see on the device?"
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "What does the tag or label show?"
        case .furniture, .home, .art:
            return "What is it made of or marked with?"
        case .collectibles, .toys, .media:
            return "Any edition, number, or package clue?"
        case .music:
            return "Any model, serial, or brand mark?"
        default:
            return "What visible clue should we search?"
        }
    }

    private static func identityClueDetail(for category: Category, itemName: String) -> String {
        if isVagueItemName(itemName) || category == .other {
            return "A label, stamp, material, number, or shape helps BuySell figure out what this is."
        }
        return "One visible clue can separate ordinary items from valuable versions."
    }

    private static func identityCluePlaceholder(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Model label, serial, storage, carrier..."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Size tag, material, style code..."
        case .furniture, .home, .art:
            return "Wood, brass, maker mark, signature..."
        case .collectibles, .toys, .media:
            return "Edition, set number, sealed, year..."
        case .music:
            return "Model, serial, brand, year..."
        default:
            return "Label, stamp, material, number..."
        }
    }

    private static func identityClueSymbol(for category: Category) -> String {
        switch category {
        case .electronics:
            return AppSymbol.Item.electronics
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return AppSymbol.Action.category
        case .furniture, .home, .art:
            return "ruler"
        case .collectibles, .toys, .media:
            return "number.circle.fill"
        case .music:
            return AppSymbol.Item.music
        default:
            return "sparkle.magnifyingglass"
        }
    }

    private static func identityClueChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics:
            return choicesWithUnknown([
                DetailChoice(title: "Model label", value: .text("Model label visible")),
                DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                DetailChoice(title: "Turns on", value: .text("Turns on"))
            ])
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return choicesWithUnknown([
                DetailChoice(title: "Size tag", value: .text("Size tag visible")),
                DetailChoice(title: "Material tag", value: .text("Material tag visible")),
                DetailChoice(title: "Style code", value: .text("Style code visible"))
            ])
        case .furniture, .home, .art:
            return choicesWithUnknown([
                DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                DetailChoice(title: "Can measure it", value: .text("Measurements available")),
                DetailChoice(title: "Material clue", value: .text("Material clue visible"))
            ])
        case .collectibles, .toys, .media:
            return choicesWithUnknown([
                DetailChoice(title: "Edition number", value: .text("Edition or number visible")),
                DetailChoice(title: "Sealed package", value: .text("Sealed package")),
                DetailChoice(title: "Year shown", value: .text("Year visible"))
            ])
        case .music:
            return choicesWithUnknown([
                DetailChoice(title: "Model name", value: .text("Model name visible")),
                DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                DetailChoice(title: "Works", value: .text("Works"))
            ])
        default:
            return choicesWithUnknown([
                DetailChoice(title: "Tag or sticker", value: .text("Tag or sticker visible")),
                DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                DetailChoice(title: "Nothing obvious", value: .text("No exact clue visible"))
            ])
        }
    }

    private static func identityClueFollowUpTitle(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Check the back, bottom, or settings screen"
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Check the inside tag or box label"
        case .furniture, .home, .art:
            return "Check underneath, the back, or a signature"
        case .collectibles, .toys, .media:
            return "Check the corner, bottom, or package back"
        case .music:
            return "Check the back plate, headstock, or label"
        default:
            return "Check the bottom, back, tag, or sticker"
        }
    }

    private static func identityClueFollowUpChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics:
            return choicesWithUnknown([
                DetailChoice(title: "Back label", value: .text("Back label visible")),
                DetailChoice(title: "Settings screen", value: .text("Settings screen visible")),
                DetailChoice(title: "No label", value: .text("No visible label"))
            ])
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return choicesWithUnknown([
                DetailChoice(title: "Inside tag", value: .text("Inside tag visible")),
                DetailChoice(title: "Box label", value: .text("Box label visible")),
                DetailChoice(title: "No tag", value: .text("No visible tag"))
            ])
        case .furniture, .home, .art:
            return choicesWithUnknown([
                DetailChoice(title: "Underneath mark", value: .text("Underneath maker mark visible")),
                DetailChoice(title: "Signature", value: .text("Signature visible")),
                DetailChoice(title: "No mark", value: .text("No visible mark"))
            ])
        default:
            return identityClueChoices(for: category)
        }
    }

    private static func defaultUnknownFollowUp(
        after question: DetailQuestion,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> DetailQuestion? {
        guard case .text(let field) = question.kind else { return nil }
        let fallback = DetailQuestionFallback(
            id: "\(question.id)-unknown-help",
            contextLabel: "Look closer",
            title: fallbackTitle(for: field, category: item.category, marketplace: marketplace),
            detail: fallbackDetail(for: field, category: item.category, marketplace: marketplace),
            placeholder: fallbackPlaceholder(for: field, category: item.category, marketplace: marketplace),
            systemImage: fallbackSymbol(for: field, category: item.category, marketplace: marketplace),
            kind: .text(field),
            choices: unknownFallbackChoices(
                for: field,
                category: item.category,
                itemName: item.name,
                clueText: "\(question.title) \(question.detail) \(question.placeholder)",
                marketplace: marketplace
            )
        )
        return fallback.makeQuestion()
    }

    private static func unknownFallbackChoices(
        for field: Field,
        category: Category,
        itemName: String,
        clueText: String,
        marketplace: Marketplace?
    ) -> [DetailChoice] {
        let fallbackChoices = itemSpecificFallbackChoices(
            for: field,
            category: category,
            itemName: itemName,
            clueText: clueText,
            marketplace: marketplace
        ) + fallbackChoices(for: field, category: category, marketplace: marketplace)
        return choicesWithOptionalScan(
            fallbackChoices,
            scanRequest: unknownFallbackScanRequest(for: field, category: category, marketplace: marketplace)
        )
    }

    private static func itemSpecificFallbackChoices(
        for field: Field,
        category: Category,
        itemName: String,
        clueText: String,
        marketplace: Marketplace?
    ) -> [DetailChoice] {
        let lowerName = "\(itemName) \(clueText)".lowercased()
        switch field {
        case .labelOrBrand:
            if lowerName.contains("signature") || lowerName.contains("signed") || lowerName.contains("artist") {
                return [
                    DetailChoice(title: "Signature", value: .text("Signature visible")),
                    DetailChoice(title: "Artist mark", value: .text("Artist or maker mark visible"))
                ]
            }
            if lowerName.contains("hallmark") || lowerName.contains("sterling") || lowerName.contains("gold") || lowerName.contains("silver") {
                return [
                    DetailChoice(title: "Hallmark", value: .text("Hallmark visible")),
                    DetailChoice(title: "Metal stamp", value: .text("Metal stamp visible"))
                ]
            }
            if lowerName.contains("tool") || lowerName.contains("drill") || lowerName.contains("saw") || lowerName.contains("battery") {
                return [
                    DetailChoice(title: "Brand plate", value: .text("Brand plate visible")),
                    DetailChoice(title: "Battery label", value: .text("Battery label visible"))
                ]
            }
            if lowerName.contains("lamp") || lowerName.contains("chair") || lowerName.contains("table") {
                return [
                    DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                    DetailChoice(title: "Signature", value: .text("Signature visible"))
                ]
            }
            if lowerName.contains("bag") || lowerName.contains("purse") || lowerName.contains("wallet") {
                return [
                    DetailChoice(title: "Logo stamp", value: .text("Logo stamp visible")),
                    DetailChoice(title: "Inside label", value: .text("Inside label visible"))
                ]
            }
            return []
        case .sizeOrModel:
            if lowerName.contains("serial") {
                return [
                    DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                    DetailChoice(title: "Model plate", value: .text("Model plate visible"))
                ]
            }
            if lowerName.contains("barcode") || lowerName.contains("upc") {
                return [
                    DetailChoice(title: "Barcode", value: .text("Barcode visible")),
                    DetailChoice(title: "UPC number", value: .text("UPC number visible"))
                ]
            }
            if lowerName.contains("camera") || lowerName.contains("lens") {
                return [
                    DetailChoice(title: "Lens model", value: .text("Lens model visible")),
                    DetailChoice(title: "Body model", value: .text("Camera body model visible")),
                    DetailChoice(title: "Serial number", value: .text("Serial number visible"))
                ]
            }
            if lowerName.contains("watch") {
                return [
                    DetailChoice(title: "Case size", value: .text("Case size visible")),
                    DetailChoice(title: "Model number", value: .text("Model number visible")),
                    DetailChoice(title: "Band included", value: .text("Band included"))
                ]
            }
            if lowerName.contains("switch") {
                return [
                    DetailChoice(title: "OLED label", value: .text("OLED label visible")),
                    DetailChoice(title: "HAC-001", value: .text("HAC-001 model visible")),
                    DetailChoice(title: "Joy-Cons included", value: .text("Joy-Cons included"))
                ]
            }
            if lowerName.contains("iphone") || lowerName.contains("ipad") || lowerName.contains("macbook") {
                return [
                    DetailChoice(title: "Storage shown", value: .text("Storage shown")),
                    DetailChoice(title: "Model number", value: .text("Model number visible")),
                    DetailChoice(title: "Turns on", value: .text("Turns on"))
                ]
            }
            if lowerName.contains("shoe") || lowerName.contains("sneaker") || lowerName.contains("boot") {
                return [
                    DetailChoice(title: "Size tag", value: .text("Size tag visible")),
                    DetailChoice(title: "Style code", value: .text("Style code visible")),
                    DetailChoice(title: "Box label", value: .text("Box label visible"))
                ]
            }
            if lowerName.contains("card") || lowerName.contains("pokemon") || lowerName.contains("magic") {
                return [
                    DetailChoice(title: "Card number", value: .text("Card number visible")),
                    DetailChoice(title: "Holographic", value: .text("Holographic card")),
                    DetailChoice(title: "Graded slab", value: .text("Graded slab"))
                ]
            }
            if lowerName.contains("book") || lowerName.contains("comic") || lowerName.contains("record") {
                return [
                    DetailChoice(title: "First edition", value: .text("First edition visible")),
                    DetailChoice(title: "Year shown", value: .text("Year visible")),
                    DetailChoice(title: "Signed", value: .text("Signed"))
                ]
            }
            if lowerName.contains("lego") || lowerName.contains("set") {
                return [
                    DetailChoice(title: "Set number", value: .text("Set number visible")),
                    DetailChoice(title: "Sealed box", value: .text("Sealed box")),
                    DetailChoice(title: "Pieces included", value: .text("Pieces appear included"))
                ]
            }
            return []
        case .flaws:
            if [.electronics, .tools, .music].contains(category) {
                return [
                    DetailChoice(title: "Powers on", value: .text("Powers on")),
                    DetailChoice(title: "Screen damage", value: .text("Screen damage")),
                    DetailChoice(title: "Needs repair", value: .text("Needs repair"))
                ]
            }
            return []
        case .included:
            if lowerName.contains("tool") || lowerName.contains("drill") || lowerName.contains("saw") || lowerName.contains("battery") {
                return [
                    DetailChoice(title: "Battery", value: .text("Battery included")),
                    DetailChoice(title: "Charger", value: .text("Charger included")),
                    DetailChoice(title: "Case", value: .text("Case included"))
                ]
            }
            if lowerName.contains("switch") || lowerName.contains("iphone") || lowerName.contains("ipad") || lowerName.contains("camera") {
                return [
                    DetailChoice(title: "Original box", value: .text("Original box included")),
                    DetailChoice(title: "Charger", value: .text("Charger included")),
                    DetailChoice(title: "Case", value: .text("Case included"))
                ]
            }
            if lowerName.contains("shoe") || lowerName.contains("sneaker") || lowerName.contains("boot") {
                return [
                    DetailChoice(title: "Original box", value: .text("Original shoe box included")),
                    DetailChoice(title: "Extra laces", value: .text("Extra laces included"))
                ]
            }
            return []
        case .extraDetails:
            if lowerName.contains("edition") || lowerName.contains("numbered") || lowerName.contains("limited") {
                return [
                    DetailChoice(title: "Limited edition", value: .text("Limited edition")),
                    DetailChoice(title: "Numbered", value: .text("Numbered edition")),
                    DetailChoice(title: "Certificate", value: .text("Certificate included"))
                ]
            }
            if lowerName.contains("vintage") || lowerName.contains("antique") || lowerName.contains("year") {
                return [
                    DetailChoice(title: "Year shown", value: .text("Year visible")),
                    DetailChoice(title: "Looks older", value: .text("Looks older or vintage")),
                    DetailChoice(title: "Maker mark", value: .text("Maker mark visible"))
                ]
            }
            if [.collectibles, .toys, .media, .books].contains(category) {
                return [
                    DetailChoice(title: "Sealed", value: .text("Sealed")),
                    DetailChoice(title: "Limited edition", value: .text("Limited edition")),
                    DetailChoice(title: "Certificate", value: .text("Certificate included"))
                ]
            }
            if [.jewelry, .art, .home, .furniture].contains(category) {
                return [
                    DetailChoice(title: "Feels heavy", value: .text("Feels heavy")),
                    DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                    DetailChoice(title: "Older style", value: .text("Looks older or vintage"))
                ]
            }
            return []
        case .marketplaceNote(let selectedMarketplace):
            let resolvedMarketplace = marketplace ?? selectedMarketplace
            if [.stockx, .goat].contains(resolvedMarketplace) {
                return [
                    DetailChoice(title: "SKU visible", value: .text("SKU visible")),
                    DetailChoice(title: "Box label", value: .text("Box label visible")),
                    DetailChoice(title: "Box damaged", value: .text("Box damaged"))
                ]
            }
            return []
        }
    }

    private static func choicesWithOptionalScan(_ choices: [DetailChoice], scanRequest: TargetedScanRequest?) -> [DetailChoice] {
        let normalizedChoices = choicesWithUnknown(choices)
        guard let scanRequest else {
            return normalizedChoices
        }

        let concreteChoices = normalizedChoices.filter {
            $0.isUnknown == false && $0.isTargetedScan == false
        }
        let clueAwareChoices = concreteChoices.map { choice in
            choice.scanningVisibleClue(with: scanRequest)
        }
        return [DetailChoice(title: "Scan it", value: .targetedScan(scanRequest))]
            + Array(clueAwareChoices.prefix(2))
            + [DetailChoice(title: "I don't know", value: .unknown)]
    }

    private static func unknownFallbackScanRequest(for field: Field, category: Category, marketplace: Marketplace?) -> TargetedScanRequest? {
        switch field {
        case .labelOrBrand:
            return TargetedScanRequest(
                prompt: labelScanPrompt(for: category),
                benefit: "This can identify the maker, brand, or exact version.",
                role: labelScanRole(for: category)
            )
        case .sizeOrModel:
            return TargetedScanRequest(
                prompt: specScanPrompt(for: category),
                benefit: "This helps us match closer sold listings.",
                role: specScanRole(for: category)
            )
        case .flaws:
            return TargetedScanRequest(
                prompt: "Show the damaged area.",
                benefit: "Buyers will want to see this.",
                role: .condition
            )
        case .included:
            return TargetedScanRequest(
                prompt: "Show everything included.",
                benefit: "Included parts can change the price.",
                role: .accessories
            )
        case .extraDetails:
            return TargetedScanRequest(
                prompt: extraDetailScanPrompt(for: category),
                benefit: "This may reveal a special version.",
                role: extraDetailScanRole(for: category)
            )
        case .marketplaceNote(let selectedMarketplace):
            return marketplaceScanRequest(for: marketplace ?? selectedMarketplace, category: category)
        }
    }

    private static func labelScanPrompt(for category: Category) -> String {
        switch category {
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Scan the tag or logo."
        case .furniture, .home, .art:
            return "Scan the maker mark."
        case .collectibles, .toys, .media:
            return "Scan the edition or mark."
        case .music:
            return "Scan the brand or serial plate."
        default:
            return "Scan the label or logo."
        }
    }

    private static func labelScanRole(for category: Category) -> TargetedScanPhotoRole {
        switch category {
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return .sizeTag
        case .collectibles, .toys, .media, .music:
            return .authenticity
        default:
            return .label
        }
    }

    private static func specScanPrompt(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Scan the model label."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Scan the size tag."
        case .furniture, .home, .art:
            return "Show the item next to a ruler."
        case .collectibles, .toys, .media:
            return "Scan the edition number."
        case .music:
            return "Scan the model or serial plate."
        default:
            return "Scan the exact detail."
        }
    }

    private static func specScanRole(for category: Category) -> TargetedScanPhotoRole {
        switch category {
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return .sizeTag
        case .electronics, .music:
            return .serial
        default:
            return .label
        }
    }

    private static func extraDetailScanPrompt(for category: Category) -> String {
        switch category {
        case .collectibles, .toys, .media:
            return "Scan the edition, number, or certificate."
        case .jewelry:
            return "Scan the hallmark or authenticity mark."
        case .furniture, .home, .art:
            return "Scan the signature or mark."
        default:
            return "Scan the special mark."
        }
    }

    private static func extraDetailScanRole(for category: Category) -> TargetedScanPhotoRole {
        switch category {
        case .collectibles, .toys, .media, .jewelry, .art:
            return .authenticity
        default:
            return .label
        }
    }

    private static func marketplaceScanRequest(for marketplace: Marketplace, category: Category) -> TargetedScanRequest? {
        if localMarketplaces.contains(marketplace), [.furniture, .home, .tools, .sports].contains(category) {
            return TargetedScanRequest(
                prompt: "Show the full item.",
                benefit: "Local buyers need to see size and condition clearly.",
                role: .fullItem
            )
        }
        if [.poshmark, .depop, .vinted, .curtsy].contains(marketplace) {
            return TargetedScanRequest(
                prompt: "Scan the size tag.",
                benefit: "This helps the listing fit the marketplace.",
                role: .sizeTag
            )
        }
        if [.stockx, .goat, .swappa, .tcgplayer].contains(marketplace) {
            return TargetedScanRequest(
                prompt: "Scan the model or authenticity label.",
                benefit: "This can confirm the exact version.",
                role: .authenticity
            )
        }
        return nil
    }

    private static func fallbackTitle(for field: Field, category: Category, marketplace: Marketplace?) -> String {
        switch field {
        case .labelOrBrand:
            return "Can you find a tag, stamp, or logo?"
        case .sizeOrModel:
            switch category {
            case .electronics:
                return "Can you find a model, storage, or serial?"
            case .clothing, .shoes, .bags, .jewelry, .kids:
                return "Can you find a size or material tag?"
            case .furniture, .home, .art:
                return "Can you measure it or find a maker mark?"
            case .collectibles:
                return "Can you find an edition, number, or mark?"
            case .music:
                return "Can you find a model, year, or serial?"
            default:
                return "Can you find one exact detail?"
            }
        case .flaws:
            return "Look at the worst spot. What do you see?"
        case .included:
            return "Is there a box, charger, case, or paperwork?"
        case .extraDetails:
            return "Anything visible that might make it special?"
        case .marketplaceNote(let selectedMarketplace):
            return marketplaceFallbackTitle(for: marketplace ?? selectedMarketplace, category: category)
        }
    }

    private static func fallbackDetail(for field: Field, category: Category, marketplace: Marketplace?) -> String {
        switch field {
        case .labelOrBrand:
            return "Check the bottom, back, inside tag, sticker, or signature. Type it if you can read it."
        case .sizeOrModel:
            return "A single exact number, size, year, edition, or serial clue helps BuySell search closer sold items."
        case .flaws:
            return "Buyers trust the listing more when the biggest flaw is clear."
        case .included:
            return "Included parts can change the price and which marketplace fits best."
        case .extraDetails:
            return "Only add something you can see, measure, or confidently know."
        case .marketplaceNote(let selectedMarketplace):
            return marketplaceFallbackDetail(for: marketplace ?? selectedMarketplace, category: category)
        }
    }

    private static func fallbackPlaceholder(for field: Field, category: Category, marketplace: Marketplace?) -> String {
        switch field {
        case .labelOrBrand:
            return brandPlaceholder(for: category)
        case .sizeOrModel:
            return sizePlaceholder(for: category)
        case .flaws:
            return "No flaws, light wear, broken part..."
        case .included:
            return includedPlaceholder(for: category)
        case .extraDetails:
            return extraDetailPlaceholder(for: category)
        case .marketplaceNote(let selectedMarketplace):
            let resolvedMarketplace = marketplace ?? selectedMarketplace
            return localMarketplaces.contains(resolvedMarketplace)
                ? localPlaceholder(for: category)
                : "Ships easily, needs padding, pickup, or note..."
        }
    }

    private static func fallbackSymbol(for field: Field, category: Category, marketplace: Marketplace?) -> String {
        switch field {
        case .labelOrBrand:
            return AppSymbol.Action.category
        case .sizeOrModel:
            return specQuestionSymbol(for: category)
        case .flaws:
            return AppSymbol.Condition.fair
        case .included:
            return AppSymbol.Marketplace.package
        case .extraDetails:
            return AppSymbol.Flow.answer
        case .marketplaceNote(let selectedMarketplace):
            return (marketplace ?? selectedMarketplace).iconSystemName
        }
    }

    private static func fallbackChoices(for field: Field, category: Category, marketplace: Marketplace?) -> [DetailChoice] {
        switch field {
        case .labelOrBrand:
            return [
                DetailChoice(title: "Tag or sticker", value: .text("Tag or sticker visible")),
                DetailChoice(title: "Stamped mark", value: .text("Stamped maker mark visible")),
                DetailChoice(title: "No label visible", value: .text("No visible label")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .sizeOrModel:
            return specFallbackChoices(for: category)
        case .flaws:
            return [
                DetailChoice(title: "No obvious damage", value: .text("No obvious damage")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "Broken or missing part", value: .text("Broken or missing part")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .included:
            return [
                DetailChoice(title: "Item only", value: .text("Item only")),
                DetailChoice(title: "Box or case", value: .text("Box or case included")),
                DetailChoice(title: "Charger or parts", value: .text("Charger or accessories included")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .extraDetails:
            return extraFallbackChoices(for: category)
        case .marketplaceNote(let selectedMarketplace):
            return marketplaceFallbackChoices(for: marketplace ?? selectedMarketplace, category: category)
        }
    }

    private static func specFallbackChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics:
            return [
                DetailChoice(title: "Model on label", value: .text("Model label visible")),
                DetailChoice(title: "Storage shown", value: .text("Storage shown")),
                DetailChoice(title: "Turns on", value: .text("Turns on")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return [
                DetailChoice(title: "Size tag visible", value: .text("Size tag visible")),
                DetailChoice(title: "Material tag visible", value: .text("Material tag visible")),
                DetailChoice(title: "No tag visible", value: .text("No visible size tag")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .furniture, .home, .art:
            return [
                DetailChoice(title: "Can measure it", value: .text("Measurements available")),
                DetailChoice(title: "Maker mark underneath", value: .text("Maker mark visible")),
                DetailChoice(title: "No mark visible", value: .text("No maker mark visible")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .collectibles:
            return [
                DetailChoice(title: "Edition visible", value: .text("Edition or number visible")),
                DetailChoice(title: "Sealed", value: .text("Sealed")),
                DetailChoice(title: "Signed or numbered", value: .text("Signed or numbered")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .music:
            return [
                DetailChoice(title: "Model visible", value: .text("Model visible")),
                DetailChoice(title: "Serial visible", value: .text("Serial number visible")),
                DetailChoice(title: "Works", value: .text("Works")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        default:
            return [
                DetailChoice(title: "Number or size", value: .text("Number or size visible")),
                DetailChoice(title: "Special mark", value: .text("Special mark visible")),
                DetailChoice(title: "Nothing visible", value: .text("No exact detail visible")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
    }

    private static func extraFallbackChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics, .tools, .music:
            return [
                DetailChoice(title: "Serial or model", value: .text("Serial or model visible")),
                DetailChoice(title: "Works", value: .text("Works")),
                DetailChoice(title: "Needs repair", value: .text("Needs repair")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .collectibles, .toys, .media, .books:
            return [
                DetailChoice(title: "From older era", value: .text("Looks older or vintage")),
                DetailChoice(title: "Special edition", value: .text("Special edition")),
                DetailChoice(title: "Signed or numbered", value: .text("Signed or numbered")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .jewelry, .art, .home, .furniture:
            return [
                DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                DetailChoice(title: "Feels heavy", value: .text("Feels heavy")),
                DetailChoice(title: "Material clue", value: .text("Material clue visible")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        default:
            return [
                DetailChoice(title: "Stamped mark", value: .text("Stamped mark visible")),
                DetailChoice(title: "Feels heavy", value: .text("Feels heavy")),
                DetailChoice(title: "Material clue", value: .text("Material clue visible")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
    }

    private static func marketplaceFallbackTitle(for marketplace: Marketplace, category: Category) -> String {
        if localMarketplaces.contains(marketplace) {
            return "Would pickup be easier than shipping?"
        }
        switch marketplace {
        case .ebay, .mercari, .bonanza:
            return "Can it ship safely?"
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy:
            return "Can you find the size or material?"
        case .etsy, .chairish, .rubylane:
            return "Can you find age, material, or a maker mark?"
        case .stockx, .goat:
            return "Can you find the SKU, size, or box label?"
        case .swappa:
            return "Can you check storage, carrier, or battery?"
        case .reverb:
            return "Can you find model, serial, or working status?"
        default:
            return "What would a buyer here need to know?"
        }
    }

    private static func marketplaceFallbackDetail(for marketplace: Marketplace, category: Category) -> String {
        if localMarketplaces.contains(marketplace) || [.furniture, .home, .art, .tools, .sports, .music].contains(category) {
            return "A pickup or loading note keeps messages simple."
        }
        switch marketplace {
        case .stockx, .goat, .swappa, .reverb:
            return "Exact specs reduce bad matches and buyer questions."
        default:
            return "One practical detail helps BuySell write a cleaner post."
        }
    }

    private static func marketplaceFallbackChoices(for marketplace: Marketplace, category: Category) -> [DetailChoice] {
        if localMarketplaces.contains(marketplace) || [.furniture, .home, .art, .tools, .sports, .music].contains(category) {
            return [
                DetailChoice(title: "Pickup only", value: .text("Pickup only")),
                DetailChoice(title: "Can help load", value: .text("Can help load")),
                DetailChoice(title: "Can deliver nearby", value: .text("Can deliver nearby")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
        return [
            DetailChoice(title: "Ships easily", value: .text("Ships easily")),
            DetailChoice(title: "Needs padding", value: .text("Needs careful packing")),
            DetailChoice(title: "Pickup is better", value: .text("Pickup preferred")),
            DetailChoice(title: "I don't know", value: .unknown)
        ]
    }

    private static func field(for answerField: AnalyzeValueQuestion.AnswerField) -> Field {
        switch answerField {
        case .brand:
            .labelOrBrand
        case .spec:
            .sizeOrModel
        case .condition:
            .flaws
        case .included:
            .included
        case .extra:
            .extraDetails
        }
    }

    private static func placeholder(for answerField: AnalyzeValueQuestion.AnswerField) -> String {
        switch answerField {
        case .brand:
            "Brand, maker, mark..."
        case .spec:
            "Model, year, edition, size..."
        case .condition:
            "Anything damaged or special..."
        case .included:
            "Box, charger, certificate..."
        case .extra:
            "Anything else that matters..."
        }
    }

    private static func symbol(for answerField: AnalyzeValueQuestion.AnswerField) -> String {
        switch answerField {
        case .brand:
            "tag"
        case .spec:
            AppSymbol.Action.search
        case .condition:
            AppSymbol.Condition.fair
        case .included:
            AppSymbol.Marketplace.package
        case .extra:
            "sparkle.magnifyingglass"
        }
    }

    private static func likelyMatchQuestion(for context: ItemQuestionsContext, answers: ItemDetailAnswers) -> DetailQuestion? {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false else { return nil }
        let matches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        guard shouldAskLikelyMatchQuestion(matches: matches, item: context.item) else { return nil }
        let choices = matches.prefix(3).map { match in
            DetailChoice(title: match.name, value: .text(match.name), localizesTitle: false)
        } + [
            DetailChoice(title: "I don't know", value: .unknown)
        ]

        return DetailQuestion(
            id: "analysis-likely-match",
            contextLabel: "Photo check",
            title: likelyMatchQuestionTitle(from: matches),
            detail: likelyMatchQuestionDetail(from: matches),
            placeholder: "Exact item name or model...",
            systemImage: AppSymbol.Action.search,
            kind: .text(.sizeOrModel),
            choices: choices,
            allowsReferenceExamples: true,
            unknownFollowUp: likelyMatchUnknownFollowUp(matches: matches, category: context.item.category)
        )
    }

    private static func likelyMatchQuestionTitle(from matches: [AnalyzeLikelyMatch]) -> String {
        let cleanNames = matches
            .prefix(2)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        if cleanNames.count == 2 {
            return String.localizedFormat("Is it closer to %@ or %@?".localized, cleanNames[0], cleanNames[1])
        }
        return "Which one looks closest?"
    }

    private static func likelyMatchQuestionDetail(from matches: [AnalyzeLikelyMatch]) -> String {
        let distinguishingQuestions = matches
            .map { $0.distinguishingQuestion.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        if matches.count == 1, let question = distinguishingQuestions.first {
            return question
        }
        if let question = distinguishingQuestions.first {
            return "\(question) If you cannot tell, BuySell will ask for a different clue."
        }
        return "Pick only if it matches what you can see. If not, BuySell will ask a different way."
    }

    private static func likelyMatchUnknownFollowUp(
        matches: [AnalyzeLikelyMatch],
        category: Category
    ) -> DetailQuestionFallback? {
        guard matches.isEmpty == false else { return nil }
        return DetailQuestionFallback(
            id: "analysis-likely-match-visible-clue",
            contextLabel: "Look closer",
            title: likelyMatchFollowUpTitle(from: matches, category: category),
            detail: "A label, size, material, edition, or mark can separate these possibilities.",
            placeholder: sizePlaceholder(for: category),
            systemImage: specQuestionSymbol(for: category),
            kind: .text(.sizeOrModel),
            choices: choicesWithOptionalScan(
                likelyMatchClueChoices(for: category),
                scanRequest: unknownFallbackScanRequest(for: .sizeOrModel, category: category, marketplace: nil)
            )
        )
    }

    private static func likelyMatchFollowUpTitle(
        from matches: [AnalyzeLikelyMatch],
        category: Category
    ) -> String {
        let question = matches
            .map { $0.distinguishingQuestion.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.isEmpty == false }
        if let question {
            return String(question.prefix(90))
        }
        return identityClueFollowUpTitle(for: category)
    }

    private static func likelyMatchClueChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics:
            return choicesWithUnknown([
                DetailChoice(title: "Model label", value: .text("Model label visible")),
                DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                DetailChoice(title: "Storage shown", value: .text("Storage shown"))
            ])
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return choicesWithUnknown([
                DetailChoice(title: "Size tag", value: .text("Size tag visible")),
                DetailChoice(title: "Material tag", value: .text("Material tag visible")),
                DetailChoice(title: "Style number", value: .text("Style number visible"))
            ])
        case .furniture, .home, .art:
            return choicesWithUnknown([
                DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                DetailChoice(title: "Measurements", value: .text("Measurements available")),
                DetailChoice(title: "Material clue", value: .text("Material clue visible"))
            ])
        case .collectibles, .toys, .media:
            return choicesWithUnknown([
                DetailChoice(title: "Edition number", value: .text("Edition or number visible")),
                DetailChoice(title: "Sealed package", value: .text("Sealed package")),
                DetailChoice(title: "Certificate", value: .text("Certificate or paperwork visible"))
            ])
        case .music:
            return choicesWithUnknown([
                DetailChoice(title: "Model name", value: .text("Model name visible")),
                DetailChoice(title: "Serial number", value: .text("Serial number visible")),
                DetailChoice(title: "Works", value: .text("Works"))
            ])
        default:
            return choicesWithUnknown([
                DetailChoice(title: "Number or size", value: .text("Number or size visible")),
                DetailChoice(title: "Special mark", value: .text("Special mark visible")),
                DetailChoice(title: "No clue visible", value: .text("No exact clue visible"))
            ])
        }
    }

    private static func uniqueLikelyMatches(from matches: [AnalyzeLikelyMatch]) -> [AnalyzeLikelyMatch] {
        matches.compactMap { $0.sanitizedForDisplay() }
            .reduce(into: [AnalyzeLikelyMatch]()) { result, match in
                let alreadyIncluded = result.contains {
                    $0.name.localizedCaseInsensitiveCompare(match.name) == .orderedSame
                }
                guard alreadyIncluded == false else { return }
                result.append(match)
            }
    }

    private static func shouldAskLikelyMatchQuestion(matches: [AnalyzeLikelyMatch], item: DetectedItem) -> Bool {
        guard let firstMatch = matches.first else { return false }
        if matches.count > 1 {
            return true
        }
        let matchesCurrentItem = firstMatch.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame
        return matchesCurrentItem == false || firstMatch.confidence < 0.82
    }

    private static func analysisQuestion(for context: ItemQuestionsContext) -> DetailQuestion? {
        guard let missingFact = context.analysis?.highestImpactMissingFact else { return nil }
        switch missingFact.detailKind {
        case .brand:
            return missingBrandQuestion(fact: missingFact.displayValue, category: context.item.category)
        case .spec:
            return missingSpecQuestion(fact: missingFact.displayValue, category: context.item.category)
        case .included:
            return missingIncludedQuestion(fact: missingFact.displayValue, category: context.item.category)
        case .condition:
            return missingConditionQuestion(fact: missingFact.displayValue)
        case .shipping:
            return largeOrFragileQuestion(for: context.item.category)
        }
    }

    private static func shouldAskBrand(
        for category: Category,
        missingFacts: [String],
        knownFacts: [AnalyzeItemFact]
    ) -> Bool {
        guard knownFacts.containsFact(namedLike: ["brand", "maker", "label", "artist", "mark"]) == false else {
            return false
        }
        if missingFacts.containsFact(namedLike: ["brand", "maker", "label", "artist", "mark"]) {
            return true
        }
        return [.electronics, .clothing, .shoes, .bags, .jewelry, .music, .collectibles, .art, .home, .tools].contains(category)
    }

    private static func shouldAskSpecs(
        for category: Category,
        missingFacts: [String],
        knownFacts: [AnalyzeItemFact]
    ) -> Bool {
        guard knownFacts.containsFact(namedLike: ["model", "size", "storage", "capacity", "measurement", "dimension", "edition", "serial"]) == false else {
            return false
        }
        if missingFacts.containsFact(namedLike: ["model", "size", "storage", "capacity", "measurement", "dimension", "edition", "serial"]) {
            return true
        }
        return [.electronics, .furniture, .clothing, .shoes, .bags, .jewelry, .kids, .music, .collectibles, .art, .home, .tools].contains(category)
    }

    private static func shouldAskIncluded(
        for category: Category,
        missingFacts: [String],
        knownFacts: [AnalyzeItemFact]
    ) -> Bool {
        guard knownFacts.containsFact(namedLike: ["box", "charger", "remote", "accessory", "packaging", "certificate"]) == false else {
            return false
        }
        if missingFacts.containsFact(namedLike: ["box", "charger", "remote", "accessory", "packaging", "certificate"]) {
            return true
        }
        return [.electronics, .tools, .music, .collectibles, .toys, .sports, .media].contains(category)
    }

    private static func shouldAskFlaws(
        missingFacts: [String],
        knownFacts: [AnalyzeItemFact]
    ) -> Bool {
        let conditionNeedles = ["flaw", "damage", "scratch", "stain", "wear", "working", "works", "condition", "missing part"]
        if missingFacts.containsFact(namedLike: conditionNeedles) {
            return true
        }
        return knownFacts.containsFact(namedLike: conditionNeedles) == false
    }

    private static func shouldAskLargeOrFragile(for category: Category, marketplace: Marketplace?) -> Bool {
        if let marketplace, localMarketplaces.contains(marketplace) {
            return true
        }
        return [.furniture, .home, .art, .tools, .music, .sports].contains(category)
    }

    private static var localMarketplaces: Set<Marketplace> {
        [.facebook, .craigslist, .offerup, .nextdoor]
    }

    private static func missingBrandQuestion(fact: String, category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "analysis-brand-\(fact)",
            contextLabel: "Photo check",
            title: "What does the label say?",
            detail: String.localizedFormat(
                "The photo did not clearly show %@. Add it only if you can see it.".localized,
                fact
            ),
            placeholder: brandPlaceholder(for: category),
            systemImage: AppSymbol.Action.category,
            kind: .text(.labelOrBrand),
            choices: [
                DetailChoice(title: "No visible label", value: .text("No visible label")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func missingSpecQuestion(fact: String, category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "analysis-spec-\(fact)",
            contextLabel: "Photo check",
            title: "What exact detail can you see?",
            detail: String.localizedFormat(
                "The photo did not clearly show %@. Add it only if you can see it.".localized,
                fact
            ),
            placeholder: sizePlaceholder(for: category),
            systemImage: specQuestionSymbol(for: category),
            kind: .text(.sizeOrModel),
            choices: specChoices(for: category)
        )
    }

    private static func missingConditionQuestion(fact: String) -> DetailQuestion {
        DetailQuestion(
            id: "analysis-condition-\(fact)",
            contextLabel: "Photo check",
            title: "Anything wrong with it?",
            detail: String.localizedFormat(
                "The photo did not clearly show %@. Add it only if you can see it.".localized,
                fact
            ),
            placeholder: "Scratch, stain, missing piece...",
            systemImage: "exclamationmark.circle.fill",
            kind: .text(.flaws),
            choices: [
                DetailChoice(title: "No visible flaws", value: .text("No visible flaws")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func missingIncludedQuestion(fact: String, category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "analysis-included-\(fact)",
            contextLabel: "Photo check",
            title: "What comes with it?",
            detail: String.localizedFormat(
                "The photo did not clearly show %@. Add it only if you can see it.".localized,
                fact
            ),
            placeholder: includedPlaceholder(for: category),
            systemImage: AppSymbol.Marketplace.package,
            kind: .text(.included),
            choices: [
                DetailChoice(title: "Item only", value: .text("Item only")),
                DetailChoice(title: "Original box", value: .text("Original box included")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func brandQuestion(for category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "brand",
            contextLabel: "Identification",
            title: "Do you see a brand, maker, or label?",
            detail: "A name on a tag, sticker, stamp, or logo can change the search and price.",
            placeholder: brandPlaceholder(for: category),
            systemImage: AppSymbol.Action.category,
            kind: .text(.labelOrBrand),
            choices: [
                DetailChoice(title: "No label", value: .text("No visible label")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func specQuestion(for category: Category, marketplace: Marketplace?) -> DetailQuestion {
        DetailQuestion(
            id: "spec",
            contextLabel: "Price clue",
            title: specQuestionTitle(for: category, marketplace: marketplace),
            detail: specQuestionDetail(for: category),
            placeholder: sizePlaceholder(for: category),
            systemImage: specQuestionSymbol(for: category),
            kind: .text(.sizeOrModel),
            choices: specChoices(for: category)
        )
    }

    private static var flawQuestion: DetailQuestion {
        DetailQuestion(
            id: "flaws",
            contextLabel: "Condition",
            title: "Any flaws someone should see?",
            detail: "Scratches, stains, missing parts, or wear keep the listing honest.",
            placeholder: "Scratch, stain, missing piece...",
            systemImage: AppSymbol.Condition.fair,
            kind: .text(.flaws),
            choices: [
                DetailChoice(title: "No visible flaws", value: .text("No visible flaws")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func includedQuestion(for category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "included",
            contextLabel: "Included",
            title: "What comes with it?",
            detail: includedQuestionDetail(for: category),
            placeholder: includedPlaceholder(for: category),
            systemImage: AppSymbol.Marketplace.package,
            kind: .text(.included),
            choices: [
                DetailChoice(title: "Item only", value: .text("Item only")),
                DetailChoice(title: "Original box", value: .text("Original box included")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func extraDetailQuestion(for category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "extra",
            contextLabel: "Details",
            title: "Anything else worth saying?",
            detail: "Only add what someone can see, measure, or trust.",
            placeholder: extraDetailPlaceholder(for: category),
            systemImage: AppSymbol.Flow.answer,
            kind: .text(.extraDetails),
            choices: [
                DetailChoice(title: "No extra detail", value: .text("No extra detail")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func extraDetailPlaceholder(for category: Category) -> String {
        switch category {
        case .art, .collectibles:
            "Signed, numbered, framed..."
        case .furniture, .home:
            "Material, age, pickup note..."
        case .electronics, .tools, .music:
            "Serial, tested, accessories..."
        default:
            "Material, color, pickup, or note..."
        }
    }

    private static func includedPlaceholder(for category: Category) -> String {
        switch category {
        case .electronics:
            "Charger, cable, box..."
        case .tools:
            "Battery, charger, case..."
        case .music:
            "Case, cable, strap..."
        case .collectibles:
            "Box, certificate, sleeve..."
        default:
            "Box, charger, remote..."
        }
    }

    private static func largeOrFragileQuestion(for category: Category) -> DetailQuestion {
        DetailQuestion(
            id: "large-fragile",
            contextLabel: "Shipping",
            title: largeOrFragileTitle(for: category),
            detail: "This helps BuySell decide whether local pickup beats shipping.",
            placeholder: "",
            systemImage: AppSymbol.Marketplace.package,
            kind: .largeOrFragile,
            choices: [
                DetailChoice(title: "Yes", value: .largeFragile(true)),
                DetailChoice(title: "No", value: .largeFragile(false)),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func marketplaceEvidenceQuestion(
        for context: ItemQuestionsContext,
        marketplace: Marketplace,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard let comparison = context.marketplaceComparison?.sanitizedForDisplay(),
              comparison.marketplace == marketplace,
              comparison.evidenceStatus != .unavailable
        else {
            return nil
        }

        let field = marketplaceEvidenceQuestionField(
            for: context.item,
            comparison: comparison,
            marketplace: marketplace,
            answers: answers
        )
        guard let field else { return nil }

        return DetailQuestion(
            id: "marketplace-evidence-\(marketplace.rawValue)-\(field.detailKey.rawValue)",
            contextLabel: marketplace.displayName,
            title: marketplaceEvidenceTitle(for: field, marketplace: marketplace),
            detail: marketplaceEvidenceDetail(for: field, comparison: comparison, marketplace: marketplace),
            placeholder: marketplaceEvidencePlaceholder(for: field, category: context.item.category, marketplace: marketplace),
            systemImage: marketplaceEvidenceSymbol(for: field, category: context.item.category, marketplace: marketplace),
            kind: .text(field),
            choices: marketplaceEvidenceChoices(
                for: field,
                comparison: comparison,
                marketplace: marketplace,
                currencyCode: context.item.currencyCode
            ),
            evidenceSummary: marketplaceEvidenceSummary(
                comparison: comparison,
                marketplace: marketplace,
                currencyCode: context.item.currencyCode
            ),
            unknownFollowUp: marketplaceEvidenceUnknownFollowUp(
                for: field,
                category: context.item.category,
                marketplace: marketplace
            )
        )
    }

    private static func marketplaceEvidenceQuestionField(
        for item: DetectedItem,
        comparison: MarketplaceComparison,
        marketplace: Marketplace,
        answers: ItemDetailAnswers
    ) -> Field? {
        if shouldAskExactMarketplaceSpec(for: item, answers: answers),
           marketplaceEvidenceTextCandidates(from: comparison).isEmpty == false {
            return .sizeOrModel
        }
        if answers.hasAnsweredOrSkipped(.included) == false,
           marketplaceEvidenceMentionsIncludedDetails(comparison) {
            return .included
        }
        if answers.hasAnsweredOrSkipped(.flaws) == false,
           marketplaceEvidenceMentionsCondition(comparison) {
            return .flaws
        }
        if answers.hasMarketplaceNoteOrSkipped(marketplace) == false {
            return .marketplaceNote(marketplace)
        }
        return nil
    }

    private static func marketplaceEvidenceTitle(for field: Field, marketplace: Marketplace) -> String {
        switch field {
        case .sizeOrModel:
            return "Which detail matches the sold ones?"
        case .included:
            return "Does yours include what the sold ones did?"
        case .flaws:
            return "Is yours closer to the clean sold ones?"
        case .marketplaceNote:
            return String.localizedFormat("Use this %@ price plan?".localized, marketplace.displayName)
        case .labelOrBrand, .extraDetails:
            return "What detail should BuySell trust?"
        }
    }

    private static func marketplaceEvidenceDetail(
        for field: Field,
        comparison: MarketplaceComparison,
        marketplace: Marketplace
    ) -> String {
        let sourceCount = comparison.evidenceSources?.count ?? 0
        let evidenceIntro = sourceCount > 0
            ? String.localizedFormat("BuySell checked %d real %@ result(s).".localized, sourceCount, marketplace.displayName)
            : String.localizedFormat("BuySell checked %@ before this.".localized, marketplace.displayName)
        switch field {
        case .sizeOrModel:
            return "\(evidenceIntro) Exact model, size, year, edition, or material can change the price."
        case .included:
            return "\(evidenceIntro) Box, charger, case, certificate, or accessories can move the price."
        case .flaws:
            return "\(evidenceIntro) Condition is what separates the low and high sold prices."
        case .marketplaceNote:
            if let strategy = comparison.reason?.trimmingCharacters(in: .whitespacesAndNewlines), strategy.isEmpty == false {
                return strategy
            }
            return "\(evidenceIntro) This keeps the final listing tied to the research."
        case .labelOrBrand, .extraDetails:
            return "\(evidenceIntro) Add only a detail you can see or confidently know."
        }
    }

    private static func marketplaceEvidencePlaceholder(
        for field: Field,
        category: Category,
        marketplace: Marketplace
    ) -> String {
        switch field {
        case .sizeOrModel:
            return sizePlaceholder(for: category)
        case .included:
            return includedPlaceholder(for: category)
        case .flaws:
            return "No flaws, light wear, broken part..."
        case .marketplaceNote:
            return marketplaceFallbackPlaceholder(for: marketplace, category: category)
        case .labelOrBrand:
            return brandPlaceholder(for: category)
        case .extraDetails:
            return extraDetailPlaceholder(for: category)
        }
    }

    private static func marketplaceEvidenceSymbol(
        for field: Field,
        category: Category,
        marketplace: Marketplace
    ) -> String {
        switch field {
        case .sizeOrModel:
            return specQuestionSymbol(for: category)
        case .included:
            return AppSymbol.Marketplace.package
        case .flaws:
            return AppSymbol.Condition.fair
        case .marketplaceNote:
            return marketplace.iconSystemName
        case .labelOrBrand:
            return AppSymbol.Action.category
        case .extraDetails:
            return AppSymbol.Flow.answer
        }
    }

    private static func marketplaceEvidenceChoices(
        for field: Field,
        comparison: MarketplaceComparison,
        marketplace: Marketplace,
        currencyCode: String
    ) -> [DetailChoice] {
        switch field {
        case .sizeOrModel:
            let evidenceChoices = marketplaceEvidenceTextCandidates(from: comparison).map {
                DetailChoice(title: $0, value: .text($0), localizesTitle: false)
            }
            return choicesWithUnknown(evidenceChoices)
        case .included:
            return choicesWithUnknown([
                DetailChoice(title: "Item only", value: .text("Item only")),
                DetailChoice(title: "Box or case", value: .text("Box or case included")),
                DetailChoice(title: "Accessories included", value: .text("Accessories included"))
            ])
        case .flaws:
            return choicesWithUnknown([
                DetailChoice(title: "No obvious flaws", value: .text("No obvious flaws")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "Needs work", value: .text("Needs work or repair"))
            ])
        case .marketplaceNote:
            let priceChoice = comparison.listPrice.map {
                DetailChoice(
                    title: String.localizedFormat("List around %@".localized, $0.currency(code: currencyCode)),
                    value: .text(String.localizedFormat("List around %@".localized, $0.currency(code: currencyCode)))
                )
            }
            let strategyChoices = [
                priceChoice,
                DetailChoice(title: "Open to offers", value: .text("Open to offers")),
                DetailChoice(title: localMarketplaces.contains(marketplace) ? "Pickup is best" : "Shipping is fine", value: .text(localMarketplaces.contains(marketplace) ? "Pickup is best" : "Shipping is fine"))
            ].compactMap { $0 }
            return choicesWithUnknown(strategyChoices)
        case .labelOrBrand, .extraDetails:
            return marketplaceEvidenceTextCandidates(from: comparison).isEmpty
                ? choicesWithUnknown([DetailChoice(title: "No extra detail", value: .text("No extra detail"))])
                : choicesWithUnknown(marketplaceEvidenceTextCandidates(from: comparison).map {
                    DetailChoice(title: $0, value: .text($0), localizesTitle: false)
                })
        }
    }

    private static func marketplaceEvidenceSummary(
        comparison: MarketplaceComparison,
        marketplace: Marketplace,
        currencyCode: String
    ) -> QuestionEvidenceSummary? {
        guard comparison.evidenceStatus != .unavailable else { return nil }
        let sourceCount = comparison.evidenceSources?.count ?? 0
        let detail = sourceCount > 0
            ? String.localizedFormat("Checked %d real %@ result(s).".localized, sourceCount, marketplace.displayName)
            : String.localizedFormat("Checked %@ before this.".localized, marketplace.displayName)

        if let low = comparison.compLowPrice, let high = comparison.compHighPrice {
            return QuestionEvidenceSummary(
                title: "Market evidence",
                value: String.localizedFormat(
                    "Sold range %@ to %@".localized,
                    low.currency(code: currencyCode),
                    high.currency(code: currencyCode)
                ),
                detail: detail,
                systemImage: "chart.line.uptrend.xyaxis"
            )
        }
        if let listPrice = comparison.listPrice {
            return QuestionEvidenceSummary(
                title: "Market evidence",
                value: String.localizedFormat("List around %@".localized, listPrice.currency(code: currencyCode)),
                detail: detail,
                systemImage: "tag.fill"
            )
        }
        let evidenceSummary = comparison.evidenceSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard evidenceSummary.isEmpty == false else { return nil }
        return QuestionEvidenceSummary(
            title: "Market evidence",
            value: String(evidenceSummary.prefix(80)),
            detail: detail,
            systemImage: marketplace.iconSystemName
        )
    }

    private static func marketplaceEvidenceUnknownFollowUp(
        for field: Field,
        category: Category,
        marketplace: Marketplace
    ) -> DetailQuestionFallback? {
        let title: String
        switch field {
        case .sizeOrModel:
            title = fallbackTitle(for: .sizeOrModel, category: category, marketplace: marketplace)
        case .included:
            title = "Check for the box, charger, case, or paperwork"
        case .flaws:
            title = "Look at the worst spot"
        case .marketplaceNote:
            title = marketplaceFallbackTitle(for: marketplace, category: category)
        case .labelOrBrand, .extraDetails:
            title = "Look for one visible clue"
        }

        return DetailQuestionFallback(
            id: "marketplace-evidence-help-\(marketplace.rawValue)-\(field.detailKey.rawValue)",
            contextLabel: "Look closer",
            title: title,
            detail: "Pick the closest thing you can see. Skip if none fits.",
            placeholder: marketplaceEvidencePlaceholder(for: field, category: category, marketplace: marketplace),
            systemImage: marketplaceEvidenceSymbol(for: field, category: category, marketplace: marketplace),
            kind: .text(field),
            choices: fallbackChoices(for: field, category: category, marketplace: marketplace)
        )
    }

    private static func marketplaceFallbackPlaceholder(for marketplace: Marketplace, category: Category) -> String {
        localMarketplaces.contains(marketplace)
            ? localPlaceholder(for: category)
            : "Ships easily, needs padding, pickup, or note..."
    }

    private static func marketplaceEvidenceTextCandidates(from comparison: MarketplaceComparison) -> [String] {
        let values = (comparison.evidenceSources ?? []).flatMap { source in
            [source.conditionAndVariant, source.title]
        } + [comparison.evidenceSummary]
        return values.compactMap { evidenceChoiceText($0) }
            .reduce(into: [String]()) { result, value in
                guard result.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) == false,
                      result.count < 3
                else { return }
                result.append(value)
            }
    }

    private static func evidenceChoiceText(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(sold|completed|active|listing|comparable)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return nil }
        return String(cleaned.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func marketplaceEvidenceMentionsIncludedDetails(_ comparison: MarketplaceComparison) -> Bool {
        text(marketplaceEvidenceSearchText(comparison), containsAny: [
            "box", "case", "charger", "cable", "remote", "certificate", "paperwork", "accessory", "accessories", "manual"
        ])
    }

    private static func marketplaceEvidenceMentionsCondition(_ comparison: MarketplaceComparison) -> Bool {
        if let low = comparison.compLowPrice, let high = comparison.compHighPrice, high > low * Decimal(135) / Decimal(100) {
            return true
        }
        return text(marketplaceEvidenceSearchText(comparison), containsAny: [
            "scratch", "wear", "worn", "stain", "working", "tested", "untested", "sealed", "new", "repair", "damage"
        ])
    }

    private static func text(_ text: String, containsAny needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func marketplaceEvidenceSearchText(_ comparison: MarketplaceComparison) -> String {
        ([
            comparison.reason,
            comparison.evidenceSummary,
            comparison.feeSummary,
            comparison.expectedSpeed,
            comparison.shippingExpectation
        ] + (comparison.evidenceSources ?? []).flatMap {
            [$0.title, $0.conditionAndVariant, $0.comparability, $0.listingStatus]
        })
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    private static func marketplaceQuestion(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> DetailQuestion {
        marketplaceQuestions(for: marketplace, item: item, answers: answers).first
            ?? generalMarketplaceQuestion(for: marketplace, item: item, answers: answers)
    }

    private static func draftWarningQuestion(
        for context: ItemQuestionsContext,
        marketplace: Marketplace,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard let warning = context.listingDraft?.missingInfoWarnings?
            .compactMap({ cleanDraftWarning($0) })
            .first
        else {
            return nil
        }
        let field = questionField(forDraftWarning: warning, marketplace: marketplace)
        guard isQuestionFieldAnswered(field, marketplace: marketplace, answers: answers) == false else {
            return nil
        }

        return DetailQuestion(
            id: "marketplace-draft-warning-\(marketplace.rawValue)-\(field.detailKey.rawValue)",
            contextLabel: marketplace.displayName,
            title: draftWarningQuestionTitle(for: field, marketplace: marketplace),
            detail: String.localizedFormat(
                "The %@ draft is missing this: %@".localized,
                marketplace.displayName,
                warning
            ),
            placeholder: playbookPlaceholder(for: field, category: context.item.category, marketplace: marketplace),
            systemImage: playbookSystemImage(for: field, category: context.item.category, marketplace: marketplace),
            kind: .text(field),
            choices: draftWarningChoices(for: field, warning: warning, category: context.item.category, marketplace: marketplace),
            unknownFollowUp: DetailQuestionFallback(
                id: "marketplace-draft-warning-help-\(marketplace.rawValue)-\(field.detailKey.rawValue)",
                contextLabel: "Look closer",
                title: draftWarningFollowUpTitle(for: field, marketplace: marketplace),
                detail: "Pick the closest clue. Skip it if you cannot tell.".localized,
                placeholder: playbookPlaceholder(for: field, category: context.item.category, marketplace: marketplace),
                systemImage: playbookSystemImage(for: field, category: context.item.category, marketplace: marketplace),
                kind: .text(field),
                choices: unknownFallbackChoices(
                    for: field,
                    category: context.item.category,
                    itemName: context.item.name,
                    clueText: warning,
                    marketplace: marketplace
                )
            )
        )
    }

    private static func cleanDraftWarning(_ warning: String) -> String? {
        let cleanWarning = warning
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanWarning.isEmpty == false else { return nil }
        return String(cleanWarning.prefix(120))
    }

    private static func questionField(forDraftWarning warning: String, marketplace: Marketplace) -> Field {
        let text = warning.lowercased()
        if text.containsAny(of: ["pickup", "delivery", "local", "meet", "porch", "shipping", "freight"]) {
            return .marketplaceNote(marketplace)
        }
        if text.containsAny(of: [
            "model", "model number", "serial", "part number", "mpn", "sku", "style code",
            "size", "measurement", "dimension", "height", "width", "depth", "storage",
            "carrier", "unlocked", "imei", "set", "card number", "language", "foil"
        ]) {
            return .sizeOrModel
        }
        if text.containsAny(of: [
            "vintage", "handmade", "supply", "material", "materials", "maker", "mark",
            "brand", "designer", "period", "age", "year"
        ]) {
            return .labelOrBrand
        }
        if text.containsAny(of: ["box", "accessory", "accessories", "certificate", "receipt", "proof", "parts"]) {
            return .included
        }
        if text.containsAny(of: ["condition", "working", "tested", "battery", "flaw", "scratch", "wear", "repair"]) {
            return .flaws
        }
        return questionField(forPlaybookField: text, marketplace: marketplace)
    }

    private static func draftWarningQuestionTitle(for field: Field, marketplace: Marketplace) -> String {
        switch field {
        case .marketplaceNote:
            return String.localizedFormat("How should this work on %@?".localized, marketplace.displayName)
        case .sizeOrModel:
            return "What exact number or size is missing?".localized
        case .labelOrBrand:
            return "What mark or material is missing?".localized
        case .flaws:
            return "What condition detail is missing?".localized
        case .included:
            return "What box, proof, or parts are included?".localized
        case .extraDetails:
            return String.localizedFormat("What detail should %@ know?".localized, marketplace.displayName)
        }
    }

    private static func draftWarningFollowUpTitle(for field: Field, marketplace: Marketplace) -> String {
        switch field {
        case .marketplaceNote:
            return String.localizedFormat("Pick the %@ selling setup".localized, marketplace.displayName)
        case .sizeOrModel:
            return "Check tags, plates, labels, or measurements".localized
        case .labelOrBrand:
            return "Check stamps, tags, signatures, or material".localized
        case .flaws:
            return "Check whether it works and show any wear".localized
        case .included:
            return "Check the box, parts, paperwork, or proof".localized
        case .extraDetails:
            return "Pick the practical detail you know".localized
        }
    }

    private static func draftWarningChoices(
        for field: Field,
        warning: String,
        category: Category,
        marketplace: Marketplace
    ) -> [DetailChoice] {
        let text = warning.lowercased()
        if text.contains("box") || text.contains("style code") || text.contains("sku") {
            return choicesWithUnknown([
                DetailChoice(title: "Box included", value: .text("Original box included")),
                DetailChoice(title: "Code visible", value: .text("Style code or SKU visible")),
                DetailChoice(title: "No box", value: .text("No original box"))
            ])
        }
        if text.contains("pickup") || text.contains("delivery") || text.contains("local") {
            return localChoices(for: category)
        }
        return playbookChoices(for: field, displayField: text, category: category, marketplace: marketplace)
    }

    private static func marketplaceQuestions(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        switch marketplace {
        case .ebay:
            return ebayQuestions(for: item, answers: answers)
        case .mercari:
            return mercariQuestions(for: item, answers: answers)
        case .facebook, .craigslist, .offerup, .nextdoor:
            return [localQuestion(for: marketplace, item: item, answers: answers)]
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy:
            return fashionQuestions(for: marketplace, item: item, answers: answers)
        case .whatnot:
            return whatnotQuestions(for: item, answers: answers)
        case .etsy, .chairish, .rubylane:
            return vintageQuestions(for: marketplace, item: item, answers: answers)
        case .stockx, .goat:
            return authenticatedGoodsQuestions(for: marketplace, item: item, answers: answers)
        case .swappa:
            return swappaQuestions(for: item, answers: answers)
        case .reverb:
            return reverbQuestions(for: item, answers: answers)
        case .amazon:
            return amazonQuestions(for: item, answers: answers)
        case .shopify:
            return shopifyQuestions(for: item, answers: answers)
        case .bonanza:
            return bonanzaQuestions(for: item, answers: answers)
        case .tcgplayer:
            return tradingCardQuestions(for: item, answers: answers)
        default:
            return [generalMarketplaceQuestion(for: marketplace, item: item, answers: answers)]
        }
    }

    private static func marketplacePlaybookQuestion(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        guard let need = marketplacePlaybookNeed(for: marketplace, item: item, answers: answers) else {
            return nil
        }
        return DetailQuestion(
            id: "marketplace-playbook-\(marketplace.rawValue)-\(need.field.detailKey.rawValue)",
            contextLabel: marketplace.displayName,
            title: playbookQuestionTitle(for: need.field, marketplace: marketplace),
            detail: String.localizedFormat(
                "%@ usually needs %@. Add it only if you can see it or know it.".localized,
                marketplace.displayName,
                need.displayField
            ),
            placeholder: need.placeholder,
            systemImage: need.systemImage,
            kind: .text(need.field),
            choices: need.choices,
            unknownFollowUp: DetailQuestionFallback(
                id: "marketplace-playbook-help-\(marketplace.rawValue)-\(need.field.detailKey.rawValue)",
                contextLabel: "Look closer",
                title: playbookFollowUpTitle(for: need.field, displayField: need.displayField),
                detail: "Pick the closest visible clue. Skip if nothing stands out.",
                placeholder: need.placeholder,
                systemImage: need.systemImage,
                kind: .text(need.field),
                choices: unknownFallbackChoices(
                    for: need.field,
                    category: item.category,
                    itemName: item.name,
                    clueText: need.displayField,
                    marketplace: marketplace
                )
            )
        )
    }

    private static func marketplacePlaybookNeed(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> MarketplacePlaybookQuestionNeed? {
        let playbook = marketplace.listingPlaybook
        return (playbook.requiredFields + playbook.highImpactOptionalFields)
            .compactMap { playbookNeed(for: $0, marketplace: marketplace, item: item, answers: answers) }
            .first
    }

    private static func playbookNeed(
        for fieldName: String,
        marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> MarketplacePlaybookQuestionNeed? {
        let displayField = fieldName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayField.isEmpty == false else { return nil }
        let lowerField = displayField.lowercased()
        guard playbookFieldIsPhotoOnly(lowerField) == false,
              playbookFieldIsAlreadyKnown(lowerField, item: item, answers: answers) == false
        else {
            return nil
        }

        let field = questionField(forPlaybookField: lowerField, marketplace: marketplace)
        guard isQuestionFieldAnswered(field, marketplace: marketplace, answers: answers) == false else {
            return nil
        }
        return MarketplacePlaybookQuestionNeed(
            displayField: displayField,
            field: field,
            placeholder: playbookPlaceholder(for: field, category: item.category, marketplace: marketplace),
            systemImage: playbookSystemImage(for: field, category: item.category, marketplace: marketplace),
            choices: playbookChoices(for: field, displayField: lowerField, category: item.category, marketplace: marketplace)
        )
    }

    private static func playbookFieldIsPhotoOnly(_ field: String) -> Bool {
        field.contains("photo") || field.contains("cover photo") || field.contains("live-sale asset")
    }

    private static func playbookFieldIsAlreadyKnown(
        _ field: String,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> Bool {
        if field == "title" || field == "product title" || field == "item identity" {
            return item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        if field == "category" {
            return item.category != .other
        }
        if field == "condition" {
            return true
        }
        if field == "price" || field == "starting price" {
            return item.priceEstimate > 0
        }
        if field.contains("description") {
            return answers.extraDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        return false
    }

    private static func questionField(forPlaybookField field: String, marketplace: Marketplace) -> Field {
        if field.contains("pickup") ||
            field.contains("delivery") ||
            field.contains("shipping") ||
            field.contains("freight") ||
            field.contains("fulfillment") ||
            field.contains("negotiability") ||
            field.contains("account") ||
            field.contains("consignment") {
            return .marketplaceNote(marketplace)
        }
        if field.contains("box") ||
            field.contains("accessor") ||
            field.contains("certificate") ||
            field.contains("receipt") ||
            field.contains("provenance") ||
            field.contains("authenticity") {
            return .included
        }
        if field.contains("condition") ||
            field.contains("working") ||
            field.contains("functional") ||
            field.contains("battery") ||
            field.contains("flaw") ||
            field.contains("scratch") ||
            field.contains("surface") ||
            field.contains("centering") ||
            field.contains("restoration") {
            return .flaws
        }
        if field.contains("brand") ||
            field.contains("designer") ||
            field.contains("maker") ||
            field.contains("materials") ||
            field.contains("material") ||
            field.contains("period") ||
            field.contains("age") {
            return .labelOrBrand
        }
        if field.contains("sku") ||
            field.contains("style code") ||
            field.contains("product identifier") ||
            field.contains("model") ||
            field.contains("storage") ||
            field.contains("size") ||
            field.contains("dimension") ||
            field.contains("set") ||
            field.contains("card number") {
            return .sizeOrModel
        }
        return .sizeOrModel
    }

    private static func isQuestionFieldAnswered(
        _ field: Field,
        marketplace: Marketplace,
        answers: ItemDetailAnswers
    ) -> Bool {
        switch field {
        case .marketplaceNote:
            return answers.hasMarketplaceNoteOrSkipped(marketplace)
        default:
            return answers.hasAnsweredOrSkipped(field.detailKey)
        }
    }

    private static func playbookQuestionTitle(for field: Field, marketplace: Marketplace) -> String {
        switch field {
        case .labelOrBrand:
            return String.localizedFormat("What name or mark does %@ need?".localized, marketplace.displayName)
        case .sizeOrModel:
            return String.localizedFormat("What exact detail does %@ need?".localized, marketplace.displayName)
        case .flaws:
            return String.localizedFormat("What condition detail does %@ need?".localized, marketplace.displayName)
        case .included:
            return String.localizedFormat("What proof or parts does %@ need?".localized, marketplace.displayName)
        case .extraDetails, .marketplaceNote:
            return String.localizedFormat("What %@ detail should we add?".localized, marketplace.displayName)
        }
    }

    private static func playbookFollowUpTitle(for field: Field, displayField: String) -> String {
        switch field {
        case .labelOrBrand:
            return "Look for a tag, stamp, signature, or maker mark"
        case .sizeOrModel:
            return String.localizedFormat("Look for %@".localized, displayField)
        case .flaws:
            return "Check the part buyers would worry about"
        case .included:
            return "Check the box, parts, paperwork, or proof"
        case .extraDetails, .marketplaceNote:
            return "Pick the practical detail you know"
        }
    }

    private static func playbookPlaceholder(
        for field: Field,
        category: Category,
        marketplace: Marketplace
    ) -> String {
        switch field {
        case .marketplaceNote:
            return marketplaceFallbackPlaceholder(for: marketplace, category: category)
        case .labelOrBrand:
            return brandPlaceholder(for: category)
        case .sizeOrModel:
            return sizePlaceholder(for: category)
        case .flaws:
            return "Works, light wear, needs repair..."
        case .included:
            return includedPlaceholder(for: category)
        case .extraDetails:
            return extraDetailPlaceholder(for: category)
        }
    }

    private static func playbookSystemImage(
        for field: Field,
        category: Category,
        marketplace: Marketplace
    ) -> String {
        switch field {
        case .marketplaceNote:
            return marketplace.iconSystemName
        case .labelOrBrand:
            return AppSymbol.Action.category
        case .sizeOrModel:
            return specQuestionSymbol(for: category)
        case .flaws:
            return AppSymbol.Condition.fair
        case .included:
            return AppSymbol.Marketplace.package
        case .extraDetails:
            return AppSymbol.Flow.answer
        }
    }

    private static func playbookChoices(
        for field: Field,
        displayField: String,
        category: Category,
        marketplace: Marketplace
    ) -> [DetailChoice] {
        switch field {
        case .marketplaceNote:
            if localMarketplaces.contains(marketplace) {
                return localChoices(for: category)
            }
            return choicesWithUnknown([
                DetailChoice(title: "Ships easily", value: .text("Ships easily")),
                DetailChoice(title: "Needs packing", value: .text("Needs careful packing")),
                DetailChoice(title: "Pickup better", value: .text("Pickup is better"))
            ])
        case .included:
            return choicesWithUnknown([
                DetailChoice(title: "Original box", value: .text("Original box included")),
                DetailChoice(title: "Parts included", value: .text("Parts included")),
                DetailChoice(title: "No box", value: .text("No original box"))
            ])
        case .flaws:
            if displayField.contains("battery") {
                return choicesWithUnknown([
                    DetailChoice(title: "Battery good", value: .text("Battery condition looks good")),
                    DetailChoice(title: "Battery issue", value: .text("Battery issue")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ])
            }
            return choicesWithUnknown([
                DetailChoice(title: "Works", value: .text("Works")),
                DetailChoice(title: "Light wear", value: .text("Light wear")),
                DetailChoice(title: "Needs repair", value: .text("Needs repair"))
            ])
        case .labelOrBrand:
            return choicesWithUnknown([
                DetailChoice(title: "Brand visible", value: .text("Brand visible")),
                DetailChoice(title: "Maker mark", value: .text("Maker mark visible")),
                DetailChoice(title: "No mark", value: .text("No visible mark"))
            ])
        case .sizeOrModel:
            return choicesWithUnknown([
                DetailChoice(title: "Model visible", value: .text("Model visible")),
                DetailChoice(title: "Size visible", value: .text("Size visible")),
                DetailChoice(title: "Number visible", value: .text("Number visible"))
            ])
        case .extraDetails:
            return choicesWithUnknown([
                DetailChoice(title: "Special detail", value: .text("Special detail visible")),
                DetailChoice(title: "No extra detail", value: .text("No extra detail"))
            ])
        }
    }

    private static func ebayQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-ebay-spec",
                contextLabel: "eBay",
                title: specQuestionTitle(for: item.category, marketplace: .ebay),
                detail: ebaySpecDetail(for: item.category),
                placeholder: sizePlaceholder(for: item.category),
                systemImage: specQuestionSymbol(for: item.category),
                kind: .text(.sizeOrModel),
                choices: specChoices(for: item.category)
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-ebay-format",
            contextLabel: "eBay",
            title: "Fixed price or auction?",
            detail: "Fixed price is easier. Auction can help when the price is hard to judge.",
            placeholder: "Fixed price, auction, shipping note...",
            systemImage: AppSymbol.Marketplace.cart,
            kind: .text(.marketplaceNote(.ebay)),
            choices: [
                DetailChoice(title: "Fixed price", value: .text("Prefer fixed price")),
                DetailChoice(title: "Auction", value: .text("Open to auction")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func mercariQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-mercari-spec",
                contextLabel: Marketplace.mercari.displayName,
                title: specQuestionTitle(for: item.category, marketplace: .mercari),
                detail: "Mercari buyers need the exact size, model, and condition before shipping feels safe.",
                placeholder: sizePlaceholder(for: item.category),
                systemImage: specQuestionSymbol(for: item.category),
                kind: .text(.sizeOrModel),
                choices: specChoices(for: item.category)
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-mercari-shipping",
            contextLabel: Marketplace.mercari.displayName,
            title: "How hard is shipping?",
            detail: "A shipping note helps BuySell price it without guessing on packing.",
            placeholder: "Ships easily, needs padding, box size...",
            systemImage: AppSymbol.Marketplace.package,
            kind: .text(.marketplaceNote(.mercari)),
            choices: [
                DetailChoice(title: "Ships easily", value: .text("Ships easily")),
                DetailChoice(title: "Pack carefully", value: .text("Needs careful packing")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func localQuestion(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> DetailQuestion {
        DetailQuestion(
            id: "marketplace-local-\(marketplace.rawValue)",
            contextLabel: marketplace.displayName,
            title: localQuestionTitle(for: item.category),
            detail: localQuestionDetail(for: item.category, answers: answers),
            placeholder: localPlaceholder(for: item.category),
            systemImage: AppSymbol.Marketplace.local,
            kind: .text(.marketplaceNote(marketplace)),
            choices: localChoices(for: item.category)
        )
    }

    private static func fashionQuestions(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-fashion-size-\(marketplace.rawValue)",
                contextLabel: marketplace.displayName,
                title: "What size or material is on the tag?",
                detail: "Fashion listings need the tag, fit, and any fabric details people can trust.",
                placeholder: "Women's M, leather, 32 x 30...",
                systemImage: AppSymbol.Marketplace.fashion,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "No size tag", value: .text("No visible size tag")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-fashion-fit-\(marketplace.rawValue)",
            contextLabel: marketplace.displayName,
            title: "Any fit or measurement note?",
            detail: "A fit note helps clothing feel safer to buy.",
            placeholder: "Runs small, pit to pit, inseam...",
            systemImage: "ruler",
            kind: .text(.marketplaceNote(marketplace)),
            choices: [
                DetailChoice(title: "No extra detail", value: .text("No extra detail")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func vintageQuestions(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if answers.hasAnsweredOrSkipped(.labelOrBrand) == false, item.category != .clothing {
            questions.append(DetailQuestion(
                id: "marketplace-vintage-maker-\(marketplace.rawValue)",
                contextLabel: marketplace.displayName,
                title: "Any maker mark, signature, or label?",
                detail: "A visible mark helps this place trust what the item is.",
                placeholder: brandPlaceholder(for: item.category),
                systemImage: AppSymbol.Marketplace.vintage,
                kind: .text(.labelOrBrand),
                choices: [
                    DetailChoice(title: "No visible label", value: .text("No visible label")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-vintage-fit-\(marketplace.rawValue)",
            contextLabel: marketplace.displayName,
            title: vintageQuestionTitle(for: item.category),
            detail: "Age, materials, signature, or maker marks matter on this marketplace.",
            placeholder: "Vintage, handmade, signed, materials...",
            systemImage: AppSymbol.Marketplace.art,
            kind: .text(.marketplaceNote(marketplace)),
            choices: [
                DetailChoice(title: "Looks vintage", value: .text("Looks vintage")),
                DetailChoice(title: "Signed or marked", value: .text("Signed or marked")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func whatnotQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-whatnot-spec",
                contextLabel: Marketplace.whatnot.displayName,
                title: whatnotSpecQuestionTitle(for: item.category),
                detail: "Whatnot works best when the exact item, quantity, and condition are easy to say fast.",
                placeholder: whatnotPlaceholder(for: item.category),
                systemImage: AppSymbol.Marketplace.video,
                kind: .text(.sizeOrModel),
                choices: whatnotChoices(for: item.category)
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-whatnot-format",
            contextLabel: Marketplace.whatnot.displayName,
            title: "Single item or bundle?",
            detail: "Lot size and condition change how live buyers compare the price.",
            placeholder: "Single item, lot of 3, sealed...",
            systemImage: AppSymbol.Marketplace.video,
            kind: .text(.marketplaceNote(.whatnot)),
            choices: [
                DetailChoice(title: "Single item", value: .text("Single item")),
                DetailChoice(title: "Lot or bundle", value: .text("Lot or bundle")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func authenticatedGoodsQuestions(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-auth-spec-\(marketplace.rawValue)",
                contextLabel: marketplace.displayName,
                title: "Do you know the exact size or SKU?",
                detail: "Exact model, size, and colorway matter here.",
                placeholder: "SKU, size, colorway...",
                systemImage: AppSymbol.Marketplace.verified,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        if answers.hasAnsweredOrSkipped(.included) == false {
            questions.append(DetailQuestion(
                id: "marketplace-auth-box-\(marketplace.rawValue)",
                contextLabel: marketplace.displayName,
                title: "Is the original box included?",
                detail: "Box condition can change what people will pay.",
                placeholder: "Original box, no box, box damage...",
                systemImage: AppSymbol.Marketplace.package,
                kind: .text(.included),
                choices: [
                    DetailChoice(title: "Original box", value: .text("Original box included")),
                    DetailChoice(title: "No box", value: .text("No original box")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        return questions.isEmpty
            ? [generalMarketplaceQuestion(for: marketplace, item: item, answers: answers)]
            : questions
    }

    private static func swappaQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-tech-spec",
                contextLabel: Marketplace.swappa.displayName,
                title: "What storage or carrier do you know?",
                detail: "Phones need storage, carrier, battery, unlock status, and condition.",
                placeholder: "128 GB, unlocked, 89% battery...",
                systemImage: AppSymbol.Marketplace.phone,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "Unlocked", value: .text("Unlocked")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-tech-working",
            contextLabel: Marketplace.swappa.displayName,
            title: "Does it turn on?",
            detail: "Working condition and obvious scratches need to be clear.",
            placeholder: "Turns on, scratches, battery issue...",
            systemImage: AppSymbol.Marketplace.phone,
            kind: .text(.marketplaceNote(.swappa)),
            choices: [
                DetailChoice(title: "Turns on", value: .text("Turns on")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func reverbQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-music-spec",
                contextLabel: Marketplace.reverb.displayName,
                title: "Any model, year, or serial number?",
                detail: "Music gear needs exact model details before the price is reliable.",
                placeholder: "Model, year, serial...",
                systemImage: AppSymbol.Marketplace.music,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-music-working",
            contextLabel: Marketplace.reverb.displayName,
            title: "Does it work, and what comes with it?",
            detail: "Music gear listings need working condition and accessories.",
            placeholder: "Works, case, cables, power supply...",
            systemImage: AppSymbol.Marketplace.music,
            kind: .text(.marketplaceNote(.reverb)),
            choices: [
                DetailChoice(title: "Works", value: .text("Works")),
                DetailChoice(title: "Untested", value: .text("Untested")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func amazonQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-amazon-spec",
                contextLabel: Marketplace.amazon.displayName,
                title: "Is there a barcode or exact product page?",
                detail: "Amazon needs the matching product page, condition, and whether it is new or used.",
                placeholder: "Barcode, product page, new sealed...",
                systemImage: AppSymbol.Marketplace.cart,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "New with barcode", value: .text("New with barcode")),
                    DetailChoice(title: "Used or open box", value: .text("Used or open box")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-amazon-fit",
            contextLabel: Marketplace.amazon.displayName,
            title: "Can you list this on Amazon?",
            detail: "Some products need approval, a matched catalog page, or an Amazon listing account.",
            placeholder: "Approved, not sure, account ready...",
            systemImage: AppSymbol.Marketplace.verified,
            kind: .text(.marketplaceNote(.amazon)),
            choices: [
                DetailChoice(title: "Ready to list", value: .text("Amazon account is ready to list")),
                DetailChoice(title: "Not sure", value: .unknown),
                DetailChoice(title: "No account", value: .text("No Amazon listing account"))
            ]
        ))
        return questions
    }

    private static func shopifyQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers), item.category != .furniture {
            questions.append(DetailQuestion(
                id: "marketplace-shopify-spec",
                contextLabel: Marketplace.shopify.displayName,
                title: "What should the product page say?",
                detail: "Your own store needs clear specs, shipping, and a reason to trust the item.",
                placeholder: "Size, material, color, shipping...",
                systemImage: AppSymbol.Marketplace.cart,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-shopify-store",
            contextLabel: Marketplace.shopify.displayName,
            title: "Do you already have a store?",
            detail: "Shopify only helps when you can send people to your own storefront.",
            placeholder: "Have a store, need setup, pickup only...",
            systemImage: AppSymbol.Marketplace.cart,
            kind: .text(.marketplaceNote(.shopify)),
            choices: [
                DetailChoice(title: "Have a store", value: .text("Has Shopify store")),
                DetailChoice(title: "No store", value: .text("No Shopify store")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func bonanzaQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-bonanza-spec",
                contextLabel: Marketplace.bonanza.displayName,
                title: specQuestionTitle(for: item.category, marketplace: .bonanza),
                detail: "Bonanza needs straightforward search words and shipping details.",
                placeholder: sizePlaceholder(for: item.category),
                systemImage: specQuestionSymbol(for: item.category),
                kind: .text(.sizeOrModel),
                choices: specChoices(for: item.category)
            ))
        }

        questions.append(DetailQuestion(
            id: "marketplace-bonanza-shipping",
            contextLabel: Marketplace.bonanza.displayName,
            title: "Any shipping or bundle note?",
            detail: "A simple shipping note helps the listing read cleanly.",
            placeholder: "Ships USPS, bundle, item only...",
            systemImage: AppSymbol.Marketplace.package,
            kind: .text(.marketplaceNote(.bonanza)),
            choices: [
                DetailChoice(title: "Ships easily", value: .text("Ships easily")),
                DetailChoice(title: "No extra detail", value: .text("No extra detail")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        ))
        return questions
    }

    private static func tradingCardQuestions(for item: DetectedItem, answers: ItemDetailAnswers) -> [DetailQuestion] {
        var questions: [DetailQuestion] = []
        if shouldAskExactMarketplaceSpec(for: item, answers: answers) {
            questions.append(DetailQuestion(
                id: "marketplace-cards-spec",
                contextLabel: Marketplace.tcgplayer.displayName,
                title: "What set, number, or card condition do you know?",
                detail: "Trading cards need exact set and condition before price is reliable.",
                placeholder: "Set, card number, foil, condition...",
                systemImage: AppSymbol.Marketplace.cards,
                kind: .text(.sizeOrModel),
                choices: [
                    DetailChoice(title: "Sleeved", value: .text("Sleeved")),
                    DetailChoice(title: "I don't know", value: .unknown)
                ]
            ))
        }

        questions.append(generalMarketplaceQuestion(for: .tcgplayer, item: item, answers: answers))
        return questions
    }

    private static func generalMarketplaceQuestion(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> DetailQuestion {
        let needsFulfillment = answers.hasAnsweredOrSkipped(.largeOrFragile) == false &&
            shouldAskLargeOrFragile(for: item.category, marketplace: marketplace)
        return DetailQuestion(
            id: "marketplace-general-\(marketplace.rawValue)",
            contextLabel: marketplace.displayName,
            title: needsFulfillment ? "Can someone pick it up?" : "Anything this place needs?",
            detail: needsFulfillment
                ? "Pickup or delivery notes help avoid confusing messages."
                : "Add one detail a person on this marketplace would expect.",
            placeholder: needsFulfillment
                ? localPlaceholder(for: item.category)
                : "Pickup, shipping, size, model, or material...",
            systemImage: needsFulfillment ? AppSymbol.Marketplace.local : AppSymbol.Marketplace.cart,
            kind: .text(.marketplaceNote(marketplace)),
            choices: needsFulfillment ? localChoices(for: item.category) : [
                DetailChoice(title: "No extra detail", value: .text("No extra detail")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        )
    }

    private static func shouldAskExactMarketplaceSpec(for item: DetectedItem, answers: ItemDetailAnswers) -> Bool {
        guard answers.hasAnsweredOrSkipped(.sizeOrModel) == false else { return false }
        return item.category != .other
    }

    private static func ebaySpecDetail(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Model, storage, carrier, and working condition help match sold prices."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Size, brand, and material help people find the listing."
        case .collectibles, .art:
            return "Edition, maker marks, and condition help match sold prices."
        default:
            return "A model number, measurement, or maker mark can change the price."
        }
    }

    private static func localQuestionTitle(for category: Category) -> String {
        switch category {
        case .furniture, .home, .art, .tools, .sports, .music:
            return "Where can someone pick it up?"
        default:
            return "How should pickup work?"
        }
    }

    private static func whatnotSpecQuestionTitle(for category: Category) -> String {
        switch category {
        case .collectibles, .toys:
            return "What set, edition, or quantity is it?"
        case .clothing, .shoes, .bags:
            return "What size, brand, or style is it?"
        default:
            return "What exact item or quantity is it?"
        }
    }

    private static func localQuestionDetail(for category: Category, answers: ItemDetailAnswers) -> String {
        if answers.isLargeOrFragile || [.furniture, .home, .art, .tools, .sports, .music].contains(category) {
            return "A pickup area, stairs, or loading note keeps messages easier."
        }
        return "A pickup area or delivery note keeps local messages easier."
    }

    private static func localPlaceholder(for category: Category) -> String {
        switch category {
        case .furniture, .home, .art, .tools, .sports, .music:
            return "Near downtown, pickup only, can help load..."
        default:
            return "Near downtown, porch pickup, can deliver..."
        }
    }

    private static func whatnotPlaceholder(for category: Category) -> String {
        switch category {
        case .collectibles, .toys:
            return "Set, edition, lot count, sealed..."
        case .clothing, .shoes, .bags:
            return "Brand, size, style, condition..."
        default:
            return "Single item, bundle, condition..."
        }
    }

    private static func localChoices(for category: Category) -> [DetailChoice] {
        if [.furniture, .home, .art, .tools, .sports, .music].contains(category) {
            return [
                DetailChoice(title: "Pickup only", value: .text("Pickup only")),
                DetailChoice(title: "Can help load", value: .text("Can help load")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
        return [
            DetailChoice(title: "Local pickup", value: .text("Local pickup")),
            DetailChoice(title: "Can deliver", value: .text("Can deliver nearby")),
            DetailChoice(title: "I don't know", value: .unknown)
        ]
    }

    private static func vintageQuestionTitle(for category: Category) -> String {
        switch category {
        case .art:
            return "Is it signed, numbered, or framed?"
        case .home, .furniture:
            return "Do you know the age or material?"
        default:
            return "Is it vintage, handmade, or signed?"
        }
    }

    private static func brandPlaceholder(for category: Category) -> String {
        switch category {
        case .electronics:
            "Apple, Sony, Samsung..."
        case .clothing, .shoes, .bags, .jewelry:
            "Nike, Coach, Levi's..."
        case .music:
            "Fender, Yamaha, Gibson..."
        case .collectibles, .art, .home, .furniture:
            "Maker, artist, mark..."
        default:
            "Brand or maker..."
        }
    }

    private static func specQuestionTitle(for category: Category, marketplace: Marketplace?) -> String {
        if let marketplace {
            switch marketplace {
            case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy:
                return "What size or material is on the tag?"
            case .ebay, .swappa:
                return "What exact model or specs do you know?"
            default:
                break
            }
        }

        switch category {
        case .furniture, .home, .art:
            return "Any measurements or maker marks?"
        case .electronics:
            return "What exact model or specs do you know?"
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "What size or material is on the tag?"
        case .music:
            return "Any model, year, or serial number?"
        case .collectibles:
            return "Any set, edition, or number?"
        default:
            return "Any size, model, or useful detail?"
        }
    }

    private static func specQuestionDetail(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Storage, carrier, model, or whether it turns on can change the price."
        case .furniture, .home, .art:
            return "Dimensions and maker marks help match better comps."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Size, material, and measurements help the listing fit the right place."
        case .music:
            return "Model, year, serial, and working condition matter for music gear."
        case .collectibles:
            return "Edition, set, number, sealed status, or certificates can change value."
        default:
            return "One exact detail can make the search and listing better."
        }
    }

    private static func sizePlaceholder(for category: Category) -> String {
        switch category {
        case .furniture, .home, .art:
            "24 in tall, 18 x 30..."
        case .electronics:
            "iPhone 15, 128 GB, unlocked..."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            "Men's M, size 9, 12 x 8..."
        case .music:
            "Model, year, serial..."
        case .collectibles:
            "Set name, edition, card number..."
        default:
            "Model, size, measurements..."
        }
    }

    private static func specQuestionSymbol(for category: Category) -> String {
        switch category {
        case .electronics:
            return AppSymbol.Item.electronics
        case .furniture, .home, .art:
            return "ruler"
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return AppSymbol.Action.category
        case .music:
            return AppSymbol.Item.music
        case .collectibles:
            return "number.circle.fill"
        default:
            return category.placeholderSystemImage
        }
    }

    private static func specChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .electronics:
            return [
                DetailChoice(title: "Turns on", value: .text("Turns on")),
                DetailChoice(title: "Won't turn on", value: .text("Does not turn on")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .furniture, .home, .art:
            return [
                DetailChoice(title: "I can measure it", value: .text("Measurements available")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return [
                DetailChoice(title: "No size tag", value: .text("No visible size tag")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        case .collectibles:
            return [
                DetailChoice(title: "Sealed", value: .text("Sealed")),
                DetailChoice(title: "Opened", value: .text("Opened")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        default:
            return [
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
    }

    private static func whatnotChoices(for category: Category) -> [DetailChoice] {
        switch category {
        case .collectibles, .toys:
            return [
                DetailChoice(title: "Sealed", value: .text("Sealed")),
                DetailChoice(title: "Opened", value: .text("Opened")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        default:
            return [
                DetailChoice(title: "Single item", value: .text("Single item")),
                DetailChoice(title: "Lot or bundle", value: .text("Lot or bundle")),
                DetailChoice(title: "I don't know", value: .unknown)
            ]
        }
    }

    private static func includedQuestionDetail(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Charger, cables, box, or remote can change what people will pay."
        case .tools:
            return "Battery, charger, case, and bits matter for tools."
        case .music:
            return "Case, cable, strap, power supply, or manual can help."
        case .collectibles:
            return "Box, certificate, sleeve, or paperwork can change value."
        default:
            return "Accessories, packaging, and manuals can help the listing."
        }
    }

    private static func largeOrFragileTitle(for category: Category) -> String {
        switch category {
        case .furniture:
            return "Is it big or pickup-only?"
        case .art, .home:
            return "Would shipping be risky?"
        default:
            return "Is it big, heavy, or fragile?"
        }
    }

    private static func assistantSummaryRows(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers,
        savedRows: [SavedDetailRow]
    ) -> [AssistantSummaryRow] {
        [
            AssistantSummaryRow(
                title: "We know",
                value: knownAssistantSummary(context: context, savedRows: savedRows),
                systemImage: "checkmark.circle.fill",
                tint: Color.brand.primaryText
            ),
            AssistantSummaryRow(
                title: "Still unsure",
                value: unresolvedAssistantSummary(context: context, answers: answers),
                systemImage: "questionmark.circle.fill",
                tint: Color.brand.foregroundSecondary
            )
        ]
    }

    private static func assistantState(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers,
        currentQuestion: DetailQuestion?,
        targetedScanRequest: TargetedScanRequest?
    ) -> AssistantState? {
        guard currentQuestion != nil || targetedScanRequest != nil else { return nil }
        return AssistantState(
            likely: assistantLikelyState(context: context, answers: answers),
            stillChecking: assistantStillCheckingState(context: context, answers: answers),
            nextClue: assistantNextClueState(
                currentQuestion: currentQuestion,
                targetedScanRequest: targetedScanRequest
            )
        )
    }

    private static func assistantLikelyState(context: ItemQuestionsContext, answers: ItemDetailAnswers) -> String {
        let confirmedMatch = answers.sizeOrModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if confirmedMatch.isEmpty == false {
            return String(confirmedMatch.prefix(80))
        }
        if let profileSummary = context.analysis?.identificationProfile?.primaryKnownSummary {
            return String(profileSummary.prefix(80))
        }
        if let strongestMatch = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
            .sorted(by: { $0.confidence > $1.confidence })
            .first {
            return strongestMatch.name
        }
        if context.item.category != .other {
            return String.localizedFormat("%@ in %@", context.item.name, context.item.category.display)
        }
        return context.item.name
    }

    private static func assistantStillCheckingState(context: ItemQuestionsContext, answers: ItemDetailAnswers) -> String {
        if let marketplace = context.preferredMarketplace,
           marketplaceKeepCheckingQuestion(
            context: context,
            marketplace: marketplace,
            answers: answers
           ) != nil {
            return String.localizedFormat("One %@ listing detail.".localized, marketplace.displayName)
        }
        let likelyMatches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        if likelyMatches.count > 1, answers.hasAnsweredOrSkipped(.sizeOrModel) == false {
            return "Which possible match fits the photo.".localized
        }
        if let profileSummary = context.analysis?.identificationProfile?.primaryUnresolvedSummary {
            return String(profileSummary.prefix(100))
        }
        if let missingFact = context.analysis?.highestImpactMissingFact,
           answers.hasAnsweredOrSkipped(detailFieldKey(for: missingFact.detailKind)) == false {
            return missingFact.displayValue
        }
        if shouldAskMoreIdentificationHelp(for: context), answers.hasAnsweredOrSkipped(.extraDetails) == false {
            return "One visible label, mark, material, or number.".localized
        }
        return context.preferredMarketplace == nil
            ? "Nothing major before price research.".localized
            : "Nothing major before writing.".localized
    }

    private static func assistantNextClueState(
        currentQuestion: DetailQuestion?,
        targetedScanRequest: TargetedScanRequest?
    ) -> String {
        if let targetedScanRequest {
            return targetedScanRequest.title
        }
        if let currentQuestion {
            return currentQuestion.title
        }
        return "Ready to continue.".localized
    }

    private static func knownAssistantSummary(
        context: ItemQuestionsContext,
        savedRows: [SavedDetailRow]
    ) -> String {
        if let savedRow = savedRows.first(where: { row in
            row.value.localizedCaseInsensitiveCompare("I don't know".localized) != .orderedSame
        }) {
            return "\(savedRow.title.localized): \(String(savedRow.value.prefix(80)))"
        }
        if let profileSummary = context.analysis?.identificationProfile?.primaryKnownSummary {
            return String(profileSummary.prefix(100))
        }
        if let fact = context.analysis?.itemFacts
            .compactMap({ $0.sanitizedForDisplay() })
            .filter({ $0.confidence >= 0.7 })
            .first {
            return "\(fact.label): \(String(fact.value.prefix(80)))"
        }
        if context.item.category != .other {
            return String.localizedFormat("Category: %@".localized, context.item.category.display)
        }
        return context.item.name
    }

    private static func unresolvedAssistantSummary(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> String {
        if let marketplace = context.preferredMarketplace,
           marketplaceKeepCheckingQuestion(
            context: context,
            marketplace: marketplace,
            answers: answers
           ) != nil {
            return String.localizedFormat("One %@ detail could still help.".localized, marketplace.displayName)
        }
        let likelyMatches = uniqueLikelyMatches(from: context.analysis?.likelyMatches ?? [])
        if likelyMatches.count > 1, answers.hasAnsweredOrSkipped(.sizeOrModel) == false {
            return "A few similar matches are still possible.".localized
        }
        if let profileSummary = context.analysis?.identificationProfile?.primaryUnresolvedSummary {
            return String(profileSummary.prefix(120))
        }
        if let missingFact = context.analysis?.highestImpactMissingFact,
           answers.hasAnsweredOrSkipped(detailFieldKey(for: missingFact.detailKind)) == false {
            return String.localizedFormat("Check %@ only if you can see it.".localized, missingFact.displayValue)
        }
        if shouldAskMoreIdentificationHelp(for: context), answers.hasAnsweredOrSkipped(.extraDetails) == false {
            return "A clearer label or mark could improve the ID.".localized
        }
        if context.preferredMarketplace == nil {
            return "No major gaps before marketplace research.".localized
        }
        return "No major gaps before writing this post.".localized
    }

    private static func assistantKeepCheckingQuestion(
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        if let marketplace = context.preferredMarketplace,
           let question = marketplaceKeepCheckingQuestion(
            context: context,
            marketplace: marketplace,
            answers: answers
           ) {
            return question
        }
        if let question = identityClueQuestion(for: context, answers: answers) {
            return question
        }
        if let question = likelyMatchQuestion(for: context, answers: answers) {
            return question
        }
        if let question = valuableVersionQuestion(for: context, answers: answers) {
            return question
        }
        if let question = analysisQuestion(for: context), question.isAnswered(in: answers) == false {
            return question
        }
        if isHighDetailCategory(context.item.category),
           answers.hasAnsweredOrSkipped(.extraDetails) == false {
            return extraDetailQuestion(for: context.item.category)
        }
        return nil
    }

    private static func assistantConversationCue(
        for question: DetailQuestion,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> String? {
        if question.isUnknownFollowUp {
            return unknownAssistantCue(for: question, item: item, marketplace: marketplace)
        }
        if question.evidenceSummary != nil {
            return "BuySell found market clues. This answer helps match the right sold items."
        }
        if question.id == "analysis-likely-match" {
            return "Pick one only if it really looks like yours. It is fine to be unsure."
        }
        switch question.kind {
        case .text(let field):
            return assistantCue(for: field, item: item, marketplace: marketplace)
        case .largeOrFragile:
            return "This decides whether shipping or local pickup makes more sense."
        }
    }

    private static func unknownAssistantCue(
        for question: DetailQuestion,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> String {
        guard case .text(let field) = question.kind else {
            return "No problem. BuySell can keep going with less certainty."
        }
        switch field {
        case .labelOrBrand:
            return "No problem. Check for any logo, tag, stamp, signature, or sticker."
        case .sizeOrModel:
            return "No problem. A model, size, serial, year, or material is enough if you see one."
        case .flaws:
            return "No problem. Look for the worst visible spot, then pick the closest choice."
        case .included:
            return "No problem. Just check whether a box, charger, case, papers, or parts are nearby."
        case .extraDetails:
            return unknownExtraAssistantCue(for: item.category)
        case .marketplaceNote(let selectedMarketplace):
            let resolvedMarketplace = marketplace ?? selectedMarketplace
            return String.localizedFormat(
                "No problem. BuySell only needs one practical %@ detail if you know it.".localized,
                resolvedMarketplace.displayName
            )
        }
    }

    private static func assistantCue(
        for field: Field,
        item: DetectedItem,
        marketplace: Marketplace?
    ) -> String {
        switch field {
        case .labelOrBrand:
            return "A visible name, logo, tag, stamp, or signature can change the search."
        case .sizeOrModel:
            return specAssistantCue(for: item.category)
        case .flaws:
            return "Condition changes price fast, so only say what a buyer can see."
        case .included:
            return "Boxes, chargers, cases, papers, and parts can change what it is worth."
        case .extraDetails:
            return extraAssistantCue(for: item.category)
        case .marketplaceNote(let selectedMarketplace):
            let resolvedMarketplace = marketplace ?? selectedMarketplace
            return String.localizedFormat(
                "BuySell uses this to make the %@ listing fit that marketplace.".localized,
                resolvedMarketplace.displayName
            )
        }
    }

    private static func specAssistantCue(for category: Category) -> String {
        switch category {
        case .electronics:
            return "Exact model, storage, carrier, and power status can change the price."
        case .clothing, .shoes, .bags, .jewelry, .kids:
            return "Size, material, style code, and tag details help buyers trust it."
        case .furniture, .home, .art:
            return "Measurements, material, maker marks, and signatures help separate common from valuable."
        case .collectibles, .toys, .media, .books:
            return "Edition, year, set number, sealed status, and certificates can change value."
        case .tools, .music:
            return "Model, serial, working status, and included parts help match real sold items."
        default:
            return "One exact detail helps BuySell search better sold matches."
        }
    }

    private static func extraAssistantCue(for category: Category) -> String {
        switch category {
        case .collectibles, .toys, .media, .books:
            return "Older versions, limited editions, signatures, or numbers can matter a lot."
        case .jewelry, .art, .home, .furniture:
            return "Weight, material, stamps, maker marks, and signatures can separate ordinary from valuable."
        case .electronics, .tools, .music:
            return "Serials, model plates, working status, and accessories can move the price."
        default:
            return "Only add something visible, measured, or confidently known."
        }
    }

    private static func unknownExtraAssistantCue(for category: Category) -> String {
        switch category {
        case .collectibles, .toys, .media, .books:
            return "No problem. Look for a year, edition, set number, signature, or sealed package."
        case .jewelry, .art, .home, .furniture:
            return "No problem. Weight, material, stamps, marks, or signatures are the best clues."
        case .electronics, .tools, .music:
            return "No problem. Check for a model plate, serial number, power light, or included parts."
        default:
            return "No problem. Check whether it feels heavy, shows a stamp, or has a material clue."
        }
    }

    private static func marketplaceKeepCheckingQuestion(
        context: ItemQuestionsContext,
        marketplace: Marketplace,
        answers: ItemDetailAnswers
    ) -> DetailQuestion? {
        if let evidenceQuestion = marketplaceEvidenceQuestion(
            for: context,
            marketplace: marketplace,
            answers: answers
        ), evidenceQuestion.isAnswered(in: answers) == false {
            return evidenceQuestion
        }

        return marketplaceQuestions(for: marketplace, item: context.item, answers: answers)
            .first { $0.isAnswered(in: answers) == false }
    }

    private static func detailFieldKey(for missingFactKind: MissingFactDetailKind) -> ItemDetailFieldKey {
        switch missingFactKind {
        case .brand:
            .labelOrBrand
        case .spec:
            .sizeOrModel
        case .included:
            .included
        case .condition:
            .flaws
        case .shipping:
            .largeOrFragile
        }
    }

    enum Field: Hashable {
        case labelOrBrand
        case sizeOrModel
        case flaws
        case included
        case extraDetails
        case marketplaceNote(Marketplace)

        var detailKey: ItemDetailFieldKey {
            switch self {
            case .labelOrBrand:
                .labelOrBrand
            case .sizeOrModel:
                .sizeOrModel
            case .flaws:
                .flaws
            case .included:
                .included
            case .extraDetails:
                .extraDetails
            case .marketplaceNote:
                .marketplaceNotes
            }
        }
    }
}

private struct DetailQuestion: Identifiable, Hashable {
    let id: String
    let contextLabel: String
    let title: String
    let detail: String
    let placeholder: String
    let systemImage: String
    let kind: QuestionKind
    let choices: [DetailChoice]
    var allowsReferenceExamples = false
    var evidenceSummary: QuestionEvidenceSummary? = nil
    var unknownFollowUp: DetailQuestionFallback? = nil
    var isUnknownFollowUp = false

    func isAnswered(in answers: ItemDetailAnswers) -> Bool {
        switch kind {
        case .text(let field):
            if case .marketplaceNote(let marketplace) = field {
                return answers.hasMarketplaceNoteOrSkipped(marketplace)
            }
            return answers.hasAnsweredOrSkipped(field.detailKey)
        case .largeOrFragile:
            return answers.hasAnsweredOrSkipped(.largeOrFragile)
        }
    }

    var analyticsKind: String {
        switch kind {
        case .text(let field):
            switch field {
            case .labelOrBrand:
                "brand"
            case .sizeOrModel:
                "size_or_model"
            case .flaws:
                "flaws"
            case .included:
                "included"
            case .extraDetails:
                "extra_details"
            case .marketplaceNote:
                "marketplace_note"
            }
        case .largeOrFragile:
            "large_or_fragile"
        }
    }

    var searchText: String {
        [
            id,
            contextLabel,
            title,
            detail,
            placeholder,
            choices.map(\.title).joined(separator: " "),
            unknownFollowUp?.title ?? "",
            unknownFollowUp?.detail ?? "",
            unknownFollowUp?.choices.map(\.title).joined(separator: " ") ?? ""
        ]
            .joined(separator: " ")
            .lowercased()
    }
}

private struct AdaptiveQuestionScore: Hashable {
    let identityInformationGain: Int
    let valuableVariantDetection: Int
    let likelyMatchDisambiguation: Int
    let pricingImpact: Int
    let marketplaceEligibilityImpact: Int
    let buyerTrustImpact: Int
    let userEffort: Int
    let answerDifficulty: Int
    let repetitionPenalty: Int

    var total: Int {
        identityInformationGain
            + valuableVariantDetection
            + likelyMatchDisambiguation
            + pricingImpact
            + marketplaceEligibilityImpact
            + buyerTrustImpact
            - userEffort
            - answerDifficulty
            - repetitionPenalty
    }
}

private struct QuestionEvidenceSummary: Hashable {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
}

private struct QuestionImpactRow: Identifiable, Hashable {
    let title: String
    let detail: String
    let systemImage: String

    var id: String {
        "\(title)-\(detail)"
    }
}

private struct DetailQuestionFallback: Hashable {
    let id: String
    let contextLabel: String
    let title: String
    let detail: String
    let placeholder: String
    let systemImage: String
    let kind: QuestionKind
    let choices: [DetailChoice]

    func makeQuestion() -> DetailQuestion {
        DetailQuestion(
            id: id,
            contextLabel: contextLabel,
            title: title,
            detail: detail,
            placeholder: placeholder,
            systemImage: systemImage,
            kind: kind,
            choices: choices,
            isUnknownFollowUp: true
        )
    }
}

private struct MarketplacePlaybookQuestionNeed: Hashable {
    let displayField: String
    let field: ItemQuestionsSheet.Field
    let placeholder: String
    let systemImage: String
    let choices: [DetailChoice]
}

private struct ValuableVersionPrompt: Hashable {
    let title: String
    let detail: String
    let placeholder: String
    let systemImage: String
    let choices: [DetailChoice]
    let followUpTitle: String
    let followUpChoices: [DetailChoice]
}

private struct ProfileDrivenQuestionSeed: Hashable {
    let idSuffix: String
    let source: String
    let field: ItemQuestionsSheet.Field
    let title: String
    let detail: String
    let placeholder: String
    let systemImage: String
    let choices: [DetailChoice]
    let followUpTitle: String
    let followUpChoices: [DetailChoice]
    let scanRequest: TargetedScanRequest?
}

private enum QuestionKind: Hashable {
    case text(ItemQuestionsSheet.Field)
    case largeOrFragile

    var isIdentityField: Bool {
        switch self {
        case .text(.labelOrBrand), .text(.sizeOrModel), .text(.extraDetails):
            return true
        case .text(.flaws), .text(.included), .text(.marketplaceNote(_)), .largeOrFragile:
            return false
        }
    }
}

private struct SavedDetailRow: Identifiable, Hashable {
    let title: String
    let value: String
    let systemImage: String
    let target: SavedDetailTarget

    var id: String {
        "\(target)-\(title)-\(value)"
    }
}

private struct AssistantSummaryRow: Identifiable {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var id: String {
        "\(title)-\(value)"
    }
}

private struct AssistantState: Equatable {
    let likely: String
    let stillChecking: String
    let nextClue: String
}

private enum SavedDetailTarget: Hashable {
    case field(ItemQuestionsSheet.Field)
    case largeOrFragile
}

private struct DetailChoice: Identifiable, Hashable {
    let title: String
    let value: DetailChoiceValue
    let localizesTitle: Bool

    init(title: String, value: DetailChoiceValue, localizesTitle: Bool = true) {
        self.title = title
        self.value = value
        self.localizesTitle = localizesTitle
    }

    var id: String { "\(title)-\(value)-\(localizesTitle)" }

    var displayTitle: String {
        localizesTitle ? title.localized : title
    }

    var systemImage: String {
        switch value {
        case .targetedScan:
            return AppSymbol.Flow.snapPhotoCompact
        case .clueScan:
            return AppSymbol.Flow.snapPhotoCompact
        case .largeFragile(let isLargeOrFragile):
            return isLargeOrFragile ? "shippingbox.fill" : "checkmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        case .text:
            return Self.systemImage(for: title)
        }
    }

    var isUnknown: Bool {
        if case .unknown = value {
            return true
        }
        return false
    }

    var isTargetedScan: Bool {
        if case .targetedScan = value {
            return true
        }
        return false
    }

    func scanningVisibleClue(with request: TargetedScanRequest) -> DetailChoice {
        guard let textValue, Self.isVisibleIdentifierClue(title: title, value: textValue) else {
            return self
        }
        return DetailChoice(
            title: title,
            value: .clueScan(Self.scanRequest(forVisibleClue: title, fallback: request), textValue),
            localizesTitle: localizesTitle
        )
    }

    private var textValue: String? {
        if case .text(let value) = value {
            return value
        }
        return nil
    }

    private static func systemImage(for title: String) -> String {
        let lowercased = title.lowercased()
        if lowercased.containsAny(of: ["scan", "photo", "camera"]) {
            return AppSymbol.Flow.snapPhotoCompact
        }
        if lowercased.containsAny(of: ["yes", "works", "powers on", "included", "sealed"]) {
            return "checkmark.circle.fill"
        }
        if lowercased.containsAny(of: ["no ", "no tag", "no label", "no mark", "no stamp", "none"]) {
            return "xmark.circle.fill"
        }
        if lowercased.containsAny(of: ["model", "serial", "number", "sku", "style code", "upc", "barcode"]) {
            return "barcode.viewfinder"
        }
        if lowercased.containsAny(of: ["tag", "label", "logo", "brand", "size"]) {
            return "tag.fill"
        }
        if lowercased.containsAny(of: ["mark", "stamp", "signature", "signed", "hallmark", "certificate", "authentic"]) {
            return "seal.fill"
        }
        if lowercased.containsAny(of: ["box", "case", "charger", "battery", "parts", "accessory", "laces"]) {
            return "shippingbox.fill"
        }
        if lowercased.containsAny(of: ["damage", "scratched", "stain", "wear", "repair", "flaw"]) {
            return "exclamationmark.triangle.fill"
        }
        if lowercased.containsAny(of: ["material", "leather", "wool", "sterling", "gold", "heavy"]) {
            return "sparkle.magnifyingglass"
        }
        if lowercased.containsAny(of: ["measure", "dimension", "case size", "storage", "capacity"]) {
            return "ruler"
        }
        return "circle.fill"
    }

    private static func isVisibleIdentifierClue(title: String, value: String) -> Bool {
        let lowercased = "\(title) \(value)".lowercased()
        if lowercased.containsAny(of: ["no visible", "no label", "no tag", "no mark", "no stamp", "no clue", "no exact", "none"]) {
            return false
        }
        let visualSignals = [
            "visible", "shown", "label", "tag", "logo", "plate", "serial",
            "model", "barcode", "upc", "sku", "style code", "number",
            "mark", "stamp", "signature", "signed", "hallmark", "certificate",
            "edition", "settings screen", "box label"
        ]
        return lowercased.containsAny(of: visualSignals)
    }

    private static func scanRequest(forVisibleClue title: String, fallback: TargetedScanRequest) -> TargetedScanRequest {
        let prompt = scanPrompt(forVisibleClue: title, fallback: fallback.prompt)
        return TargetedScanRequest(
            prompt: prompt,
            benefit: fallback.benefit,
            role: fallback.role
        )
    }

    private static func scanPrompt(forVisibleClue title: String, fallback: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTitle.isEmpty == false else { return fallback }
        let lowercased = cleanTitle.lowercased()
        if lowercased.contains("screen") {
            return "Scan the \(cleanTitle.lowercased())."
        }
        if lowercased.containsAny(of: ["tag", "label", "plate", "mark", "stamp", "signature", "hallmark", "barcode", "serial", "sku", "style code", "edition", "number"]) {
            return "Scan the \(cleanTitle.lowercased())."
        }
        return fallback
    }
}

private enum DetailChoiceValue: Hashable {
    case text(String)
    case largeFragile(Bool)
    case targetedScan(TargetedScanRequest)
    case clueScan(TargetedScanRequest, String)
    case unknown
}

private struct PrioritizedMissingFact: Hashable {
    let displayValue: String
    let detailKind: MissingFactDetailKind
    let priority: Int

    init?(_ value: String) {
        let cleanValue = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard cleanValue.isEmpty == false else { return nil }

        displayValue = String(cleanValue.prefix(60))
        detailKind = Self.detailKind(for: cleanValue)
        priority = Self.priority(for: detailKind)
    }

    private static func detailKind(for value: String) -> MissingFactDetailKind {
        let lowercased = value.lowercased()
        if ["brand", "maker", "label", "artist", "mark", "logo"].contains(where: lowercased.contains) {
            return .brand
        }
        if ["box", "charger", "remote", "accessory", "packaging", "certificate", "manual", "case", "cable"].contains(where: lowercased.contains) {
            return .included
        }
        if ["flaw", "damage", "scratch", "stain", "wear", "working", "works", "condition", "missing part"].contains(where: lowercased.contains) {
            return .condition
        }
        if ["weight", "pickup", "fragile", "large", "heavy"].contains(where: lowercased.contains) {
            return .shipping
        }
        return .spec
    }

    private static func priority(for kind: MissingFactDetailKind) -> Int {
        switch kind {
        case .brand:
            100
        case .spec:
            90
        case .included:
            80
        case .condition:
            70
        case .shipping:
            60
        }
    }
}

private enum MissingFactDetailKind: Hashable {
    case brand
    case spec
    case included
    case condition
    case shipping
}

private extension AnalyzeIntelligence {
    var highestImpactMissingFact: PrioritizedMissingFact? {
        missingFacts
            .compactMap(PrioritizedMissingFact.init)
            .sorted { left, right in
                if left.priority == right.priority {
                    return left.displayValue.count < right.displayValue.count
                }
                return left.priority > right.priority
            }
            .first
    }
}

private extension Array where Element == String {
    func containsFact(namedLike needles: [String]) -> Bool {
        contains { fact in
            let lowercased = fact.lowercased()
            return needles.contains { lowercased.contains($0) }
        }
    }
}

private extension Array where Element == AnalyzeItemFact {
    func containsFact(namedLike needles: [String]) -> Bool {
        contains { fact in
            guard fact.confidence >= 0.7 else { return false }
            let searchable = "\(fact.label) \(fact.value)".lowercased()
            return needles.contains { searchable.contains($0) }
        }
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}
