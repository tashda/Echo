import EchoSense
import SwiftUI

/// Connect to a test server through the real driver packages, run SQL and load its schema.
struct ConnectionsTestPage: View {
    @State private var session = LabLiveSession.shared
    @AppStorage("lab.connections.server") private var selectedName: String?
    @AppStorage("lab.connections.database") private var database = ""
    @AppStorage("lab.connections.sql") private var sql = "SELECT 1 AS one"
    @State private var output: LabLiveConnection.QueryOutput?
    @State private var queryError: String?
    @State private var isRunning = false

    private var profile: LabConnectionProfile? { session.profiles.first { $0.name == selectedName } }
    private var connection: LabLiveConnection? { session.connection?.profile.name == selectedName ? session.connection : nil }

    var body: some View {
        if session.profiles.isEmpty {
            ContentUnavailableView(
                "No test servers",
                systemImage: "externaldrive.badge.questionmark",
                description: Text("Add connections to .echo-automation/config.json in the repo (the file Echo's automation mode uses)."))
        } else {
            HSplitView {
                sidebar.frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                querySide.frame(minWidth: 460)
            }
            .onAppear { selectedName = selectedName ?? session.connection?.profile.name ?? session.profiles.first?.name }
        }
    }

    // MARK: Server side

    private var sidebar: some View {
        Form {
            Section("Server") {
                Picker("Test server", selection: $selectedName) {
                    ForEach(session.profiles) { Text($0.name).tag(Optional($0.name)) }
                }
                if let profile {
                    LabeledContent("Host", value: "\(profile.host):\(profile.port.map(String.init) ?? "default")")
                    LabeledContent("Engine", value: profile.isSQLServer ? "SQL Server" : "PostgreSQL")
                }
                statusRow
            }
            if let connection, connection.state == .connected {
                Section("Server info") {
                    LabeledContent("Version", value: connection.serverVersion.map { String($0.prefix(48)) } ?? "unknown")
                    LabeledContent("Databases", value: "\(connection.databases.count)")
                }
                Section("Schema for EchoSense") {
                    if let profile, profile.isSQLServer {
                        Picker("Database", selection: $database) {
                            ForEach(connection.databases, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Button("Load schema") { Task { await connection.loadStructure(database: database.isEmpty ? nil : database) } }
                    if let structure = connection.structure {
                        let objects = structure.databases.flatMap(\.schemas).flatMap(\.objects).count
                        Text("\(objects) tables and views loaded. Open EchoSense › Completions and choose “Use live schema”.")
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            Section("Log") {
                ForEach(Array((connection?.log ?? []).enumerated().reversed()), id: \.offset) { _, line in
                    Text(line).font(.system(.caption, design: .monospaced)).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var statusRow: some View {
        HStack {
            switch connection?.state ?? .idle {
            case .idle: Label("Not connected", systemImage: "circle").foregroundStyle(ColorTokens.Text.secondary)
            case .connecting: ProgressView().controlSize(.small); Text("Connecting")
            case .connected: Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(ColorTokens.Status.success)
            case .failed(let message): Label(message, systemImage: "xmark.circle.fill").foregroundStyle(ColorTokens.Status.error).lineLimit(3)
            }
            Spacer()
            if connection?.state == .connected {
                Button("Disconnect") { Task { await connection?.disconnect() } }
            } else {
                Button("Connect") { connect() }.disabled(profile == nil || connection?.state == .connecting)
            }
        }
    }

    private func connect() {
        guard let profile else { return }
        let live = LabLiveConnection(profile: profile)
        session.connection = live
        Task { await live.connect(); database = live.databases.first ?? "" }
    }

    // MARK: Query side

    private var querySide: some View {
        VStack(spacing: 0) {
            TextEditor(text: $sql)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .padding(SpacingTokens.xs)
            HStack {
                Button(isRunning ? "Running" : "Run") { run() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(connection?.state != .connected || isRunning)
                if let output {
                    Text("\(output.rows.count) rows in \(output.elapsed.formatted(.units(allowed: [.milliseconds, .seconds], fractionalPart: .show(length: 2))))")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            Divider()
            if let queryError {
                Text(queryError).foregroundStyle(ColorTokens.Status.error).textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(SpacingTokens.md)
            } else if let output {
                ConnectionsResultGrid(output: output)
            } else {
                ContentUnavailableView("Run a query", systemImage: "play", description: Text("⌘↩ runs the SQL on the connected server."))
            }
        }
    }

    private func run() {
        guard let connection else { return }
        isRunning = true
        queryError = nil
        Task {
            do { output = try await connection.run(sql) } catch { queryError = error.localizedDescription; output = nil }
            isRunning = false
        }
    }
}

/// Query results as a plain grid: enough to read what the driver returned.
struct ConnectionsResultGrid: View {
    let output: LabLiveConnection.QueryOutput

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xxs) {
                GridRow {
                    ForEach(Array(output.columns.enumerated()), id: \.offset) { _, name in
                        Text(name).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                Divider()
                ForEach(Array(output.rows.prefix(500).enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell).font(.system(.callout, design: .monospaced)).lineLimit(1).textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
    }
}
