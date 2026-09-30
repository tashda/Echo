#if DEBUG
import SwiftUI

/// Round 15: getting the top-right toasts right, and three popover-free notification centers, in
/// one live window. Post a few, hover them, open the bell, show the inspector.
struct LabRound15NotificationsPlayground: View {
    @State private var center = LabNoticeCenter()
    @State private var style: LabNoticeCenterStyle = .unfold
    @State private var top: LabToastTop = .belowToolbar
    @State private var showsInspector = false
    @State private var speed: LabSpeed = .standard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LabStage(title: "Notifications · placement and history") {
            Button("Post") { center.post() }
            Button("Post the same again") { center.repeatLatest() }
            LabPicker(title: "History", selection: $style, options: LabNoticeCenterStyle.allCases)
            LabPicker(title: "Toasts' top", selection: $top, options: LabToastTop.allCases)
            Toggle("Inspector", isOn: $showsInspector)
            LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
        } content: {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(style.summary)
                    .font(TypographyTokens.callout)
                    .foregroundStyle(ColorTokens.Text.secondary)
                LabNoticeWindow(center: center, style: style, top: top, showsInspector: showsInspector)
            }
            .padding(SpacingTokens.md)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.toasts)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.hoveredToast)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.isOpen)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.expandedItem)
            .animation(speed.spring(reduceMotion: reduceMotion), value: showsInspector)
        }
    }
}

private struct LabNoticeWindow: View {
    let center: LabNoticeCenter
    let style: LabNoticeCenterStyle
    let top: LabToastTop
    let showsInspector: Bool

    @State private var selectedItem: UUID? = LabNotice.samples[1].id

    private var gutter: CGFloat { SpacingTokens.xs }
    private var showsTabPage: Bool { style == .tab && center.isOpen }
    private var showsDrawer: Bool { style == .drawer && center.isOpen }
    private var showsColumn: Bool { showsInspector || showsDrawer }

    var body: some View {
        VStack(spacing: gutter) {
            toolbar
            HStack(spacing: gutter) {
                LabWindowCard { Text("Explorer").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).padding(SpacingTokens.sm) }
                    .frame(width: LabRound15NoticeMetrics.treeWidth)
                VStack(spacing: gutter) {
                    tabBar
                    LabWindowCard {
                        if showsTabPage { tabPage } else { LabEditorText().padding(SpacingTokens.sm) }
                    }
                }
                if showsColumn {
                    LabWindowCard { column }
                        .frame(width: LabRound15NoticeMetrics.inspectorWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) { corner }
        }
        .padding(gutter)
        .frame(width: LabRound15NoticeMetrics.windowWidth, height: LabRound15NoticeMetrics.windowHeight)
        .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous).strokeBorder(.separator, lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
    }

    private var toolbar: some View {
        HStack(spacing: gutter) {
            LabRunGlyphCapsule(symbols: ["sidebar.left"])
            Spacer(minLength: SpacingTokens.none)
            LabRunEditorCapsule()
            HStack(spacing: SpacingTokens.none) {
                LabRunGlyph(symbol: "magnifyingglass")
                LabRunGlyph(symbol: "square.grid.2x2")
                Button { center.isOpen.toggle() } label: {
                    LabRunGlyph(symbol: center.isOpen ? "bell.fill" : "bell")
                        .overlay(alignment: .topTrailing) {
                            if !center.toasts.isEmpty && !center.isOpen {
                                Circle().fill(ColorTokens.Status.error).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                            }
                        }
                }
                .buttonStyle(.plain)
                LabRunGlyph(symbol: "sidebar.right")
            }
            .padding(.horizontal, SpacingTokens.xxs)
            .glassEffect(.regular, in: .capsule)
        }
        .frame(height: LabRound15Metrics.toolbarHeight)
    }

    private var tabBar: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: !showsTabPage)
            LabRunTabLabel(icon: "doc.text", title: "Query 3", subtitle: "employees", isActive: false)
            if style == .tab && center.isOpen {
                LabRunTabLabel(icon: "bell", title: "Notifications", subtitle: "\(center.history.count)", isActive: true)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
    }

    /// The top-right corner: toasts, or the unfolded history. It lines up with the toolbar's
    /// trailing capsule, or with the cards when a column is open.
    private var corner: some View {
        let trailing = showsColumn ? LabRound15NoticeMetrics.inspectorWidth + gutter : SpacingTokens.none
        let topInset = top == .belowToolbar ? SpacingTokens.none : LabRound15Metrics.tabHeight + SpacingTokens.xs + gutter
        return GlassEffectContainer(spacing: SpacingTokens.sm) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                if style == .unfold && center.isOpen {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        LabNoticeHeader()
                        LabNoticeList(center: center)
                    }
                    .padding(LayoutTokens.FloatingSurface.padding)
                    .frame(width: LabRound15NoticeMetrics.toastWidth, height: LabRound15NoticeMetrics.panelMaxHeight)
                    .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius))
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
                } else {
                    ForEach(center.toasts) { notice in
                        LabToastView(notice: notice, center: center)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.top, topInset)
        .padding(.trailing, trailing)
    }

    @ViewBuilder
    private var column: some View {
        if showsDrawer {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                LabNoticeHeader()
                LabNoticeList(center: center)
            }
            .padding(LayoutTokens.FloatingSurface.padding)
        } else {
            Text("Inspector").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).padding(SpacingTokens.sm)
        }
    }

    /// Option C: list on the left, the whole message on the right.
    private var tabPage: some View {
        HStack(spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                LabNoticeHeader()
                LabNoticeList(center: center, selection: $selectedItem)
            }
            .padding(LayoutTokens.FloatingSurface.padding)
            .frame(width: LabRound15NoticeMetrics.historyListWidth)
            Divider()
            if let notice = center.history.first(where: { $0.id == selectedItem }) {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Label(notice.title, systemImage: notice.symbol)
                        .font(TypographyTokens.headline)
                        .foregroundStyle(notice.tint)
                    Text("\(notice.server) · \(notice.time)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Text(notice.detail).font(TypographyTokens.code).textSelection(.enabled)
                    LabNoticeActions(notice: notice)
                    Spacer(minLength: SpacingTokens.none)
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// An opaque card in the mock window.
private struct LabWindowCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
                .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
            .shadow(ShadowTokens.workspaceCard)
    }
}
#endif
