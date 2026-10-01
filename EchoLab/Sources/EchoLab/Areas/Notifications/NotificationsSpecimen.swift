import SwiftUI

/// Notifications as Echo has them today (commit 755f8254): toasts in the top-right corner of the
/// tab's first card, the bell with its unread badge, and the history in the inspector's column.
struct NotificationsSpecimen: View {
    let state: NotificationsSpecimenState

    @Environment(\.echoMotion) private var motion
    private let gutter = SpacingTokens.xs

    var body: some View {
        VStack(spacing: gutter) {
            toolbar
            HStack(spacing: SpacingTokens.none) {
                VStack(spacing: gutter) {
                    tabBar
                    editorCard
                }
                .padding(.trailing, state.column == .closed ? gutter : SpacingTokens.none)
                column
            }
        }
        .padding(.leading, gutter)
        .padding(.vertical, gutter)
        // The column moves as the tree does: the house spring out, settling back.
        .animation(state.column == .closed ? motion.settle : motion.standard, value: state.column)
    }

    private var toolbar: some View {
        HStack(spacing: gutter) {
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
            Spacer(minLength: SpacingTokens.none)
            RunSpecimenCapsule {
                RunSpecimenGlyph(symbol: "magnifyingglass")
                RunSpecimenGlyph(symbol: "square.grid.2x2")
                RunSpecimenGlyph(symbol: "arrow.clockwise")
                Button(action: state.toggleHistory) {
                    RunSpecimenGlyph(symbol: state.column == .history ? "bell.fill" : "bell")
                        .overlay(alignment: .topTrailing) { badge }
                }
                .specAnchor("4.1")
                .buttonStyle(.plain)
                .help("Notifications")
                Button(action: state.toggleInspector) {
                    RunSpecimenGlyph(symbol: state.column == .details ? "sidebar.right" : "sidebar.right")
                        .symbolVariant(state.column == .details ? .fill : .none)
                }
                .buttonStyle(.plain)
                .help("Inspector")
            }
        }
        .padding(.trailing, gutter)
    }

    @ViewBuilder
    private var badge: some View {
        if state.unread > 0 {
            Text("\(state.unread)")
                .font(TypographyTokens.compact.weight(.bold))
                .foregroundStyle(ColorTokens.Background.primary)
                .padding(.horizontal, SpacingTokens.xxxs1)
                .background(ColorTokens.Status.error, in: .capsule)
        }
    }

    private var tabBar: some View {
        HStack {
            Label("Query 1", systemImage: "tablecells")
                .font(TypographyTokens.standard)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.xxs2)
                .background(ColorTokens.Workspace.card, in: .capsule)
        }
        .padding(SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
    }

    /// The tab's first card; the toasts sit in its top-right corner, inset from its edges.
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("select *")
            Text("from employees.employee")
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.code)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .overlay(alignment: .topTrailing) {
            NotificationsSpecimenToasts(state: state)
                .padding(LayoutTokens.Toast.inset)
        }
    }

    @ViewBuilder
    private var column: some View {
        let isVisible = state.column != .closed
        let width = LayoutTokens.Inspector.idealWidth
        ZStack {
            if state.column == .history {
                NotificationsSpecimenHistory(state: state).transition(.opacity)
            } else {
                NotificationsSpecimenDetails().transition(.opacity)
            }
        }
        .frame(width: width)
        .specAnchor("3.1")
        .padding(.horizontal, gutter)
        .offset(x: isVisible || motion.reduceMotion ? 0 : width + gutter * 2)
        .opacity(isVisible ? 1 : 0)
        .frame(width: isVisible ? width + gutter * 2 : 0, alignment: .leading)
        .clipped()
    }
}

/// The toast stack: up to three, one width, melting together in one glass container.
private struct NotificationsSpecimenToasts: View {
    let state: NotificationsSpecimenState
    @Environment(\.echoMotion) private var motion

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.sm) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                ForEach(state.toasts) { toast in
                    NotificationsSpecimenToast(toast: toast, state: state)
                        .specAnchor("1.1")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .specAnchor("2.1")
        .animation(motion.standard, value: state.toasts)
        .animation(motion.standard, value: state.hoveredID)
    }
}

/// One toast, copied from StatusToastRow (round 18): a bold title with the reason under it in
/// two lines; hovered, the whole reason (selectable) and small buttons; a flick right dismisses.
private struct NotificationsSpecimenToast: View {
    let toast: NotificationsSpecimenState.Event
    let state: NotificationsSpecimenState

    @State private var dragOffset: CGFloat = 0
    @Environment(\.echoMotion) private var motion

    private var isExpanded: Bool { state.hoveredID == toast.id }

    var body: some View {
        let parts = toast.message.components(separatedBy: ": ")
        let detail = parts.count > 1 ? parts.dropFirst().joined(separator: ": ") : nil
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: toast.icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(toast.tint)
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(parts.first ?? toast.message)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .lineLimit(1)
                        .specAnchor("1.2")
                    if let detail {
                        Text(detail)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isExpanded)
                            .textSelection(.enabled)
                            .specAnchor("1.3")
                    }
                }
                if toast.count > 1 {
                    Text("×\(toast.count)")
                        .font(TypographyTokens.detail.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer(minLength: SpacingTokens.none)
                Button { state.dismiss(toast.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .opacity(isExpanded || toast.kind == .error ? 1 : 0)
            }
            if isExpanded {
                HStack(spacing: SpacingTokens.xs) {
                    if let link = toast.link { Button(link) { state.dismiss(toast.id) } }
                    Button("Copy") {}
                    Button("Show All") {
                        state.dismiss(toast.id)
                        state.toggleHistory()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.leading, SpacingTokens.lg)
                .specAnchor("1.4")
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .frame(width: LayoutTokens.Toast.width, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: LayoutTokens.Toast.cornerRadius, style: .continuous))
        .offset(x: dragOffset)
        .opacity(1 - Double(min(dragOffset / LayoutTokens.Toast.width, LayoutTokens.Toast.swipeFadeLimit)))
        .gesture(
            DragGesture(minimumDistance: SpacingTokens.xs)
                .onChanged { dragOffset = max(0, $0.translation.width) }
                .onEnded { value in
                    if value.translation.width > LayoutTokens.Toast.swipeDismissDistance {
                        state.dismiss(toast.id)
                    } else {
                        withAnimation(motion.standard) { dragOffset = 0 }
                    }
                }
        )
        .onHover { inside in
            if inside { state.hoveredID = toast.id } else if state.hoveredID == toast.id { state.hoveredID = nil }
        }
    }
}
