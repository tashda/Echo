import SwiftUI

extension TableDataView {
    var tableDataToolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("\(viewModel.schemaName).\(viewModel.tableName)")
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer()

            if viewModel.isEditMode && viewModel.hasPendingEdits {
                Button {
                    viewModel.discardChanges()
                } label: {
                    Label("Discard", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await viewModel.saveChanges() }
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.canEdit {
                Button {
                    viewModel.toggleEditMode()
                } label: {
                    Label(
                        viewModel.isEditMode ? "Done Editing" : "Edit Mode",
                        systemImage: viewModel.isEditMode ? "pencil.slash" : "pencil"
                    )
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isEditMode ? .accentColor : nil)
                .controlSize(.small)
            }

            Button {
                Task { await viewModel.loadInitialData() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    var tableDataStatusBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            if viewModel.isLoadingMore {
                ProgressView()
                    .controlSize(.mini)
            }

            Text("\(EchoFormatters.compactNumber(viewModel.totalLoadedRows)) rows loaded")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            if viewModel.hasMoreRows {
                Text("(more available)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }

            Spacer()

            if viewModel.hasPendingEdits {
                Text("\(viewModel.pendingEdits.count) pending edit(s)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.warning)
            }

            if !viewModel.canEdit {
                Label("Read-only (no primary key)", systemImage: "lock")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }
}
