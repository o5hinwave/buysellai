import SwiftUI
import UIKit

struct ItemQuestionsSheet: View {
    let context: ItemQuestionsContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var answers: ItemDetailAnswers
    @FocusState private var focusedField: Field?

    init(context: ItemQuestionsContext) {
        self.context = context
        _answers = State(initialValue: context.answers ?? ItemDetailAnswers())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    itemHeader
                }

                if smartPrompts.isEmpty == false {
                    Section {
                        ForEach(smartPrompts) { prompt in
                            SmartPromptRow(prompt: prompt)
                        }
                    } header: {
                        Text("Check if you know it".localized)
                    } footer: {
                        Text("These help BuySell search real comps and write the listing without guessing.".localized)
                    }
                    .accessibilitySortPriority(3)
                }

                Section {
                    questionField(
                        title: "Brand, maker, or label",
                        placeholder: brandPlaceholder,
                        text: $answers.labelOrBrand,
                        field: .labelOrBrand
                    )

                    questionField(
                        title: sizeFieldTitle,
                        placeholder: sizePlaceholder,
                        text: $answers.sizeOrModel,
                        field: .sizeOrModel
                    )

                    questionField(
                        title: "Flaws or damage",
                        placeholder: "Scratch, stain, missing piece...",
                        text: $answers.flaws,
                        field: .flaws
                    )

                    questionField(
                        title: "What comes with it",
                        placeholder: "Box, charger, remote...",
                        text: $answers.included,
                        field: .included
                    )

                    questionField(
                        title: "Anything else",
                        placeholder: extraPlaceholder,
                        text: $answers.extraDetails,
                        field: .extraDetails
                    )

                    Toggle(isOn: $answers.isLargeOrFragile) {
                        Label("Big, heavy, or fragile".localized, systemImage: "shippingbox")
                            .foregroundStyle(Color.brand.foreground)
                    }
                    .tint(Color.brand.primary)
                    .accessibilityHint("Helps prefer local pickup when shipping would be a pain.".localized)
                } header: {
                    Text("Add what you know".localized)
                } footer: {
                    Text("Skip anything you do not know.".localized)
                }
                .accessibilitySortPriority(2)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
            .navigationTitle("A few details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip".localized) {
                        continueWithoutDetails()
                    }
                    .accessibilityLabel("Skip".localized)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done".localized) {
                            focusedField = nil
                        }
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
            PhotoThumbnail(data: context.imageData, size: 64)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("BuySell found".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                Text(context.item.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tiny answers make better searches.".localized)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", "BuySell found".localized, context.item.name))
        .accessibilitySortPriority(4)
    }

    private func questionField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)

            TextField(placeholder.localized, text: text, axis: .vertical)
                .lineLimit(1...3)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: field)
                .accessibilityLabel(title.localized)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var bottomAction: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                continueWithDetails()
            } label: {
                Label(primaryActionTitle.localized, systemImage: "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel(primaryActionTitle.localized)

            Text("BuySell searches real marketplace info next.".localized)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
    }

    private var primaryActionTitle: String {
        context.preferredMarketplace == nil ? "Find best place" : "Write listing"
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 220 : 150
    }

    private var brandPlaceholder: String {
        switch context.item.category {
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

    private var sizeFieldTitle: String {
        switch context.item.category {
        case .furniture, .home, .art:
            "Measurements or model"
        case .electronics:
            "Model, storage, or specs"
        case .clothing, .shoes, .bags, .jewelry, .kids:
            "Size or measurements"
        case .music:
            "Model, year, or serial"
        case .collectibles:
            "Set, edition, or number"
        default:
            "Size, model, or details"
        }
    }

    private var sizePlaceholder: String {
        switch context.item.category {
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

    private var extraPlaceholder: String {
        if let firstPrompt = smartPrompts.first?.title {
            return firstPrompt
        }
        return "Anything a buyer would ask..."
    }

    private var smartPrompts: [SmartPrompt] {
        var prompts: [SmartPrompt] = []
        let missingFacts = context.analysis?.missingFacts ?? []
        for fact in missingFacts.prefix(2) {
            let title = fact.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { continue }
            prompts.append(SmartPrompt(title: String.localizedFormat("Check %@", title), systemImage: "text.magnifyingglass"))
        }

        if let categoryPrompt, prompts.contains(where: { $0.title == categoryPrompt.title }) == false {
            prompts.append(categoryPrompt)
        }

        return Array(prompts.prefix(3))
    }

    private var categoryPrompt: SmartPrompt? {
        switch context.item.category {
        case .electronics:
            SmartPrompt(title: "Find the exact model or storage", systemImage: "cpu")
        case .furniture:
            SmartPrompt(title: "Measure width, height, and depth", systemImage: "ruler")
        case .clothing, .shoes, .bags, .kids:
            SmartPrompt(title: "Check the size tag", systemImage: "tag")
        case .jewelry:
            SmartPrompt(title: "Check metal, stamp, or stone info", systemImage: "sparkles")
        case .collectibles:
            SmartPrompt(title: "Find edition, set, or serial number", systemImage: "number")
        case .music:
            SmartPrompt(title: "Find model, serial, and working condition", systemImage: "music.note")
        case .art:
            SmartPrompt(title: "Check artist, signature, and measurements", systemImage: "paintpalette")
        case .home:
            SmartPrompt(title: "Check maker mark or measurements", systemImage: "house")
        default:
            nil
        }
    }

    private func continueWithDetails() {
        continueForward(details: answers.sanitizedForUse)
    }

    private func continueWithoutDetails() {
        continueForward(details: nil)
    }

    private func continueForward(details: ItemDetailAnswers?) {
        focusedField = nil
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
                details: details
            )
        }
    }

    private enum Field: Hashable {
        case labelOrBrand
        case sizeOrModel
        case flaws
        case included
        case extraDetails
    }
}

private struct SmartPrompt: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
}

private struct SmartPromptRow: View {
    let prompt: SmartPrompt

    var body: some View {
        Label {
            Text(prompt.title.localized)
                .font(.body)
                .foregroundStyle(Color.brand.foreground)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: prompt.systemImage)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(prompt.title.localized)
    }
}
