import SwiftUI
import Foundation
import AppKit
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - View Builders

    @ViewBuilder
    internal func toolbarButtonLabel(icon: ToolbarIcon, title: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            toolbarIconView(icon)
            Text(title)
                .font(TypographyTokens.standard.weight(.regular))
                .foregroundStyle(ColorTokens.Text.primary)
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .padding(.vertical, SpacingTokens.xxs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    internal func menuRow(icon: ToolbarIcon, title: String, isSelected: Bool = false) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            toolbarIconView(icon)
            Text(title)
                .font(TypographyTokens.standard.weight(.regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(TypographyTokens.caption2.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    internal func toolbarIconView(_ icon: ToolbarIcon) -> some View {
        icon.image
            .renderingMode(icon.isTemplate ? .template : .original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .cornerRadius(icon.isTemplate ? 0 : 3)
    }

    // MARK: - Image Detection

    internal func hasImage(named name: String) -> Bool {
        return NSImage(named: name) != nil
    }
}
