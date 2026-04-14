import SwiftUI

extension SchemaDiagramView {

    var toolbarOverlay: some View {
        HStack(spacing: SpacingTokens.sm) {
            // Filter
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .font(TypographyTokens.caption2)
                TextField("Filter tables\u{2026}", text: $diagramSearchText)
                    .textFieldStyle(.plain)
                    .font(TypographyTokens.caption2)
                    .frame(width: 120)
                if !diagramSearchText.isEmpty {
                    Button {
                        diagramSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                    .accessibilityLabel("Clear Search")
                }
            }

            Divider()
                .frame(height: 16)

            // Export
            Menu {
                Button("Export as PNG") { exportDiagram(as: .png) }
                Button("Export as PDF") { exportDiagram(as: .pdf) }
                Divider()
                Button("Export Diagram Model as JSON") { exportDiagram(as: .jsonModel) }
                Button("Export Forward Engineering SQL") { exportDiagram(as: .sql) }
                Divider()
                Button("Export Documentation as HTML") { exportDiagram(as: .htmlDocumentation) }
                Button("Export Documentation as Markdown") { exportDiagram(as: .markdownDocumentation) }
                Button("Export Documentation as Text") { exportDiagram(as: .textDocumentation) }
                Divider()
                Button("Print") { printDiagram() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export Diagram")
            .accessibilityLabel("Export Diagram")

            Divider()
                .frame(height: 16)

            // Visibility toggles
            Menu {
                Toggle("Relationships", isOn: $showRelationships)
                Toggle("Indexes", isOn: $showIndexes)
            } label: {
                Label("Visibility", systemImage: "eye")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Toggle Visibility")
            .accessibilityLabel("Toggle element visibility")

            Divider()
                .frame(height: 16)

            // Status badge — rightmost
            loadSourceBadge
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    var loadSourceBadge: some View {
        let descriptor = loadSourceDescriptor(for: viewModel.loadSource)
        return Label(descriptor.text, systemImage: descriptor.icon)
            .font(TypographyTokens.caption2.weight(.semibold))
            .padding(.horizontal, SpacingTokens.xs2)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(descriptor.background, in: Capsule())
            .foregroundColor(descriptor.foreground)
    }

    func loadSourceDescriptor(for source: DiagramLoadSource) -> (text: String, icon: String, foreground: Color, background: Color) {
        switch source {
        case .live(let date):
            return (
                "Live \u{00b7} " + relativeTimeString(since: date),
                "bolt.fill",
                ColorTokens.Status.success.opacity(0.9),
                ColorTokens.Status.success.opacity(0.15)
            )
        case .cache(let date):
            return (
                "Cached \u{00b7} " + relativeTimeString(since: date),
                "clock.fill",
                ColorTokens.Text.secondary,
                ColorTokens.Text.primary.opacity(0.08)
            )
        }
    }

    func relativeTimeString(since date: Date) -> String {
        EchoFormatters.relativeDate(date)
    }
}
