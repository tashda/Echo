import SwiftUI

struct IdentityDecoration {
    let label: String
    let symbol: String
    let tooltip: String?
}

struct ConnectionIconCell: View {
    let connection: SavedConnection

    var body: some View {
        iconView
            .frame(width: 20, height: 20)
            .padding(.vertical, SpacingTokens.xxxs)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconView: some View {
        if let (image, isTemplate) = iconInfo {
            if isTemplate {
                image
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            } else {
                image
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "externaldrive")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.primary)
    }

    private var iconInfo: (Image, Bool)? {
#if os(macOS)
        if let nsImage = NSImage(named: connection.databaseType.iconName) {
            return (Image(nsImage: nsImage), nsImage.isTemplate)
        }
#else
        if let uiImage = UIImage(named: connection.databaseType.iconName) {
            let isTemplate = uiImage.renderingMode == .alwaysTemplate || uiImage.isSymbolImage
            let rendered = uiImage.withRenderingMode(isTemplate ? .alwaysTemplate : .alwaysOriginal)
            return (Image(uiImage: rendered), isTemplate)
        }
#endif
        return nil
    }
}

struct IdentityIconCell: View {
    let identity: SavedIdentity

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.primary)
            .frame(width: 20, height: 20)
            .padding(.vertical, SpacingTokens.xxxs)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}

struct LeadingTableCell<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 6) {
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#if os(macOS)
import AppKit

struct ThemedTableContainer<Content: View>: NSViewRepresentable {
    let content: Content
    @ObservedObject private var appearanceStore = AppearanceStore.shared
    let onConfigure: ((NSTableView) -> Void)?

    init(onConfigure: ((NSTableView) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onConfigure = onConfigure
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)

        DispatchQueue.main.async {
            if let tableView = findTableView(in: hostingView) {
                context.coordinator.tableView = tableView
                configure(tableView: tableView)
            }
        }

        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        if let tableView = context.coordinator.tableView {
            configure(tableView: tableView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configure(tableView: NSTableView) {
        applyTableTheme(tableView, appearanceStore: appearanceStore)
        onConfigure?(tableView)
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let found = findTableView(in: subview) {
                return found
            }
        }
        return nil
    }

    class Coordinator {
        weak var tableView: NSTableView?
    }
}

#else
struct ThemedTableContainer<Content: View>: View {
    let content: Content

    init(onConfigure: ((Any) -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View { content }
}
#endif
