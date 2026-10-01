import SwiftUI

struct MySQLServerConfigurationView: View {
    @Bindable var viewModel: ServerPropertiesViewModel

    @Environment(ProjectStore.self) private var projectStore
    @State private var fileListFraction: CGFloat = 0.3

    var body: some View {
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {

            // TT1: the files and the editor are two cards.
            CardSplitView(axis: .horizontal, fraction: $fileListFraction, minFraction: 0.2, maxFraction: 0.45) {
                configFileList
            } second: {
                // Properties (round 37.4, PR0): unsaved changes wait in a bar at the bottom.
                VStack(spacing: SpacingTokens.none) {
                    configEditor
                    if viewModel.hasUnsavedConfigChanges {
                        ToolTabApplyBar(summary: "Unsaved changes", applyTitle: "Save", canApply: canSave,
                                        onRevert: { viewModel.revertSelectedConfigFile() },
                                        onApply: { Task { await viewModel.saveSelectedConfigFile() } })
                    }
                }
            }
        }
        .toolTabHeaderControls { headerControls }
        .toolTabHeaderDetail(viewModel.selectedConfigFile?.path)
    }

    /// The file's actions on the tool's header line (round 37.2, 37.3).
    private var headerControls: some View {
        let exists = viewModel.selectedConfigFile?.exists == true
        return ToolTabActionGroup {
            ToolTabActionButton(title: "Choose File", systemImage: "doc.badge.ellipsis") { viewModel.chooseConfigFile() }
            ToolTabActionButton(title: "Open", systemImage: "arrow.up.forward.app", isDisabled: !exists) { viewModel.openSelectedConfigFile() }
            ToolTabActionButton(title: "Reveal in Finder", systemImage: "folder", isDisabled: !exists) { viewModel.revealSelectedConfigFile() }
            ToolTabActionButton(title: "Reload from Disk", systemImage: "arrow.uturn.backward", isDisabled: viewModel.selectedConfigFile == nil) {
                do { try viewModel.reloadSelectedConfigFile() } catch { viewModel.configStatusMessage = error.localizedDescription }
            }
            ToolTabRefreshButton(isRefreshing: false) { Task { await viewModel.loadCurrentSection() } }
        }
    }

    private var canSave: Bool {
        guard let selected = viewModel.selectedConfigFile else { return false }
        return selected.exists && selected.isWritable && viewModel.hasUnsavedConfigChanges
    }

    private var configFileList: some View {
        Table(viewModel.configFiles, selection: $viewModel.selectedConfigFileID) {
            TableColumn("File") { item in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(item.title)
                        .font(TypographyTokens.Table.name)
                    Text(item.source)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .width(min: 150, ideal: 180)

            TableColumn("Status") { item in
                Text(statusLabel(for: item))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(statusColor(for: item))
            }
            .width(min: 80, ideal: 110)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .onChange(of: viewModel.selectedConfigFileID) { _, _ in
            do {
                try viewModel.reloadSelectedConfigFile()
            } catch {
                viewModel.configStatusMessage = error.localizedDescription
            }
        }
        .overlay {
            if viewModel.configFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Config Files", systemImage: "doc.badge.gearshape")
                } description: {
                    Text("Choose a my.cnf or my.ini file to inspect MySQL server configuration from Echo.")
                }
            }
        }
    }

    @ViewBuilder
    private var configEditor: some View {
        if let selected = viewModel.selectedConfigFile {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    HStack(spacing: SpacingTokens.sm) {
                        Text(selected.title)
                            .font(TypographyTokens.prominent.weight(.semibold))
                        Text(statusLabel(for: selected))
                            .font(TypographyTokens.detail.weight(.medium))
                            .foregroundStyle(statusColor(for: selected))
                    }

                    Text(selected.path)
                        .font(TypographyTokens.Table.path)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)

                    if let message = viewModel.configStatusMessage {
                        Text(message)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                .padding(SpacingTokens.md)

                Divider()

                Group {
                    if selected.exists {
                        TextEditor(text: $viewModel.configFileContents)
                            .font(TypographyTokens.code)
                            .padding(SpacingTokens.sm)
                    } else {
                        ContentUnavailableView {
                            Label("File Not Found", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("This config path does not exist on this Mac. Choose another file or use Reveal to inspect the surrounding folder.")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.secondary.opacity(0.35))
            }
        } else {
            ContentUnavailableView {
                Label("No Config File Selected", systemImage: "doc.text")
            } description: {
                Text("Select a candidate config file or choose one manually to review MySQL server configuration.")
            }
        }
    }

    private func statusLabel(for item: ServerPropertiesViewModel.ConfigFileItem) -> String {
        if !item.exists { return "Missing" }
        return item.isWritable ? "Writable" : "Read Only"
    }

    private func statusColor(for item: ServerPropertiesViewModel.ConfigFileItem) -> Color {
        if !item.exists { return ColorTokens.Status.warning }
        return item.isWritable ? ColorTokens.Status.success : ColorTokens.Text.secondary
    }
}
