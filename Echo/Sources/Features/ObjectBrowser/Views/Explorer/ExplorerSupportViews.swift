import SwiftUI
import AppKit
import EchoSense

struct CompactDatabaseCard: View {
    let database: DatabaseInfo
    let isSelected: Bool
    let serverColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    private var schemaCountText: String {
        let count = database.schemas.isEmpty ? database.schemaCount : database.schemas.count
        return "\(count)"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(serverColor)
                        .frame(width: 4, height: 4)
                    Text(database.name)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(isSelected ? serverColor : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(TypographyTokens.compact.weight(.semibold))
                            .foregroundStyle(serverColor)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(schemaCountText)
                        .font(TypographyTokens.compact.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.xs2)
            .padding(.vertical, SpacingTokens.xs)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? serverColor.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? serverColor.opacity(0.3) : (isHovered ? Color.primary.opacity(0.05) : .clear),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ExplorerLoadingOverlay: View {
    let progress: Double?
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            } else {
                ProgressView()
                    .scaleEffect(0.85)
            }

            Text(message)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}
