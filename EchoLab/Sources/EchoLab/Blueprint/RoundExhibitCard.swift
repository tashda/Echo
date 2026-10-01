import SwiftUI

/// One exhibit: title, what makes it different, the live specimen, and (when the round picks
/// between exhibits) Pick, Maybe, No and a note. The button at the top right shows it on its own.
struct RoundExhibitCard: View {
    let page: LabPage
    let exhibit: RoundSpec.Exhibit
    let values: RoundValues
    let settings: LabStageSettings
    let decides: Bool
    /// The agent's reason, set when this exhibit is the recommended one.
    var recommendation: String?
    /// Whether the card is the one shown on its own.
    var isAlone = false
    /// Switches between showing this exhibit on its own and showing all of them.
    var toggleAlone: (() -> Void)?

    @Environment(LabStore.self) private var store
    @State private var note = ""
    @State private var showsNote = false

    private var verdict: LabStore.OptionVerdict? { store.verdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                Text(exhibit.title).font(TypographyTokens.headline)
                if exhibit.isEchoToday {
                    Text("Echo today").font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
                        .background(ColorTokens.Surface.hover, in: Capsule())
                }
                if store.isNew(page, addedIn: exhibit.addedIn) { LabNewBadge() }
                if recommendation != nil {
                    Label("Recommended", systemImage: "star.fill").font(TypographyTokens.detail.weight(.semibold))
                        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, 1)
                        .background(ColorTokens.accent.opacity(0.14), in: Capsule()).foregroundStyle(ColorTokens.accent)
                }
                Spacer()
                if let toggleAlone {
                    Button(isAlone ? "Show All" : "Show on Its Own",
                           systemImage: isAlone ? "square.grid.2x2" : "arrow.up.left.and.arrow.down.right") { toggleAlone() }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                        .help(isAlone ? "Show every exhibit side by side" : "Show this exhibit on its own, as large as the zoom asks")
                }
            }
            if let recommendation {
                Text(recommendation).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !exhibit.summary.isEmpty {
                Text(exhibit.summary).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabFitToWidth(designWidth: exhibit.designWidth, designHeight: exhibit.designHeight) {
                exhibit.build(values).labStage(settings)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
            .preferredColorScheme(settings.appearance.scheme)
            if decides {
                HStack(spacing: SpacingTokens.xs) {
                    mark("Pick", "checkmark.circle.fill", .pick, ColorTokens.Status.success)
                    mark("Maybe", "questionmark.circle", .maybe, ColorTokens.Status.warning)
                    mark("No", "xmark.circle", .no, ColorTokens.Status.error)
                    Spacer()
                    Button(showsNote || !note.isEmpty ? "Note" : "Add note", systemImage: "text.bubble") { showsNote.toggle() }
                        .buttonStyle(.plain).font(TypographyTokens.detail)
                        .foregroundStyle(note.isEmpty ? ColorTokens.Text.secondary : ColorTokens.accent)
                }
                if showsNote || !note.isEmpty {
                    TextField("", text: $note, prompt: Text("Note on \(exhibit.title)"), axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                        .onChange(of: note) { _, new in store.setOptionNote(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id, note: new) }
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(cornerRadius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(border, lineWidth: verdict == nil ? 0 : 2))
        .opacity(verdict == .no ? 0.7 : 1)
        .onAppear {
            note = store.optionNote(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id)
            showsNote = !note.isEmpty
        }
    }

    private var border: Color {
        switch verdict {
        case .pick: ColorTokens.Status.success
        case .maybe: ColorTokens.Status.warning
        case .no: ColorTokens.Status.error.opacity(0.6)
        case nil: .clear
        }
    }

    private func mark(_ title: String, _ symbol: String, _ value: LabStore.OptionVerdict, _ tint: Color) -> some View {
        let isOn = verdict == value
        return Button {
            store.setVerdict(page, topic: RoundSpec.exhibitTopicID, option: exhibit.id, verdict: isOn ? nil : value)
        } label: { Label(title, systemImage: symbol) }
            .buttonStyle(LabPillButtonStyle(tint: tint, isOn: isOn))
    }
}
