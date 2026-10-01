import SwiftUI

/// Round 43.4 (TP0): a narrow, true-to-life server card as the preview of Settings › Sidebar, not
/// stretched to the window's edge. It follows hiding offline databases, which folders open by
/// themselves and the scroll bar.
struct SidebarSettingsPreview: View {
    let settings: GlobalSettings

    private let cardWidth: CGFloat = 260

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            card
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xs) {
                Circle().fill(ColorTokens.accent).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                Text("Production").font(TypographyTokens.standard.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, SpacingTokens.xxs)
            databaseRow("Sales", isOnline: true)
            ForEach(openFolders, id: \.self) { folder in
                row(folder.displayName, systemImage: "folder", indent: SpacingTokens.md)
                row("Items", systemImage: "circle.fill", indent: SpacingTokens.lg, isPlaceholder: true)
            }
            if !settings.sidebarHideOfflineDatabasesByDefault { databaseRow("Archive", isOnline: false) }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sm)
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .overlay(alignment: .trailing) {
            if settings.sidebarShowsScrollBar {
                Capsule().fill(ColorTokens.Text.tertiary.opacity(0.5)).frame(width: SpacingTokens.xxs, height: SpacingTokens.xl2)
                    .padding(.trailing, SpacingTokens.xxxs)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous)
                .strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5)
        )
    }

    private var openFolders: [SidebarAutoExpandSection] {
        SidebarAutoExpandSection.generalSections.filter { settings.sidebarAutoExpandSections.contains($0) && $0 != .databases }.prefix(2).map { $0 }
    }

    private func databaseRow(_ name: String, isOnline: Bool) -> some View {
        row(name, systemImage: "cylinder", indent: SpacingTokens.none, isDimmed: !isOnline)
    }

    private func row(_ title: String, systemImage: String, indent: CGFloat, isDimmed: Bool = false, isPlaceholder: Bool = false) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: systemImage).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: SpacingTokens.md)
            Text(title).font(TypographyTokens.standard)
                .foregroundStyle(isDimmed || isPlaceholder ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            Spacer()
        }
        .padding(.leading, indent)
        .frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
    }
}
