import SwiftUI
import AppKit

struct VisualQueryBuilderView: View {
    @Bindable var viewModel: VisualQueryBuilderViewModel
    @Environment(EnvironmentState.self) private var environmentState

    @State private var canvasOffset: CGSize = .zero
    @State private var canvasZoom: CGFloat = 1.0
    @State private var lastDragOffset: CGSize = .zero
    @State private var isDraggingNode = false
    @State private var showAddJoinSheet = false
    @State private var showAddWhereSheet = false
    @State private var tablesFraction: CGFloat = 0.2
    @State private var canvasFraction: CGFloat = 0.7

    var body: some View {
        // TT1: the tables, the canvas and the SQL are three cards.
        CardSplitView(axis: .horizontal, fraction: $tablesFraction, minFraction: 0.14, maxFraction: 0.35) {
            tablePicker
        } second: {
            CardSplitView(axis: .vertical, fraction: $canvasFraction, minFraction: 0.3, maxFraction: 0.85) {
                canvas
            } second: {
                sqlPreview
            }
        }
        .toolTabHeaderControls { headerControls }
        .task {
            await viewModel.loadSchemas()
        }
        .sheet(isPresented: $showAddJoinSheet) {
            QueryBuilderJoinSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddWhereSheet) {
            QueryBuilderWhereSheet(viewModel: viewModel)
        }
    }

    // MARK: - Table Picker Sidebar

    private var tablePicker: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tables")
                    .font(TypographyTokens.headline)
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)

            if viewModel.availableSchemas.count > 1 {
                Picker("Schema", selection: $viewModel.selectedSchema) {
                    ForEach(viewModel.availableSchemas, id: \.self) { schema in
                        Text(schema).tag(schema)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, SpacingTokens.sm)
                .onChange(of: viewModel.selectedSchema) { _, _ in
                    Task { await viewModel.loadTablesForSchema() }
                }
            }

            Divider()

            if viewModel.isLoadingTables {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.availableTables) { object in
                    HStack {
                        Image(systemName: object.type == .view ? "eye" : "tablecells")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .font(TypographyTokens.caption2)
                        Text(object.name)
                            .font(TypographyTokens.detail)
                        Spacer()
                        Button {
                            let position = CGPoint(
                                x: CGFloat(viewModel.tables.count) * 260 + 40,
                                y: 40
                            )
                            Task { await viewModel.addTable(object, at: position) }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Add to query")
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            Color(ColorTokens.Background.primary)
                .overlay {
                    canvasGrid
                }

            // Table nodes
            ForEach(viewModel.tables) { table in
                QueryBuilderTableNode(
                    table: table,
                    zoom: canvasZoom,
                    onToggleColumn: { col in viewModel.toggleColumn(tableID: table.id, column: col) },
                    onRemove: { viewModel.removeTable(table.id) },
                    onSelectAll: { viewModel.selectAllColumns(tableID: table.id) },
                    onDeselectAll: { viewModel.deselectAllColumns(tableID: table.id) }
                )
                .position(
                    x: table.position.x * canvasZoom + canvasOffset.width,
                    y: table.position.y * canvasZoom + canvasOffset.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDraggingNode = true
                            if let idx = viewModel.tables.firstIndex(where: { $0.id == table.id }) {
                                viewModel.tables[idx].position = CGPoint(
                                    x: table.position.x + value.translation.width / canvasZoom,
                                    y: table.position.y + value.translation.height / canvasZoom
                                )
                            }
                        }
                        .onEnded { _ in isDraggingNode = false }
                )
            }

            // Canvas (round 37.4, CA0): the view controls float at the bottom of the drawing.
            VStack {
                Spacer()
                CanvasFloatingBar {
                    CanvasZoomControls(zoom: canvasZoom, range: 0.4...2.5, onZoom: { canvasZoom = $0 }) {
                        canvasZoom = 1
                        canvasOffset = .zero
                        lastDragOffset = .zero
                    }
                }
            }
        }
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard !isDraggingNode else { return }
                    canvasOffset = CGSize(
                        width: lastDragOffset.width + value.translation.width,
                        height: lastDragOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastDragOffset = canvasOffset }
        )
    }

    private var canvasGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30 * canvasZoom
            guard spacing > 4 else { return }
            let opacity = min(1.0, spacing / 15)
            let dotColor = Color.gray.opacity(0.15 * opacity)

            let startX = canvasOffset.width.truncatingRemainder(dividingBy: spacing)
            let startY = canvasOffset.height.truncatingRemainder(dividingBy: spacing)

            var x = startX
            while x < size.width {
                var y = startY
                while y < size.height {
                    context.fill(Circle().path(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(dotColor))
                    y += spacing
                }
                x += spacing
            }
        }
    }

    /// DISTINCT, the limit, Add Filter and Add Join on the tool's header line (round 37.2, 37.3).
    @ViewBuilder
    private var headerControls: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text("Limit").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Limit", value: $viewModel.limit, format: .number, prompt: Text("None"))
                .textFieldStyle(.plain)
                .frame(width: SpacingTokens.xxxl)
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.ToolTab.controlHeight)
        .glassEffect(.regular, in: .capsule)
        ToolTabActionGroup {
            ToolTabActionButton(title: "DISTINCT", systemImage: "square.on.square.dashed", isOn: viewModel.distinct) {
                viewModel.distinct.toggle()
            }
            ToolTabActionButton(title: "Add Filter", systemImage: "line.3.horizontal.decrease", isDisabled: viewModel.tables.isEmpty) {
                showAddWhereSheet = true
            }
        }
        ToolTabPrimaryButton(title: "Add Join", systemImage: "arrow.triangle.swap", isDisabled: viewModel.tables.count < 2) {
            showAddJoinSheet = true
        }
    }

    // MARK: - SQL Preview

    private var sqlPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Generated SQL")
                    .font(TypographyTokens.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.generatedSQL, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Copy SQL to clipboard")
                .accessibilityLabel("Copy SQL to clipboard")

                Button {
                    environmentState.openQueryTab(presetQuery: viewModel.generatedSQL)
                } label: {
                    Label("Open in Query Tab", systemImage: "arrow.up.forward.square")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Open in new query tab")
                .accessibilityLabel("Open in new query tab")

                Button {
                    environmentState.openQueryTab(presetQuery: viewModel.generatedSQL, autoExecute: true)
                } label: {
                    Label("Execute", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!viewModel.hasSelectedColumns)
                .help("Execute query")
                .accessibilityLabel("Execute query")
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)

            Divider()

            ScrollView {
                Text(viewModel.generatedSQL)
                    .font(TypographyTokens.code)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                    .textSelection(.enabled)
            }
        }
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }
}
