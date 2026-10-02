import SwiftUI

/// The list of connections inside the panel, drawer, palette or widened rail, in one of round
/// 52's contents and footers. Hover a row for its highlight; press one to "connect" (the lab only closes).
struct LabCMList: View {
    let look: LabCMLook
    var onConnect: () -> Void = {}
    @State private var query = ""
    @State private var folded: Set<String> = ["corporate", "All connections"]

    private var all: [LabCMConnection] { LabCMConnection.samples(look.count.limit) }
    private var matches: [LabCMConnection] {
        query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query) }
    }
    private var open: [LabCMConnection] { look.hidesOpen ? [] : matches.filter(\.isOpen) }
    private var saved: [LabCMConnection] { look.hidesOpen ? matches.filter { !$0.isOpen } : matches.filter { !$0.isOpen } }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if look.content != .menu { searchField }
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.none) { contentBody(look.content) }
                    .padding(.horizontal, SpacingTokens.xxs1)
                    .padding(.vertical, SpacingTokens.xxs)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            if !look.hidesOpen { footer }
        }
    }

    // MARK: Contents

    @ViewBuilder
    private func contentBody(_ content: LabCMContent) -> some View {
        switch content {
        case .menu: menuList
        case .search: searchList
        case .recent: recentList
        case .tiles: tiles
        case .engine: engineList
        }
    }

    /// CT0: what the system menu has today.
    private var menuList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            heading("Connections")
            ForEach(open) { plain($0) }
            Divider().padding(.vertical, SpacingTokens.xxs).padding(.horizontal, SpacingTokens.xs)
            ForEach(Array(Set(saved.compactMap(\.folder))).sorted(), id: \.self) { folder in
                LabCMRow(isChevron: true, action: {}) { Text(folder).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary) }
            }
            ForEach(saved.filter { $0.folder == nil }) { plain($0) }
        }
    }

    private func plain(_ connection: LabCMConnection) -> some View {
        LabCMRow(action: onConnect) { Text(connection.name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary) }
    }

    /// CT1.
    private var searchList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if !open.isEmpty { heading("Open") }
            ForEach(open) { row($0) }
            ForEach(folders, id: \.self) { folder in
                heading(folder ?? "Saved")
                ForEach(saved.filter { $0.folder == folder }) { row($0) }
            }
            empty
        }
    }

    /// CT2.
    private var recentList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if !open.isEmpty { heading("Open") }
            ForEach(open) { row($0) }
            if query.isEmpty {
                heading("Recent")
                ForEach(saved.filter(\.isRecent).prefix(3)) { row($0) }
                foldingHeading("All connections")
                if !folded.contains("All connections") {
                    ForEach(saved) { row($0, showsFolder: true) }
                }
            } else {
                heading("Matches")
                ForEach(saved) { row($0, showsFolder: true) }
            }
            empty
        }
    }

    /// CT3.
    private var tiles: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if !open.isEmpty { heading("Open") }
            tileGrid(open)
            heading("Saved")
            tileGrid(saved)
            empty
        }
    }

    private func tileGrid(_ connections: [LabCMConnection]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.xxs), count: 2), spacing: SpacingTokens.xxs) {
            ForEach(connections) { connection in
                LabCMTile(connection: connection, action: onConnect)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs)
    }

    /// CT4.
    private var engineList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(LabCMEngine.allCases, id: \.self) { engine in
                let rows = matches.filter { $0.engine == engine }
                if !rows.isEmpty {
                    heading(engine.rawValue)
                    ForEach(rows) { row($0, showsFolder: true) }
                }
            }
            empty
        }
    }

    // MARK: Pieces

    private var folders: [String?] {
        let names = Array(Set(saved.compactMap(\.folder))).sorted()
        return (saved.contains { $0.folder == nil } ? [nil] : []) + names.map { Optional($0) }
    }

    private func row(_ connection: LabCMConnection, showsFolder: Bool = false) -> some View {
        LabCMRow(action: onConnect) {
            HStack(spacing: SpacingTokens.xs2) {
                LabCMMark(connection: connection)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(connection.name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    Text(showsFolder && connection.folder != nil ? "\(connection.folder ?? "") · \(connection.detail)" : connection.detail)
                        .font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.xxs)
                if connection.isOpen { Circle().fill(ColorTokens.Status.success).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2) }
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs).padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxs)
    }

    private func foldingHeading(_ title: String) -> some View {
        Button {
            if folded.contains(title) { folded.remove(title) } else { folded.insert(title) }
        } label: {
            HStack(spacing: SpacingTokens.xxs) {
                Text(title).font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
                Image(systemName: "chevron.right").font(SidebarRowConstants.sectionChevronFont).foregroundStyle(ColorTokens.Text.tertiary)
                    .rotationEffect(.degrees(folded.contains(title) ? 0 : 90))
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.xs).padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var empty: some View {
        if matches.isEmpty {
            Text("No connection matches \"\(query)\"").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
                .padding(SpacingTokens.sm)
        }
    }

    // MARK: Search and footer

    private var searchField: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: "magnifyingglass").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                TextField("", text: $query, prompt: Text("Search connections"))
                    .textFieldStyle(.plain).font(TypographyTokens.standard)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
            .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
            if look.hidesOpen, look.opened == .search { LabCMActionIcons(onClose: nil, look: look) }
            if !look.hidesOpen, look.footer == .split {
                Button { onConnect() } label: {
                    Label("New", systemImage: "plus").font(TypographyTokens.detail.weight(.medium))
                        .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg + SpacingTokens.xxs)
                        .background(ColorTokens.accent, in: Capsule()).foregroundStyle(ColorTokens.Text.onFill)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpacingTokens.xs)
    }

    @ViewBuilder
    private var footer: some View {
        switch look.footer {
        case .rows:
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Divider().padding(.horizontal, SpacingTokens.xs)
                LabCMRow(action: {}) { Label("New Connection", systemImage: "plus").font(TypographyTokens.standard) }
                LabCMRow(action: {}) { Label("Manage Connections", systemImage: "gearshape").font(TypographyTokens.standard) }
                LabCMRow(action: {}) { Label("Quick Connect", systemImage: "bolt.fill").font(TypographyTokens.standard) }
            }
            .padding(.horizontal, SpacingTokens.xxs1).padding(.bottom, SpacingTokens.xxs)
        case .bar:
            VStack(spacing: SpacingTokens.none) {
                Divider()
                HStack(spacing: SpacingTokens.xxs) {
                    footerButton("New", "plus")
                    footerButton("Manage", "gearshape")
                    footerButton("Quick Connect", "bolt.fill")
                }
                .padding(SpacingTokens.xxs1)
            }
        case .split:
            HStack(spacing: SpacingTokens.md) {
                Button("Manage Connections") {}
                Button("Quick Connect") {}
            }
            .buttonStyle(.plain)
            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, SpacingTokens.xs)
        }
    }

    private func footerButton(_ title: String, _ symbol: String) -> some View {
        Button {} label: {
            Label(title, systemImage: symbol).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity).frame(height: SpacingTokens.lg)
                .background(ColorTokens.Text.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A row with a hover highlight, as a menu's.
struct LabCMRow<Content: View>: View {
    var isChevron = false
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xxs) {
                content
                if isChevron {
                    Spacer(minLength: SpacingTokens.xxs)
                    Image(systemName: "chevron.right").font(SidebarRowConstants.sectionChevronFont)
                        .foregroundStyle(isHovering ? ColorTokens.Text.onFill : ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(minHeight: SpacingTokens.lg + SpacingTokens.xxs, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).fill(ColorTokens.Sidebar.selectedFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// A connection's mark in a list: a filled disc with its letters.
struct LabCMMark: View {
    let connection: LabCMConnection
    var size: CGFloat = SpacingTokens.lg

    var body: some View {
        Circle().fill(connection.color)
            .frame(width: size, height: size)
            .overlay {
                Text(connection.monogram)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.Text.onFill)
            }
    }
}

private struct LabCMTile: View {
    let connection: LabCMConnection
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                LabCMMark(connection: connection)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(connection.name).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    Text(connection.detail.components(separatedBy: " · ").last ?? "").font(.system(size: 10)).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.xs)
            .background(isHovering ? ColorTokens.Sidebar.selectedFill : ColorTokens.Text.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}


extension LabCMLook {
    /// The opened trail with its actions in a header: the list drops its Open section and its footer.
    var hidesOpen: Bool { presentation == .rail && opened.hidesOpenSection }
}

/// New Connection, Manage Connections and Quick Connect as icons, and optionally the close button.
struct LabCMActionIcons: View {
    let onClose: (() -> Void)?
    let look: LabCMLook
    var onlyClose = false
    var namespace: Namespace.ID?

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            if !onlyClose {
                icon("plus", "New Connection")
                icon("gearshape", "Manage Connections")
                icon("bolt.fill", "Quick Connect")
            }
            if let onClose, look.close != .none {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(look.close == .filled ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .frame(width: SpacingTokens.lg + SpacingTokens.xxs, height: SpacingTokens.lg + SpacingTokens.xxs)
                        .background(look.close == .filled ? ColorTokens.Text.primary.opacity(0.1) : Color.clear, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
                .modifier(LabCMMatched(namespace: namespace))
            }
        }
    }

    private func icon(_ symbol: String, _ help: String) -> some View {
        Button {} label: {
            Image(systemName: symbol).font(.system(size: 12.5, weight: .medium)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: SpacingTokens.lg + SpacingTokens.xxs, height: SpacingTokens.lg + SpacingTokens.xxs)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// A server as the trail draws it (monogram, the white disc when selected), so the opened trail's row
/// looks like the trail it came from.
struct LabCMTrailItem: View {
    let server: LabTIServer
    var isSelected = false
    private var size: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }

    var body: some View {
        LabTIMark(server: server, style: .monogram, isSelected: isSelected, size: size)
            .background {
                if isSelected {
                    Capsule().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                        .padding(LayoutTokens.Rail.selectionInset)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

/// The opened trail's top: the connected servers lying in a row, as in the trail, and the actions.
/// The row scrolls sideways under a soft edge when there are more servers than room.
struct LabCMOpenedHeader: View {
    let look: LabCMLook
    let servers: [LabTIServer]
    @Binding var selected: String
    let namespace: Namespace.ID
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xxs) {
                ScrollView(.horizontal) {
                    HStack(spacing: LayoutTokens.Rail.itemSpacing) {
                        ForEach(servers) { server in
                            Button { selected = server.id; onClose() } label: { LabCMTrailItem(server: server, isSelected: server.id == selected) }
                                .buttonStyle(.plain)
                                .help(server.server.name)
                                .matchedGeometryEffect(id: server.id, in: namespace)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .horizontal)
                switch look.opened {
                case .header: LabCMActionIcons(onClose: onClose, look: look, namespace: namespace)
                default: LabCMActionIcons(onClose: onClose, look: look, onlyClose: true, namespace: namespace)
                }
            }
            if look.opened == .stacked {
                HStack { Spacer(minLength: SpacingTokens.none); LabCMActionIcons(onClose: nil, look: look) }
            }
        }
    }
}

/// Lets the + glide to the close button's place as the trail opens.
struct LabCMMatched: ViewModifier {
    let namespace: Namespace.ID?
    func body(content: Content) -> some View {
        if let namespace { content.matchedGeometryEffect(id: "toggle", in: namespace) } else { content }
    }
}
