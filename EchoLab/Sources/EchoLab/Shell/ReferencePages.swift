/// Living references that always reflect the shipped design system.
@MainActor enum ReferencePages {
    static let all: [LabPage] = [
        LabPage(
            id: "reference.tokens",
            section: .reference,
            group: "Design system",
            title: "Design tokens",
            symbol: "paintpalette",
            summary: "The shared EchoDesignSystem tokens, rendered by Echo Lab itself."
        ) { TokensReferencePage() }
    ]
}
