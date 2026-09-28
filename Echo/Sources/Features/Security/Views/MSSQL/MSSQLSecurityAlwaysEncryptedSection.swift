import SwiftUI
import SQLServerKit

struct MSSQLSecurityAlwaysEncryptedSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewCMK: () -> Void
    var onNewCEK: () -> Void
    @Environment(EnvironmentState.self) var environmentState

    enum SubSection: String, CaseIterable {
        case columnMasterKeys = "Column Master Keys"
        case columnEncryptionKeys = "Column Encryption Keys"
    }

    @State private var selectedSubSection: SubSection = .columnMasterKeys
    @State var cmkSortOrder = [KeyPathComparator(\ColumnMasterKeyInfo.name)]
    @State var cekSortOrder = [KeyPathComparator(\ColumnEncryptionKeyInfo.name)]
    @State var showDropAlert = false
    @State var pendingDropName: String?
    @State var pendingDropType: SubSection?

    var body: some View {
        VStack(spacing: 0) {
            subSectionPicker
            switch selectedSubSection {
            case .columnMasterKeys:
                cmkTable
            case .columnEncryptionKeys:
                cekTable
            }
        }
        .alert("Drop Key?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName, let type = pendingDropType {
                    Task {
                        switch type {
                        case .columnMasterKeys:
                            await viewModel.dropColumnMasterKey(name: name)
                        case .columnEncryptionKeys:
                            await viewModel.dropColumnEncryptionKey(name: name)
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to drop \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private var subSectionPicker: some View {
        TabSectionPicker(
            "Encryption Key Section",
            selection: $selectedSubSection,
            itemCount: SubSection.allCases.count
        ) {
            ForEach(SubSection.allCases, id: \.self) { sub in
                Text(sub.rawValue).tag(sub)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
    }
}
