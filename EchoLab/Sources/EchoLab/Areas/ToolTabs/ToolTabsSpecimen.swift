import SwiftUI

/// A tool tab as Echo draws it: the header on the canvas, the toolbar row under it, dashboard
/// tiles, and the panes as cards a gutter apart. Each part carries its Spec number.
struct ToolTabsSpecimen: View {
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private let gutter: CGFloat = 6

    var body: some View {
        VStack(spacing: gutter) {
            header.specAnchor("1.1")
            toolbarRow.specAnchor("2.1")
            tiles.specAnchor("3.1")
            HStack(spacing: gutter) {
                pane("Jobs", count: 5, rows: ["Nightly backup", "Index maintenance", "Stats refresh", "Log cleanup", "ETL load"]).specAnchor("4.1")
                VStack(spacing: gutter) {
                    pane("Details", rows: ["Enabled  Yes", "Owner  sa", "Next run  02:00"]).specAnchor("4.2")
                    pane("History", count: 52, rows: ["Succeeded  26 Sep 23:00"]).specAnchor("7.1")
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: 820, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(ColorTokens.accent)
                .frame(width: 28, height: 28)
                .background(ColorTokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs3, style: .continuous))
                .specAnchor("1.2")
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text("Activity Monitor").font(TypographyTokens.standard.weight(.semibold)).specAnchor("1.3")
                Text("Test MSSQL · AdventureWorks2022 · updated 2 s ago").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).monospacedDigit().specAnchor("1.4")
            }
            Spacer()
            Label("Pause", systemImage: "pause.fill").font(TypographyTokens.detail).padding(.horizontal, 10).frame(height: 24)
                .glassEffect(.regular, in: .capsule).specAnchor("1.5")
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: 40)
    }

    private var toolbarRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(["Processes", "Waits", "I/O", "Queries"], id: \.self) { title in
                Text(title).font(TypographyTokens.detail)
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(title == "Processes" ? ColorTokens.Sidebar.selectedFill : .clear, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: 26)
    }

    private var tiles: some View {
        HStack(spacing: gutter) {
            ForEach([("Processor time", "18", "%", ColorTokens.Explorer.databaseInstance), ("Waiting tasks", "3", "", ColorTokens.Explorer.jobs),
                     ("Batch requests/s", "412", "", ColorTokens.Explorer.security), ("Database I/O", "6", "MB/s", ColorTokens.Explorer.tables)], id: \.0) { item in
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(item.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Text("\(Text(item.1).font(TypographyTokens.statNumber))\(Text(item.2).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary))")
                        .monospacedDigit()
                    Sparkline(color: item.3).frame(height: 28)
                }
                .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius))
                .overlay(cardEdge)
                .shadow(ShadowTokens.workspaceCard)
            }
        }
        .frame(height: 76)
    }

    /// A pane: the one pane header (title, grey count, 36pt; TLT-6.1), then its rows.
    private func pane(_ title: String, count: Int? = nil, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(spacing: SpacingTokens.xxs2) {
                Text(title).font(TypographyTokens.headline)
                if let count { Text("\(count)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary) }
                Spacer()
            }
            .frame(height: SpacingTokens.lg + SpacingTokens.sm)
            .specAnchorIf(title == "Jobs", "6.1")
            ForEach(rows, id: \.self) { Text($0).font(TypographyTokens.standard) }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius))
        .overlay(cardEdge)
        .shadow(ShadowTokens.workspaceCard)
    }

    private var cardEdge: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth)
    }
}

/// A small filled line of recent history.
private struct Sparkline: View {
    let color: Color
    private let values: [CGFloat] = [0.3, 0.4, 0.35, 0.5, 0.45, 0.6, 0.4, 0.55, 0.7, 0.5, 0.6]

    var body: some View {
        GeometryReader { proxy in
            let points = values.enumerated().map { CGPoint(x: proxy.size.width * CGFloat($0.offset) / CGFloat(values.count - 1), y: proxy.size.height * (1 - $0.element)) }
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                }.fill(color.opacity(0.14))
                Path { path in
                    path.move(to: points[0])
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }.stroke(color.opacity(0.85), lineWidth: 1.5)
            }
        }
    }
}
