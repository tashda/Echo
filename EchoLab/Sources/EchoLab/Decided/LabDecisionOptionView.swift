import Foundation
import SwiftUI

/// One option: its verdict and reason, the specimen running live, and its source on demand.
struct LabDecisionOptionView: View {
    let option: LabDecisionOption
    @State private var showsCode = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: option.isWinner ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(option.isWinner ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                Text(option.name).font(TypographyTokens.headline)
                Spacer()
                Toggle("Show code", isOn: $showsCode).toggleStyle(.button)
            }
            Text(option.why)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            option.specimen()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.md)
                .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: 12))
            if showsCode {
                ForEach(option.sourcePaths, id: \.self) { path in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text(source(at: path))
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(SpacingTokens.sm)
                    .background(ColorTokens.Surface.rest, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    /// The lab runs from a source checkout, so the specimen's files are on disk.
    private func source(at path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? "Source not found at \(path)"
    }
}
