import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Side-by-side comparison of two execution plans.
/// Loads a second plan from a saved .sqlplan or .xml file.
struct ExecutionPlanComparisonView: View {
    let currentPlan: ExecutionPlanData
    @State private var comparedPlanXML: String?
    @State private var comparedPlanFileName: String?
    @State private var errorMessage: String?

    var body: some View {
        if comparedPlanXML != nil {
            comparisonContent
        } else {
            loadPrompt
        }
    }

    private var loadPrompt: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "arrow.left.arrow.right")
                .font(TypographyTokens.iconDisplay)
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text("Compare Execution Plans")
                .font(TypographyTokens.headline)

            Text("Load a saved ShowPlan XML file to compare against the current plan.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Open Plan XML") {
                loadPlanFile()
            }
            .buttonStyle(.borderedProminent)

            if let error = errorMessage {
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var comparisonContent: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            HSplitView {
                currentPlanColumn
                comparedPlanColumn
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: SpacingTokens.lg) {
            if let cost = currentPlan.statements.first?.subtreeCost {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Current:")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(String(format: "%.4f", cost))
                        .font(TypographyTokens.detail.weight(.medium).monospacedDigit())
                }
            }

            if let fileName = comparedPlanFileName {
                Text(fileName)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            Button("Change File") {
                loadPlanFile()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    private var currentPlanColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current Plan")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Background.secondary)

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading) {
                    ForEach(currentPlan.statements.indices, id: \.self) { idx in
                        let stmt = currentPlan.statements[idx]
                        if let root = stmt.queryPlan?.rootOperator {
                            ExecutionPlanFlowView(
                                root: root,
                                totalCost: stmt.subtreeCost ?? root.totalSubtreeCost ?? 1,
                                selectedNodeID: .constant(nil)
                            )
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300)
    }

    private var comparedPlanColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compared Plan")
                .font(TypographyTokens.headline)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Background.secondary)

            ScrollView {
                if let xml = comparedPlanXML {
                    Text(xml)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(SpacingTokens.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 300)
    }

    private func loadPlanFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlplan") ?? .xml, .xml]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        errorMessage = nil
        do {
            let xmlString = try String(contentsOf: url, encoding: .utf8)
            comparedPlanXML = xmlString
            comparedPlanFileName = url.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
