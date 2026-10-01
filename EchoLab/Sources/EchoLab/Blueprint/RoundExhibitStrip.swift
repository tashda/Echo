import SwiftUI

/// Above an exhibit shown on its own: every exhibit as a pill, and previous and next
/// (⌥⌘← and ⌥⌘→), so you flip between them in the same spot and compare them at full size.
struct RoundExhibitStrip: View {
    let page: LabPage
    let spec: RoundSpec
    @Binding var selection: String

    @Environment(LabStore.self) private var store

    private var index: Int { spec.exhibits.firstIndex { $0.id == selection } ?? 0 }

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Button("Previous Exhibit", systemImage: "chevron.backward") { step(-1) }
                .labelStyle(.iconOnly)
                .buttonStyle(LabPillButtonStyle())
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .help("Previous exhibit (⌥⌘←)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(spec.exhibits) { exhibit in
                    Button { selection = exhibit.id } label: { pill(exhibit) }
                        .buttonStyle(LabPillButtonStyle(isOn: exhibit.id == spec.exhibits[index].id))
                        .help(exhibit.title)
                }
            }
            Button("Next Exhibit", systemImage: "chevron.forward") { step(1) }
                .labelStyle(.iconOnly)
                .buttonStyle(LabPillButtonStyle())
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .help("Next exhibit (⌥⌘→)")
        }
    }

    private func pill(_ exhibit: RoundSpec.Exhibit) -> some View {
        HStack(spacing: 4) {
            if let symbol = verdictSymbol(exhibit) { Image(systemName: symbol) }
            Text(exhibit.title).lineLimit(1)
            if spec.exhibitTopic?.recommended == exhibit.id { Image(systemName: "star.fill").font(TypographyTokens.detail) }
        }
    }

    private func verdictSymbol(_ exhibit: RoundSpec.Exhibit) -> String? {
        switch store.verdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id) {
        case .pick: "checkmark.circle.fill"
        case .maybe: "questionmark.circle"
        case .no: "xmark.circle"
        case nil: nil
        }
    }

    private func step(_ offset: Int) {
        let count = spec.exhibits.count
        guard count > 0 else { return }
        selection = spec.exhibits[(index + offset + count) % count].id
    }
}
