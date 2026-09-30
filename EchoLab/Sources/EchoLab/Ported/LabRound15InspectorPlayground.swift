import SwiftUI

/// Round 15: the inspector column drawn three ways beside each other, on the canvas, with the
/// same content. Each scrolls on its own, so the edges can be judged while scrolling too.
struct LabRound15InspectorPlayground: View {
    var body: some View {
        LabStage(title: "Inspector · three looks") {
            Text("Scroll each column and look at its edges, in light and dark.")
                .foregroundStyle(ColorTokens.Text.secondary)
        } content: {
            HStack(alignment: .top, spacing: SpacingTokens.lg) {
                ForEach(LabInspectorLook.allCases) { look in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        Text(look.rawValue).font(TypographyTokens.headline)
                        Text(look.summary)
                            .font(TypographyTokens.callout)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        LabInspectorColumn(look: look)
                    }
                    .frame(width: LabRound15Metrics.columnWidth + SpacingTokens.lg, alignment: .leading)
                }
            }
            .padding(SpacingTokens.md)
        }
    }
}

/// One inspector column on a patch of canvas.
private struct LabInspectorColumn: View {
    let look: LabInspectorLook

    var body: some View {
        ScrollView {
            content
                .padding(look == .separateCards ? SpacingTokens.sm : SpacingTokens.none)
        }
        // Separate cards need room for their shadows: they scroll inside a margin instead of
        // being cut at the column's edge.
        .scrollClipDisabled(look == .separateCards)
        .scrollIndicators(.never)
        .frame(width: LabRound15Metrics.columnWidth, height: LabRound15Metrics.columnHeight)
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .clipShape(.rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
    }

    @ViewBuilder
    private var content: some View {
        switch look {
        case .oneCard:
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(LabR15InspectorSection.samples.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        LabR15InspectorHeader(section: section)
                        LabR15InspectorBody(section: section)
                    }
                    .padding(LayoutTokens.FloatingSurface.padding)
                    if index < LabR15InspectorSection.samples.count - 1 { Divider() }
                }
            }
            .labInspectorCard()
        case .groupedBoxes:
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabR15InspectorSection.samples) { section in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        LabR15InspectorHeader(section: section)
                            .padding(.horizontal, SpacingTokens.xxs)
                        LabR15InspectorBody(section: section)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, SpacingTokens.xxs)
                            .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius))
                    }
                }
            }
            .padding(LayoutTokens.FloatingSurface.padding)
            .labInspectorCard()
        case .separateCards:
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(LabR15InspectorSection.samples) { section in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        LabR15InspectorHeader(section: section)
                        LabR15InspectorBody(section: section)
                    }
                    .padding(LayoutTokens.FloatingSurface.padding)
                    .labInspectorCard()
                }
            }
        }
    }
}

private extension View {
    /// Echo's workspace card: opaque fill, hairline edge, floating shadow.
    func labInspectorCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
                .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
            .shadow(ShadowTokens.workspaceCard)
    }
}
