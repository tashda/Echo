import SwiftUI

/// Displays a categorized key-value table of common SQLite PRAGMAs.
/// Read-only display with a copy button per value.
struct SQLitePRAGMABrowserView: View {
    let session: DatabaseSession

    @State private var entries: [PRAGMAEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                pragmaList
            }
        }
        .task { await loadPragmas() }
    }

    private var header: some View {
        HStack {
            Text("Database Properties")
                .font(TypographyTokens.standard.weight(.medium))
            Spacer()
            Button {
                Task { await loadPragmas() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    private var pragmaList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(PRAGMACategory.allCases) { category in
                    let categoryEntries = entries.filter { $0.category == category }
                    if !categoryEntries.isEmpty {
                        Section {
                            ForEach(categoryEntries) { entry in
                                pragmaRow(entry)
                                if entry.id != categoryEntries.last?.id {
                                    Divider().padding(.leading, SpacingTokens.lg)
                                }
                            }
                        } header: {
                            Text(category.displayName)
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .padding(.horizontal, SpacingTokens.md)
                                .padding(.vertical, SpacingTokens.xs)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                        }
                    }
                }
            }
            .padding(.bottom, SpacingTokens.md)
        }
    }

    private func pragmaRow(_ entry: PRAGMAEntry) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                Text(entry.description)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            Text(entry.value ?? "—")
                .font(TypographyTokens.standard.monospaced())
                .foregroundStyle(entry.value != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                .textSelection(.enabled)
            Button {
                if let value = entry.value {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help("Copy value")
            .disabled(entry.value == nil)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func loadPragmas() async {
        isLoading = true
        defer { isLoading = false }

        guard let sqliteSession = session as? SQLiteSession else { return }

        var loaded: [PRAGMAEntry] = []
        for definition in Self.pragmaDefinitions {
            let value = try? await sqliteSession.fetchPragmaValue(definition.pragma, schema: nil)
            loaded.append(PRAGMAEntry(
                name: definition.pragma,
                description: definition.description,
                value: value,
                category: definition.category
            ))
        }
        entries = loaded
    }
}

// MARK: - Data Types

extension SQLitePRAGMABrowserView {

    struct PRAGMAEntry: Identifiable {
        let name: String
        let description: String
        let value: String?
        let category: PRAGMACategory
        var id: String { name }
    }

    enum PRAGMACategory: String, CaseIterable, Identifiable {
        case storage
        case performance
        case integrity
        case encoding

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .storage: "Storage"
            case .performance: "Performance"
            case .integrity: "Integrity & Safety"
            case .encoding: "Encoding & Format"
            }
        }
    }

    struct PRAGMADefinition {
        let pragma: String
        let description: String
        let category: PRAGMACategory
    }

    static let pragmaDefinitions: [PRAGMADefinition] = [
        // Storage
        PRAGMADefinition(pragma: "page_size", description: "Database page size in bytes", category: .storage),
        PRAGMADefinition(pragma: "page_count", description: "Total number of pages in the database", category: .storage),
        PRAGMADefinition(pragma: "freelist_count", description: "Number of unused pages", category: .storage),
        PRAGMADefinition(pragma: "max_page_count", description: "Maximum number of pages allowed", category: .storage),
        PRAGMADefinition(pragma: "auto_vacuum", description: "Auto-vacuum mode (0=none, 1=full, 2=incremental)", category: .storage),
        PRAGMADefinition(pragma: "journal_mode", description: "Journal mode (delete, truncate, persist, memory, wal, off)", category: .storage),

        // Performance
        PRAGMADefinition(pragma: "cache_size", description: "Number of pages in the page cache", category: .performance),
        PRAGMADefinition(pragma: "mmap_size", description: "Maximum memory-mapped I/O size in bytes", category: .performance),
        PRAGMADefinition(pragma: "wal_autocheckpoint", description: "WAL auto-checkpoint threshold (pages)", category: .performance),
        PRAGMADefinition(pragma: "busy_timeout", description: "Busy handler timeout in milliseconds", category: .performance),
        PRAGMADefinition(pragma: "threads", description: "Max helper threads for sort and index operations", category: .performance),

        // Integrity & Safety
        PRAGMADefinition(pragma: "foreign_keys", description: "Foreign key enforcement (0=off, 1=on)", category: .integrity),
        PRAGMADefinition(pragma: "synchronous", description: "Synchronous commit mode (0=OFF, 1=NORMAL, 2=FULL, 3=EXTRA)", category: .integrity),
        PRAGMADefinition(pragma: "secure_delete", description: "Overwrite deleted content with zeros", category: .integrity),
        PRAGMADefinition(pragma: "query_only", description: "Prevent database modifications (0=off, 1=on)", category: .integrity),
        PRAGMADefinition(pragma: "cell_size_check", description: "Additional cell size validation on read", category: .integrity),

        // Encoding & Format
        PRAGMADefinition(pragma: "encoding", description: "Text encoding (UTF-8, UTF-16le, UTF-16be)", category: .encoding),
        PRAGMADefinition(pragma: "data_version", description: "Incremented when database content changes", category: .encoding),
        PRAGMADefinition(pragma: "schema_version", description: "Incremented when database schema changes", category: .encoding),
        PRAGMADefinition(pragma: "user_version", description: "Application-defined version number", category: .encoding),
        PRAGMADefinition(pragma: "application_id", description: "Application-defined database identifier", category: .encoding),
    ]
}
