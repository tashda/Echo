import SwiftUI

/// Legacy placeholder view kept in the project for Xcode targets that still reference it.
/// The modern explorer uses `DatabaseObjectBrowserView`, but this keeps the build green
/// while the project file still contains an entry for this file.
struct ExplorerSidebarDatabaseView: View {
    let database: DatabaseInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(database.name)
                .font(.headline)

            if database.schemas.isEmpty {
                Text("No schemas available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(database.schemas, id: \.name) { schema in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(schema.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if schema.objects.isEmpty {
                            Text("No objects")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(schema.objects, id: \.id) { object in
                                HStack(spacing: 8) {
                                    Image(systemName: object.type.systemImage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(object.name)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

#Preview {
    ExplorerSidebarDatabaseView(
        database: DatabaseInfo(
            name: "postgres",
            schemas: [
                SchemaInfo(
                    name: "public",
                    objects: [
                        SchemaObjectInfo(name: "users", schema: "public", type: .table),
                        SchemaObjectInfo(name: "orders", schema: "public", type: .table)
                    ]
                )
            ]
        )
    )
}
