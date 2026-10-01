import SwiftUI

/// Round 28.11: every editor setting Echo has today, by the pane it lives in.
struct LabQESettingsMap: View {
    var body: some View {
        Form {
            Section("Appearance › Editor") {
                row("Outline Edge", "Off")
                row("Statement Focus", "On")
                row("Line Number Gutter", "Subtle · Column · Lane")
            }
            Section("Appearance › Editor Font") {
                row("Font", "JetBrains Mono")
                row("Font Size", "13,0 pt")
                row("Line Spacing", "1.55 (counted twice)")
                row("Enable Ligatures", "On")
            }
            Section("EchoSense") {
                row("Qualify table completions", "Off")
                row("Show system schemas", "Off")
                row("Ghost text instead of the list", "Off")
                row("Live query validation", "On")
                row("Trigger shortcuts", "")
            }
            Section("Query Results › Errors") {
                row("Full message at the statement", "Off")
            }
            Section("Stored, with no switch anywhere") {
                row("Show line numbers", "On")
                row("Highlight the word at the caret", "On")
                row("Highlight delay", "0.25 s")
                row("Wrap lines", "On")
                row("Indent wrapped lines", "4")
                row("Editor theme (20 palettes)", "Aurora · Midnight")
            }
        }
        .formStyle(.grouped)
        .font(TypographyTokens.detail)
        .workspaceCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).foregroundStyle(ColorTokens.Text.secondary) }
    }
}

/// Round 28.11: the proposed Settings › Editor pane, with the recommended defaults.
struct LabQEEditorPane: View {
    var body: some View {
        Form {
            Section("Text") {
                row("Font", "SF Mono")
                row("Size", "13 pt")
                row("Line Height", "Comfortable")
                toggle("Ligatures", false)
                row("Theme", "Aurora · Midnight")
            }
            Section("Gutter") {
                toggle("Line Numbers", true)
                row("Style", "Subtle")
            }
            Section("While Typing") {
                toggle("Statement Focus", true)
                toggle("Highlight the Word at the Caret", true)
                toggle("Check the Query as You Type", true)
                toggle("Wrap Long Lines", true)
            }
            Section("After a Run") {
                toggle("Full Error Message at the Statement", false)
            }
            Section("Edges") {
                toggle("Outline Edge", false)
            }
        }
        .formStyle(.grouped)
        .font(TypographyTokens.detail)
        .workspaceCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: SpacingTokens.xxs) {
                Text(value)
                Image(systemName: "chevron.up.chevron.down").imageScale(.small)
            }
            .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private func toggle(_ title: String, _ isOn: Bool) -> some View {
        Toggle(title, isOn: .constant(isOn)).toggleStyle(.switch).controlSize(.mini)
    }
}
