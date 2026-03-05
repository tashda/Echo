import SwiftUI

struct JobQueueView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    @State private var verticalRatio: CGFloat = 0.6
    @State private var horizontalRatio: CGFloat = 0.45
    @State private var selection: Set<String> = []
    
    // Properties editing
    @State private var editingProps: JobQueueViewModel.PropertySheet? = nil
    
    // Step editing
    @State private var newStepName: String = ""
    @State private var newStepDatabase: String = ""
    @State private var newStepCommand: String = ""
    @State private var selectedStepID: Int? = nil
    @State private var editStepName: String = ""
    @State private var editStepDatabase: String = ""
    @State private var editStepCommand: String = ""
    
    // Schedule editing
    @State private var newScheduleName: String = ""
    @State private var newScheduleEnabled: Bool = true
    @State private var newScheduleFreqType: Int = 4
    @State private var newScheduleFreqInterval: Int = 1

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    JobListView(viewModel: viewModel, selection: $selection)
                        .frame(width: geo.size.width * horizontalRatio)
                    
                    Divider()
                    
                    JobDetailsView(
                        viewModel: viewModel,
                        editingProps: $editingProps,
                        newStepName: $newStepName,
                        newStepDatabase: $newStepDatabase,
                        newStepCommand: $newStepCommand,
                        selectedStepID: $selectedStepID,
                        editStepName: $editStepName,
                        editStepDatabase: $editStepDatabase,
                        editStepCommand: $editStepCommand,
                        newScheduleName: $newScheduleName,
                        newScheduleEnabled: $newScheduleEnabled,
                        newScheduleFreqType: $newScheduleFreqType,
                        newScheduleFreqInterval: $newScheduleFreqInterval
                    )
                    .frame(width: geo.size.width * (1 - horizontalRatio))
                }
                .frame(height: totalHeight * verticalRatio)

                ResizeHandle(
                    ratio: verticalRatio,
                    minRatio: 0.3,
                    maxRatio: 0.85,
                    availableHeight: totalHeight,
                    onLiveUpdate: { proposed in verticalRatio = proposed },
                    onCommit: { proposed in verticalRatio = proposed }
                )

                JobHistoryView(viewModel: viewModel)
                    .frame(height: totalHeight * (1 - verticalRatio))
            }
        }
        .task { await viewModel.loadInitial() }
    }
}
