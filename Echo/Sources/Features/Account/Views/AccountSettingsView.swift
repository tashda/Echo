import SwiftUI

/// Account section in Settings — now redirects to the General page
/// where the account card lives. Kept for backward compatibility with
/// any navigation that targets the .account section.
struct AccountSettingsView: View {
    @Environment(AuthState.self) private var authState

    var body: some View {
        if authState.isSignedIn {
            signedInContent
        } else {
            SignInView(authState: authState)
        }
    }

    private var signedInContent: some View {
        Form {
            SignedInAccountCard(authState: authState, syncEngine: AppDirector.shared.syncEngine)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
