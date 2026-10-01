import SwiftUI

/// The welcome as Echo draws it (WorkspaceWelcomeView): the mark, the connect actions on glass
/// buttons and the latest connections on one small card. The mark's name is a choice (WM0 keeps it).
struct LabOCWelcome: View {
    let scene: LabOCScene

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            VStack(spacing: SpacingTokens.sm) {
                LabOCMark(phase: scene.markPhase, ghosts: scene.look.mark == .ghosts, slow: scene.look.slow)
                if scene.look.mark.showsName {
                    Text("Echo")
                        .font(.system(size: LayoutTokens.Welcome.titleSize, weight: .bold))
                        .foregroundStyle(ColorTokens.Text.primary)
                }
            }
            actions.modifier(LabOCRise(shown: scene.actionsShown))
            recents.modifier(LabOCRise(shown: scene.recentsShown))
        }
        .frame(maxWidth: LayoutTokens.Welcome.width)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(scene.welcomeOpacity)
    }

    private var actions: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button {} label: { Label("Connect", systemImage: "plus") }.buttonStyle(.glassProminent)
            Button {} label: { Label("Quick Connect", systemImage: "bolt") }.buttonStyle(.glass)
            Button {} label: { Label("Manage", systemImage: "gearshape") }.buttonStyle(.glass)
        }
        .controlSize(.large)
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Recent")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.leading, LayoutTokens.FloatingSurface.padding)
            VStack(spacing: SpacingTokens.none) {
                ForEach(Array(LabOCSample.recents.enumerated()), id: \.offset) { _, recent in
                    HStack(spacing: SpacingTokens.xs) {
                        Text(recent.monogram)
                            .font(.system(size: LayoutTokens.Welcome.monogramSize, weight: .bold, design: .rounded))
                            .foregroundStyle(recent.color)
                            .frame(width: LayoutTokens.Welcome.monogramWidth)
                        Text(recent.name).font(TypographyTokens.standard.weight(.medium)).foregroundStyle(ColorTokens.Text.primary)
                        Text(recent.host).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        Spacer(minLength: SpacingTokens.xs)
                        Text(recent.ago).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .frame(height: LayoutTokens.FloatingSurface.rowHeight)
                }
            }
            .padding(LayoutTokens.Welcome.listPadding)
            .workspaceCard()
        }
    }
}

/// The connected server's page (ConnectionDashboardView): the name large, its version, the tools
/// on glass buttons and the databases on one small card. Its four pieces can arrive one by one.
struct LabOCServerPage: View {
    let scene: LabOCScene

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.lg) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(LabOCSample.serverName)
                    .font(.system(size: LayoutTokens.ServerPage.nameSize, weight: .bold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .modifier(LabOCRise(shown: scene.pieces > 0, distance: 8))
                Text(LabOCSample.serverVersion)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .modifier(LabOCRise(shown: scene.pieces > 1, distance: 8))
            }
            HStack(spacing: SpacingTokens.xs) {
                Button {} label: { Label("New Query", systemImage: "plus") }.buttonStyle(.glassProminent)
                Button {} label: { Label("Activity", systemImage: "gauge.high") }.buttonStyle(.glass)
                Button {} label: { Label("Jobs", systemImage: "clock") }.buttonStyle(.glass)
            }
            .controlSize(.large)
            .modifier(LabOCRise(shown: scene.pieces > 2, distance: 8))
            databases.modifier(LabOCRise(shown: scene.pieces > 3, distance: 8))
        }
        .frame(maxWidth: LayoutTokens.ServerPage.width, alignment: .leading)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.top, SpacingTokens.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(scene.serverOpacity)
    }

    private var databases: some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(LabOCSample.databases, id: \.self) { name in
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "cylinder").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Sidebar.symbol)
                        .frame(width: SpacingTokens.lg)
                    Text(name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary)
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.FloatingSurface.rowHeight)
            }
        }
        .padding(LayoutTokens.Welcome.listPadding)
        .workspaceCard()
    }
}

/// An open query tab: the strip with its tab, and the card with an editor over a result.
struct LabOCTabLayer: View {
    let scene: LabOCScene

    var body: some View {
        ZStack {
            // Opaque canvas under the tab, so a page kept underneath (CH1) is covered until the card leaves.
            ColorTokens.Workspace.canvas.opacity(scene.tabOpacity)
            VStack(spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xxs) {
                    HStack(spacing: SpacingTokens.xxs) {
                        Image(systemName: "doc.text").foregroundStyle(ColorTokens.Text.secondary)
                        Text("Query 1").foregroundStyle(ColorTokens.Text.primary)
                        Image(systemName: "xmark").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .font(TypographyTokens.standard)
                    .padding(.horizontal, SpacingTokens.xs)
                    .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
                    .glassEffect(.regular, in: .capsule)
                    Spacer()
                }
                .frame(height: SpacingTokens.xl)
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(LabOCSample.queryLines, id: \.self) { line in
                        Text(line).font(.system(size: 12, design: .monospaced)).foregroundStyle(ColorTokens.Text.primary)
                    }
                    Spacer()
                    Divider()
                    Text("3 rows · 0.04 s").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .workspaceCard()
            }
            .opacity(scene.tabOpacity)
            .scaleEffect(scene.tabScale)
        }
        .allowsHitTesting(false)
    }
}

/// Fades a piece in and lifts it into place.
struct LabOCRise: ViewModifier {
    let shown: Bool
    var distance: CGFloat = 10

    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : distance)
    }
}

/// Sample content for the stage.
enum LabOCSample {
    static let serverName = "dkloosql10-p"
    static let serverVersion = "SQL Server 2017"
    static let databases = ["AML", "ccsLDK10", "DBA", "master"]
    static let queryLines = ["SELECT TOP 10 *", "FROM dbo.Orders", "ORDER BY OrderDate DESC;"]

    struct Recent {
        let monogram: String
        let name: String
        let host: String
        let ago: String
        let color: Color
    }

    static let recents: [Recent] = [
        Recent(monogram: "DK", name: serverName, host: "dkloosql10-p.corp", ago: "2m", color: ColorTokens.Status.error),
        Recent(monogram: "18", name: "postgres18", host: "localhost:5432", ago: "1h", color: ColorTokens.Status.info),
        Recent(monogram: "WH", name: "warehouse", host: "wh.internal", ago: "3d", color: ColorTokens.Status.success),
    ]
}
