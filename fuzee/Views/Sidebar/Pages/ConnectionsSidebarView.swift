import SwiftUI

struct ConnectionsSidebarView: View {
    let connections: [SavedConnection]
    @Binding var selectedConnectionID: UUID?
    let onAddConnection: () -> Void
    let onDeleteConnection: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with Add button
            HStack {
                Text("Connections")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    onAddConnection()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Add Connection")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if connections.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text("No Connections")
                        .font(.headline)

                    Text("Click the plus button to add your first database connection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button("Add Connection") {
                        onAddConnection()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Connections list
                List {
                    ForEach(connections) { connection in
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.connectionName)
                                        .font(.body)
                                    Text("\(connection.username)@\(connection.host)\(connection.port > 0 ? ":\(connection.port)" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: connection.databaseType.iconName)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                onDeleteConnection(connection.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Delete Connection")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConnectionID = connection.id
                        }
                        .listRowBackground(
                            (selectedConnectionID == connection.id) ? Color.accentColor.opacity(0.12) : Color.clear
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
