import SwiftUI

struct PgRoleEditorSQLPage: View {
    @Bindable var viewModel: PgRoleEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
