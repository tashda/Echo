import SwiftUI
import Foundation
import AppKit
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Icon Helpers

    internal var projectIcon: ToolbarIcon { .system("folder.badge.person.crop") }

    // MARK: - View Builders

    @ViewBuilder
    internal func toolbarButtonLabel(icon: ToolbarIcon, title: String) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(TypographyTokens.standard.weight(.regular))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .padding(.vertical, SpacingTokens.xxs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    internal func menuRow(icon: ToolbarIcon, title: String, isSelected: Bool = false) -> some View {
        HStack(spacing: 8) {
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
