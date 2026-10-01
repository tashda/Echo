import SwiftUI

/// Round 21, cancelling a query (CS2): the server hasn't stopped the query 5 s after Cancel.
extension QueryResultsSection {
    var forceStopBanner: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.warning)
            Text("The server hasn't stopped the query.")
                .font(TypographyTokens.detail)
            Spacer(minLength: SpacingTokens.xs)
            Button("Force Stop") { query.forceStopHandler?() }
                .controlSize(.small)
                .help("Closes the connection. An open transaction is rolled back.")
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Status.warning.opacity(0.12))
    }
}
