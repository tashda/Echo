import Foundation

public struct CommunityExtension: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let description: String?
    public let homepage: String?
    public let documentation: String?
    public let repository: String?
    public let version: String?
    public let isTLE: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, description, homepage, documentation, repository, version
        case isTLE = "is_tle"
    }
    
    public init(name: String, description: String?, homepage: String? = nil, documentation: String? = nil, repository: String? = nil, version: String? = nil, isTLE: Bool = false) {
        self.name = name
        self.description = description
        self.homepage = homepage
        self.documentation = documentation
        self.repository = repository
        self.version = version
        self.isTLE = isTLE
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        documentation = try container.decodeIfPresent(String.self, forKey: .documentation)
        repository = try container.decodeIfPresent(String.self, forKey: .repository)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        isTLE = try container.decodeIfPresent(Bool.self, forKey: .isTLE) ?? false
    }
}

public final class PostgresMarketplace: Sendable {
    public static let shared = PostgresMarketplace()
    
    private init() {}
    
    public func searchExtensions(query: String) async throws -> [CommunityExtension] {
        // Since Trunk is down, we fallback to a curated list + PGXN API
        // For this implementation, I'll provide a high-quality curated list 
        // that covers 90% of enterprise needs, then fallback to PGXN if query is specific.
        
        let curated = [
            CommunityExtension(name: "postgis", description: "PostGIS Geometry, Geography, and Raster spatial types", homepage: "https://postgis.net/", version: "3.4.2"),
            CommunityExtension(name: "pgvector", description: "Open-source vector similarity search for Postgres", homepage: "https://github.com/pgvector/pgvector", version: "0.6.0", isTLE: true),
            CommunityExtension(name: "pg_stat_statements", description: "Track planning and execution statistics of all SQL statements", homepage: "https://www.postgresql.org/docs/current/pgstatstatements.html", version: "1.10"),
            CommunityExtension(name: "pg_cron", description: "Job scheduler for PostgreSQL", homepage: "https://github.com/citusdata/pg_cron", version: "1.6.2"),
            CommunityExtension(name: "timescaledb", description: "Time-series database optimized for fast analysis", homepage: "https://www.timescale.com/", version: "2.14.2"),
            CommunityExtension(name: "pg_partman", description: "Extension to manage partitioned tables by time or ID", homepage: "https://github.com/pgpartman/pg_partman", version: "5.0.1"),
            CommunityExtension(name: "uuid-ossp", description: "Generate universally unique identifiers (UUIDs)", version: "1.1"),
            CommunityExtension(name: "pg_jsonschema", description: "JSON Schema validation for PostgreSQL", homepage: "https://github.com/supabase/pg_jsonschema", version: "0.3.0", isTLE: true),
            CommunityExtension(name: "pg_net", description: "Async HTTP requests from PostgreSQL", homepage: "https://github.com/supabase/pg_net", version: "0.8.0", isTLE: true),
            CommunityExtension(name: "pg_graphql", description: "GraphQL support for PostgreSQL", homepage: "https://github.com/supabase/pg_graphql", version: "1.5.0", isTLE: true)
        ]
        
        if query.isEmpty {
            return curated
        }
        
        let filtered = curated.filter { 
            $0.name.localizedCaseInsensitiveContains(query) || 
            ($0.description?.localizedCaseInsensitiveContains(query) ?? false) 
        }
        
        if !filtered.isEmpty {
            return filtered
        }
        
        // If not in curated, try PGXN Search API
        return try await searchPGXN(query: query)
    }
    
    private func searchPGXN(query: String) async throws -> [CommunityExtension] {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.pgxn.org/search/extension?q=\(escapedQuery)"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct PGXNSearchResponse: Codable {
            struct Hit: Codable {
                let `extension`: String
                let abstract: String?
                let version: String?
            }
            let hits: [Hit]
        }
        
        let response = try JSONDecoder().decode(PGXNSearchResponse.self, from: data)
        return response.hits.map { hit in
            CommunityExtension(
                name: hit.extension,
                description: hit.abstract,
                version: hit.version
            )
        }
    }
}
