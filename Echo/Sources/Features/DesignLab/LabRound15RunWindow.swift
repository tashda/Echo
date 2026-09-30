#if DEBUG
import SwiftUI

/// A slice of Echo for the Run concepts: toolbar, tab bar, and an editor card with its footer.
/// Each concept fills the slots it uses; the rest stay as Echo has them.
struct LabRunWindow<EditorCapsule: View, ActiveTab: View, EditorOverlay: View, FooterTrailing: View>: View {
    @ViewBuilder var editorCapsule: () -> EditorCapsule
    @ViewBuilder var activeTab: () -> ActiveTab
    @ViewBuilder var editorOverlay: () -> EditorOverlay
    @ViewBuilder var footerTrailing: () -> FooterTrailing
    var gutterArrow: (() -> Void)?

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            toolbar
            HStack(spacing: SpacingTokens.xxxs) {
                activeTab()
                LabRunTabLabel(icon: "doc.text", title: "Query 2", subtitle: "sales", isActive: false)
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.xxxs)
            .glassEffect(.regular, in: .capsule)
            editorCard
        }
        .padding(SpacingTokens.xs)
        .frame(width: LabRound15Metrics.windowWidth, height: LabRound15Metrics.windowHeight)
        .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous).strokeBorder(.separator, lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabRunGlyphCapsule(symbols: ["sidebar.left"])
            Spacer(minLength: SpacingTokens.none)
            editorCapsule()
            LabRunGlyphCapsule(symbols: ["magnifyingglass", "bell", "sidebar.right"])
        }
        .frame(height: LabRound15Metrics.toolbarHeight)
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                gutter
                LabEditorText()
                    .font(TypographyTokens.code)
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(.top, SpacingTokens.sm)
            Spacer(minLength: SpacingTokens.none)
            HStack(spacing: SpacingTokens.xs) {
                Text("prod · employees")
                    .font(TypographyTokens.detail)
                    .padding(.horizontal, SpacingTokens.xs)
                    .frame(height: LabRound15Metrics.footerHeight)
                    .glassEffect(.regular, in: .capsule)
                Spacer(minLength: SpacingTokens.none)
                footerTrailing()
            }
            .padding(SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay { editorOverlay() }
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .shadow(ShadowTokens.workspaceCard)
    }

    /// Line numbers, with concept 5's ▸ on line 1 when it uses one.
    private var gutter: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xxs) {
            ForEach(1...4, id: \.self) { line in
                HStack(spacing: SpacingTokens.xxxs) {
                    if line == 1, let gutterArrow {
                        Button(action: gutterArrow) {
                            Image(systemName: "play.fill").font(TypographyTokens.compact)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.accent)
                        .help("Run this statement")
                    }
                    Text("\(line)")
                }
            }
        }
        .font(TypographyTokens.code)
        .foregroundStyle(ColorTokens.Text.tertiary)
        .frame(width: SpacingTokens.lg2, alignment: .trailing)
    }
}

/// A glass capsule of plain toolbar glyphs.
struct LabRunGlyphCapsule: View {
    let symbols: [String]

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(symbols, id: \.self) { LabRunGlyph(symbol: $0) }
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
    }
}

struct LabRunGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Text.primary)
            .frame(width: LabRound15Metrics.toolbarGlyph, height: LabRound15Metrics.toolbarGlyph)
    }
}

/// Echo's editor capsule without Run: Format, Validate, Help, Plan.
struct LabRunEditorCapsule: View {
    var body: some View {
        LabRunGlyphCapsule(symbols: ["sparkles", "exclamationmark.triangle", "text.book.closed", "flowchart"])
    }
}

/// A tab in the mock bar: icon, title and a second line.
struct LabRunTabLabel<Icon: View, Subtitle: View>: View {
    let isActive: Bool
    @ViewBuilder var icon: () -> Icon
    let title: String
    @ViewBuilder var subtitle: () -> Subtitle

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            icon()
                .frame(width: SpacingTokens.md)
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Text(title).font(TypographyTokens.detail.weight(isActive ? .semibold : .regular))
                subtitle()
                    .font(TypographyTokens.label.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(width: LabRound15Metrics.columnWidth / 2, height: LabRound15Metrics.tabHeight + SpacingTokens.xs, alignment: .leading)
        .background(isActive ? ColorTokens.Workspace.card : .clear, in: .capsule)
    }
}

extension LabRunTabLabel where Icon == Image, Subtitle == Text {
    init(icon: String, title: String, subtitle: String, isActive: Bool) {
        self.init(isActive: isActive, icon: { Image(systemName: icon) }, title: title, subtitle: { Text(subtitle) })
    }
}
#endif
