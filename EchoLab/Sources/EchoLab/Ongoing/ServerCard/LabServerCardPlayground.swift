import SwiftUI

/// Round 16 · Server card. Echo today beside a proposal built from the controls, with the same
/// two servers, so every bug and every idea is judged on real SwiftUI.
struct LabServerCardPlayground: View {
    @State private var options = LabSCOptions()

    private var todayOptions: LabSCOptions {
        LabSCOptions(header: .today, edge: .material, switchMotion: .today, loading: .shimmer, latency: options.latency,
                     dockIcons: options.treeIcons, treeIcons: options.treeIcons, density: options.density,
                     counts: .hover, selection: .today, version: .beside, speed: options.speed)
    }

    var body: some View {
        LabStage(title: "Server card · round 16") {
            Text("Left is Echo today, right is the proposal. Scroll, switch sections, open folders, right-click the icons.")
                .foregroundStyle(ColorTokens.Text.secondary)
        } content: {
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: SpacingTokens.lg) {
                    controls
                    column("Echo today", options: todayOptions)
                    column("Proposal", options: options)
                    LabSCQuestions()
                }
                .padding(SpacingTokens.md)
            }
        }
    }

    private func column(_ title: String, options: LabSCOptions) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.headline)
            LabSCTreeColumn(servers: LabSCServer.samples, options: options,
                            dockIcons: $options.dockIcons, treeIcons: $options.treeIcons)
                .frame(width: LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl, height: SpacingTokens.xxxl * 9)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        }
    }

    private var controls: some View {
        Form {
            Section("Header") {
                picker("Style", $options.header)
                Text(options.header.summary).font(TypographyTokens.callout).foregroundStyle(ColorTokens.Text.secondary)
                picker("Version", $options.version)
                picker("Dock icons", $options.dockIcons)
            }
            Section("Under the header") {
                picker("Edge", $options.edge)
                Text(options.edge.summary).font(TypographyTokens.callout).foregroundStyle(ColorTokens.Text.secondary)
            }
            Section("Switching and loading") {
                picker("Switch", $options.switchMotion)
                picker("Loading", $options.loading)
                Text(options.loading.summary).font(TypographyTokens.callout).foregroundStyle(ColorTokens.Text.secondary)
                picker("Server", $options.latency)
                picker("Speed", $options.speed)
            }
            Section("Rows") {
                picker("Sidebar size", $options.density)
                picker("Tree icons", $options.treeIcons)
                picker("Counts", $options.counts)
                picker("Selection", $options.selection)
            }
        }
        .formStyle(.grouped)
        .frame(width: SpacingTokens.xxxl * 5)
        .frame(minHeight: SpacingTokens.xxxl * 9)
    }

    private func picker<Value: Hashable & Identifiable & RawRepresentable & CaseIterable>(_ title: String, _ selection: Binding<Value>) -> some View
    where Value.RawValue == String, Value.AllCases: RandomAccessCollection {
        Picker(title, selection: selection) {
            ForEach(Value.allCases) { Text($0.rawValue).tag($0) }
        }
    }
}

/// What to try, and what to look at, for each question of the round.
private struct LabSCQuestions: View {
    private let questions: [(String, String)] = [
        ("1 · Header", "Header › Style. Try each with Sidebar size at Default and Large. Which reads best: the name with icons under it, one line, a menu, or glass?"),
        ("2 · Version", "Header › Version. SQL Server shows as \"SQL Server 2022\" (the full build is in the tooltip). Under, beside, or only in the tooltip?"),
        ("3 · Under the header", "Scroll the Proposal. Compare Blur rows and Fade rows with Today. System edge is macOS's own, but only works with one server per column (the picker stands in for the rail)."),
        ("4 · Switching", "Click the dock icons. Crossfade, Slide or Instant instead of rows dropping in from the top?"),
        ("5 · Loading", "Set Server to Slow, press Reset loading, then open Security and Tables. Quiet skeleton or Keep + spinner? With a Fast server the skeleton never shows."),
        ("6 · Counts", "Hover a folder while it loads. On hover, always (quiet), or hidden?"),
        ("7 · Selection", "Select a row. Symmetric insets fix the fill touching the left edge."),
        ("8 · Customising", "Right-click an icon: its section's own menu, then Dock. Customize Dock sets the icons for every server of the type or this server only, and the dock's icon style apart from the tree's."),
        ("9 · PostgreSQL", "postgres18 gets Activity, Management and Tablespaces from tools Echo already has. Anything missing or wrongly grouped?"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Questions").font(TypographyTokens.headline)
            ForEach(questions, id: \.0) { title, detail in
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(title).font(TypographyTokens.standard.weight(.semibold))
                    Text(detail)
                        .font(TypographyTokens.callout)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(width: SpacingTokens.xxxl * 4, alignment: .leading)
    }
}
