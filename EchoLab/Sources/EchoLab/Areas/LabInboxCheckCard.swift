import SwiftUI

/// What to check in the running Echo for a round that is built, with Accept and Reject.
struct LabInboxCheckCard: View {
    let page: LabPage
    @Environment(LabStore.self) private var store
    @State private var rejecting = false

    var body: some View {
        let verification = store.verification(of: page)
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            LabColumnTitle(text: "Check this in Echo", symbol: "checkmark.seal")
            if let summary = verification?.summary, !summary.isEmpty {
                Text(summary).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
            } else if let note = store.builtNote(of: page) {
                Text(note).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
            }
            if let verification, !verification.checks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What to look at").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    ForEach(Array(verification.checks.enumerated()), id: \.offset) { index, check in
                        let done = verification.done.contains(index)
                        Button { store.toggleCheck(page, index: index) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                                Text(check).strikethrough(done, color: ColorTokens.Text.tertiary)
                                    .foregroundStyle(done ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
                                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(TypographyTokens.standard)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if verification == nil {
                Text("The agent gave no checklist for this one. Open the round and its As built page to see what changed.")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            }
            if let verification, !verification.shots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What it looks like").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    ForEach(verification.shots, id: \.self) { name in
                        if let image = NSImage(contentsOf: store.shotURL(page, name: name)) {
                            Image(nsImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
                        }
                    }
                }
            }
            HStack(spacing: SpacingTokens.xs) {
                Button { store.confirm(page) } label: { Label("Accept", systemImage: "checkmark") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, prominent: true))
                Button { rejecting = true } label: { Label("Reject", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error))
                Text("Reject sends it back to the agent with your note.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(cornerRadius: 14)
        .sheet(isPresented: $rejecting) { LabRejectSheet(pages: [page]) }
    }
}

/// Asks for the note that goes with a rejection, for one round or several.
struct LabRejectSheet: View {
    let pages: [LabPage]
    @Environment(LabStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(pages.count == 1 ? "Reject \(pages[0].title)" : "Reject \(pages.count) items").font(TypographyTokens.headline)
            Text("What is wrong? The agent reads this note and revises.")
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            TextEditor(text: $note)
                .font(TypographyTokens.standard).frame(height: 110).scrollContentBackground(.hidden)
                .padding(6).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Send Back") {
                    for page in pages { store.reject(page, note: note) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(SpacingTokens.md).frame(width: 420)
    }
}

/// The reading pane when several inbox items are selected.
struct LabInboxBulkPane: View {
    let pages: [LabPage]
    @Environment(LabStore.self) private var store
    @State private var rejecting = false

    private var checkable: [LabPage] { pages.filter { store.status(of: $0) == .inEcho } }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "checklist").font(.system(size: 34)).foregroundStyle(ColorTokens.Text.tertiary)
            Text("\(pages.count) items selected").font(TypographyTokens.title2.weight(.bold))
            Text(checkable.isEmpty ? "None of them is waiting to be checked in Echo." : "\(checkable.count) waiting to be checked in Echo.")
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            HStack(spacing: SpacingTokens.xs) {
                Button { checkable.forEach(store.confirm) } label: { Label("Accept \(checkable.count)", systemImage: "checkmark") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, prominent: true))
                Button { rejecting = true } label: { Label("Reject \(checkable.count)", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error))
            }
            .disabled(checkable.isEmpty)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $rejecting) { LabRejectSheet(pages: checkable) }
    }
}
