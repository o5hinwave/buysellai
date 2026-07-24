import SwiftUI
import UIKit

struct ItemQuestionsSheet: View {
    let context: ItemQuestionsContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var answers: ItemDetailAnswers
    @State private var questions: [DetailQuestion]
    @State private var currentQuestionIndex = 0
    @FocusState private var focusedField: Field?

    init(context: ItemQuestionsContext) {
        self.context = context
        let initialAnswers = context.answers ?? ItemDetailAnswers()
        _answers = State(initialValue: initialAnswers)
        _questions = State(initialValue: Self.makeQuestions(context: context, answers: initialAnswers))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    itemHeader
                }

                if let currentQuestion {
                    Section {
                        questionCard(currentQuestion)
                    } header: {
                        Text("One quick thing".localized)
                    } footer: {
                        Text("Answer if you know it. Skip if you don't.".localized)
                    }
                    .accessibilitySortPriority(3)
                } else {
                    Section {
                        readyCard
                    }
                    .accessibilitySortPriority(3)
                }

                if savedDetailRows.isEmpty == false {
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
            .navigationTitle("Tiny details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip all".localized) {
                        continueWithoutDetails()
                    }
                    .accessibilityLabel("Skip all".localized)
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
                Text("Answer only what you know.".localized)
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

    private func questionCard(_ question: DetailQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: question.systemImage)
                        .brandSymbol(.controlIcon)
                        .foregroundStyle(Color.brand.primaryText)
                        .accessibilityHidden(true)

                    Text(question.contextLabel.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.mutedForeground)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)
                }

                Text(question.title.localized)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text(question.detail.localized)
                    .font(.body)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            questionInput(question)

            if question.choices.isEmpty == false {
                choiceGrid(for: question)
            }

            ProgressView(value: questionProgress)
                .tint(Color.brand.primary)
                .accessibilityLabel("Question progress".localized)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
    }

    private var readyCard: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Ready to write".localized)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text("BuySell has enough details for this marketplace.".localized)
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
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
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
                    Text(choice.title.localized)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color.brand.foregroundSecondary)
                .accessibilityLabel(choice.title.localized)
            }
        }
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

    private var bottomAction: some View {
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
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
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
            .controlSize(.large)
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
        .controlSize(.large)
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
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel(primaryActionTitle.localized)
    }

    private var currentQuestion: DetailQuestion? {
        guard questions.isEmpty == false else { return nil }
        return questions[min(currentQuestionIndex, questions.count - 1)]
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
        return "Skip anything you do not know."
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 260 : 170
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
        switch (question.kind, choice.value) {
        case (.text(let field), .text(let value)):
            setAnswer(value, for: field)
        case (.text, .unknown):
            markQuestionHandled(question)
        case (.text, .largeFragile):
            break
        case (.largeOrFragile, .largeFragile(let value)):
            answers.isLargeOrFragile = value
            answers.markAnswered(.largeOrFragile)
        case (.largeOrFragile, .unknown):
            answers.isLargeOrFragile = false
            answers.markAnswered(.largeOrFragile)
        case (.largeOrFragile, .text):
            break
        }
        advanceOrContinue(emitsFeedback: false)
    }

    private func advanceOrContinue(emitsFeedback: Bool = true) {
        focusedField = nil
        if emitsFeedback {
            Haptics.impact(isLastQuestion ? .medium : .light)
        }
        if isLastQuestion {
            continueWithDetails()
        } else {
            currentQuestionIndex = min(currentQuestionIndex + 1, questions.count - 1)
        }
    }

    private func skipQuestion() {
        focusedField = nil
        Haptics.impact(.light)
        if let currentQuestion {
            markQuestionHandled(currentQuestion)
        }
        if isLastQuestion {
            continueWithDetails()
        } else {
            currentQuestionIndex = min(currentQuestionIndex + 1, questions.count - 1)
        }
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
        Haptics.impact(.light)
        currentQuestionIndex = max(currentQuestionIndex - 1, 0)
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
        if let preferredMarketplace = context.preferredMarketplace {
            appStore.presentListing(
                item: context.item,
                imageData: context.imageData,
                marketplace: preferredMarketplace,
                details: details
            )
        } else {
            appStore.presentMarketplacePicker(
                item: context.item,
                imageData: context.imageData,
                details: details,
                analysis: context.analysis
            )
        }
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
            marketplaceQuestions(for: marketplace, item: context.item, answers: answers).forEach { add($0) }
            add(analysisQuestion(for: context))
            if shouldAskLargeOrFragile(for: context.item.category, marketplace: marketplace) {
                add(largeOrFragileQuestion(for: context.item.category))
            }
            return Array(questions.prefix(3))
        }
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

        let limit = context.preferredMarketplace == nil ? 4 : 5
        let limitedQuestions = Array(questions.prefix(limit))
        return limitedQuestions
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

    private static func marketplaceQuestion(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> DetailQuestion {
        marketplaceQuestions(for: marketplace, item: item, answers: answers).first
            ?? generalMarketplaceQuestion(for: marketplace, item: item, answers: answers)
    }

    private static func marketplaceQuestions(
        for marketplace: Marketplace,
        item: DetectedItem,
        answers: ItemDetailAnswers
    ) -> [DetailQuestion] {
        switch marketplace {
        case .ebay:
            return ebayQuestions(for: item, answers: answers)
        case .facebook, .craigslist, .offerup, .nextdoor:
            return [localQuestion(for: marketplace, item: item, answers: answers)]
        case .poshmark, .depop, .vinted, .vestiaire, .therealreal, .grailed, .curtsy:
            return fashionQuestions(for: marketplace, item: item, answers: answers)
        case .etsy, .chairish, .rubylane:
            return vintageQuestions(for: marketplace, item: item, answers: answers)
        case .stockx, .goat:
            return authenticatedGoodsQuestions(for: marketplace, item: item, answers: answers)
        case .swappa:
            return swappaQuestions(for: item, answers: answers)
        case .reverb:
            return reverbQuestions(for: item, answers: answers)
        case .tcgplayer:
            return tradingCardQuestions(for: item, answers: answers)
        default:
            return [generalMarketplaceQuestion(for: marketplace, item: item, answers: answers)]
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
}

private enum QuestionKind: Hashable {
    case text(ItemQuestionsSheet.Field)
    case largeOrFragile
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

private enum SavedDetailTarget: Hashable {
    case field(ItemQuestionsSheet.Field)
    case largeOrFragile
}

private struct DetailChoice: Identifiable, Hashable {
    let title: String
    let value: DetailChoiceValue

    var id: String { "\(title)-\(value)" }

    var isUnknown: Bool {
        if case .unknown = value {
            return true
        }
        return false
    }
}

private enum DetailChoiceValue: Hashable {
    case text(String)
    case largeFragile(Bool)
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
