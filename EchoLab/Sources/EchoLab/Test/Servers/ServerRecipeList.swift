import EchoDesignSystem
import ServerLabCatalog
import ServerLabKit
import SwiftUI

/// Recipes grouped by engine, the selected recipe's settings and packs, and Build / Start.
struct ServerRecipeList: View {
    let model: LabServersModel
    @Binding var selectedRecipe: String?
    @Binding var leaseMinutes: Int
    @AppStorage("lab.servers.capture") private var capture = false
    @AppStorage("lab.servers.faults") private var faults = false
    @State private var search = ""

    private var filtered: [Recipe] {
        guard !search.isEmpty else { return model.recipes }
        return model.recipes.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search) }
    }

    private var selected: Recipe? { model.recipes.first { $0.name == selectedRecipe } }

    var body: some View {
        VSplitView {
            List(selection: $selectedRecipe) {
                Section("SQLite files") {
                    ForEach(LabSQLiteFixture.allCases, id: \.self) { fixture in
                        Label(fixture.rawValue, systemImage: "doc").font(TypographyTokens.standard).tag("sqlite:\(fixture.rawValue)")
                    }
                }
                ForEach(EngineKind.allCases, id: \.self) { engine in
                    let recipes = filtered.filter { $0.engine == engine }
                    if !recipes.isEmpty {
                        Section(engine.displayName) {
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
            } else if let fixture = selectedRecipe.flatMap({ $0.hasPrefix("sqlite:") ? LabSQLiteFixture(rawValue: String($0.dropFirst(7))) : nil }) {
                SQLiteFixtureDetail(model: model, fixture: fixture).frame(minHeight: 220)
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
                LabeledContent("Engine", value: "\(recipe.engine.displayName) \(recipe.version)")
                if let agent = recipe.settings.agent { LabeledContent("Agent", value: agent ? "On" : "Off") }
                if let collation = recipe.settings.collation { LabeledContent("Collation", value: collation) }
                if let variant = recipe.settings.imageVariant { LabeledContent("Image", value: variant) }
                if let topology = recipe.settings.topology {
                    LabeledContent("Parts", value: topology + (recipe.settings.replicas.map { ", \($0) replicas" } ?? ""))
                }
                if let tls = recipe.settings.tls { LabeledContent("TLS", value: "\(tls.mode.rawValue), \(tls.certificate.rawValue) certificate") }
                if recipe.settings.kerberos == true { LabeledContent("Kerberos", value: "Active Directory domain LAB.TEST") }
                if recipe.settings.mailServer == true { LabeledContent("Mail", value: "Mailpit part for Database Mail") }
                ForEach((recipe.settings.serverOptions ?? [:]).sorted { $0.key < $1.key }, id: \.key) { option in
                    LabeledContent(option.key, value: option.value.isEmpty ? "(empty)" : option.value)
                }
            }
            Section("Packs") {
                if recipe.packs.isEmpty { Text("None: an empty server").foregroundStyle(ColorTokens.Text.secondary) }
                ForEach(Array(recipe.packs.enumerated()), id: \.offset) { _, use in
                    LabeledContent(use.pack, value: use.params.values.sorted { $0.key < $1.key }.map { "\($0.key) \(Self.describe($0.value))" }.joined(separator: ", "))
                }
            }
            Section {
                Stepper("Remove after \(leaseMinutes) minutes", value: $leaseMinutes, in: 15...480, step: 15)
                Toggle("Record traffic", isOn: $capture)
                    .help("Records the server's traffic; see it decoded under Wire and Explained, or open it in Wireshark")
                Toggle("Fault proxy", isOn: $faults)
                    .help("Puts a Toxiproxy part in front of the server for latency, hangs, resets and network cuts")
                HStack {
                    Button("Build image") { Task { await model.build(recipe) } }
                        .disabled(model.busyRecipes.contains(recipe.name))
                    Button("Start server") { Task { await model.start(recipe, leaseMinutes: leaseMinutes, capture: capture, faults: faults) } }
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
