import SwiftUI

/// Round 33.2's sheet: title, content in one of the layouts, footer. The edges (SE) decide
/// whether hairlines separate the title and the buttons from the content.
struct LabAJStepSheet: View {
    typealias Round = AgentJobStepSheetRound
    let look: Round.Look
    @State var name = "Rebuild indexes"

    static let sql = ["EXECUTE dbo.IndexOptimize", "  @Databases = 'USER_DATABASES',", "  @FragmentationLevel1 = 5,", "  @LogToTable = 'Y'"]

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            title
            if look.edges == .hairlines { Divider() }
            content
                .frame(maxHeight: .infinity)
            if look.edges == .hairlines { Divider() }
            if look.edges != .glass { footer }
        }
        .overlay(alignment: .bottom) { if look.edges == .glass { footer } }
        .background(look.structure == .cards ? ColorTokens.Workspace.canvas : ColorTokens.Background.primary)
        .clipShape(.rect(cornerRadius: SpacingTokens.md, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .frame(maxWidth: look.structure.isWide ? 760 : 600)
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private var title: some View {
        let showsJob = look.structure != .today
        Text(showsJob ? "New Step · IndexOptimize - USER_DATABASES" : "New Step")
            .font(TypographyTokens.headline)
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.sm)
    }

    @ViewBuilder
    private var content: some View {
        switch look.structure {
        case .today, .sections: form(includeCommand: true, includeCompletion: look.completion == .offered)
        case .twoPane:
            HStack(alignment: .top, spacing: SpacingTokens.none) {
                form(includeCommand: false, includeCompletion: look.completion == .offered).frame(width: 280)
                Divider()
                commandField.padding(SpacingTokens.md)
            }
        case .editorFirst: editorFirst
        case .inspector: inspector
        case .flow: flow
        case .cards: cards
        }
    }

    func form(includeCommand: Bool, includeCompletion: Bool) -> some View {
        Form {
            Section(look.structure == .today ? "New Step" : "Step") {
                TextField("Name", text: $name, prompt: Text("e.g. Run cleanup query"))
                typePicker
                databasePicker
                if look.structure == .today, includeCommand { LabeledContent("Command") { commandField } }
            }
            if look.structure != .today, includeCommand {
                Section("Command") { commandField }
            }
            if includeCompletion {
                Section("When it finishes") { completionRows }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    var typePicker: some View {
        Picker("Type", selection: .constant("T-SQL")) { Text("T-SQL").tag("T-SQL"); Text("PowerShell").tag("PowerShell") }
    }

    var databasePicker: some View {
        Picker("Database", selection: .constant("master")) { Text("master").tag("master") }
    }

    @ViewBuilder
    var completionRows: some View {
        Picker("On success", selection: .constant("Go to the next step")) { Text("Go to the next step").tag("Go to the next step") }
        Picker("On failure", selection: .constant("Quit the job reporting failure")) {
            Text("Quit the job reporting failure").tag("Quit the job reporting failure")
        }
        LabeledContent("Retry") {
            Text("0 times, 1 minute apart").foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    @ViewBuilder
    var commandField: some View {
        if look.command == .today {
            HStack(alignment: .top) {
                Text(Self.sql.joined(separator: "\n")).font(TypographyTokens.body.monospaced())
                    .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxxl + SpacingTokens.md, alignment: .topLeading)
                    .padding(SpacingTokens.xxs)
                    .background(ColorTokens.Background.primary, in: .rect(cornerRadius: SpacingTokens.xxs2))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs2).strokeBorder(ColorTokens.Text.quaternary.opacity(0.4), lineWidth: 0.5))
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
        } else {
            VStack(alignment: .trailing, spacing: SpacingTokens.xxs) {
                LabWKEditor(lines: Self.sql)
                    .frame(minHeight: SpacingTokens.xxxl * 2, maxHeight: .infinity)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5))
                HStack {
                    if look.command == .parse {
                        Label("No errors", systemImage: "checkmark.circle.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success)
                        Spacer()
                        Button("Parse") {}.controlSize(.small)
                    } else { Spacer() }
                    Button("Open in Editor", systemImage: "arrow.up.left.and.arrow.down.right") {}.controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        let buttons = HStack {
            if look.edges != .glass { Spacer() }
            Button("Cancel") {}
            if look.primary == .prominent {
                Button("Add Step") {}.buttonStyle(.borderedProminent)
            } else {
                Button("Add Step") {}.buttonStyle(.bordered)
            }
        }
        switch look.edges {
        case .hairlines: buttons.padding(SpacingTokens.sm).background(.bar)
        case .plain: buttons.padding(.horizontal, SpacingTokens.md).padding(.bottom, SpacingTokens.md).padding(.top, SpacingTokens.xs)
        case .glass:
            buttons.padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xs)
                .glassEffect(.regular, in: .capsule)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(SpacingTokens.sm)
        }
    }
}
