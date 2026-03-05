#if os(macOS)
import AppKit
#endif
import SwiftUI

extension TableStructureEditorView {
    
    internal var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.schemaName).\(viewModel.tableName)")
                        .font(TypographyTokens.displayLarge.weight(.semibold))
                        .foregroundStyle(headerPrimaryColor)
                    Label(tab.connection.connectionName, systemImage: "externaldrive.connected.to.line.below")
                        .font(TypographyTokens.caption2.weight(.medium))
                        .foregroundStyle(headerSecondaryColor)
                        .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 16)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(accentColor)
                }
            }

            TableStructureTitleView(
                selection: $selectedSection,
                accentColor: accentColor
            )
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.top, SpacingTokens.lg)
        .padding(.bottom, SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(headerBackgroundColor)
        .overlay(
            Rectangle()
                .fill(headerBorderColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    internal var content: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView {
                LazyVStack(alignment: .center, spacing: 20) {
                    if let message = viewModel.lastError {
                        statusMessage(text: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
                    } else if let success = viewModel.lastSuccessMessage {
                        statusMessage(text: success, systemImage: "checkmark.circle.fill", tint: .green)
                    }

                    switch selectedSection {
                    case .columns:
                        columnsSection
                        primaryKeySection
                        uniqueConstraintsSection
                    case .indexes:
                        indexesSection
                    case .relations:
                        foreignKeysSection
                        dependenciesSection
                    }
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.top, SpacingTokens.md2)
                .padding(.bottom, 140)
            }

            bottomActionBar
                .padding(.horizontal, SpacingTokens.xl)
                .padding(.bottom, 28)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            reloadButton
            applyButton
            Spacer()
        }
    }

    internal func statusMessage(text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(TypographyTokens.caption2.weight(.medium))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, tint.opacity(0.4))
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.xs2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 580, alignment: .center)
    }

    internal func sectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: SectionAction? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemImage)
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let action {
                    sectionActionButton(action)
                }
            }

            content()
        }
        .padding(SpacingTokens.md2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        .frame(maxWidth: 580, alignment: .center)
    }

    @ViewBuilder
    private func sectionActionButton(_ action: SectionAction) -> some View {
        if action.style == .accent {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        } else {
            Button(action: action.action) {
                sectionActionLabel(for: action)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func sectionActionLabel(for action: SectionAction) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }

}
