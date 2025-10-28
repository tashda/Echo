import SwiftUI
import Foundation
import EchoSense

struct AutocompleteManagementRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var sqlText: String = "SELECT * FROM "
    @State private var latestTrace: SQLAutocompleteTrace?
    @State private var isTraceFrozen = false

    private var editorTheme: SQLEditorTheme {
        let targetTone: SQLEditorPalette.Tone = themeManager.effectiveColorScheme == .dark ? .dark : .light
        let resolved = appState.sqlEditorTheme
        if resolved.palette.tone == targetTone {
            return resolved
        }
        return SQLEditorThemeResolver.resolve(
            globalSettings: appModel.globalSettings,
            project: appModel.selectedProject,
            tone: targetTone
        )
    }

    private var traceConfiguration: SQLAutocompleteRuleTraceConfiguration? {
        guard !isTraceFrozen else { return nil }
        return SQLAutocompleteRuleTraceConfiguration { trace in
            DispatchQueue.main.async {
                latestTrace = trace
            }
        }
    }

    private var completionContext: SQLEditorCompletionContext? {
        guard let session = appModel.sessionManager.activeSession else { return nil }
        let connection = session.connection
        let databaseType = EchoSenseDatabaseType(connection.databaseType)
        let selectedDatabase = normalize(session.selectedDatabaseName)
            ?? normalize(connection.database)
        let structure = session.databaseStructure
            ?? connection.cachedStructure
        return SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: selectedDatabase,
            defaultSchema: defaultSchema(for: databaseType),
            structure: structure.flatMap { EchoSenseBridge.makeStructure(from: $0) }
        )
    }

    private var activeConnectionSummary: String? {
        guard let session = appModel.sessionManager.activeSession else { return nil }
        let connection = session.connection
        let databasePart = normalize(session.selectedDatabaseName) ?? normalize(connection.database)
        if let databasePart, !databasePart.isEmpty {
            return "\(connection.connectionName) • \(databasePart)"
        }
        return connection.connectionName.isEmpty ? nil : connection.connectionName
    }

    private var structureStatusMessage: String? {
        guard let session = appModel.sessionManager.activeSession else { return nil }
        switch session.structureLoadingState {
        case .idle:
            return session.databaseStructure == nil ? "Database structure not loaded yet. Trigger a refresh if suggestions remain limited." : nil
        case .loading(let progress):
            if let progress {
                let percentage = Int((progress * 100).rounded())
                return "Loading database structure (\(percentage)% complete)"
            } else {
                return "Loading database structure…"
            }
        case .ready:
            return session.databaseStructure == nil ? "Structure ready but data unavailable; try refreshing the schema." : nil
        case .failed(let message):
            if let message, !message.isEmpty {
                return "Structure load failed: \(message)"
            } else {
                return "Unable to load database structure; suggestions may be limited."
            }
        }
    }

    var body: some View {
        let context = completionContext
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                SQLEditorView(
                    text: $sqlText,
                    theme: editorTheme,
                    display: appState.sqlEditorDisplay,
                    backgroundColor: nil,
                    completionContext: context,
                    ruleTraceConfig: traceConfiguration,
                    onTextChange: { sqlText = $0 },
                    onSelectionChange: { _ in },
                    onSelectionPreviewChange: { _ in },
                    clipboardMetadata: .empty
                )
                .frame(minHeight: 320)
                if context == nil {
                    Text("Connect to a database in the main workspace to populate autocomplete data. This editor mirrors the active connection’s schema.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let status = structureStatusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(themeManager.surfaceBackgroundColor)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tracePanel
                    Divider()
                    definitionsPanel
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 360, maxWidth: 420, maxHeight: .infinity)
            .background(themeManager.surfaceBackgroundColor)
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(themeManager.windowBackground)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .accentColor(themeManager.accentColor)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Autocomplete Management")
                    .font(.title2.weight(.semibold))
                Text("Type queries to inspect suppression decisions and tweak rule documentation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let summary = activeConnectionSummary {
                    Text("Active connection: \(summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle(isOn: $isTraceFrozen) {
                Label("Freeze Trace", systemImage: isTraceFrozen ? "pause.fill" : "play.fill")
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(isTraceFrozen ? "Resume Trace Updates" : "Freeze Trace Updates")
            }
            .toggleStyle(.switch)
            .help("When enabled, the current trace stays visible while you experiment in the editor.")
        }
    }

    private var tracePanel: some View {
        Group {
            if let trace = latestTrace {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Trace")
                        .font(.headline)
                    if !trace.metadataItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(trace.metadataItems, id: \.0) { key, value in
                                HStack {
                                    Text(key)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 12)
                                    Text(value)
                                        .font(.footnote)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if trace.stepItems.isEmpty {
                        Text("No rule steps recorded.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(trace.stepItems) { step in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.subheadline.weight(.medium))
                                    ForEach(step.details, id: \.self) { detail in
                                        Text(detail)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }

                    if let outcome = traceOutcomeDescription(trace.outcome) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Outcome")
                                .font(.subheadline.weight(.medium))
                            Text(outcome.title)
                                .font(.callout.weight(.semibold))
                            ForEach(outcome.details, id: \.self) { line in
                                Text(line)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trace")
                        .font(.headline)
                    Text("Start typing in the editor to capture the rule evaluation flow. The trace lists each decision taken by the suppression heuristics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func traceOutcomeDescription(_ outcome: SQLAutocompleteTrace.Outcome?) -> (title: String, details: [String])? {
        guard let outcome else { return nil }
        switch outcome {
        case let .produced(summary):
            let diagnostics = summary.diagnostics.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
            return ("Suppression Applied (\(summary.canonicalText))", ["Has follow-ups: \(summary.hasFollowUps ? "Yes" : "No")"] + diagnostics)
        case let .skipped(reason):
            return ("Suppression Skipped", [reason])
        }
    }

    private var definitionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rule Definitions")
                .font(.headline)
            Text("Add notes or reminders for each heuristic. Notes are stored locally and help keep future tweaks aligned.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(SQLAutocompleteRuleDefinition.core) { definition in
                RuleDefinitionRow(definition: definition)
                if definition.id != SQLAutocompleteRuleDefinition.core.last?.id {
                    Divider()
                }
            }
        }
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func defaultSchema(for type: EchoSenseDatabaseType) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql, .sqlite:
            return nil
        }
    }
}

private struct RuleDefinitionRow: View {
    let definition: SQLAutocompleteRuleDefinition
    @State private var notes: String = ""

    init(definition: SQLAutocompleteRuleDefinition) {
        self.definition = definition
        _notes = State(initialValue: UserDefaults.standard.string(forKey: definition.storageKey) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(definition.title)
                .font(.subheadline.weight(.semibold))
            Text(definition.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Add notes…", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
        }
        .onChange(of: notes) {
            UserDefaults.standard.set(notes, forKey: definition.storageKey)
        }
    }
}

struct SQLAutocompleteRuleDefinition: Identifiable {
    let id: String
    let title: String
    let summary: String
    let storageKey: String
}

extension SQLAutocompleteRuleDefinition {
    static let core: [SQLAutocompleteRuleDefinition] = [
        SQLAutocompleteRuleDefinition(
            id: "suppression-gate",
            title: "Suppression Gate",
            summary: "Determines when completions should stay hidden because the user already accepted an object and no additional follow-ups are available.",
            storageKey: "autocomplete.rule.suppression"
        ),
        SQLAutocompleteRuleDefinition(
            id: "column-follow-ups",
            title: "Column Follow-Ups",
            summary: "Inspects engine results and structure metadata to confirm whether columns or alternative objects justify reopening suggestions.",
            storageKey: "autocomplete.rule.columns"
        ),
        SQLAutocompleteRuleDefinition(
            id: "structure-fallback",
            title: "Structure Fallback",
            summary: "Falls back to database structure when the completion engine returns no direct match so users can reveal schema-driven suggestions with ⌘.",
            storageKey: "autocomplete.rule.structure"
        )
    ]
}
