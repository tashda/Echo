import SwiftUI

extension View {
    /// A search field in the window's toolbar. `.searchable(placement: .toolbar)` on two pages in a
    /// row (Inbox, then Scenarios) sends AppKit into an endless constraint pass and crashes Echo
    /// Labs, so the field is an ordinary toolbar item.
    func labToolbarSearch(text: Binding<String>, prompt: String) -> some View {
        toolbar {
            ToolbarItem {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(prompt, text: text, prompt: Text(prompt))
                        .textFieldStyle(.plain)
                        .frame(width: 170)
                    if !text.wrappedValue.isEmpty {
                        Button { text.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help("Clear")
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}
