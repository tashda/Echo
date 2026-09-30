import SwiftUI

/// Every capsule style side by side, each on a small card with rows scrolled under its capsule,
/// so each can be judged with something behind the glass. Weight, size, current mark and
/// section name follow the controls.
struct LabSDStyleGallery: View {
    let options: LabSDOptions

    private let columns = [GridItem(.flexible(), spacing: SpacingTokens.md), GridItem(.flexible(), spacing: SpacingTokens.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: SpacingTokens.md) {
                ForEach(LabSDCapsuleStyle.allCases) { style in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        Text(style.rawValue)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                        LabSDStyleTile(options: styled(style))
                    }
                }
            }
            .padding(SpacingTokens.md)
        }
        .scrollIndicators(.never)
    }

    private func styled(_ style: LabSDCapsuleStyle) -> LabSDOptions {
        var options = options
        options.capsule = style
        return options
    }
}

/// A small pinned card: the name, the capsule, and rows passing under them.
private struct LabSDStyleTile: View {
    let options: LabSDOptions
    @State private var chosen = "security"

    private var server: LabSDServer { LabSDSamples.mssql(.ssms) }
    private let rows = ["AdventureWorks2022", "master", "model", "msdb", "tempdb", "dbprops_04361588"]

    var body: some View {
        let slot = options.density.rowSlot
        let headerHeight = slot + SpacingTokens.xs + SpacingTokens.sm + LabSDCapsuleMetrics.rowHeight(server, options: options)
        ZStack(alignment: .top) {
            // Rows scrolled up under the header, blurred the way the tree blurs them.
            VStack(spacing: SpacingTokens.none) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, name in
                    LabSDNodeRow(node: LabSDNode(id: name, title: name, symbol: "cylinder", color: ColorTokens.Explorer.databaseInstance),
                                 depth: 0, isExpanded: false, isSelected: false, isLoading: false, density: options.density) {}
                        .frame(height: slot)
                        .blur(radius: max(0, CGFloat(3 - index)) * 3)
                        .opacity(index < 3 ? 0.35 + Double(index) * 0.2 : 1)
                }
            }
            .padding(.top, headerHeight - slot * 2.5)
            VStack(spacing: SpacingTokens.none) {
                LabSDServerRow(server: server, sectionTitle: options.sectionName == .underName ? server.section(chosen)?.title : nil,
                               isCollapsed: false, density: options.density) {}
                    .frame(height: slot + SpacingTokens.xs + SpacingTokens.sm)
                LabSDCapsule(server: server, chosen: chosen, options: options) { chosen = $0 }
                    .frame(height: LabSDCapsuleMetrics.rowHeight(server, options: options))
            }
            .background {
                LinearGradient(stops: [.init(color: ColorTokens.Workspace.card.opacity(0.85), location: 0),
                                       .init(color: ColorTokens.Workspace.card.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(height: headerHeight + slot * 3, alignment: .top)
        .clipped()
        .workspaceCard()
    }
}

/// One card per database type, each with the proposal's grouping and overflow.
struct LabSDEveryType: View {
    let options: LabSDOptions
    var resetToken = ""

    private let columns = [GridItem(.flexible(), spacing: SpacingTokens.md), GridItem(.flexible(), spacing: SpacingTokens.md)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.md) {
            ForEach(LabSDSamples.allTypes(grouping: options.grouping)) { server in
                LabSDTreeView(servers: [server], options: options, resetToken: resetToken)
                    .frame(height: SpacingTokens.xxxl * 4 + SpacingTokens.lg)
            }
        }
        .padding(SpacingTokens.md)
    }
}
