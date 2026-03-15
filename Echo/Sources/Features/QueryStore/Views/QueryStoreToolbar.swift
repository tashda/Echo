import SwiftUI
import SQLServerKit

struct QueryStoreToolbar: View {
    @Bindable var viewModel: QueryStoreViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            sectionPicker
            Spacer()
            orderByPicker
            refreshButton
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    private var sectionPicker: some View {
        Picker("Section", selection: $viewModel.selectedSection) {
            ForEach(QueryStoreViewModel.SelectedSection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }

    private var orderByPicker: some View {
        Menu {
            ForEach(orderOptions, id: \.value) { option in
                Button {
                    viewModel.orderBy = option.value
                    Task { await viewModel.refreshTopQueries() }
                } label: {
                    HStack {
                        Text(option.label)
                        if viewModel.orderBy == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .font(TypographyTokens.detail)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.loadAll() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.loadingState == .loading)
    }

    private var orderOptions: [(label: String, value: SQLServerQueryStoreTopQueryOrder)] {
        [
            ("Total Duration", .totalDuration),
            ("Total CPU", .totalCPU),
            ("Total I/O Reads", .totalIOReads),
            ("Total Executions", .totalExecutions),
        ]
    }
}
