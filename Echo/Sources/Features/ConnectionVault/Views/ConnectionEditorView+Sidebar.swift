import SwiftUI

extension ConnectionEditorView {
    var sidebarView: some View {
        List(selection: $selectedDatabaseType) {
            ForEach(DatabaseType.allCases, id: \.self) { type in
                Label {
                    Text(type.displayName)
                } icon: {
                    Image(type.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                .tag(type)
            }
        }
        .navigationTitle("Database")
        .navigationSplitViewColumnWidth(min: 160, ideal: 160, max: 200)
        .onChange(of: selectedDatabaseType) { oldType, newType in
            if newType == .sqlite {
                port = 0
                useTLS = false
                credentialSource = .manual
                identityID = nil
                username = ""
                password = ""
                database = ""
                authenticationMethod = .sqlPassword
                domain = ""
            } else {
                if oldType == .sqlite || port == 0 || port == oldType.defaultPort {
                    port = newType.defaultPort
                }
                let supportedMethods = newType.supportedAuthenticationMethods
                if !supportedMethods.contains(authenticationMethod) {
                    authenticationMethod = newType.defaultAuthenticationMethod
                }
                if authenticationMethod == .windowsIntegrated {
                    credentialSource = .manual
                }
            }
        }
        .onChange(of: authenticationMethod) { _, newMethod in
            if newMethod == .windowsIntegrated {
                credentialSource = .manual
            }
        }
    }
}
