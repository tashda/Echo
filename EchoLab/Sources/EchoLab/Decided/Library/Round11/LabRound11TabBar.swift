import SwiftUI

/// The tab bar in one of round 11's designs. Tabs select on press, show a close button on hover,
/// and + adds one.
struct LabTabBarView: View {
    let design: LabTabDesign
    @Binding var tabs: [LabTabItem]
    @Binding var activeID: UUID?

    @Namespace private var selection
    private let height: CGFloat = 30

    var body: some View {
        Group {
            switch design {
            case .todayGlass:
                capsule { row(fill: true); plus(glass: false) }
            case .classic:
                HStack(spacing: 6) {
                    HStack(spacing: 2) { row(fill: true) }
                        .padding(3)
                        .background(Color.primary.opacity(0.07), in: .rect(cornerRadius: 9))
                    plus(glass: true)
                }
            case .safari, .serverColour, .accent:
                capsule { row(fill: true); plus(glass: false) }
            case .filled:
                capsule { row(fill: true, spacing: 3); plus(glass: false) }
            case .separatePills:
                HStack(spacing: 6) { row(fill: false, spacing: 6); plus(glass: true); Spacer(minLength: 0) }
            case .hugging:
                HStack {
                    capsule { row(fill: false); plus(glass: false) }
                    Spacer(minLength: 0)
                }
            case .underline:
                HStack(spacing: 2) { row(fill: false, spacing: 4); plus(glass: false); Spacer(minLength: 0) }
                    .padding(.horizontal, 6)
            case .twoLine:
                capsule { row(fill: true); plus(glass: false) }
            }
        }
        .frame(height: design == .twoLine ? height + 8 : height)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: activeID)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: tabs)
    }

    private func capsule(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 2) { content() }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private func row(fill: Bool, spacing: CGFloat = 2) -> some View {
        ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
            LabTabButton(
                design: design,
                tab: tab,
                isActive: tab.id == activeID,
                fillsWidth: fill,
                showsDivider: design == .safari || design == .serverColour
                    ? index < tabs.count - 1 && tab.id != activeID && tabs[index + 1].id != activeID
                    : false,
                selection: selection,
                onSelect: { activeID = tab.id },
                onClose: { close(tab) }
            )
            if spacing > 2, index < tabs.count - 1 { Spacer().frame(width: spacing - 2) }
        }
    }

    private func plus(glass: Bool) -> some View {
        Button {
            let tab = LabTabItem(title: "Query \(tabs.count + 1)", database: "employees", symbol: "doc.text", serverColor: .blue)
            tabs.append(tab)
            activeID = tab.id
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .modifier(LabGlassIf(isOn: glass, shape: .circle))
        .help("New Query Tab")
    }

    private func close(_ tab: LabTabItem) {
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        if activeID == tab.id { activeID = tabs[min(index, tabs.count - 1)].id }
    }
}

private struct LabGlassIf<S: Shape>: ViewModifier {
    let isOn: Bool
    let shape: S

    func body(content: Content) -> some View {
        if isOn { content.glassEffect(.regular, in: shape) } else { content }
    }
}

/// One tab in a round 11 design.
struct LabTabButton: View {
    let design: LabTabDesign
    let tab: LabTabItem
    let isActive: Bool
    let fillsWidth: Bool
    let showsDivider: Bool
    let selection: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            leading
            titleBlock
            if fillsWidth { Spacer(minLength: 0) }
            closeButton
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .frame(minWidth: design == .hugging ? 90 : nil, maxWidth: design == .hugging ? 200 : (fillsWidth ? .infinity : nil))
        .frame(height: design == .twoLine ? 32 : 24)
        .background { background }
        .overlay(alignment: .bottom) { underline }
        .overlay(alignment: .trailing) {
            if showsDivider {
                Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 1, height: 12).offset(x: 1)
            }
        }
        .contentShape(.capsule)
        .onHover { isHovering = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in onSelect() })
    }

    // MARK: Parts

    @ViewBuilder
    private var leading: some View {
        if tab.isRunning {
            ProgressView().controlSize(.mini)
        } else if design == .serverColour {
            Circle().fill(tab.serverColor).frame(width: 6, height: 6)
        } else if design == .twoLine || design == .separatePills || design == .hugging {
            Image(systemName: tab.symbol)
                .font(.system(size: 11))
                .foregroundStyle(isActive && design == .accent ? .white : .secondary)
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        if design == .twoLine {
            VStack(alignment: .leading, spacing: 0) {
                Text(tab.title).font(.system(size: 11.5, weight: isActive ? .semibold : .medium)).foregroundStyle(titleColor)
                Group {
                    if tab.isRunning { Text(Date().addingTimeInterval(-12), style: .timer) } else { Text(tab.database) }
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        } else {
            HStack(spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 11.5, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(titleColor)
                Text(tab.isRunning ? "0:12" : tab.database)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(subtitleColor)
            }
            .lineLimit(1)
        }
    }

    private var titleColor: Color {
        if design == .accent && isActive { return .white }
        switch design {
        case .todayGlass: return isActive ? .primary : .secondary
        case .underline: return isActive ? .primary : .secondary
        default: return .primary.opacity(isActive ? 1 : 0.8)
        }
    }

    private var subtitleColor: Color {
        if design == .accent && isActive { return .white.opacity(0.75) }
        return design == .todayGlass ? Color.secondary.opacity(0.6) : .secondary
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(design == .accent && isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 14, height: 14)
                .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .help("Close Tab")
    }

    @ViewBuilder
    private var background: some View {
        let shape = Capsule()
        switch design {
        case .underline:
            if isHovering && !isActive { RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)) }
        case .separatePills:
            shape.fill(isActive ? Color(nsColor: .textBackgroundColor) : .clear)
                .shadow(color: .black.opacity(isActive ? 0.15 : 0), radius: 1.5, y: 0.5)
                .modifier(LabGlassIf(isOn: !isActive, shape: shape))
        case .filled:
            if isActive {
                activePill
            } else {
                shape.fill(Color.primary.opacity(isHovering ? 0.1 : 0.06))
            }
        case .accent:
            if isActive {
                shape.fill(Color.accentColor).matchedGeometryEffect(id: "active", in: selection)
            } else if isHovering {
                shape.fill(Color.primary.opacity(0.06))
            }
        case .serverColour:
            if isActive {
                activePill.overlay(alignment: .leading) {
                    Capsule().fill(tab.serverColor).frame(width: 3, height: 14).padding(.leading, 4)
                }
            } else if isHovering {
                shape.fill(Color.primary.opacity(0.06))
            }
        default:
            if isActive {
                activePill
            } else if isHovering {
                shape.fill(Color.primary.opacity(0.06))
            }
        }
    }

    private var activePill: some View {
        Capsule()
            .fill(Color(nsColor: .textBackgroundColor))
            .shadow(color: .black.opacity(0.16), radius: 1.5, y: 0.5)
            .matchedGeometryEffect(id: "active", in: selection)
    }

    @ViewBuilder
    private var underline: some View {
        if design == .underline && isActive {
            Capsule().fill(Color.accentColor).frame(width: 24, height: 2).offset(y: 2)
                .matchedGeometryEffect(id: "active", in: selection)
        }
    }
}
