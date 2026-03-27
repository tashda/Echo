import SwiftUI

struct PublicationEditorSQLPage: View {
    @Bindable var viewModel: PublicationEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
