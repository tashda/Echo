import SwiftUI

struct ViewEditorSQLPage: View {
    @Bindable var viewModel: ViewEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
