import SwiftUI

/// One toast, drawn from the round's options.
struct NTToastView: View {
    let toast: NTSimulation.Toast
    let options: NTOptions
    let simulation: NTSimulation
    /// Toasts hidden behind this one (S3 shows them as "+2").
    var hiddenCount = 0

    @State private var dragOffset: CGFloat = 0
    @Environment(\.echoMotion) private var motion

    private var isExpanded: Bool { simulation.hoveredID == toast.id }
    private var isPill: Bool { options.layout == .pill && !isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            content
            if isExpanded { actions.padding(.leading, SpacingTokens.lg).conformanceTag(tag("actions")) }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, isPill ? SpacingTokens.xxs2 : SpacingTokens.xs)
        .frame(width: isPill ? nil : LayoutTokens.Toast.width, alignment: .leading)
        .modifier(NTMaterialModifier(material: options.material, tint: toast.tint, isPill: isPill))
        .conformanceTag(tag())
        .offset(x: dragOffset)
        .opacity(1 - Double(min(dragOffset / 240, 0.6)))
        .gesture(swipe, including: options.dismiss == .swipe ? .all : .none)
        .onTapGesture {
            if options.dismiss == .click || options.actions == .none { simulation.dismiss(toast.id) }
        }
        .onHover { inside in
            if inside { simulation.hoveredID = toast.id } else if simulation.hoveredID == toast.id { simulation.hoveredID = nil }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch options.layout {
        case .oneLine:
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                icon
                Text(toast.message)
                    .font(TypographyTokens.standard.weight(.medium))
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isExpanded)
                    .textSelection(.enabled)
                trailing
            }
        case .titleDetail, .pill:
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                icon
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(toast.headline).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                        .conformanceTag(tag("title"))
                    if !isPill, let detail = toast.detail {
                        Text(detail)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isExpanded)
                            .textSelection(.enabled)
                            .conformanceTag(tag("detail"))
                    }
                }
                if isPill { count } else { trailing }
            }
        case .withServer:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                    icon
                    Text(toast.headline).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                    trailing
                }
                Text(isExpanded ? (toast.detail ?? toast.server) : "\(toast.server) · now")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: isExpanded)
                    .textSelection(.enabled)
                    .padding(.leading, SpacingTokens.lg)
            }
        }
    }

    private var icon: some View {
        Image(systemName: toast.icon)
            .font(TypographyTokens.standard.weight(.semibold))
            .foregroundStyle(toast.tint)
            .conformanceTag(tag("icon"))
    }

    /// The conformance tag of this toast or one of its parts: `toast.error`, `toast.error.title`.
    private func tag(_ part: String? = nil) -> String {
        ["toast", "\(toast.kind)", part].compactMap(\.self).joined(separator: ".")
    }

    @ViewBuilder
    private var count: some View {
        let total = toast.count > 1 ? toast.count : 0
        if total > 0 || hiddenCount > 0 {
            Text(hiddenCount > 0 ? "+\(hiddenCount)" : "×\(total)")
                .font(TypographyTokens.detail.weight(.semibold).monospacedDigit())
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    /// The count, then × when the dismiss style shows one. These join the row's own HStack, as in
    /// Echo: wrapped in a stack of their own (with its Spacer) they took half the row from the text,
    /// which cut the title and wrapped the reason short (found by the conformance check, rev 2).
    @ViewBuilder
    private var trailing: some View {
        count
        Spacer(minLength: SpacingTokens.none)
        if options.dismiss != .click {
            let shows = options.dismiss == .alwaysX || isExpanded || toast.kind == .error
            Button { simulation.dismiss(toast.id) } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .opacity(shows ? 1 : 0)
                .help("Dismiss")
                .conformanceTag(tag("dismiss"))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch options.actions {
        case .textLinks:
            HStack(spacing: SpacingTokens.sm) { actionButtons }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.accent)
        case .smallButtons:
            HStack(spacing: SpacingTokens.xs) { actionButtons }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .icons:
            HStack(spacing: SpacingTokens.sm) {
                if let link = toast.link { Button {} label: { Image(systemName: "arrow.up.right.square") }.help(link) }
                Button {} label: { Image(systemName: "doc.on.doc") }.help("Copy")
                Button {} label: { Image(systemName: "list.bullet") }.help("Show All")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ColorTokens.Text.secondary)
        case .none:
            Text("Click to open")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let link = toast.link { Button(link) { simulation.dismiss(toast.id) } }
        Button("Copy") {}
        Button("Show All") { simulation.dismiss(toast.id) }
    }

    /// D3: flick it to the right to dismiss; a short drag springs back.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { dragOffset = max(0, $0.translation.width) }
            .onEnded { value in
                if value.translation.width > LayoutTokens.Toast.width / 4 {
                    simulation.dismiss(toast.id)
                } else {
                    withAnimation(motion.standard) { dragOffset = 0 }
                }
            }
    }
}

/// M1 glass, M2 glass tinted by severity, M3 an opaque card.
private struct NTMaterialModifier: ViewModifier {
    let material: NTMaterial
    let tint: Color
    let isPill: Bool

    func body(content: Content) -> some View {
        let radius = isPill ? LayoutTokens.Toast.width : LayoutTokens.Toast.cornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch material {
        case .glass:
            content.glassEffect(.regular.interactive(), in: shape)
        case .tintedGlass:
            content.glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: shape)
        case .card:
            content
                .background(ColorTokens.Workspace.card, in: shape)
                .overlay(shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
                .shadow(ShadowTokens.workspaceCard)
        }
    }
}
