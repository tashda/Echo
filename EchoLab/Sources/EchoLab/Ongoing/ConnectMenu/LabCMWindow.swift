import SwiftUI

/// Enough of Echo's window to feel the + opening: the trail with two servers and the +, the two
/// cards beside it. Press the + (or Escape) to open and close the list.
struct LabCMWindow: View {
    let look: LabCMLook
    @State private var isOpen = false
    @Namespace private var glass
    @Environment(\.echoMotion) private var motion

    private let servers = ["TP", "TM"]
    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var railWidth: CGFloat { itemSize + railPad * 2 }
    private var gap: CGFloat { SpacingTokens.xxs2 }
    /// The + sits under the servers.
    private var plusTop: CGFloat { railPad + CGFloat(servers.count) * (itemSize + LayoutTokens.Rail.itemSpacing) }
    private var panelWidth: CGFloat { SpacingTokens.xxxl * 4.6 }
    private var isRailOpen: Bool { look.presentation == .rail && isOpen }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree
                .padding(.leading, railWidth + SpacingTokens.sm + SpacingTokens.xxs1)
            if look.presentation == .palette, isOpen {
                ColorTokens.Text.primary.opacity(0.12).transition(.opacity)
                    .onTapGesture { toggle() }
            }
            presentation
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: isOpen)
        .onExitCommand { if isOpen { toggle() } }
    }

    private func toggle() { isOpen.toggle() }

    // MARK: Rail

    private var rail: some View {
        GlassEffectContainer(spacing: SpacingTokens.xs) {
            Group {
                if isRailOpen, look.opened != .classic {
                    // Revision 2: the servers lie down into a row, the actions are icons.
                    VStack(spacing: SpacingTokens.xxs) {
                        LabCMOpenedHeader(look: look, onClose: { toggle() })
                        LabCMList(look: look, onConnect: { toggle() })
                            .frame(width: panelWidth - railPad * 2, height: SpacingTokens.xxxl * 5.4)
                    }
                    .padding(railPad)
                    .transition(.opacity)
                } else {
                    closedColumn
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: isRailOpen && look.opened != .classic ? SpacingTokens.lg : railWidth / 2, style: .continuous))
        }
    }

    /// The trail as it is: a column of servers and the +; revision 1 widened it to a list below the servers.
    private var closedColumn: some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) {
            ForEach(servers, id: \.self) { code in
                LabTIMark(server: code == "TP" ? .named("dev") : .named("test"), style: .monogram, isSelected: code == "TM")
            }
            if isRailOpen {
                LabCMList(look: look, onConnect: { toggle() })
                    .frame(width: panelWidth - railPad * 2, height: SpacingTokens.xxxl * 5.4)
                    .transition(.opacity)
            }
            plus
        }
        .padding(railPad)
    }

    @ViewBuilder
    private var plus: some View {
        if look.presentation == .menu {
            Menu {
                LabCMNativeMenu()
            } label: { plusGlyph }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            Button { toggle() } label: { plusGlyph }
                .buttonStyle(.plain)
                .background {
                    if look.morph == .lift, isOpen {
                        Circle().fill(.clear)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID("connect", in: glass)
                    }
                }
        }
    }

    private var plusGlyph: some View {
        Group {
            switch look.morph {
            case .none, .lift:
                Image(systemName: "plus")
            case .turn:
                Image(systemName: "plus").rotationEffect(.degrees(isOpen ? 45 : 0))
            case .chevronBack:
                Image(systemName: isOpen ? "chevron.left" : "plus").contentTransition(.symbolEffect(.replace))
            case .chevronOut:
                Image(systemName: isOpen ? "chevron.right" : "plus").contentTransition(.symbolEffect(.replace))
            }
        }
        .font(.system(size: LayoutTokens.Rail.toolSymbolSize, weight: .medium))
        .foregroundStyle(isOpen ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        .frame(width: itemSize, height: itemSize)
        .contentShape(Circle())
    }

    // MARK: Presentations

    @ViewBuilder
    private var presentation: some View {
        if isOpen {
            switch look.presentation {
            case .panel:
                glassPanel(height: SpacingTokens.xxxl * 5.4)
                    .padding(.leading, railWidth + gap + SpacingTokens.xxs1)
                    .padding(.top, plusTop + SpacingTokens.xxs1)
                    .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
            case .drawer:
                glassPanel(height: nil)
                    .padding(.leading, railWidth + gap + SpacingTokens.xxs1)
                    .padding(.vertical, SpacingTokens.xxs1)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .palette:
                glassPanel(height: SpacingTokens.xxxl * 5)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, SpacingTokens.xxl)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            case .menu, .rail:
                EmptyView()
            }
        }
    }

    private func glassPanel(height: CGFloat?) -> some View {
        LabCMList(look: look, onConnect: { toggle() })
            .frame(width: panelWidth, height: height)
            .frame(maxHeight: height == nil ? .infinity : height)
            .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.lg, style: .continuous))
            .glassEffectID(look.morph == .lift ? "connect" : "panel", in: glass)
            .shadow(color: ColorTokens.Text.primary.opacity(0.1), radius: SpacingTokens.md, y: SpacingTokens.xxs)
    }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabSHCard(server: .development, look: .today, rowLimit: 3, selectedRow: nil)
            LabSHCard(server: .test, look: .today, rowLimit: 3, selectedRow: nil)
        }
        .padding(.trailing, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The menu as it is today (ConnectionsMenuContent): open sessions, saved connections, then the actions.
struct LabCMNativeMenu: View {
    var body: some View {
        Section("Connections") {
            Button("Test Postgres • postgres") {}
            Button("Test MSSQL • AdventureWorks2022") {}
            Divider()
            Menu("corporate") {
                Button("dkloosql10-p") {}
                Button("dkloosql20-t") {}
                Button("ReadsoftEast") {}
            }
            ForEach(["dkhj-axpresql01", "Microsoft SQL Server", "mssql25", "mssql25 (Copy)", "mysql", "norway",
                     "postgres_services", "postgres16", "postgres18", "tippr"], id: \.self) { Button($0) {} }
        }
        Divider()
        Button { } label: { Label("Manage Connections", systemImage: "gearshape") }
        Button { } label: { Label("Quick Connect", systemImage: "bolt.fill") }
    }
}

/// Every content on its own, in a panel, so the lists can be compared without opening anything.
struct LabCMGallery: View {
    let look: LabCMLook

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabCMContent.allCases, id: \.self) { content in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(content.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabCMList(look: LabCMLook(presentation: look.presentation, morph: look.morph, content: content,
                                                  footer: look.footer, count: look.count))
                            .frame(height: SpacingTokens.xxxl * 5.4)
                            .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.lg, style: .continuous))
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
