import SwiftUI

/// Round 20's main exhibit: Echo's toolbar with Run in its own group, and the editor card under it,
/// as the Editor area's As built specimen draws them. The neighbours show whether Run pushes them.
struct LabRBToolbarExhibit: View {
    let look: LabRBLook
    let values: RoundValues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var simulation: LabRBSimulation { .shared }
    private var editor: LabRBEditorState { LabRBPages.editorState() }

    static let width: CGFloat = 640
    static let height: CGFloat = 250

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            toolbar
            editorCard
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Workspace.canvas)
        .environment(\.echoMotion, LabRBPages.motion(values, reduceMotion: reduceMotion))
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            RunSpecimenCapsule { RunSpecimenGlyph(symbol: "sidebar.left") }
            Spacer(minLength: SpacingTokens.none)
            LabRBButton(style: look, editor: editor)
            RunSpecimenCapsule {
                ForEach(["sparkles", "exclamationmark.triangle", "text.book.closed", "flowchart"], id: \.self) {
                    RunSpecimenGlyph(symbol: $0)
                }
            }
            RunSpecimenCapsule {
                ForEach(["square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"], id: \.self) {
                    RunSpecimenGlyph(symbol: $0)
                }
            }
        }
    }

    /// Three lines of SQL, the second selected with Text selected, and the inline result after a run.
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if editor == .empty {
                Text("Type a query").foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                line(1, "select *", selected: false)
                HStack(spacing: SpacingTokens.md) {
                    line(2, "from employees.employee", selected: editor == .selection)
                    inlineResult
                }
                line(3, "where hired > '2020-01-01';", selected: false)
            }
            Spacer(minLength: SpacingTokens.none)
            Text(editor == .disconnected ? "Not connected" : "SQL Server 2022 · employees")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.code)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    @ViewBuilder
    private var inlineResult: some View {
        switch simulation.phase {
        case .succeeded(let rows, let seconds):
            Text("✓ \(rows.formatted()) rows · \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
                .foregroundStyle(ColorTokens.Status.success)
        case .failed(let line):
            Text("! Incorrect syntax near 'hired' (line \(line))")
                .foregroundStyle(ColorTokens.Status.error)
        default:
            EmptyView()
        }
    }

    private func line(_ number: Int, _ text: String, selected: Bool) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text("\(number)").foregroundStyle(ColorTokens.Text.tertiary)
            Text(text).background(selected ? ColorTokens.accent.opacity(0.25) : .clear)
        }
    }
}
