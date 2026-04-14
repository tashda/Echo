import SwiftUI

/// Apple ID-style account row in General settings.
/// Shows avatar + name + chevron. Clicking opens a detail sheet.
struct SignedInAccountCard: View {
    @Bindable var authState: AuthState
    var syncEngine: SyncEngine?

    @State private var showAccountSheet = false
    @State private var lastAutoPresentedUserID: String?
    @State var isRefreshHovered = false

    var body: some View {
        Section {
            accountRow
        } header: {
            Text("Echo Account")
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountDetailSheet(authState: authState, syncEngine: syncEngine)
        }
        .task(id: authState.currentUser?.userID) {
            await presentAccountSheetIfSetupNeedsAttention()
        }
    }

    // MARK: - Clickable Row

    private var accountRow: some View {
        ZStack(alignment: .trailing) {
            Button {
                showAccountSheet = true
            } label: {
                HStack(spacing: SpacingTokens.md) {
                    accountAvatar

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authState.currentUser?.displayName ?? "Echo User")
                            .font(TypographyTokens.prominent)
                            .foregroundStyle(ColorTokens.Text.primary)

                        if let email = authState.currentUser?.email {
                            Text(email)
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }

                        syncSummary
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.labelBold)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let syncEngine {
                syncRefreshButton(syncEngine)
                    .padding(.trailing, 28)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    private func presentAccountSheetIfSetupNeedsAttention() async {
        guard let userID = authState.currentUser?.userID,
              lastAutoPresentedUserID != userID else { return }

        let e2eManager = AppDirector.shared.e2eEnrollmentManager
        await e2eManager.checkEnrollmentStatus()
        await e2eManager.tryAutoUnlock()

        let needsCredentialUnlock = e2eManager.isEnrolled
            && SyncPreferences.isCredentialSyncEnabled
            && !e2eManager.isUnlocked
        let needsMergeDecision = await syncEngine?.hasPendingMergeDecision() ?? false

        guard needsCredentialUnlock || needsMergeDecision else { return }

        lastAutoPresentedUserID = userID
        showAccountSheet = true
    }
}
