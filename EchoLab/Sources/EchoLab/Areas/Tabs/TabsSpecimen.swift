import AppKit
import Observation
import SwiftUI

/// What the Tabs specimen shows; the spec's controls change it.
@Observable @MainActor
final class TabsSpecimenModel {
    private struct Saved: Codable { var count: Int; var active: Int; var isRunning: Bool; var showsPages: Bool; var hasPinned: Bool }

    var count = 4 { didSet { save() } }
    var active = 0 { didSet { save() } }
    var isRunning = true { didSet { save() } }
    var showsPages = true { didSet { save() } }
    var hasPinned = false { didSet { save() } }
    /// A state forced from the Spec page: hoverInactive, hoverActive, hoverClose or dropTarget.
    var forced: String?

    init() {
        if let saved: Saved = LabPrefs.load("tabsSpecimen", default: Optional<Saved>.none) {
            count = saved.count; active = saved.active; isRunning = saved.isRunning
            showsPages = saved.showsPages; hasPinned = saved.hasPinned
        }
    }

    private func save() {
        LabPrefs.save(Saved(count: count, active: active, isRunning: isRunning, showsPages: showsPages, hasPinned: hasPinned), key: "tabsSpecimen")
    }
}

/// Echo's tab strip drawn from the same tokens and metrics as `QueryTabStrip` and
/// `QueryTabButton` (one line, Round 9 plate), without Echo's app state. Parts carry their
/// element numbers (`specAnchor`) so the Spec view can label them.
struct TabsSpecimen: View {
    @Bindable var model: TabsSpecimenModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.echoMotion) private var motion
    @State private var hovered: Int?
    @State private var closeHovered = false
    @State private var plusHovered = false
    @State private var selectedPage = "Processes"

    private struct Item { let title: String; let icon: String; let pages: [String]; let pinned: Bool }

    /// The unfolded tab, or nil: the strip springs only when this changes (QueryTabStrip).
    private var unfoldedKey: Int? {
        let list = items
        guard model.showsPages, list.count > 1, list.indices.contains(model.active), !list[model.active].pages.isEmpty else { return nil }
        return model.active
    }

    private var items: [Item] {
        var list: [Item] = []
        if model.hasPinned { list.append(Item(title: "Q", icon: "doc.text", pages: [], pinned: true)) }
        list += [
            Item(title: "Activity Monitor", icon: "waveform.path.ecg", pages: ["Processes", "Waits", "I/O", "Queries", "XEvents", "Profiler"], pinned: false),
            Item(title: "Jobs", icon: "clock", pages: [], pinned: false),
            Item(title: "Query 2", icon: "doc.text", pages: [], pinned: false),
            Item(title: "Query 3", icon: "doc.text", pages: [], pinned: false),
        ]
        var n = 4
        while list.count < model.count { list.append(Item(title: "Query \(n)", icon: "doc.text", pages: [], pinned: false)); n += 1 }
        return Array(list.prefix(max(model.count, 1)))
    }

    // Echo's metrics (QueryTabStrip, QueryTabButton, WorkspaceChromeMetrics).
    private let stripHeight: CGFloat = 32
    private let plateHeight: CGFloat = 28
    private let plateCorner: CGFloat = 14
    private let plateInset: CGFloat = 2
    private let tabHeight: CGFloat = 24
    private let tabCorner: CGFloat = 15
    private let plusSize: CGFloat = 28
    private let plusGap: CGFloat = 6
    private let cardEdgePadding: CGFloat = 8
    private var hairline: CGFloat { tabHairlineWidth() }
    private var isDark: Bool { scheme == .dark }

    private var effectiveHovered: Int? {
        switch model.forced {
        case "hoverInactive": firstInactive >= 0 ? firstInactive : hovered
        case "hoverActive", "hoverClose": model.active
        default: hovered
        }
    }
    private var effectiveClose: Bool { closeHovered || model.forced == "hoverClose" }
    private var dropIndex: Int? { model.forced == "dropTarget" ? firstInactive : nil }

    var body: some View {
        GeometryReader { geo in
            let list = items
            let n = CGFloat(list.count)
            let leading = cardEdgePadding + plateInset
            let available = max(geo.size.width - leading - (cardEdgePadding + plateInset) - plusSize - plusGap, 0)
            let effective = max(available - hairline * max(n - 1, 0), 0)
            let equal = effective / n
            let widths = tabWidths(list, equal: equal, total: effective)
            let group = widths.reduce(0, +) + hairline * max(n - 1, 0)

            VStack {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: plateCorner, style: .continuous)
                        .fill(ColorTokens.TabStrip.Background.plate)
                        .frame(width: group + plateInset * 2, height: plateHeight)
                        .offset(x: leading - plateInset)
                        .specAnchor("1.2")
                    HStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.offset) { index, item in
                                tab(item, index: index, width: widths[index])
                                    .overlay(alignment: .trailing) {
                                        if index < list.count - 1 {
                                            separator(hidden: index == model.active || index + 1 == model.active || index == effectiveHovered || index + 1 == effectiveHovered)
                                                .specAnchorIf(index == 0, "3.1")
                                        }
                                    }
                            }
                        }
                        .fixedSize()
                        .specAnchor("1.3")
                        plus.padding(.leading, plusGap)
                    }
                    .padding(.leading, leading)
                }
                .frame(height: stripHeight)
                .specAnchor("1.1")
                // As in Echo: only a tool tab unfolding or folding springs (the house spring, round
                // 36.1); a plain switch is instant.
                .animation(motion.standard, value: unfoldedKey)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: Widths (QueryTabStrip+Unfold)

    private func tabWidths(_ list: [Item], equal: CGFloat, total: CGFloat) -> [CGFloat] {
        let base = Array(repeating: equal, count: list.count)
        guard list.indices.contains(model.active), model.showsPages, !list[model.active].pages.isEmpty, list.count > 1 else { return base }
        let item = list[model.active]
        let size = TypographyTokens.AppKit.detail.pointSize
        let title = (item.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium)]).width
        let pages = item.pages.reduce(CGFloat.zero) {
            $0 + ($1 as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)]).width
                + LayoutTokens.TabPages.chipHorizontalPadding * 2 + LayoutTokens.TabPages.spacing
        }
        let ideal = ceil(title + pages + LayoutTokens.TabPages.tabChrome)
        // Round 36.1 (RW1): exactly its content's width, at most 62% of the strip.
        let unfolded = min(ideal, total * LayoutTokens.TabPages.maxShareOfStrip)
        guard unfolded != equal else { return base }
        let others = max((total - unfolded) / CGFloat(list.count - 1), 0)
        return list.indices.map { $0 == model.active ? unfolded : others }
    }

    // MARK: Tab (QueryTabButton)

    private func tab(_ item: Item, index: Int, width: CGFloat) -> some View {
        let isActive = index == model.active
        let isHover = effectiveHovered == index
        let isDrop = dropIndex == index
        let showsClose = isHover && !item.pinned
        return HStack(spacing: SpacingTokens.xxxs) {
            Group {
                if item.pinned { Color.clear.frame(width: 0, height: 12) } else { closeButton(visible: showsClose, isActive: isActive, anchored: isActive) }
            }
            titleContent(item, isActive: isActive, anchored: isActive)
                .frame(maxWidth: .infinity, alignment: .center)
            Color.clear.frame(width: item.pinned ? 0 : SpacingTokens.sm2, height: 12)
        }
        .padding(.leading, item.pinned ? 13 : SpacingTokens.xs)
        .padding(.trailing, item.pinned ? 13 : SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxxs)
        .frame(width: width, height: tabHeight)
        .background(background(isActive: isActive, isHover: isHover, isDrop: isDrop))
        .overlay(stroke(isActive: isActive, isHover: isHover))
        .shadow(color: isActive ? shadowColor : .clear, radius: 2.5, y: 1.2)
        .specAnchorIf(isActive, "2.1")
        .specAnchorIf(!isActive && !isHover && index == firstInactive, "2.5")
        .specAnchorIf(isHover && !isActive, "2.6")
        .specAnchorIf(item.pinned, "2.9")
        .contentShape(RoundedRectangle(cornerRadius: tabCorner, style: .continuous))
        .onHover { inside in hovered = inside ? index : (hovered == index ? nil : hovered); if !inside { closeHovered = false } }
        .onTapGesture { if !closeHovered { model.active = index } }
    }

    private var firstInactive: Int { items.indices.first { $0 != model.active } ?? -1 }

    @ViewBuilder
    private func titleContent(_ item: Item, isActive: Bool, anchored: Bool) -> some View {
        if item.pinned {
            Text(item.title).font(TypographyTokens.detail.weight(.semibold)).lineLimit(1).foregroundStyle(titleColor(isActive, pinned: true))
        } else {
            HStack(spacing: SpacingTokens.xxs2) {
                Group {
                    if model.isRunning && item.title == "Query 2" {
                        ProgressView().controlSize(.mini).specAnchorIf(true, "2.10")
                    } else {
                        Image(systemName: item.icon).font(TypographyTokens.detail)
                            .foregroundStyle(titleColor(isActive, pinned: false).opacity(isActive ? 0.8 : 0.7))
                            .specAnchorIf(anchored, "2.2")
                    }
                }
                .frame(width: SpacingTokens.sm2)
                Text(item.title)
                    .font(isActive && model.showsPages && !item.pages.isEmpty ? TypographyTokens.detail.weight(.medium) : TypographyTokens.detail)
                    .lineLimit(1).layoutPriority(1)
                    .foregroundStyle(titleColor(isActive, pinned: false))
                    .specAnchorIf(anchored, "2.3")
                if isActive && model.showsPages && !item.pages.isEmpty {
                    pageChips(item.pages).specAnchor("5.1")
                }
            }
        }
    }

    private func titleColor(_ active: Bool, pinned: Bool) -> Color {
        Color(nsColor: active ? .labelColor : (pinned ? NSColor.secondaryLabelColor.withAlphaComponent(0.75) : .secondaryLabelColor))
    }

    // MARK: Close ×

    private func closeButton(visible: Bool, isActive: Bool, anchored: Bool) -> some View {
        let foreground: Color = effectiveClose ? Color(nsColor: .labelColor)
            : (isActive ? Color(nsColor: .secondaryLabelColor) : Color(nsColor: .tertiaryLabelColor))
        return Image(systemName: "xmark")
            .font(TypographyTokens.compact.weight(.bold))
            .foregroundStyle(foreground)
            .frame(width: SpacingTokens.sm2, height: SpacingTokens.sm2)
            .background(Circle().fill(effectiveClose && visible ? (isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)) : .clear))
            .opacity(visible ? 1 : 0)
            .contentShape(Circle())
            .onHover { closeHovered = $0 && visible }
            .help("Close tab")
            .specAnchorIf(anchored, "2.7")
    }

    // MARK: Fills

    private func background(isActive: Bool, isHover: Bool, isDrop: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: tabCorner, style: .continuous)
        return Group {
            if isDrop {
                shape.fill(LinearGradient(colors: isDark ? [ColorTokens.TabStrip.DropTarget.Dark.top, ColorTokens.TabStrip.DropTarget.Dark.bottom] : [ColorTokens.TabStrip.DropTarget.Light.top, ColorTokens.TabStrip.DropTarget.Light.bottom], startPoint: .top, endPoint: .bottom))
                    .specAnchor("2.8")
            } else if isActive {
                shape.fill(LinearGradient(colors: isHover ? activeHover : activeIdle, startPoint: .top, endPoint: .bottom))
                    .specAnchor("2.4")
            } else if isHover {
                shape.fill(LinearGradient(colors: inactiveHover, startPoint: .top, endPoint: .bottom))
            } else {
                shape.fill(Color.clear)
            }
        }
    }

    private func stroke(isActive: Bool, isHover: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: tabCorner, style: .continuous)
        return Group {
            if isActive { shape.stroke(isDark ? ColorTokens.TabStrip.Border.activeDark : ColorTokens.TabStrip.Border.activeLight, lineWidth: hairline) }
            else if isHover { shape.stroke(isDark ? ColorTokens.TabStrip.Border.hoverDark : ColorTokens.TabStrip.Border.hoverLight, lineWidth: hairline) }
        }
    }

    private var activeIdle: [Color] { isDark ? [ColorTokens.TabStrip.ActiveTab.Dark.top, ColorTokens.TabStrip.ActiveTab.Dark.bottom] : [ColorTokens.TabStrip.ActiveTab.Light.top, ColorTokens.TabStrip.ActiveTab.Light.bottom] }
    private var activeHover: [Color] { isDark ? [ColorTokens.TabStrip.ActiveTab.Dark.hoverTop, ColorTokens.TabStrip.ActiveTab.Dark.hoverBottom] : [ColorTokens.TabStrip.ActiveTab.Light.hoverTop, ColorTokens.TabStrip.ActiveTab.Light.hoverBottom] }
    private var inactiveHover: [Color] { isDark ? [ColorTokens.TabStrip.InactiveHover.Dark.top, ColorTokens.TabStrip.InactiveHover.Dark.bottom] : [ColorTokens.TabStrip.InactiveHover.Light.top, ColorTokens.TabStrip.InactiveHover.Light.bottom] }
    private var shadowColor: Color { isDark ? ColorTokens.TabStrip.Shadow.dark : ColorTokens.TabStrip.Shadow.light }

    // MARK: Separator, +, page chips

    private func separator(hidden: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(LinearGradient(
                colors: isDark ? [ColorTokens.TabStrip.Separator.Dark.top, ColorTokens.TabStrip.Separator.Dark.bottom]
                               : [ColorTokens.TabStrip.Separator.Light.top, ColorTokens.TabStrip.Separator.Light.bottom],
                startPoint: .top, endPoint: .bottom))
            .frame(width: hairline, height: 18)
            .padding(.vertical, SpacingTokens.xs)
            .opacity(hidden ? 0 : 1)
    }

    private var plus: some View {
        Image(systemName: "plus")
            .font(TypographyTokens.prominent.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: plusSize, height: plusSize)
            .background(Circle().fill(Color.primary.opacity(plusHovered ? 0.06 : 0)))
            .glassEffect(.regular, in: .circle)
            .onHover { plusHovered = $0 }
            .help("New Tab")
            .specAnchor("4.1")
    }

    private func pageChips(_ pages: [String]) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Rectangle().fill(ColorTokens.Separator.primary)
                .frame(width: LayoutTokens.TabPages.dividerWidth, height: LayoutTokens.TabPages.dividerHeight)
                .padding(.horizontal, LayoutTokens.TabPages.dividerPadding)
                .specAnchor("5.3")
            HStack(spacing: LayoutTokens.TabPages.spacing) {
                ForEach(pages, id: \.self) { page in
                    let isSelected = page == selectedPage
                    Text(page)
                        .font(TypographyTokens.detail.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, LayoutTokens.TabPages.chipHorizontalPadding)
                        .frame(height: LayoutTokens.TabPages.chipHeight)
                        .background { if isSelected { Capsule().fill(ColorTokens.TabStrip.Pages.selected) } }
                        .contentShape(Capsule())
                        .onTapGesture { withAnimation(motion.press) { selectedPage = page } }
                }
            }
        }
    }
}


extension View {
    /// `specAnchor` only when `condition` holds.
    @ViewBuilder
    func specAnchorIf(_ condition: Bool, _ number: String) -> some View {
        if condition { specAnchor(number) } else { self }
    }
}

/// Echo's hairline: one device pixel, never thinner than 0.5pt.
@MainActor
func tabHairlineWidth() -> CGFloat {
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    return max(1.0 / scale, 0.5)
}
