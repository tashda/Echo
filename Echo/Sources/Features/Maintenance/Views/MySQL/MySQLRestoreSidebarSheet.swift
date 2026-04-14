import SwiftUI

struct MySQLRestoreSidebarSheet: View {
    @Bindable var viewModel: MySQLBackupRestoreViewModel
    let customToolPath: String?
    let onDismiss: () -> Void

    @State private var selectedPage: MySQLRestorePage = .general

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
        .frame(minWidth: 640, minHeight: 460)
        .frame(idealWidth: 700, idealHeight: 520)
        .interactiveDismissDisabled(viewModel.isRestoreRunning)
    }

    private var sidebar: some View {
        List(MySQLRestorePage.allCases, id: \.self, selection: $selectedPage) { page in
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
                optionsPage
            }

            outputSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

enum MySQLRestorePage: CaseIterable {
    case general
    case options

    var title: String {
        switch self {
        case .general: "General"
        case .options: "Options"
        }
    }

    var icon: String {
        switch self {
        case .general: "square.and.arrow.down"
        case .options: "slider.horizontal.3"
        }
    }
}
