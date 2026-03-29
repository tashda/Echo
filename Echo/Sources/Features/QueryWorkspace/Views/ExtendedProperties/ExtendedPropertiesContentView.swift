import SwiftUI

struct ExtendedPropertiesContentView: View {
    @Bindable var viewModel: ExtendedPropertiesViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .sheet(item: $viewModel.editingProperty) { _ in
            ExtendedPropertyEditorSheet(viewModel: viewModel)
        }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Extended Properties")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                viewModel.beginAdd()
            } label: {
                Label("Add Property", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.sm)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            StatusToastView(icon: "exclamationmark.triangle.fill", message: error, style: .error)
                .padding(SpacingTokens.md)
        }

        if viewModel.tableProperties.isEmpty && viewModel.columnProperties.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    if !viewModel.tableProperties.isEmpty {
                        tablePropertiesGroup
                    }

                    if !viewModel.columnProperties.isEmpty {
                        columnPropertiesGroup
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "tag")
                .font(TypographyTokens.iconDisplay)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Extended Properties")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Add metadata to this table and its columns.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.xl)
    }

    private var tablePropertiesGroup: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("Table Properties")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    viewModel.beginAdd()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(ColorTokens.accent)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }

            ForEach(viewModel.tableProperties) { property in
                ExtendedPropertyRow(
                    property: property,
                    onEdit: { viewModel.beginEdit(property) },
                    onDelete: { Task { await viewModel.delete(property) } }
                )
            }
        }
    }

    private var columnPropertiesGroup: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Column Properties")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .textCase(.uppercase)

            ForEach(sortedColumnNames, id: \.self) { columnName in
                columnSection(name: columnName)
            }
        }
    }

    private var sortedColumnNames: [String] {
        viewModel.columnProperties.keys.sorted()
    }

    private func columnSection(name: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Label(name, systemImage: "column")
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)

                Spacer()

                Button {
                    viewModel.beginAdd(childType: "COLUMN", childName: name)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(ColorTokens.accent)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }

            if let props = viewModel.columnProperties[name] {
                ForEach(props) { property in
                    ExtendedPropertyRow(
                        property: property,
                        onEdit: { viewModel.beginEdit(property, childType: "COLUMN", childName: name) },
                        onDelete: { Task { await viewModel.delete(property, childType: "COLUMN", childName: name) } }
                    )
                }
            }
        }
        .padding(.leading, SpacingTokens.sm)
    }
}
