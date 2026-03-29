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

    var body: some View {
        HSplitView {
            tablePicker
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)

            VSplitView {
                canvas
                    .frame(minHeight: 200)
                sqlPreview
                    .frame(minHeight: 120, idealHeight: 180)
            }
        }
        .background(ColorTokens.Background.primary)
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

            // Toolbar overlay
            canvasToolbar
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

    private var canvasToolbar: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: SpacingTokens.xs) {
                    Button {
                        showAddJoinSheet = true
                    } label: {
                        Label("Add Join", systemImage: "arrow.triangle.swap")
                            .labelStyle(.titleAndIcon)
                    }
                    .controlSize(.small)
                    .disabled(viewModel.tables.count < 2)

                    Button {
                        showAddWhereSheet = true
                    } label: {
                        Label("Add Filter", systemImage: "line.3.horizontal.decrease")
                            .labelStyle(.titleAndIcon)
                    }
                    .controlSize(.small)
                    .disabled(viewModel.tables.isEmpty)

                    Toggle("DISTINCT", isOn: $viewModel.distinct)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)

                    Divider().frame(height: 16)

                    HStack(spacing: 4) {
                        Text("LIMIT")
                            .font(TypographyTokens.compact)
                        TextField("", value: $viewModel.limit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8)
                .padding(SpacingTokens.sm)
            }
            Spacer()
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

                Button {
                    environmentState.openQueryTab(presetQuery: viewModel.generatedSQL)
                } label: {
                    Label("Open in Query Tab", systemImage: "arrow.up.forward.square")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Open in new query tab")

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
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)

            Divider()

            ScrollView {
                Text(viewModel.generatedSQL)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                    .textSelection(.enabled)
            }
        }
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }
}
