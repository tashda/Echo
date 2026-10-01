import SwiftUI

/// A query tab with the ☆ on the tab and the save popover open.
struct LabRBSaving: View {
    let save: RailBookmarksRound.Save

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.none) {
                HStack(spacing: SpacingTokens.xs) {
                    Label("Query 1", systemImage: "tablecells").font(TypographyTokens.detail)
                    if save != .today { Image(systemName: "star").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary) }
                }
                .frame(maxWidth: .infinity).frame(height: SpacingTokens.lg)
                .background(Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection))
                Label("Query 2", systemImage: "tablecells").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).frame(maxWidth: .infinity)
            }
            .padding(SpacingTokens.xxxs).background(ColorTokens.Sidebar.hoverFill, in: Capsule())
            ZStack(alignment: .topLeading) {
                LabWKEditor().workspaceCard()
                if save == .popover {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("Add to Bookmarks").font(TypographyTokens.headline)
                        LabeledContent("Name") { Text("Last checkpoints").padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs).background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xxs)) }
                        LabeledContent("Folder") { Text("AML ⌄") }
                        LabeledContent("Note") { Text("Optional").foregroundStyle(ColorTokens.Text.tertiary) }
                        HStack { Spacer(); Button("Cancel") {}; Button("Add") {}.buttonStyle(.borderedProminent) }
                    }
                    .font(TypographyTokens.standard)
                    .padding(SpacingTokens.md).frame(width: 300)
                    .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md))
                    .padding(.leading, SpacingTokens.lg).padding(.top, SpacingTokens.xxs)
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}
