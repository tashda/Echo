#if DEBUG
import SwiftUI

/// Round 18's conformance specimen: Echo's real toast stack in the top-right corner of an editor
/// card, with the round's two events posted the way Echo posts them (a failed query, then a
/// connection) through a real `NotificationEngine`. In the `hovered` state the error toast is hovered.
/// The tab capsule, card and buttons around it repeat the round's exhibit, so the glass has the
/// same surroundings on both sides (Liquid Glass adapts its content to what is around it).
@MainActor
struct NotificationToastSpecimen: View {
    let state: String

    @State private var presenter = StatusToastPresenter()
    @State private var engine: NotificationEngine?

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Label("Query 1", systemImage: "tablecells")
                .font(TypographyTokens.standard)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.xxs2)
                .background(ColorTokens.Workspace.card, in: .capsule)
                .padding(SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
            editorCard
            HStack(spacing: SpacingTokens.xs) {
                ForEach(["Connected", "Query failed", "Long error", "Switched", "Same again"], id: \.self) { title in
                    Button(title) {}
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .task { await post() }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("select *")
            Text("from public.employees")
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.code)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .overlay(alignment: .topTrailing) {
            StatusToastStack(presenter: presenter)
                .padding(LayoutTokens.Toast.inset)
        }
    }

    private func post() async {
        let engine = NotificationEngine(toastPresenter: presenter, preferencesProvider: {
            var preferences = NotificationPreferences()
            preferences.markExplicitPreferences()
            return preferences
        })
        self.engine = engine
        // As `reportQueryFailure` posts it; the tab is not open here, so there is no Open Tab.
        engine.post(category: .queryFailed, icon: NotificationCategory.queryFailed.defaultIcon,
                    message: "Query 1 failed: relation \"public.employees\" does not exist", style: .error,
                    context: NotificationContext(serverName: "postgres18", tabID: UUID()))
        engine.post(.connected(displayName: "postgres18"))
        // The engine delivers on the next turn of the main actor.
        try? await Task.sleep(for: .milliseconds(50))
        if state == "hovered" {
            presenter.hoveredID = presenter.toasts.first { $0.staysUntilDismissed }?.id
        }
    }
}
#endif
