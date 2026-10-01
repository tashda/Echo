import AppKit
import SwiftUI

/// The last conformance check of a round against Echo, as `verify-round.py` wrote it to
/// `EchoLab/State/References/<page-id>/last-check.json`.
struct LabConformanceCheck: Decodable {
    /// `PASS`, `PASS with pixel warnings…` or `FAIL`.
    let result: String
    let failures: Int
    let warnings: Int
    let checkedAt: String
    let commit: String
    /// The failing checks, one line each.
    let findings: [String]

    var passed: Bool { failures == 0 }

    private static var labFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    static func referenceFolder(page: String) -> URL {
        labFolder.appending(path: "State/References/\(page)")
    }

    /// The side by side (accepted | Echo | diff) of the last check, if it is still on this Mac.
    static func comparisonImage(page: String) -> URL? {
        let url = labFolder.appending(path: ".build/conformance/\(page)/compare.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func load(page: String) -> LabConformanceCheck? {
        let url = referenceFolder(page: page).appending(path: "last-check.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LabConformanceCheck.self, from: data)
    }

    static func hasReference(page: String) -> Bool {
        FileManager.default.fileExists(atPath: referenceFolder(page: page).appending(path: "contract.json").path)
    }
}

/// One line in a round's info box: whether Echo was checked against what you accepted, and the
/// result, with the comparison image one click away.
struct LabConformanceStatusRow: View {
    let pageID: String

    @State private var check: LabConformanceCheck?
    @State private var hasReference: Bool

    // Loaded here, not in `.task`: with no reference the row is empty, and an empty view never
    // runs its tasks.
    init(pageID: String) {
        self.pageID = pageID
        _check = State(initialValue: LabConformanceCheck.load(page: pageID))
        _hasReference = State(initialValue: LabConformanceCheck.hasReference(page: pageID))
    }

    var body: some View {
        Group {
            if hasReference {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: symbol).foregroundStyle(tint)
                        Text(headline).font(TypographyTokens.detail.weight(.semibold))
                        Spacer(minLength: SpacingTokens.none)
                        if let image = LabConformanceCheck.comparisonImage(page: pageID) {
                            Button("Open Comparison") { NSWorkspace.shared.open(image) }
                                .controlSize(.small)
                        }
                        Button("Reference", systemImage: "folder") {
                            NSWorkspace.shared.open(LabConformanceCheck.referenceFolder(page: pageID))
                        }
                        .labelStyle(.iconOnly)
                        .controlSize(.small)
                        .help("Show the accepted reference in Finder")
                    }
                    ForEach(check?.findings.prefix(3) ?? [], id: \.self) { finding in
                        Text(finding)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(SpacingTokens.xs)
                .background(tint.opacity(0.08), in: .rect(cornerRadius: SpacingTokens.xs))
            }
        }
    }

    private var headline: String {
        guard let check else { return "Accepted reference captured; Echo not checked yet" }
        return "Checked against Echo: \(check.result) · \(check.checkedAt) · \(check.commit)"
    }

    private var symbol: String {
        guard let check else { return "seal" }
        return check.passed ? (check.warnings > 0 ? "checkmark.seal" : "checkmark.seal.fill") : "xmark.seal.fill"
    }

    private var tint: Color {
        guard let check else { return ColorTokens.Text.secondary }
        return check.passed ? ColorTokens.Status.success : ColorTokens.Status.error
    }
}
