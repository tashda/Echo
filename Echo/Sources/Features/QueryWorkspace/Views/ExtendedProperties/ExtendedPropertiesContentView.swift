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
        .tabContentFrame()
    }

    private var toolbar: some View {
        TabSectionToolbar {
            Text("Extended Properties")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)
        } controls: {
            Button {
                viewModel.beginAdd()
            } label: {
                Label("Add Property", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            TabRefreshButton(isRefreshing: viewModel.isLoading) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let isEmpty = viewModel.tableProperties.isEmpty && viewModel.columnProperties.isEmpty

        if isEmpty && viewModel.isLoading {
            TabInitializingPlaceholder(
                icon: "tag",
                title: "Loading Extended Properties",
                subtitle: "Fetching table and column metadata…"
            )
        } else if isEmpty, let error = viewModel.errorMessage {
            TabContentUnavailableView("Could Not Load Extended Properties", systemImage: "exclamationmark.triangle") {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
            }
        } else if isEmpty {
            emptyState
        } else {
            if let error = viewModel.errorMessage {
                StatusToastView(icon: "exclamationmark.triangle.fill", message: error, style: .error)
                    .padding(SpacingTokens.md)
            }
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
        TabContentUnavailableView("No Extended Properties", systemImage: "tag") {
            Text("Add metadata to this table and its columns.")
        } actions: {
            Button("Add Property") { viewModel.beginAdd() }
                .buttonStyle(.bordered)
        }
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
                Label(name, systemImage: "tablecells")
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
