import SwiftUI
import Foundation
import EchoSense

struct AutocompleteInspectorRootView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @State private var sqlText: String = "SELECT * FROM "
    @State private var latestTrace: SQLAutocompleteTrace?
    @State private var isTraceFrozen = false

    // MARK: - Internal Accessors for Extensions

    var latestTraceValue: SQLAutocompleteTrace? { latestTrace }
    var isTraceFrozenValue: Bool { isTraceFrozen }
    var traceFrozenBinding: Binding<Bool> { $isTraceFrozen }

    // MARK: - Computed Properties

    private var editorTheme: SQLEditorTheme {
        let targetTone: SQLEditorPalette.Tone = appearanceStore.effectiveColorScheme == .dark ? .dark : .light
        let resolved = appState.sqlEditorTheme
        if resolved.palette.tone == targetTone {
            return resolved
        }
        return SQLEditorThemeResolver.resolve(
            globalSettings: projectStore.globalSettings,
            project: projectStore.selectedProject,
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
        guard let session = environmentState.sessionGroup.activeSession else { return nil }
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

    var activeConnectionSummary: String? {
        guard let session = environmentState.sessionGroup.activeSession else { return nil }
        let connection = session.connection
        let databasePart = normalize(session.selectedDatabaseName) ?? normalize(connection.database)
        if let databasePart, !databasePart.isEmpty {
            return "\(connection.connectionName) \u{2022} \(databasePart)"
        }
        return connection.connectionName.isEmpty ? nil : connection.connectionName
    }

    private var structureStatusMessage: String? {
        guard let session = environmentState.sessionGroup.activeSession else { return nil }
        switch session.structureLoadingState {
        case .idle:
            return session.databaseStructure == nil ? "Database structure not loaded yet. Trigger a refresh if suggestions remain limited." : nil
        case .loading(let progress):
            if let progress {
                let percentage = Int((progress * 100).rounded())
                return "Loading database structure (\(percentage)% complete)"
            } else {
                return "Loading database structure\u{2026}"
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

    // MARK: - Body

    var body: some View {
        let context = completionContext
        HStack(spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
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
                    Text("Connect to a database in the main workspace to populate autocomplete data. This editor mirrors the active connection's schema.")
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let status = structureStatusMessage {
                    Text(status)
                        .font(TypographyTokens.footnote)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(SpacingTokens.lg)
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ColorTokens.Background.secondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md2) {
                    tracePanel
                    Divider()
                    definitionsPanel
                }
                .padding(SpacingTokens.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 360, maxWidth: 420, maxHeight: .infinity)
            .background(ColorTokens.Background.secondary)
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(ColorTokens.Background.primary)
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
    }

    // MARK: - Helpers

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
