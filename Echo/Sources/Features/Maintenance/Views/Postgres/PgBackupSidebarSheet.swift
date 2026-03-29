import SwiftUI

struct PgBackupSidebarSheet: View {
    @Bindable var viewModel: PostgresBackupRestoreViewModel
    let customToolPath: String?
    let onDismiss: () -> Void

    @State private var selectedPage: PgBackupPage = .general

    var body: some View {
        SheetLayoutCustomFooter(title: "Back Up Database") {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 170)
                Divider()
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } footer: {
            footerContent
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 700, idealHeight: 540)
        .interactiveDismissDisabled(viewModel.isBackupRunning)
    }

    private var sidebar: some View {
        List(PgBackupPage.allCases, id: \.self, selection: $selectedPage) { page in
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
            case .scope:
                scopePage
            case .options:
                optionsPage
            case .advanced:
                advancedPage
            }

            outputSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
