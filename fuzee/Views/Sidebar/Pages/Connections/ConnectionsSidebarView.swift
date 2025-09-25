import SwiftUI

struct ConnectionsSidebarView: View {
    // The new hierarchical data source
    let items: [SidebarItem]
    @Binding var selectedConnectionID: UUID?
    
    // Updated callbacks to handle items and folders
    let onAddConnection: (SavedFolder?) -> Void // Pass parent folder
    let onAddFolder: (SavedFolder?) -> Void     // Pass parent folder
    let onEditItem: (SidebarItem) -> Void
    let onDeleteItem: (SidebarItem) -> Void

    @State private var itemToDelete: SidebarItem?
    @State private var selectedItemID: UUID? // For local row highlighting

    var body: some View {
        VStack(spacing: 0) {
            // Header with Add button
            HStack {
                Text("Connections")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button {
                        onAddConnection(nil) // Add to root
                    } label: {
                        Label("New Connection", systemImage: "externaldrive.badge.plus")
                    }
                    Button {
                        onAddFolder(nil) // Add to root
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24, height: 24)
                .help("Add Connection or Folder")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if items.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text("No Connections")
                        .font(.headline)

                    Text("Click the plus button to add your first connection or folder.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button("Add Connection") {
                        onAddConnection(nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Hierarchical connections list
                List(selection: $selectedItemID) {
                    ForEach(items) { item in
                        SidebarItemView(
                            item: item,
                            selectedConnectionID: $selectedConnectionID,
                            onAddConnection: onAddConnection,
                            onAddFolder: onAddFolder,
                            onEditItem: onEditItem,
                            onDeleteItem: { itemToDelete = $0 }
                        )
                    }
                }
                .listStyle(.sidebar) // Use .sidebar style for proper appearance
                .scrollContentBackground(.hidden) // Makes background transparent
            }
        }
        .onChange(of: selectedConnectionID, { _, newValue in
            // Sync local selection when external selection changes
            selectedItemID = newValue
        })
        .alert(
            "Delete Item?",
            isPresented: .constant(itemToDelete != nil),
            presenting: itemToDelete
        ) { item in
            Button("Delete", role: .destructive) {
                if let itemToDelete = itemToDelete {
                    onDeleteItem(itemToDelete)
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: { item in
            let name: String
            switch item {
            case .connection(let connection):
                name = connection.connectionName
            case .folder(let folder):
                name = folder.name
            }
            return Text("Are you sure you want to delete “\(name)”? This action cannot be undone.")
        }
    }
}

// A new recursive view to handle the hierarchy
struct SidebarItemView: View {
    let item: SidebarItem
    @Binding var selectedConnectionID: UUID?
    
    // Callbacks
    let onAddConnection: (SavedFolder?) -> Void
    let onAddFolder: (SavedFolder?) -> Void
    let onEditItem: (SidebarItem) -> Void
    let onDeleteItem: (SidebarItem) -> Void

    var body: some View {
        switch item {
        case .connection(let connection):
            ConnectionRowView(
                connection: connection,
                onEdit: { onEditItem(.connection(connection)) },
                onDelete: { onDeleteItem(.connection(connection)) }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedConnectionID = connection.id
            }
            
        case .folder(let folder):
            DisclosureGroup {
                // Recursive content
                ForEach(folder.children) { childItem in
                    SidebarItemView(
                        item: childItem,
                        selectedConnectionID: $selectedConnectionID,
                        onAddConnection: onAddConnection,
                        onAddFolder: onAddFolder,
                        onEditItem: onEditItem,
                        onDeleteItem: onDeleteItem
                    )
                }
            } label: {
                FolderRowView(
                    folder: folder,
                    onEdit: { onEditItem(.folder(folder)) },
                    onDelete: { onDeleteItem(.folder(folder)) }
                )
            }
            .contextMenu {
                Button {
                    onAddConnection(folder)
                } label: {
                    Label("New Connection in Folder", systemImage: "externaldrive.badge.plus")
                }
                Button {
                    onAddFolder(folder)
                } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}

// A new view for displaying a folder row, similar to ConnectionRowView
struct FolderRowView: View {
    let folder: SavedFolder
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(folder.color)

                Image(systemName: "folder.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(folder.color.contrastingForegroundColor)
                    .frame(width: 22, height: 22)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(folder.children.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Edit Folder")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete Folder")
                }
                .foregroundStyle(.secondary)
                .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}
