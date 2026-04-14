import SwiftUI

struct TypeEditorSQLPage: View {
    @Bindable var viewModel: TypeEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
