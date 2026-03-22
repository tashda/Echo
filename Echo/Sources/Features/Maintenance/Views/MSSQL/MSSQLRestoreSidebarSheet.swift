import SwiftUI
import SQLServerKit

struct MSSQLRestoreSidebarSheet: View {
    @Bindable var viewModel: MSSQLBackupRestoreViewModel
    let onDismiss: () -> Void

    @State private var selectedPage: MSSQLRestorePage = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 170)
                Divider()
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footerBar
        }
        .frame(minWidth: 680, minHeight: 500)
        .frame(idealWidth: 740, idealHeight: 580)
        .interactiveDismissDisabled(viewModel.isRestoreRunning)
    }

    private var sidebar: some View {
        List(MSSQLRestorePage.allCases, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(SpacingTokens.xs)
    }

    @ViewBuilder
    private var detailPane: some View {
        Form {
            switch selectedPage {
            case .general:
                generalPage
            case .files:
                filesPage
            case .options:
                restoreOptionsPage
            case .recovery:
                recoveryPage
            case .verify:
                verifyPage
            }

            outputSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
