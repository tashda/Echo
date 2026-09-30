import SwiftUI

#if os(macOS)
/// A PostgreSQL script's results (Echo Labs round 21, script results, accepted): the statements
/// in a list at the left (SR4), named by their first words (SL3), commands as entries with their
/// tag (SC2); selecting one shows its result and lights its statement in the editor (SK2).
extension QueryResultsSection {
    func scriptResultsView(_ entries: [ScriptResultEntry]) -> some View {
        HStack(spacing: 0) {
            ScriptStatementList(entries: entries, selectedID: query.selectedScriptEntryID) { entry in
                query.selectScriptEntry(entry)
            }
            .frame(width: 220)
            Divider()
            scriptEntryDetail(query.selectedScriptEntry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func scriptEntryDetail(_ entry: ScriptResultEntry?) -> some View {
        switch entry?.outcome {
        case .rows:
            VStack(spacing: 0) {
                resultsToolbar
                Divider()
                switch gridState.detailMode {
                case .table: multiResultSetView
                case .form: formResultsView
                case .fieldTypes: fieldTypesResultsView
                }
            }
        case .command(let tag):
            VStack(spacing: SpacingTokens.xs) {
                Label(tag, systemImage: "checkmark.circle")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                if let duration = entry?.duration {
                    Text(QueryRunNote.formatted(duration))
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        case .failed(let message):
            QueryFailureView(message: message, query: query, panelState: panelState)
        case nil:
            noRowsReturnedView
        }
    }
}

/// The statement list: a status icon and the statement's first words per row.
struct ScriptStatementList: View {
    let entries: [ScriptResultEntry]
    let selectedID: Int?
    let onSelect: (ScriptResultEntry) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                ForEach(entries) { entry in
                    Button { onSelect(entry) } label: {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: entry.isFailure ? "xmark.circle.fill" : "checkmark.circle")
                                .foregroundStyle(entry.isFailure ? ColorTokens.Status.error : ColorTokens.Status.success)
                            Text(entry.label)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                        .contentShape(Rectangle())
                        .background(
                            entry.id == selectedID ? ColorTokens.Text.primary.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(entry.messageLine)
                }
            }
            .padding(SpacingTokens.xs)
        }
    }
}
#endif
