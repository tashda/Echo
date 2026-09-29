#if DEBUG
import SwiftUI

enum LabHeaderStyle: String, CaseIterable, Identifiable {
    case bold = "Bold"
    case caps = "Small caps"
    var id: String { rawValue }
}

enum LabIconMode: String, CaseIterable, Identifiable {
    case mono = "Monochrome"
    case monoAccent = "Mono + accent on open"
    case soft = "Soft colour"
    var id: String { rawValue }
}

/// Mock Explorer tree: server sections whose header pins at the top and grows a breadcrumb for the
/// database you are scrolled into.
struct LabTreeView: View {
    var servers: [LabServer] = Array(LabServer.samples.prefix(3))
    var headerStyle: LabHeaderStyle = .bold
    var iconMode: LabIconMode = .mono
    var onTopServerChange: (String?) -> Void = { _ in }

    @State private var visibleIDs: Set<String> = []
    @State private var selectedRow: String? = "pg18.employees.salary"

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(servers) { server in
                    Section {
                        sectionRows(server)
                    } header: {
                        header(server)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.automatic)
        .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.2) { ids in
            visibleIDs = Set(ids)
            onTopServerChange(topServerID)
        }
    }

    // MARK: Pinned header

    /// The first server with any visible row, in tree order.
    private var topServerID: String? {
        servers.first { server in rowIDs(server).contains { visibleIDs.contains($0) } }?.id
    }

    private func isPinned(_ server: LabServer) -> Bool {
        server.id == topServerID && !visibleIDs.contains(anchorID(server))
    }

    /// Database the user is scrolled into within a server.
    private func currentDatabase(_ server: LabServer) -> String? {
        for database in LabTree.databases[server.id] ?? [] {
            let ids = [database.id] + database.tables.map { "\(database.id).\($0)" }
            if ids.contains(where: { visibleIDs.contains($0) }) { return database.name }
        }
        return nil
    }

    private func header(_ server: LabServer) -> some View {
        let pinned = isPinned(server)
        let database = pinned ? currentDatabase(server) : nil

        return HStack(spacing: 4) {
            Text(headerStyle == .caps ? server.name.uppercased() : server.name)
                .font(headerStyle == .caps ? .system(size: 11, weight: .semibold) : .system(size: 13, weight: .bold))
                .tracking(headerStyle == .caps ? 0.4 : 0)
                .foregroundStyle(headerStyle == .caps ? .secondary : .primary)
            if let database {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(headerStyle == .caps ? database.uppercased() : database)
                    .font(headerStyle == .caps ? .system(size: 11, weight: .semibold) : .system(size: 13))
                    .tracking(headerStyle == .caps ? 0.4 : 0)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .offset(x: -4)))
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(alignment: .top) {
            // Soft fade under the text instead of a band: rows dissolve as they pass beneath.
            Color(nsColor: .windowBackgroundColor)
                .frame(height: 42)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .opacity(pinned ? 1 : 0)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.2), value: database)
        .animation(.easeInOut(duration: 0.2), value: pinned)
    }

    // MARK: Rows

    private func anchorID(_ server: LabServer) -> String { "\(server.id).anchor" }

    private func rowIDs(_ server: LabServer) -> [String] {
        (LabTree.databases[server.id] ?? []).flatMap { [$0.id] + $0.tables.map { table in "\($0.id).\(table)" } }
    }

    @ViewBuilder
    private func sectionRows(_ server: LabServer) -> some View {
        Color.clear.frame(height: 1).id(anchorID(server))
        LabTreeRow(depth: 0, icon: "cylinder.split.1x2", title: "Databases", detail: "\((LabTree.databases[server.id] ?? []).count)", isExpanded: true, iconColor: folderColor(.green, expanded: true))
        ForEach(LabTree.databases[server.id] ?? []) { database in
            LabTreeRow(depth: 1, icon: "cylinder", title: database.name, isExpanded: true, iconColor: folderColor(.blue, expanded: true))
                .id(database.id)
            LabTreeRow(depth: 2, icon: "tablecells", title: "Tables", detail: "\(database.tables.count)", isExpanded: true, iconColor: folderColor(.cyan, expanded: true))
            ForEach(database.tables, id: \.self) { table in
                let rowID = "\(database.id).\(table)"
                Button { selectedRow = rowID } label: {
                    LabTreeRow(depth: 3, icon: "tablecells", title: table, isExpanded: false, iconColor: selectedRow == rowID ? .accentColor : .secondary, isSelected: selectedRow == rowID)
                }
                .buttonStyle(.plain)
                .id(rowID)
            }
        }
        LabTreeRow(depth: 0, icon: "shield", title: "Security", isExpanded: false, iconColor: folderColor(.purple, expanded: false))
        Color.clear.frame(height: 10)
    }

    private func folderColor(_ color: Color, expanded: Bool) -> Color {
        switch iconMode {
        case .mono: return .secondary
        case .monoAccent: return expanded ? .accentColor : .secondary
        case .soft: return color.opacity(0.65)
        }
    }
}

struct LabTreePlayground: View {
    @State private var headerStyle: LabHeaderStyle = .bold
    @State private var iconMode: LabIconMode = .mono

    var body: some View {
        LabStage(title: "Tree · sticky server header and icon colour") {
            LabPicker(title: "Header", selection: $headerStyle, options: LabHeaderStyle.allCases)
            LabPicker(title: "Icons", selection: $iconMode, options: LabIconMode.allCases)
        } content: {
            HStack(spacing: 0) {
                LabTreeView(headerStyle: headerStyle, iconMode: iconMode)
                    .frame(width: 300)
                Text("Scroll the tree. The server header pins at the top and shows the database you're in.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 720, height: 560)
    }
}

#Preview("Tree · sticky header, icons") {
    LabTreePlayground()
}
#endif
