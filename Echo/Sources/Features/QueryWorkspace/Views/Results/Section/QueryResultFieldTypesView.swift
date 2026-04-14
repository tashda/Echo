import SwiftUI

struct QueryResultFieldTypesView: View {
    let descriptors: [QueryResultFieldTypeDescriptor]

    var body: some View {
        Table(descriptors) {
            TableColumn("Field") { descriptor in
                Text(descriptor.name)
            }
            TableColumn("Type") { descriptor in
                Text(descriptor.dataType)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            TableColumn("Null") { descriptor in
                Text(descriptor.allowsNull ? "YES" : "NO")
            }
            TableColumn("Key") { descriptor in
                Text(descriptor.isPrimaryKey ? "PRI" : "—")
            }
            TableColumn("Length") { descriptor in
                Text(descriptor.maxLengthDescription)
            }
            TableColumn("Comment") { descriptor in
                Text(descriptor.comment.isEmpty ? "—" : descriptor.comment)
                    .foregroundStyle(descriptor.comment.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}
