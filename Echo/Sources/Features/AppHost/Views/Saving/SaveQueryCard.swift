import SwiftUI

/// The Save card (round IC, H1): where a query goes, Bookmarks or File. On Bookmarks: a name, a
/// folder (No Folder, your folders, or New Folder… which turns the row into a name field) and a
/// note. On File: a file name; Save asks where with the system panel, starting in the last folder
/// used. Return saves, Esc cancels; ⌘1 and ⌘2 switch the destination.
struct SaveQueryCard: View {
    let request: SaveCardRequest

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var destination: SaveDestination
    @State private var name: String
    @State private var folderChoice: FolderChoice = .noFolder
    @State private var newFolderName = ""
    @State private var note = ""
    @State private var isSaving = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, newFolder, note }

    private enum FolderChoice: Hashable {
        case noFolder
        case folder(String)
        case newFolder
    }

    init(request: SaveCardRequest) {
        self.request = request
        _destination = State(initialValue: request.allowsFile ? request.destination : .bookmarks)
        _name = State(initialValue: request.suggestedName)
    }

    private var folders: [String] { environmentState.bookmarkProject?.bookmarkFolders ?? [] }

    private var connection: SavedConnection? {
        connectionStore.connections.first { $0.id == request.connectionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Save \u{201C}\(request.suggestedName.isEmpty ? "Query" : request.suggestedName)\u{201D}")
                .font(TypographyTokens.headline)
                .lineLimit(1)

            if request.allowsFile {
                Picker("Save to", selection: $destination) {
                    Label("Bookmarks", systemImage: "bookmark").tag(SaveDestination.bookmarks)
                    Label("File", systemImage: "doc").tag(SaveDestination.file)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Form {
                if destination == .bookmarks {
                    TextField("Name", text: $name)
                        .focused($focus, equals: .name)
                    if folderChoice == .newFolder {
                        TextField("Folder", text: $newFolderName, prompt: Text("New folder name"))
                            .focused($focus, equals: .newFolder)
                            .onExitCommand { folderChoice = .noFolder }
                        if let problem = newFolderProblem {
                            Text(problem)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Status.error)
                        }
                    } else {
                        Picker("Folder", selection: $folderChoice) {
                            Text(BookmarkRepository.noFolderTitle).tag(FolderChoice.noFolder)
                            if !folders.isEmpty {
                                Divider()
                                ForEach(folders, id: \.self) { Text($0).tag(FolderChoice.folder($0)) }
                            }
                            Divider()
                            Text("New Folder…").tag(FolderChoice.newFolder)
                        }
                    }
                    TextField("Note", text: $note, prompt: Text("Optional"))
                        .focused($focus, equals: .note)
                } else {
                    TextField("Name", text: $name)
                        .focused($focus, equals: .name)
                    Text("Save asks where to put the file, starting in the folder you used last.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .formStyle(.columns)

            HStack(spacing: SpacingTokens.xs) {
                if let connection {
                    HStack(spacing: SpacingTokens.xxs1) {
                        Circle().fill(connection.color)
                            .frame(width: LayoutTokens.InspectorList.dotSize, height: LayoutTokens.InspectorList.dotSize)
                        Text([connection.connectionName.isEmpty ? connection.host : connection.connectionName,
                              request.databaseName].compactMap { $0 }.joined(separator: " · "))
                            .lineLimit(1)
                    }
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer(minLength: SpacingTokens.xs)
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(destination == .file ? "Save…" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || (destination == .bookmarks && folderChoice == .newFolder && newFolderProblem != nil))
            }
        }
        .padding(SpacingTokens.md)
        .frame(width: LayoutTokens.SaveCard.width)
        .background {
            // ⌘1 and ⌘2 switch the destination.
            Group {
                Button("") { destination = .bookmarks }.keyboardShortcut("1", modifiers: .command)
                Button("") { if request.allowsFile { destination = .file } }.keyboardShortcut("2", modifiers: .command)
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .onAppear {
            if let last = environmentState.lastBookmarkFolder(for: request.connectionID) {
                folderChoice = .folder(last)
            }
            focus = .name
        }
        .onChange(of: folderChoice) { _, choice in
            if choice == .newFolder {
                newFolderName = ""
                focus = .newFolder
            }
        }
    }

    private var newFolderProblem: String? {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name the new folder." }
        if trimmed == BookmarkRepository.noFolderTitle || folders.contains(trimmed) {
            return "There\u{2019}s already a folder called \u{201C}\(trimmed)\u{201D}."
        }
        return nil
    }

    private func save() {
        isSaving = true
        let request = request
        switch destination {
        case .bookmarks:
            let folder: String?
            let isNew: Bool
            switch folderChoice {
            case .noFolder: folder = nil; isNew = false
            case .folder(let name): folder = name; isNew = false
            case .newFolder: folder = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines); isNew = true
            }
            let title = name
            let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                await environmentState.completeSaveToBookmarks(request, name: title, folder: folder, newFolder: isNew, note: note)
                dismiss()
            }
        case .file:
            let fileName = name
            // The card goes first, so the save panel can take the window.
            dismiss()
            Task { await environmentState.completeSaveToFile(request, name: fileName) }
        }
    }
}

extension LayoutTokens {
    /// The Save card (round IC).
    enum SaveCard {
        static let width: CGFloat = 340
    }
}
