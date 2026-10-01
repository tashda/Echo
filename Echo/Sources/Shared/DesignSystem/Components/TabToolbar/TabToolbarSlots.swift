import SwiftUI

/// The front tab's special button (round 37.5): a native toolbar item showing its symbol and word
/// (MA1); running, Stop with a pulsing red dot (ST1). It changes in place as tabs and pages change.
struct TabToolbarSpecialSlot: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(\.echoMotion) private var motion

    var body: some View {
        Group {
            if let item = tabStore.activeTab?.toolbarSection?.special {
                TabToolbarButton(item: item, showsTitle: true)
            }
        }
        .animation(motion.standard, value: tabStore.activeTab?.toolbarSection?.special)
    }
}

/// One group of the front tab's other buttons (round 37.5): a native toolbar item whose buttons
/// share the system's glass, as the query editor's Format · Validate · Help · Plan do.
struct TabToolbarGroupSlot: View {
    let index: Int
    @Environment(TabStore.self) private var tabStore
    @Environment(\.echoMotion) private var motion

    private var items: [TabToolbarItem] {
        let groups = tabStore.activeTab?.toolbarSection?.groups.filter { !$0.isEmpty } ?? []
        return groups.indices.contains(index) ? groups[index] : []
    }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(items) { TabToolbarButton(item: $0, showsTitle: false) }
        }
        .animation(motion.standard, value: items.map(\.id))
    }
}

/// A tab's button as a plain toolbar control, so the toolbar gives it its size and highlight: a
/// button, a toggle that shows when it is on, a menu, or a spinner while busy.
struct TabToolbarButton: View {
    let item: TabToolbarItem
    let showsTitle: Bool

    var body: some View {
        Group {
            if item.isBusy {
                ProgressView().controlSize(.small)
                    .help(item.title)
            } else if !item.menu.isEmpty {
                Menu {
                    ForEach(item.menu) { entry in
                        if entry.title == "—" {
                            Divider()
                        } else {
                            Button(entry.title, systemImage: entry.symbol, action: entry.action)
                                .disabled(entry.isDisabled)
                        }
                    }
                } label: { label }
                .menuIndicator(showsTitle ? .visible : .hidden)
            } else if item.isToggle {
                Toggle(isOn: Binding(get: { item.isOn }, set: { _ in MainActor.assumeIsolated { item.action() } })) { label }
                    .toggleStyle(.button)
            } else {
                Button(action: item.action) { label }
            }
        }
        .modifier(TabToolbarLabelStyle(showsTitle: showsTitle))
        .disabled(item.isDisabled)
        .help(shownTitle)
        .accessibilityLabel(shownTitle)
    }

    private var shownTitle: String { item.isRunning ? (item.runningTitle ?? "Stop") : item.title }

    @ViewBuilder
    private var label: some View {
        if item.isRunning {
            Label {
                Text(shownTitle)
            } icon: {
                PulsingStatusDot(tint: ColorTokens.Status.error, isPulsing: true)
            }
        } else {
            Label(shownTitle, systemImage: item.symbol)
        }
    }
}

/// The special button shows its word (MA1); the group's buttons only their symbols.
private struct TabToolbarLabelStyle: ViewModifier {
    let showsTitle: Bool

    func body(content: Content) -> some View {
        if showsTitle { content.labelStyle(.titleAndIcon) } else { content.labelStyle(.iconOnly) }
    }
}
