import SwiftUI

/// CN5: Add and Edit happen in Manage Connections' detail pane. Select a connection and its
/// fields are editable in place; + adds a new one with the same form. No separate sheet.
struct LabRound14ManageConnections: View {
    @State private var connections = LabConnection.samples
    @State private var selectedID: String? = LabConnection.samples.first?.id
    @State private var draft = LabConnection.samples[0]
    @State private var showsErrors = false
    @State private var testStatus: String?
    @State private var isTesting = false
    @State private var folder = "All Connections"
    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    private var saved: LabConnection? { connections.first { $0.id == draft.id } }
    private var isEdited: Bool { saved != draft }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            sidebar
            Divider()
            list
            Divider()
            detail
        }
        .frame(width: LayoutTokens.DesignLabRound14.manageWidth, height: LayoutTokens.DesignLabRound14.manageHeight)
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .onChange(of: selectedID) { _, id in
            guard let id, let connection = connections.first(where: { $0.id == id }) else { return }
            draft = connection
            showsErrors = false
            testStatus = nil
        }
    }

    private var sidebar: some View {
        List(selection: Binding(get: { folder }, set: { folder = $0 ?? folder })) {
            Section("Folders") {
                ForEach(["All Connections"] + LabConnection.folders, id: \.self) { name in
                    Label(name, systemImage: name == "All Connections" ? "tray.full" : "folder").tag(name)
                }
            }
            Section("Identities") {
                Label("sa · Test servers", systemImage: "key")
            }
        }
        .listStyle(.sidebar)
        .frame(width: LayoutTokens.DesignLabRound14.manageSidebarWidth)
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.none) {
            List(selection: $selectedID) {
                ForEach(connections.filter { folder == "All Connections" || $0.folder == folder }) { connection in
                    HStack(spacing: SpacingTokens.xs) {
                        LabEngineBadge(engine: connection.engine)
                        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                            Text(connection.name.isEmpty ? "New Connection" : connection.name).font(TypographyTokens.standard.weight(.medium))
                            Text(connection.address.isEmpty ? "No server yet" : connection.address)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    .tag(connection.id)
                }
            }
            .listStyle(.inset)
            Divider()
            HStack(spacing: SpacingTokens.xxs) {
                Button { addConnection() } label: { Image(systemName: "plus") }
                    .help("New Connection")
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .help("Delete Connection")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(SpacingTokens.xs)
        }
        .frame(width: LayoutTokens.DesignLabRound14.manageListWidth)
    }

    private var detail: some View {
        VStack(spacing: SpacingTokens.none) {
            HStack(spacing: SpacingTokens.sm) {
                LabEngineBadge(engine: draft.engine, size: SpacingTokens.xl)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(draft.name.isEmpty ? "New Connection" : draft.name).font(TypographyTokens.headline)
                    Text(isEdited ? "Edited · not saved" : "Saved")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(isEdited ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.top, SpacingTokens.sm)
            LabRound14ConnectionForm(connection: $draft, showsErrors: showsErrors)
            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack(spacing: SpacingTokens.xs) {
            if isTesting {
                ProgressView().controlSize(.small)
            } else if let testStatus {
                Label(testStatus, systemImage: "checkmark.circle.fill")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.success)
            }
            Spacer()
            Button("Test") { test() }
            Button("Revert") { if let saved { draft = saved; showsErrors = false } }
                .disabled(!isEdited)
            Button("Connect") {}
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.sm)
    }

    private func addConnection() {
        let connection = LabConnection.blank()
        connections.append(connection)
        folder = "All Connections"
        selectedID = connection.id
    }

    private func removeSelected() {
        guard let selectedID else { return }
        connections.removeAll { $0.id == selectedID }
        self.selectedID = connections.first?.id
    }

    private func save() {
        let missing = draft.host.isEmpty || (draft.engine != .sqlite && draft.user.isEmpty)
        showsErrors = missing
        guard !missing, let index = connections.firstIndex(where: { $0.id == draft.id }) else { return }
        connections[index] = draft
    }

    private func test() {
        isTesting = true
        testStatus = nil
        let engine = draft.engine
        Task(name: "design-lab-connection-test") { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            isTesting = false
            testStatus = "Connected · \(engine.rawValue) · 38 ms"
        }
    }
}
