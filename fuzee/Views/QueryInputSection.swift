import SwiftUI

struct QueryInputSection: View {
    @ObservedObject var tab: QueryTab
    let onExecute: (String) async -> Void
    @State private var selectedLineNumbers: Set<Int> = []
    @State private var dragInitialLine: Int?

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    private var editorFont: Font {
        .custom(appState.editorFontName, size: appState.editorFontSize)
    }

    private var editorLineHeight: CGFloat {
        // This heuristic provides good spacing for most fonts.
        // For pixel-perfect accuracy, one would use NSLayoutManager.
        appState.editorFontSize * 1.4
    }

    private var lineCount: Int {
        max(1, tab.sql.components(separatedBy: .newlines).count)
    }

    @ViewBuilder
    private var lineNumbers: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lineCount, id: \.self) { lineNumber in
                HStack {
                    Spacer()
                    Text("\(lineNumber)")
                        .font(.system(size: appState.editorFontSize * 0.9, design: .monospaced))
                        .foregroundStyle(selectedLineNumbers.contains(lineNumber) ? .primary : .secondary)
                        .padding(.trailing, 8)
                }
                .frame(height: editorLineHeight) // Match line height
                .background(
                    selectedLineNumbers.contains(lineNumber) ?
                    Color.accentColor.opacity(0.15) : Color.clear
                )
                .contentShape(Rectangle())
                .overlay(
                    PointerGestureArea(
                        onTap: { modifiers in
                            handleLineNumberClick(lineNumber, modifiers: modifiers)
                        },
                        onDrag: { translation in
                            if dragInitialLine == nil {
                                dragInitialLine = lineNumber
                            }
                            handleLineNumberDrag(startLine: dragInitialLine!, translation: translation)
                        },
                        onDragEnd: {
                            dragInitialLine = nil
                        }
                    )
                )
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with connection info and controls
            HStack {
                // Connection info
                HStack(spacing: 8) {
                    Circle()
                        .fill(tab.connection.color)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.connection.connectionName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        let databaseString = tab.connection.database.isEmpty ? "" : "/\(tab.connection.database)"
                        Text("\(tab.connection.host):\(tab.connection.port)\(databaseString)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Query history menu
                if !appState.queryHistory.isEmpty {
                    Menu {
                        ForEach(appState.queryHistory.prefix(10)) { item in
                            Button(action: {
                                tab.sql = item.query
                            }) {
                                VStack(alignment: .leading) {
                                    Text(item.query.prefix(50) + (item.query.count > 50 ? "..." : ""))
                                        .lineLimit(1)
                                    Text(item.formattedTimestamp)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        Button("Clear History") {
                            appState.clearQueryHistory()
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }

                // Execute button
                Button {
                    Task {
                        await onExecute(tab.sql)
                    }
                } label: {
                    Label("Run Query", systemImage: "play.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(tab.isExecuting || tab.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.windowBackground)

            Divider()

            // SQL Editor with line numbers
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Line numbers
                    lineNumbers
                        .frame(width: 60)
                        .background(themeManager.backgroundColor.opacity(0.3))

                    // Vertical separator
                    Rectangle()
                        .fill(.separator)
                        .frame(width: 1)

                    // Text editor
                    TextEditor(text: $tab.sql)
                        .font(editorFont)
                        .scrollContentBackground(.hidden)
                        .background(themeManager.windowBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }

            // Execution status
            if tab.isExecuting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Executing query...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.windowBackground.opacity(0.8))
            }
        }
    }

    private func handleLineNumberClick(_ lineNumber: Int, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            if selectedLineNumbers.contains(lineNumber) {
                selectedLineNumbers.remove(lineNumber)
            } else {
                selectedLineNumbers.insert(lineNumber)
            }
        } else if modifiers.contains(.shift), let lastLine = selectedLineNumbers.max() {
            let range = min(lastLine, lineNumber)...max(lastLine, lineNumber)
            selectedLineNumbers.formUnion(Set(range))
        } else {
            selectedLineNumbers = [lineNumber]
        }

        selectLinesInTextEditor()
    }

    private func handleLineNumberDrag(startLine: Int, translation: CGSize) {
        let lineHeight: CGFloat = editorLineHeight
        let draggedLines = Int(round(translation.height / lineHeight))
        let endLine = max(1, min(lineCount, startLine + draggedLines))

        let range = min(startLine, endLine)...max(startLine, endLine)
        selectedLineNumbers = Set(range)

        selectLinesInTextEditor()
    }

    private func selectLinesInTextEditor() {
        // This would require accessing the underlying NSTextView/UITextView.
        // For now, we just highlight the line numbers
        // A full implementation would need to manipulate the text selection.
    }
}
