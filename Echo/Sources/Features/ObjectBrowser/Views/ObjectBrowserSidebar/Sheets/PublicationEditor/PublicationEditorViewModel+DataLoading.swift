import Foundation
import PostgresKit

extension PublicationEditorViewModel {

    // MARK: - Load

    func load(session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Publication editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await loadAvailableTables(pg: pg)
            if isEditing {
                try await loadExistingPublication(pg: pg)
            }
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Available Tables

    private func loadAvailableTables(pg: PostgresSession) async throws {
        let schemas = try await pg.client.introspection.listSchemas()
        var tables: [String] = []

        for schema in schemas {
            let objects = try await pg.client.introspection.listTablesAndViews(schema: schema.name)
            for obj in objects where obj.kind == .table {
                tables.append("\(schema.name).\(obj.name)")
            }
        }

        availableTables = tables.sorted()
    }

    // MARK: - Existing Publication

    private func loadExistingPublication(pg: PostgresSession) async throws {
        let publications = try await pg.client.introspection.listPublications()
        guard let pub = publications.first(where: { $0.name == publicationName }) else { return }

        allTables = pub.allTables
        publishInsert = pub.publishInsert
        publishUpdate = pub.publishUpdate
        publishDelete = pub.publishDelete
        publishTruncate = pub.publishTruncate

        if !pub.allTables {
            let pubTables = try await pg.client.introspection.listPublicationTables(publication: publicationName)
            selectedTables = Set(pubTables.map { "\($0.schemaName).\($0.tableName)" })
        }
    }
}
