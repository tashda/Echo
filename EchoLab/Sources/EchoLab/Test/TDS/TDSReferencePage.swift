import EchoDesignSystem
import SwiftUI
import TDSSpec

/// The TDS protocol reference and decoder (echo-server-lab's TDSSpec, the same as the tds-mcp MCP
/// server): explain pasted bytes field by field, or ask any reference tool.
struct TDSReferencePage: View {
    @AppStorage("lab.tds.hex") private var hex = "04 01 00 25 00 00 01 00 FD 10 00 C1 00 01 00 00 00 00 00 00 00 79 00 00 00 00 FE 00 00 00 00 00 00 00 00 00 00 00"
    @AppStorage("lab.tds.structure") private var structure = "packet"
    @AppStorage("lab.tds.tool") private var tool = "search_spec"
    @AppStorage("lab.tds.query") private var query = "PLP"

    private static let structures = [("packet", "Packet (with header)"), ("prelogin", "PRELOGIN"), ("login7", "LOGIN7"),
                                     ("sqlbatch", "SQL batch"), ("rpc", "RPC"), ("tokens", "Token stream")]

    private var explanation: TDSExplanation? {
        TDSExplainer.bytes(fromHex: hex).map { TDSExplainer().explain($0, as: structure) }
    }

    private var answer: String {
        let parameter = TDSTools.all.first { $0.name == tool }?.parameters.first?.name ?? "query"
        return TDSTools.call(tool, arguments: [parameter: query, "query": query])
    }

    var body: some View {
        HSplitView {
            explainColumn.frame(minWidth: 380)
            referenceColumn.frame(minWidth: 360)
        }
    }

    private var explainColumn: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Explain bytes").font(TypographyTokens.headline)
            Picker("As", selection: $structure) {
                ForEach(Self.structures, id: \.0) { Text($0.1).tag($0.0) }
            }
            .fixedSize()
            TextEditor(text: $hex)
                .font(TypographyTokens.monospaced)
                .frame(minHeight: 70, maxHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs).stroke(ColorTokens.Text.tertiary.opacity(0.3)))
            if let explanation {
                List {
                    if !explanation.problems.isEmpty {
                        Section("Not in the spec") {
                            ForEach(explanation.problems, id: \.self) { Text($0).foregroundStyle(ColorTokens.Status.warning) }
                        }
                    }
                    Section("\(explanation.structure), \(explanation.byteCount) bytes") {
                        TDSFieldOutline(fields: explanation.fields)
                    }
                }
                .font(TypographyTokens.monospaced)
            } else {
                ContentUnavailableView("Paste hex bytes", systemImage: "number",
                                       description: Text("Pairs of hex digits, spaces optional, e.g. from Wireshark's Copy as Hex"))
            }
        }
        .padding(SpacingTokens.sm)
    }

    private var referenceColumn: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Reference").font(TypographyTokens.headline)
            HStack {
                Picker("Tool", selection: $tool) {
                    ForEach(TDSTools.all.filter { $0.name != "explain_bytes" }, id: \.name) { Text($0.name).tag($0.name) }
                }
                .labelsHidden()
                .fixedSize()
                TextField("Query", text: $query, prompt: Text("nvarchar, 0xE7, LOGIN7, 2022"))
            }
            Text(TDSTools.all.first { $0.name == tool }?.description ?? "")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            ScrollView {
                Text(answer)
                    .font(TypographyTokens.monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(SpacingTokens.sm)
    }
}
