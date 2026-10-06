import SQLServerKit

/// The events of a server grouped by package, narrowed by what the person typed in the event picker. Matches the
/// event name or the package, ignoring case, so "sql_stat" and "sqlserver stat" both find `sqlserver.sql_statement_completed`.
nonisolated struct ExtendedEventSearch {
    struct Group: Identifiable, Equatable {
        let packageName: String
        let events: [SQLServerXEEvent]
        var id: String { packageName }
    }

    let groups: [Group]

    init(events: [SQLServerXEEvent], query: String) {
        let words = query.lowercased().split(whereSeparator: { $0 == " " || $0 == "." }).map(String.init)
        let matching = events.filter { event in
            let haystack = (event.packageName + " " + event.eventName).lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        groups = Dictionary(grouping: matching, by: \.packageName)
            .map { Group(packageName: $0.key, events: $0.value.sorted { $0.eventName < $1.eventName }) }
            .sorted { $0.packageName < $1.packageName }
    }

    var count: Int { groups.reduce(0) { $0 + $1.events.count } }
    var first: SQLServerXEEvent? { groups.first?.events.first }
}
