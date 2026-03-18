import Foundation

public struct DatabaseObjectInspectorContent: Sendable, Equatable {
    public struct Field: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.id = UUID()
            self.label = label
            self.value = value
        }
    }

    public let title: String
    public let subtitle: String?
    public let fields: [Field]
    public let related: [DatabaseObjectInspectorContent]
    public let lookupQuerySQL: String?
    public let errorMessage: String?

    public init(
        title: String,
        subtitle: String? = nil,
        fields: [Field],
        related: [DatabaseObjectInspectorContent] = [],
        lookupQuerySQL: String? = nil,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
        self.related = related
        self.lookupQuerySQL = lookupQuerySQL
        self.errorMessage = errorMessage
    }
}
