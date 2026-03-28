import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TableDataEditableCell: View {
    @Binding var text: String
    let valueMode: TableDataCellValueMode
    let isEdited: Bool
    let onSetNull: () -> Void
    let onTransform: (TableDataTextTransform) -> Void
    let onLoadFromFile: (URL) -> Void
    let onSetValueMode: (TableDataCellValueMode) -> Void

    private let columnMinWidth: CGFloat = 120

    var body: some View {
        TextField("", text: $text, prompt: Text("NULL"))
            .font(TypographyTokens.detail.monospaced())
            .textFieldStyle(.plain)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)
            .frame(minWidth: columnMinWidth, alignment: .leading)
            .background(backgroundColor)
            .overlay(alignment: .trailing) {
                if valueMode == .expression {
                    Text("fx")
                        .font(TypographyTokens.caption2.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                }
            }
            .contextMenu {
                Button("Set to NULL") {
                    onSetNull()
                }

                Menu("Transform Text") {
                    Button("UPPERCASE") {
                        onTransform(.uppercase)
                    }
                    Button("lowercase") {
                        onTransform(.lowercase)
                    }
                    Button("Capitalize") {
                        onTransform(.capitalize)
                    }
                }

                Button("Load Value from File…") {
                    presentOpenPanel()
                }

                Divider()

                if valueMode == .expression {
                    Button("Treat as Literal") {
                        onSetValueMode(.literal)
                    }
                } else {
                    Button("Treat as SQL Expression") {
                        onSetValueMode(.expression)
                    }
                }
            }
    }

    private var backgroundColor: Color {
        if valueMode == .expression {
            return ColorTokens.Status.info.opacity(0.12)
        }
        if isEdited {
            return ColorTokens.Status.warning.opacity(0.1)
        }
        return .clear
    }

    private func presentOpenPanel() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onLoadFromFile(url)
#endif
    }
}
