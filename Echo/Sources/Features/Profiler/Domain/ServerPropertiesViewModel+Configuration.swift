import AppKit
import Foundation
import MySQLKit
import MySQLWire

extension ServerPropertiesViewModel {
    func loadConfiguration(mysql: MySQLSession) async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading MySQL configuration", connectionSessionID: connectionSessionID)

        do {
            let variables = try await mysql.client.admin.globalVariables()
            let variableMap = Dictionary(uniqueKeysWithValues: variables.map { ($0.name.lowercased(), $0.value) })
            let candidates = MySQLServerConfigurationLocator.candidates(
                host: mysql.configuration.host,
                baseDirectory: variableMap["basedir"],
                dataDirectory: variableMap["datadir"]
            )

            configFiles = candidates.map { makeConfigFileItem(candidate: $0) }
            if selectedConfigFile == nil {
                selectedConfigFileID = configFiles.first.map { [$0.id] } ?? []
            }
            configStatusMessage = mysql.configuration.host.localizedCaseInsensitiveCompare("localhost") == .orderedSame ||
                mysql.configuration.host == "127.0.0.1" ||
                mysql.configuration.host == "::1"
                ? nil
                : "This connection is remote. Echo can inspect or edit local MySQL config files you choose, but it cannot browse the remote server filesystem directly."
            try reloadSelectedConfigFile()
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load MySQL configuration candidates: \(error.localizedDescription)", severity: .error)
        }
    }

    @MainActor
    func chooseConfigFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose MySQL Configuration File"
        panel.message = "Select a my.cnf, my.ini, or included configuration file."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let selectedPath = url.path
        guard !selectedPath.isEmpty else { return }

        let item = makeConfigFileItem(
            candidate: .init(
                id: selectedPath,
                title: url.lastPathComponent,
                path: selectedPath,
                source: "Manual selection"
            )
        )

        if !configFiles.contains(where: { $0.id == item.id }) {
            configFiles.insert(item, at: 0)
        } else {
            configFiles = configFiles.map { $0.id == item.id ? item : $0 }
        }
        selectedConfigFileID = [item.id]

        do {
            try reloadSelectedConfigFile()
        } catch {
            configStatusMessage = "Unable to open \(selectedPath): \(error.localizedDescription)"
        }
    }

    func saveSelectedConfigFile() async {
        guard let selected = selectedConfigFile else { return }
        guard selected.exists else {
            configStatusMessage = "The selected configuration file does not exist."
            return
        }
        guard selected.isWritable else {
            configStatusMessage = "The selected configuration file is not writable."
            return
        }

        let handle = activityEngine?.begin("Saving MySQL configuration", connectionSessionID: connectionSessionID)
        do {
            try configFileContents.write(toFile: selected.path, atomically: true, encoding: .utf8)
            loadedConfigFileContents = configFileContents
            refreshSelectedConfigFileMetadata()
            configStatusMessage = "Saved \(selected.path)"
            handle?.succeed()
            panelState?.appendMessage("Saved MySQL configuration file \(selected.path)")
        } catch {
            handle?.fail(error.localizedDescription)
            configStatusMessage = "Failed to save \(selected.path): \(error.localizedDescription)"
            panelState?.appendMessage("Failed to save MySQL configuration file: \(error.localizedDescription)", severity: .error)
        }
    }

    func revertSelectedConfigFile() {
        configFileContents = loadedConfigFileContents
        configStatusMessage = "Reverted unsaved changes."
    }

    func reloadSelectedConfigFile() throws {
        guard let selected = selectedConfigFile else {
            configFileContents = ""
            loadedConfigFileContents = ""
            return
        }

        refreshSelectedConfigFileMetadata()
        guard FileManager.default.fileExists(atPath: selected.path) else {
            configFileContents = ""
            loadedConfigFileContents = ""
            configStatusMessage = "The selected configuration file does not exist on this Mac."
            return
        }

        let contents = try String(contentsOfFile: selected.path, encoding: .utf8)
        configFileContents = contents
        loadedConfigFileContents = contents
        configStatusMessage = "Loaded \(selected.path)"
    }

    @MainActor
    func openSelectedConfigFile() {
        guard let selected = selectedConfigFile, FileManager.default.fileExists(atPath: selected.path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: selected.path))
    }

    @MainActor
    func revealSelectedConfigFile() {
        guard let selected = selectedConfigFile, FileManager.default.fileExists(atPath: selected.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selected.path)])
    }

    private func refreshSelectedConfigFileMetadata() {
        guard let selected = selectedConfigFile else { return }
        let refreshed = makeConfigFileItem(
            candidate: .init(
                id: selected.id,
                title: selected.title,
                path: selected.path,
                source: selected.source
            )
        )
        configFiles = configFiles.map { $0.id == refreshed.id ? refreshed : $0 }
    }

    private func makeConfigFileItem(candidate: MySQLServerConfigurationCandidate) -> ConfigFileItem {
        let path = candidate.path
        let fileManager = FileManager.default
        return ConfigFileItem(
            id: candidate.id,
            title: candidate.title,
            path: path,
            source: candidate.source,
            exists: fileManager.fileExists(atPath: path),
            isWritable: fileManager.isWritableFile(atPath: path)
        )
    }
}
