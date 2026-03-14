import AppKit
import SwiftUI

extension TableStructureEditorView {

    internal func sectionToolbar(title: String, count: Int, addAction: @escaping () -> Void) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(title)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)

            if count > 0 {
                Text("\(count)")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .padding(.vertical, SpacingTokens.xxxs)
                    .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
            }

            Spacer()

            Button {
                addAction()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.xs)
    }

    internal func statusBadge(isNew: Bool, isDirty: Bool) -> some View {
        Group {
            if isNew {
                Text("New")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(accentColor)
            } else if isDirty {
                Text("Modified")
                    .font(TypographyTokens.label.weight(.medium))
                    .foregroundStyle(accentColor)
            }
        }
    }

    internal var accentNSColor: NSColor {
        if projectStore.globalSettings.accentColorSource == .connection {
            return NSColor(tab.connection.color)
        }
        return NSColor.controlAccentColor
    }

    internal var accentColor: Color { Color(nsColor: accentNSColor) }
}
