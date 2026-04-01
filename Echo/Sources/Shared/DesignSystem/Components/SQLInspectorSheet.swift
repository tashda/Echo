import SwiftUI

// MARK: - SQL Popout Context

/// Context for presenting SQL in an inspector sheet. Used across the app —
/// Activity Monitor, Profiler, Extended Events, Query Store, Schema Diff, etc.
struct SQLPopoutContext: Identifiable {
    let id = UUID()
    let sql: String
    let title: String
    let databaseName: String?
    let formatterDialect: SQLFormatter.Dialect

    init(sql: String, title: String, databaseName: String? = nil, dialect: SQLFormatter.Dialect = .postgres) {
        self.sql = sql
        self.title = title
        self.databaseName = databaseName
        self.formatterDialect = dialect
    }
}

// MARK: - SQL Inspector Sheet

/// Full-screen sheet for inspecting SQL text. Auto-formats the SQL on appear
/// and provides Copy and "Open in Query Window" actions.
struct SQLInspectorSheet: View {
    let context: SQLPopoutContext
    let onOpenInWindow: (_ sql: String, _ database: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var formattedSQL: String?

    private var displaySQL: String { formattedSQL ?? context.sql }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.title)
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()

                HStack(spacing: SpacingTokens.sm) {
                    Button("Copy SQL") {
                        PlatformClipboard.copy(displaySQL)
                    }

                    Button("Open in Query Window") {
                        onOpenInWindow(displaySQL, context.databaseName)
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)

            Divider()

            ScrollView {
                Text(displaySQL)
                    .font(TypographyTokens.code)
                    .padding(SpacingTokens.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            if let formatted = try? await SQLFormatter.shared.format(sql: context.sql, dialect: context.formatterDialect) {
                formattedSQL = formatted
            }
        }
    }
}

// MARK: - SQL Query Cell

/// Compact table cell that shows truncated SQL with an expand button and context menu.
/// Used in Activity Monitor, Profiler, Extended Events, and any table displaying SQL.
struct SQLQueryCell: View {
    let sql: String
    let databaseName: String?
    let onPopout: (String) -> Void
    var onOpenInQueryWindow: ((_ sql: String, _ database: String?) -> Void)?

    init(sql: String, databaseName: String? = nil, onPopout: @escaping (String) -> Void, onOpenInQueryWindow: ((_ sql: String, _ database: String?) -> Void)? = nil) {
        self.sql = sql
        self.databaseName = databaseName
        self.onPopout = onPopout
        self.onOpenInQueryWindow = onOpenInQueryWindow
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            let flat = sql.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            Text(flat)
                .font(TypographyTokens.detail)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(sql)

            Spacer()

            Button(action: { onPopout(sql) }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Expand SQL")
        }
        .contextMenu {
            Button {
                onPopout(sql)
            } label: {
                Label("Expand SQL", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            if let onOpenInQueryWindow {
                Button {
                    onOpenInQueryWindow(sql, databaseName)
                } label: {
                    Label("Open in Query Window", systemImage: "terminal")
                }
            }

            Divider()

            Button {
                PlatformClipboard.copy(sql)
            } label: {
                Label("Copy SQL", systemImage: "doc.on.doc")
            }
        }
    }
}
