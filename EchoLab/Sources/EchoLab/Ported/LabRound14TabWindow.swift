import SwiftUI

/// One mock window: canvas, the tree card, the tab bar, the tool pages and the content card.
struct LabRound14TabWindow: View {
    let style: LabRound14BarStyle
    let pageStyle: LabRound14PageStyle
    let animation: Animation

    @State private var state = LabRound14TabState()
    @State private var toolTabFrame: CGRect = .zero
    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    private var toolIsActive: Bool { state.activeTab?.hasPages == true }

    var body: some View {
        HStack(alignment: .top, spacing: LayoutTokens.DesignLabRound14.gutter) {
            LabRound14TreeStub()
                .frame(width: LayoutTokens.DesignLabRound14.treeWidth)
            VStack(spacing: LayoutTokens.DesignLabRound14.gutter) {
                LabRound14TabBar(style: style, pageStyle: pageStyle, state: state, animation: animation) { toolTabFrame = $0 }
                pagesRow
                content
            }
        }
        .padding(SpacingTokens.sm)
        .frame(width: LayoutTokens.DesignLabRound14.windowWidth)
        .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
    }

    @ViewBuilder
    private var pagesRow: some View {
        let tool = state.tabs.first { $0.hasPages }
        let selected = tool.map { state.page(of: $0) }
        switch pageStyle {
        case .drawer:
            LabRound14Drawer(style: style, tab: tool, selected: selected, isOpen: toolIsActive, anchor: toolTabFrame, animation: animation) { page in
                if let tool { withAnimation(animation) { state.select(page: page, of: tool) } }
            }
            .padding(.top, toolIsActive ? SpacingTokens.none : -LayoutTokens.DesignLabRound14.gutter)
        case .secondBar:
            LabRound14SecondBar(style: style, tab: tool, selected: selected, isOpen: toolIsActive, animation: animation) { page in
                if let tool { withAnimation(animation) { state.select(page: page, of: tool) } }
            }
            .padding(.top, toolIsActive ? SpacingTokens.none : -LayoutTokens.DesignLabRound14.gutter)
        case .unfold, .group, .menu:
            EmptyView()
        }
    }

    private var content: some View {
        LabCard(cornerRadius: cardCornerRadius) {
            if let tab = state.activeTab, tab.hasPages {
                LabRound14ToolContent(page: state.page(of: tab))
            } else {
                LabEditorText()
            }
        }
        .frame(height: LayoutTokens.DesignLabRound14.contentHeight)
    }
}

/// Activity Monitor's content for the selected page.
struct LabRound14ToolContent: View {
    let page: String

    private let rows: [(String, String, String, String, String)] = [
        ("52", "echo_app", "AdventureWorks2022", "SELECT", "running"),
        ("55", "reporting_ro", "WideWorldImporters", "SELECT", "blocked by 52"),
        ("58", "sa", "msdb", "EXECUTE", "sleeping"),
        ("61", "echo_app", "AdventureWorks2022", "UPDATE", "sleeping"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Text(page).font(TypographyTokens.standard.weight(.bold))
                Text("Test MSSQL · updated 2 s ago").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            if page == "Processes" {
                Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xxs2) {
                    GridRow {
                        ForEach(["ID", "Login", "Database", "Command", "Status"], id: \.self) {
                            Text($0).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    ForEach(rows, id: \.0) { row in
                        GridRow {
                            Text(row.0).monospacedDigit()
                            Text(row.1)
                            Text(row.2)
                            Text(row.3)
                            Text(row.4).foregroundStyle(row.4.hasPrefix("blocked") ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                        }
                        .font(TypographyTokens.detail)
                    }
                }
            } else {
                Text("\(page) uses the same header and table style.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(SpacingTokens.md)
        .contentTransition(.opacity)
    }
}

/// A quiet stand-in for the tree card beside the tab bar.
struct LabRound14TreeStub: View {
    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    var body: some View {
        LabCard(cornerRadius: cardCornerRadius) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack {
                    Text("Test MSSQL").font(TypographyTokens.standard.weight(.bold))
                    Spacer()
                    Text("16.0.4250.1").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
                ForEach(["Databases", "Security", "Agent Jobs", "Management"], id: \.self) {
                    Text($0).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .padding(SpacingTokens.sm)
        }
        .frame(height: LayoutTokens.DesignLabRound14.contentHeight + LayoutTokens.DesignLabRound14.barHeight + LayoutTokens.DesignLabRound14.drawerHeight)
    }
}
