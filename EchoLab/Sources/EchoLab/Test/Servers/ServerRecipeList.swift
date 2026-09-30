import EchoDesignSystem
import ServerLabKit
import SwiftUI

/// Recipes grouped by engine, the selected recipe's settings and packs, and Build / Start.
struct ServerRecipeList: View {
    let model: LabServersModel
    @Binding var selectedRecipe: String?
    @Binding var leaseMinutes: Int
    @State private var search = ""

    private var filtered: [Recipe] {
        guard !search.isEmpty else { return model.recipes }
        return model.recipes.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search) }
    }

    private var selected: Recipe? { model.recipes.first { $0.name == selectedRecipe } }

    var body: some View {
        VSplitView {
            List(selection: $selectedRecipe) {
                ForEach(EngineKind.allCases, id: \.self) { engine in
                    let recipes = filtered.filter { $0.engine == engine }
                    if !recipes.isEmpty {
                        Section(engine == .sqlServer ? "SQL Server" : "PostgreSQL") {
                            ForEach(recipes, id: \.name) { recipe in
                                row(recipe).tag(recipe.name)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Filter recipes")
            .frame(minHeight: 240)

            if let selected {
                detail(selected).frame(minHeight: 220)
            }
        }
    }

    private func row(_ recipe: Recipe) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: model.hasImage(recipe) ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(model.hasImage(recipe) ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                .help(model.hasImage(recipe) ? "Seeded image built: starts in seconds" : "No seeded image yet: the first start builds it")
            Text(recipe.name).font(TypographyTokens.standard)
            Spacer()
            if model.busyRecipes.contains(recipe.name) { ProgressView().controlSize(.small) }
        }
    }

    private func detail(_ recipe: Recipe) -> some View {
        Form {
            Section(recipe.name) {
                Text(recipe.summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                LabeledContent("Engine", value: "\(recipe.engine == .sqlServer ? "SQL Server" : "PostgreSQL") \(recipe.version)")
                if let agent = recipe.settings.agent { LabeledContent("Agent", value: agent ? "On" : "Off") }
                if let collation = recipe.settings.collation { LabeledContent("Collation", value: collation) }
                if let variant = recipe.settings.imageVariant { LabeledContent("Image", value: variant) }
            }
            Section("Packs") {
                if recipe.packs.isEmpty { Text("None: an empty server").foregroundStyle(ColorTokens.Text.secondary) }
                ForEach(Array(recipe.packs.enumerated()), id: \.offset) { _, use in
                    LabeledContent(use.pack, value: use.params.values.sorted { $0.key < $1.key }.map { "\($0.key) \(Self.describe($0.value))" }.joined(separator: ", "))
                }
            }
            Section {
                Stepper("Remove after \(leaseMinutes) minutes", value: $leaseMinutes, in: 15...480, step: 15)
                HStack {
                    Button("Build image") { Task { await model.build(recipe) } }
                        .disabled(model.busyRecipes.contains(recipe.name))
                    Button("Start server") { Task { await model.start(recipe, leaseMinutes: leaseMinutes) } }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.busyRecipes.contains(recipe.name))
                }
            }
        }
        .formStyle(.grouped)
    }

    private static func describe(_ value: PackParameterValue) -> String {
        switch value {
        case .int(let int): String(int)
        case .bool(let bool): bool ? "on" : "off"
        case .string(let string): string
        }
    }
}
