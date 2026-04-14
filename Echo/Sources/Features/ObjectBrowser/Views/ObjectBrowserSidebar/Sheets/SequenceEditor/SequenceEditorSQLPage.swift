import SwiftUI

struct SequenceEditorSQLPage: View {
    @Bindable var viewModel: SequenceEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
