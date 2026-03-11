import SwiftUI
import AppKit

struct PSQLTabView: View {
    @ObservedObject var viewModel: PSQLTabViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            PSQLConsoleHistoryView(text: $viewModel.history)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            HStack(spacing: 4) {
                Text("\(viewModel.database)=>")
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.leading, SpacingTokens.sm)
                
                TextField("", text: $viewModel.input)
                    .font(TypographyTokens.monospaced)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        viewModel.execute()
                    }
                    .padding(.vertical, SpacingTokens.sm)
                    .disabled(viewModel.isExecuting)
                
                if viewModel.isExecuting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, SpacingTokens.sm)
                }
            }
            .background(ColorTokens.Background.secondary)
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            isFocused = true
        }
    }
}

struct PSQLConsoleHistoryView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}
