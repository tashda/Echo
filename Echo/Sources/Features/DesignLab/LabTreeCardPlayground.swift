#if DEBUG
import SwiftUI

/// Tree card page: six new ways to draw the content of the server cards, beside today's. The card
/// itself (surface, corners, edge, shadow) is unchanged. All trees share one expanded set and one
/// selection, so opening a folder in one opens it in all of them.
struct LabTreeCardPlayground: View {
    @State private var look = LabTreeLook()
    @State private var expanded = LabTreeCardSamples.initiallyExpanded
    @State private var selected: String? = LabTreeCardSamples.initiallySelected

    private let columns = Array(repeating: GridItem(.fixed(336), spacing: 16, alignment: .top), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controls
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(LabTreeCardStyle.allCases) { style in
                    cell(style)
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                LabPicker(title: "Icons", selection: $look.icons, options: LabTreeIconMode.allCases)
                LabPicker(title: "Palette", selection: $look.palette, options: LabTreePalette.allCases)
                    .disabled(look.icons == .monochrome)
            }
            HStack(spacing: 14) {
                LabPicker(title: "Schema", selection: $look.schema, options: LabTreeSchemaMode.allCases)
                LabPicker(title: "Server folders", selection: $look.topLevel, options: LabTreeTopLevel.allCases)
                Button("Reset tree") {
                    expanded = LabTreeCardSamples.initiallyExpanded
                    selected = LabTreeCardSamples.initiallySelected
                }
            }
        }
        .controlSize(.small)
    }

    private func cell(_ style: LabTreeCardStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(style.rawValue).font(.headline)
                if style.isReference {
                    Text("Reference").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(style.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 308, height: 52, alignment: .topLeading)
            LabTreeCanvas(style: style, look: look, expanded: $expanded, selected: $selected)
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }
}

/// A slice of the window's canvas holding both server cards, scrollable like the tree.
struct LabTreeCanvas: View {
    let style: LabTreeCardStyle
    let look: LabTreeLook
    @Binding var expanded: Set<String>
    @Binding var selected: String?

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                ForEach(LabTreeCardSamples.servers) { server in
                    LabTreeServerCard(server: server, style: style, look: look, expanded: $expanded, selected: $selected)
                }
            }
            .padding(8)
        }
        .scrollIndicators(.never)
        .frame(width: 308, height: 620)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }
}
#endif
