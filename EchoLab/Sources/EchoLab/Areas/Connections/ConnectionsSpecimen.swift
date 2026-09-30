import Observation
import SwiftUI

/// What the Connections specimen shares with its controls.
@Observable @MainActor
final class ConnectionsSpecimenState {
    enum Presentation: String, CaseIterable, Identifiable {
        case quick = "Quick Connect", new = "New Connection", inline = "In Manage Connections", manage = "Manage Connections window"
        var id: String { rawValue }
    }
    enum Engine: String, CaseIterable, Identifiable {
        case sqlServer = "SQL Server", postgres = "PostgreSQL", mysql = "MySQL", sqlite = "SQLite"
        var id: String { rawValue }
        var defaultPort: Int { switch self { case .sqlServer: 1433; case .postgres: 5432; case .mysql: 3306; case .sqlite: 0 } }
        var summary: String { switch self { case .sqlServer: "Optional · 30 s"; case .postgres: "TLS prefer · 30 s"; case .mysql: "TLS · 30 s"; case .sqlite: "30 s" } }
    }

    var presentation: Presentation = .quick
    var engine: Engine = .postgres
    var showsMissing = false
    var saveToConnections = false
    var optionsOpen = false
    var testing = false
    var host = ""
    var database = ""
    var user = ""
    var name = ""
    var colour = 0
    /// The Spec page forces a state: the presentation, missing fields, or the disclosure.
    func force(_ key: String?) {
        switch key {
        case "quick": presentation = .quick
        case "new": presentation = .new
        case "inline": presentation = .inline
        case "missing": showsMissing = true
        case "options": optionsOpen = true
        case "saving": presentation = .new
        default: break
        }
    }
}

/// The connection form as `ConnectionEditorView` draws it (a native grouped form, 520pt wide as a
/// sheet), with the pieces that carry Spec numbers. The Manage Connections window is the Round 14
/// mock and is approximate.
struct ConnectionsSpecimen: View {
    @Bindable var state: ConnectionsSpecimenState

    private static let palette: [Color] = [Color(red: 0.35, green: 0.61, blue: 0.87), Color(red: 0.43, green: 0.68, blue: 0.45),
                                            Color(red: 0.91, green: 0.58, blue: 0.23), Color(red: 0.61, green: 0.45, blue: 0.81), Color(red: 0.83, green: 0.41, blue: 0.48)]

