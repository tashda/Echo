import SwiftUI

struct TriggerEditorSQLPage: View {
    @Bindable var viewModel: TriggerEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
