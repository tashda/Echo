import SwiftUI

struct FunctionEditorSQLPage: View {
    @Bindable var viewModel: FunctionEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
