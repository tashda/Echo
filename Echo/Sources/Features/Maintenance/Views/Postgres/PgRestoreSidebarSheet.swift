import SwiftUI

struct PgRestoreSidebarSheet: View {
    @Bindable var viewModel: PostgresBackupRestoreViewModel
    let customToolPath: String?
    let onDismiss: () -> Void

    @State private var selectedPage: PgRestorePage = .general

    var body: some View {
        SheetLayoutCustomFooter(title: "Restore Database") {
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
        .interactiveDismissDisabled(viewModel.isRestoreRunning)
    }

    private var sidebar: some View {
        List(PgRestorePage.allCases, id: \.self, selection: $selectedPage) { page in
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
            case .options:
                restoreOptionsPage
            case .advanced:
                advancedPage
            }

            outputSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