    var body: some View {
        Group {
            if state.presentation == .manage {
                LabRound14ManageConnections()
            } else {
                form.frame(width: state.presentation == .inline ? 460 : 520).frame(height: 500)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator))
                    .shadow(ShadowTokens.workspaceCard)
                    .specAnchor(state.presentation == .inline ? "1.3" : state.presentation == .quick ? "1.1" : "1.2")
                    .padding(SpacingTokens.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSQLite: Bool { state.engine == .sqlite }
    private var isQuick: Bool { state.presentation == .quick }
    private var isSheet: Bool { state.presentation != .inline }
    private var savesName: Bool { !isQuick || state.saveToConnections }

    private var form: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Database", selection: $state.engine) {
                        ForEach(ConnectionsSpecimenState.Engine.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).specAnchor("2.2")
                    if isSQLite {
                        LabeledContent("Database File") {
                            HStack { TextField("", text: $state.host, prompt: Text("~/Data/app.sqlite")).textFieldStyle(.plain).multilineTextAlignment(.trailing)
                                Button("Choose") {}.buttonStyle(.bordered).controlSize(.small) }
                        }.specAnchor("2.5")
                    } else {
                        LabeledContent("Server") {
                            HStack(spacing: 6) {
                                TextField("", text: $state.host, prompt: Text("db.example.com or a connection URL")).textFieldStyle(.plain).multilineTextAlignment(.trailing)
                                Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                                Text(verbatim: "\(state.engine.defaultPort)").foregroundStyle(ColorTokens.Text.tertiary).frame(width: 32, alignment: .trailing)
                            }
                        }.specAnchor("2.3")
                        missing("Enter the server's host name or address.").specAnchor("6.3")
                        LabeledContent("Database") {
                            TextField("", text: $state.database, prompt: Text("Default")).textFieldStyle(.plain).multilineTextAlignment(.trailing)
                        }
                    }
                } header: { Text(isQuick ? "Quick Connect" : state.presentation == .new ? "New Connection" : "prod-reporting") }

                if !isSQLite {
                    Section("Sign In") {
                        LabeledContent("Method") { Menu("Manual") {}.menuStyle(.borderlessButton).fixedSize() }.specAnchor("3.1")
                        LabeledContent("Username") { TextField("", text: $state.user, prompt: Text("username")).textFieldStyle(.plain).multilineTextAlignment(.trailing) }.specAnchor("3.2")
                        missing("Enter a user name.")
                        LabeledContent("Password") { SecureField("", text: .constant(""), prompt: Text("password")).textFieldStyle(.plain).multilineTextAlignment(.trailing) }
                    }
                }
                Section {
                    DisclosureGroup(isExpanded: $state.optionsOpen) {
                        LabeledContent("Encryption") { Text("Optional").foregroundStyle(ColorTokens.Text.secondary) }
                        LabeledContent("Connection Timeout") { Text("30 seconds").foregroundStyle(ColorTokens.Text.secondary) }
                        LabeledContent("Query Timeout") { Text("60 seconds").foregroundStyle(ColorTokens.Text.secondary) }
                    } label: {
                        LabeledContent("Security and timeouts") { Text(state.engine.summary).foregroundStyle(ColorTokens.Text.secondary) }
                    }
                }
                .specAnchor("4.1")
                Section {
                    if isQuick { Toggle("Save to Connections", isOn: $state.saveToConnections).specAnchor("5.1") }
                    if savesName {
                        LabeledContent("Name") { TextField("", text: $state.name, prompt: Text(state.host.isEmpty ? "My Connection" : state.host)).textFieldStyle(.plain).multilineTextAlignment(.trailing) }
                        LabeledContent("Folder") { Menu("None") {}.menuStyle(.borderlessButton).fixedSize() }
                        LabeledContent("Color") {
                            HStack(spacing: 8) {
                                ForEach(Array(Self.palette.enumerated()), id: \.offset) { index, swatch in
                                    Circle().fill(swatch).frame(width: 20, height: 20)
                                        .overlay { if index == state.colour { Circle().strokeBorder(ColorTokens.accent, lineWidth: 2).padding(-3) } }
                                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { state.colour = index } }
                                }
                            }
                        }.specAnchor("5.3")
                    }
                } header: { if !isQuick { Text("Saved As") } }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: 8) {
                Button(state.testing ? "Cancel Test" : "Test") { state.testing.toggle() }
                if state.testing {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Testing").foregroundStyle(ColorTokens.Text.secondary) }.font(TypographyTokens.formDescription)
                } else {
                    Label("Connected in 42 ms", systemImage: "checkmark.circle.fill").foregroundStyle(ColorTokens.Status.success).font(TypographyTokens.formDescription)
                }
                Spacer()
                if isSheet {
                    Button("Cancel") {}
                    if isQuick { Button(state.saveToConnections ? "Save and Connect" : "Connect") {}.keyboardShortcut(.defaultAction) }
                    else { Button("Save") {}; Button("Save and Connect") {}.keyboardShortcut(.defaultAction) }
                } else {
                    Button("Revert") {}; Button("Connect") {}; Button("Save") {}.keyboardShortcut(.defaultAction)
                }
            }
            .padding(isSheet ? 20 : 12)
            .specAnchor("6.1")
        }
    }

    @ViewBuilder
    private func missing(_ text: String) -> some View {
        if state.showsMissing {
            Label(text, systemImage: "exclamationmark.circle.fill")
                .font(TypographyTokens.formDescription).foregroundStyle(ColorTokens.Status.error).listRowSeparator(.hidden)
        }
    }
}

struct ConnectionsSpecimenControls: View {
    @Bindable var state: ConnectionsSpecimenState

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker("Shown as", selection: $state.presentation) {
                ForEach(ConnectionsSpecimenState.Presentation.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 320)
            Toggle("Missing fields", isOn: $state.showsMissing)
            Toggle("Security and timeouts open", isOn: $state.optionsOpen)
            Spacer()
        }
    }
}
