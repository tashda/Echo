import SwiftUI

struct EmptyPreviewPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(TypographyTokens.caption2.weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(SpacingTokens.sm)
    }
}

struct QueryTabPreview: View {
    @Bindable var query: QueryEditorState

    private var trimmedSQL: String {
        let trimmed = query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if trimmedSQL.isEmpty {
                Text("Empty query")
                    .font(TypographyTokens.detail.weight(.medium).monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .italic()
            } else {
                Text(trimmedSQL)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SpacingTokens.sm)
    }
}

struct DiagramTabPreview: View {
    @Bindable var diagram: SchemaDiagramViewModel

    private var status: (icon: String, text: String, color: Color) {
        if diagram.isLoading {
            return ("hourglass", "Loading…", ColorTokens.accent)
        }
        if let error = diagram.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Diagram error", .orange)
        }
        return ("chart.xyaxis.line", "\(diagram.nodes.count) table\(diagram.nodes.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(diagram.title)
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            Label(status.text, systemImage: status.icon)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(status.color)

            if let message = diagram.statusMessage, !message.isEmpty {
                Text(message)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SpacingTokens.sm)
    }
}

struct StructureTabPreview: View {
    var editor: TableStructureEditorViewModel

    private var status: (icon: String, text: String, color: Color) {
        if editor.isApplying {
            return ("hammer.fill", "Applying changes…", ColorTokens.accent)
        }
        if editor.isLoading {
            return ("arrow.triangle.2.circlepath", "Refreshing…", ColorTokens.accent)
        }
        if let error = editor.lastError, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Last update failed", .orange)
        }
        if let message = editor.lastSuccessMessage, !message.isEmpty {
            return ("checkmark.circle.fill", message, .green)
        }
        return ("tablecells", "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(editor.schemaName).\(editor.tableName)")
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            Label(status.text, systemImage: status.icon)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(status.color)

            if !editor.indexes.isEmpty {
                Text("\(editor.indexes.count) index\(editor.indexes.count == 1 ? "" : "es") configured")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SpacingTokens.sm)
    }
}

struct ExtensionStructureTabPreview: View {
    var viewModel: PostgresExtensionStructureViewModel

    private var status: (icon: String, text: String, color: Color) {
        if viewModel.isLoading {
            return ("hourglass", "Loading…", ColorTokens.accent)
        }
        if let error = viewModel.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Extension error", .orange)
        }
        return ("puzzlepiece", "\(viewModel.objects.count) object\(viewModel.objects.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.extensionName)
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            Label(status.text, systemImage: status.icon)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(status.color)

            if !viewModel.objects.isEmpty {
                Text("Database: \(viewModel.databaseName)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SpacingTokens.sm)
    }
}

struct ExtensionsTabPreview: View {
    var viewModel: PostgresExtensionsViewModel

    private var status: (icon: String, text: String, color: Color) {
        if viewModel.isLoading {
            return ("hourglass", "Loading…", ColorTokens.accent)
        }
        if let error = viewModel.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Manager error", .orange)
        }
        return ("puzzlepiece", "\(viewModel.installedExtensions.count) installed", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Extensions Manager")
                .font(TypographyTokens.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            Label(status.text, systemImage: status.icon)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(status.color)

            Text("Database: \(viewModel.databaseName)")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SpacingTokens.sm)
    }
}
