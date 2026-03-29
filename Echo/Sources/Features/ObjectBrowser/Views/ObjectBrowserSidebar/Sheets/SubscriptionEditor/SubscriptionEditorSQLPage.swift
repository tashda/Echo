import SwiftUI

struct SubscriptionEditorSQLPage: View {
    @Bindable var viewModel: SubscriptionEditorViewModel

    var body: some View {
        SQLPreviewSection(sql: viewModel.generateSQL())
    }
}
