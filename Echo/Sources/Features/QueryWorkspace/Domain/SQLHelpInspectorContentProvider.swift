import Foundation
import EchoSense

struct SQLHelpInspectorContentProvider {
    func content(for selectedText: String, databaseType: EchoSenseDatabaseType) -> SQLHelpInspectorContent? {
        guard let topic = SQLHelpCatalog.topic(for: selectedText, databaseType: databaseType) else { return nil }
        return SQLHelpInspectorContent(
            title: topic.title,
            category: topic.category,
            summary: topic.summary,
            matchedText: selectedText.trimmingCharacters(in: .whitespacesAndNewlines),
            syntax: topic.syntax,
            example: topic.example,
            notes: topic.notes,
            relatedTopics: topic.relatedTopics,
            sections: topic.sections.map { .init(id: $0.id, title: $0.title, value: $0.value) }
        )
    }
}
