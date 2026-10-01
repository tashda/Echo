import EchoSenseScenarios
import SwiftUI

/// The strip on top: where you are in the queue, the score and streak, and which area is played.
struct RefereeScoreboard: View {
    let position: Int
    let count: Int
    let score: Int
    let streak: Int
    let areas: [String]
    @Binding var area: String

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            VStack(alignment: .leading, spacing: 0) {
                Text("POPUP REFEREE").font(TypographyTokens.title2.weight(.heavy))
                Text("EchoSense makes a play at the caret. You set the rule and make the call.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            Picker("Area", selection: $area) {
                Text("All areas").tag("")
                ForEach(areas, id: \.self) { Text($0).tag($0) }
            }
            .fixedSize()
            stat("Round", "\(position)/\(count)")
            stat("Score", "\(score)")
            stat("Streak", "×\(1 + Double(min(streak, 4)) / 2)".replacingOccurrences(of: ".0", with: ""))
        }
        .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased()).font(TypographyTokens.label).foregroundStyle(ColorTokens.Text.secondary)
            Text(value).font(TypographyTokens.statNumber.monospacedDigit())
        }
        .frame(minWidth: 64, alignment: .leading)
    }
}

/// What the scenario reads from its query, so a wrong reading is visible: the database, the default
/// schema, the tables in the query, what is before the dot and what is typed.
struct RefereeContextLine: View {
    let resolver: PopupResolver

    var body: some View {
        let context = resolver.context
        LabFlowLayout(spacing: SpacingTokens.sm) {
            fact("Database", "\(resolver.database), default schema \(resolver.defaultSchema)")
            fact("Tables in the query", context.tables.isEmpty ? "none" : context.tables.map(\.label).joined(separator: ", "))
            if let dot = context.dot { fact("Before the dot", dotText(dot)) }
            if !context.typed.isEmpty { fact("Typed", "“\(context.typed)”") }
            if let changed = context.changedTable { fact("Table being changed", changed) }
            if !context.derived.isEmpty { fact("CTEs and subqueries", context.derived.keys.sorted().joined(separator: ", ")) }
        }
        .help("Read from the SQL by the scenario, separately from EchoSense. If this is wrong, the rule resolves wrong: tell the agent.")
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(label).foregroundStyle(ColorTokens.Text.secondary)
            Text(value).fontWeight(.semibold)
        }
        .font(TypographyTokens.detail)
    }

    private func dotText(_ dot: ScenarioContext.Dot) -> String {
        switch dot.kind {
        case .alias: "\(dot.name), alias of the table \(dot.table ?? "")"
        case .table: "\(dot.name), a table"
        case .derived: "\(dot.name), a CTE or subquery"
        case .schema: "\(dot.name), a schema\(dot.database.map { " in \($0)" } ?? "")"
        case .database: "\(dot.name), a database"
        case .unknown: "\(dot.name), unknown"
        }
    }
}

/// After the call: right or missed, why (the checks), and a note for the agent.
struct RefereeVerdict: View {
    let follows: Bool?
    let said: Bool?
    let result: ScenarioResult?
    @Binding var message: String
    let send: () -> Void
    let next: () -> Void

    var body: some View {
        let right = follows != nil && follows == said
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
                Text(follows == nil ? "NO RULE TO JUDGE BY" : right ? "RIGHT CALL" : "MISSED CALL").font(TypographyTokens.title.weight(.heavy))
                    .foregroundStyle(follows == nil ? ColorTokens.Text.secondary : right ? ColorTokens.Status.success : ColorTokens.Status.error)
                Text(follows == nil ? "Write a rule (E) first." : follows == true ? "It follows the rule." : "It breaks the rule.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            ScenarioChecksCard(result: result)
            HStack(alignment: .bottom, spacing: SpacingTokens.xs) {
                TextField("", text: $message, prompt: Text("Feedback for the agent: what's wrong with the rule or the popup"), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...4).onSubmit(send)
                Button("Send", systemImage: "paperplane", action: send).buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                    .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Next play (Return)", systemImage: "arrow.right", action: next).buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
            }
        }
        .padding(SpacingTokens.sm)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(follows == nil ? ColorTokens.Text.tertiary : right ? ColorTokens.Status.success : ColorTokens.Status.error, lineWidth: 2))
    }
}
