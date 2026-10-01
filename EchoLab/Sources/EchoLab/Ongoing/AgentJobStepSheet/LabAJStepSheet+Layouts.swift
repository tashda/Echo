import SwiftUI

/// Round 33.2, revision 2: the more radical layouts (NS3 to NS6).
extension LabAJStepSheet {
    /// NS3: the command fills the sheet; the settings on one line above it, what happens next
    /// as a sentence below.
    var editorFirst: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                TextField("Name", text: $name, prompt: Text("Step name"))
                    .textFieldStyle(.roundedBorder)
                typePicker.labelsHidden().fixedSize()
                Text("in").foregroundStyle(ColorTokens.Text.secondary)
                databasePicker.labelsHidden().fixedSize()
            }
            commandField
            if look.completion == .offered { completionSentence }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    /// "When it succeeds, go to the next step. When it fails, quit reporting failure. Retry 0 times."
    var completionSentence: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xxs) {
                Text("When it succeeds,")
                inlineMenu("go to the next step", tint: ColorTokens.Status.success)
                Text("When it fails,")
                inlineMenu("quit and report failure", tint: ColorTokens.Status.error)
            }
            HStack(spacing: SpacingTokens.xxs) {
                Text("Before failing, retry")
                inlineMenu("0 times", tint: ColorTokens.Text.primary)
                Text("every")
                inlineMenu("1 minute", tint: ColorTokens.Text.primary)
            }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(ColorTokens.Text.secondary)
    }

    func inlineMenu(_ title: String, tint: Color) -> some View {
        Menu {
            Button(title) {}
        } label: {
            Text(title).foregroundStyle(tint)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    /// NS4: the command full height on the left; the settings in a sidebar at the right.
    var inspector: some View {
        HStack(spacing: SpacingTokens.none) {
            commandField
                .padding(SpacingTokens.md)
            Form {
                Section("Step") {
                    TextField("Name", text: $name, prompt: Text("e.g. Run cleanup query"))
                    typePicker
                    databasePicker
                }
                if look.completion == .offered {
                    Section("When it finishes") { completionRows }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .controlSize(.small)
            .frame(width: 280)
            .background(ColorTokens.Workspace.canvas)
        }
    }

    /// NS5: the job's steps as a flow at the left, the new step slotted in with its arrows;
    /// the form at the right. Success and failure are the arrows, not form rows.
    var flow: some View {
        HStack(spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text("Steps of IndexOptimize - USER_DATABASES")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.bottom, SpacingTokens.xxs)
                flowStep(1, "DatabaseIntegrityCheck", isNew: false)
                flowArrows(failure: "quit, report failure")
                flowStep(2, name, isNew: true)
                flowArrows(failure: look.completion == .offered ? "retry 0 ×, then quit" : "quit, report failure")
                flowStep(3, "Update statistics", isNew: false)
                flowArrows(failure: "quit, report failure", isLast: true)
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.md)
            .frame(width: 270, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
            form(includeCommand: true, includeCompletion: false)
        }
    }

    private func flowStep(_ number: Int, _ title: String, isNew: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("\(number)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
            Text(title).font(TypographyTokens.standard).lineLimit(1)
            Spacer(minLength: SpacingTokens.none)
            if isNew { Text("New").font(TypographyTokens.label.weight(.semibold)).foregroundStyle(ColorTokens.accent) }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: SpacingTokens.xl)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .strokeBorder(isNew ? ColorTokens.accent : ColorTokens.Separator.primary, lineWidth: isNew ? 1.5 : 0.5)
        }
    }

    private func flowArrows(failure: String, isLast: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Label(isLast ? "quit, report success" : "next step", systemImage: "arrow.down")
                .foregroundStyle(ColorTokens.Status.success)
            Label(failure, systemImage: "xmark")
                .foregroundStyle(ColorTokens.Status.error)
        }
        .font(TypographyTokens.detail)
        .padding(.leading, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.xxs)
    }

    /// NS6: NS1's three sections as cards on the canvas; a small title above each, no lines.
    var cards: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            card("Step") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("Name", text: $name, prompt: Text("Step name")).textFieldStyle(.plain)
                    typePicker.labelsHidden().fixedSize()
                    databasePicker.labelsHidden().fixedSize()
                }
            }
            card("Command") { commandField }
                .frame(maxHeight: .infinity)
            if look.completion == .offered {
                card("When it finishes") { completionSentence }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text(title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.leading, SpacingTokens.xxs)
            content()
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        }
    }
}
