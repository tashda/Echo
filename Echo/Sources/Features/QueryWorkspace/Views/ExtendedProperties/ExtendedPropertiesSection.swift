import SwiftUI

struct ExtendedPropertiesSection: View {
    let session: DatabaseSession
    let schema: String
    let tableName: String

    @State private var viewModel: ExtendedPropertiesViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ExtendedPropertiesContentView(viewModel: viewModel)
            } else {
                ProgressView("Loading extended properties\u{2026}")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            let vm = ExtendedPropertiesViewModel(
                session: session, schema: schema, tableName: tableName
            )
            viewModel = vm
            Task { await vm.load() }
        }
    }
}
