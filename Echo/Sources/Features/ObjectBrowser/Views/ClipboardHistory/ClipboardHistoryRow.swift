import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ClipboardHistoryRow: View {
    let entry: ClipboardHistoryStore.Entry
    let isRecentlyCopied: Bool
    let onCopy: () -> Void

    @State internal var showInfo = false
#if os(macOS)
    @State private var isHovering = false
#else
    private let isHovering = false
#endif
    @EnvironmentObject internal var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 8) {
                    headerRow
                    Text(entry.previewText)
                        .font(TypographyTokens.standard.weight(.medium).monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if entry.metadata.hasDetails {
                        metadataSection
                    }
                }
            }
            .padding(.vertical, SpacingTokens.sm)
            .padding(.horizontal, SpacingTokens.sm2)
        }
        .background(backgroundShape)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRecentlyCopied ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.2)
                .animation(.easeInOut(duration: 0.2), value: isRecentlyCopied)
        )
        .overlay(alignment: .topLeading) {
            if isRecentlyCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .padding(.horizontal, SpacingTokens.xs2)
                    .padding(.vertical, SpacingTokens.xxs2)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 6, y: 3)
                    .padding([.top, .leading], 12)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onCopy)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isRecentlyCopied)
    }

    private var icon: some View {
        TintedIcon(systemImage: entry.source.iconName, tint: entry.source.tint, size: 18, boxSize: 32)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(entry.source.caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(entry.timestampDisplay)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            infoButton
        }
    }

    var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .opacity(0.15)

            HStack(spacing: 8) {
                if let server = sanitizedMetadataValue(entry.metadata.serverName) {
                    metadataBadge(icon: "server.rack", text: server, tint: connectionTint)
                }
                if let database = sanitizedMetadataValue(entry.metadata.databaseName) {
                    metadataBadge(icon: "cylinder", text: database, tint: connectionTint)
                }
                if let object = sanitizedMetadataValue(entry.metadata.objectName) {
                    metadataBadge(icon: "tablecells", text: object)
                }
            }
        }
        .padding(.top, SpacingTokens.xxs)
    }

    private func metadataBadge(icon: String, text: String, tint: Color? = nil) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint ?? Color.secondary)
            .padding(.vertical, SpacingTokens.xxs)
            .padding(.horizontal, SpacingTokens.xs)
            .background((tint?.opacity(0.18) ?? Color.primary.opacity(0.04)), in: Capsule())
    }

    private func sanitizedMetadataValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private var connectionTint: Color {
        if let hex = sanitizedMetadataValue(entry.metadata.connectionColorHex), let color = Color(hex: hex) {
            return color
        }
        return Color.accentColor
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
    }

    private var infoButton: some View {
        Button {
            showInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(SpacingTokens.xxs)
        }
        .buttonStyle(.plain)
#if os(macOS)
        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
            infoPopover
                .frame(minWidth: 280, minHeight: 220)
                .padding(SpacingTokens.md)
        }
#else
        .sheet(isPresented: $showInfo) {
            infoPopover
                .padding(SpacingTokens.md)
        }
#endif
    }
}
