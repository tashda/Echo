import AppKit
import SwiftUI

extension TableStructureEditorView {

    internal var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("\(viewModel.schemaName).\(viewModel.tableName)")
                        .font(TypographyTokens.prominent.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                    Text(tab.connection.connectionName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                Spacer(minLength: SpacingTokens.md)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Picker("", selection: $selectedSection) {
                ForEach(TableStructureSection.cases(for: viewModel.databaseType)) { section in
                    Text(section.displayName).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.top, SpacingTokens.md)
        .padding(.bottom, SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    internal var content: some View {
        VStack(spacing: 0) {
            if let message = viewModel.lastError {
                StatusToastView(icon: "exclamationmark.triangle.fill", message: message, style: .error)
                    .padding(.top, SpacingTokens.sm)
            } else if let success = viewModel.lastSuccessMessage {
                StatusToastView(icon: "checkmark.circle.fill", message: success, style: .success)
                    .padding(.top, SpacingTokens.sm)
            }

            if viewModel.isLoading && viewModel.columns.isEmpty {
                Spacer()
                ProgressView("Loading structure\u{2026}")
                    .controlSize(.small)
                Spacer()
            } else {
                switch selectedSection {
                case .columns:
                    columnsContent

                    Divider()

                    constraintsPanel

                case .indexes:
                    indexesContent

                case .relations:
                    relationsContent

                case .extendedProperties:
                    ExtendedPropertiesSection(
                        session: viewModel.session,
                        schema: viewModel.schemaName,
                        tableName: viewModel.tableName
                    )
                }
            }

            bottomBar
        }
    }

    private var bottomBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()

            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isApplying)

            Button {
                applyChanges()
            } label: {
                if viewModel.isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Apply Changes", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasPendingChanges || viewModel.isApplying)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.sm)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
