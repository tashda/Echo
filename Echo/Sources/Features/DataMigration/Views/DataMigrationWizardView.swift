import SwiftUI

struct DataMigrationWizardView: View {
    @Bindable var viewModel: DataMigrationWizardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetLayoutCustomFooter(title: "Data Migration") {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            footerButtons
        }
        .frame(width: 640, height: 520)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isMigrating {
            migrationProgressView
        } else if viewModel.migrationSucceeded {
            migrationSuccessView
        } else {
            switch viewModel.currentStep {
            case .selectSource: sourceSelectionStep
            case .selectTarget: targetSelectionStep
            case .selectObjects: objectSelectionStep
            case .options: optionsStep
            case .review: reviewStep
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerButtons: some View {
        if viewModel.migrationSucceeded && viewModel.outputDestination == .file {
            Button("Save to File") { viewModel.saveToFile() }
                .buttonStyle(.bordered)
        }

        Spacer()

        Button("Cancel") { dismiss() }
            .keyboardShortcut(.cancelAction)

        if !viewModel.migrationSucceeded && !viewModel.isMigrating {
            if viewModel.currentStep.rawValue > 1 {
                Button("Back") { viewModel.previousStep() }
            }

            if viewModel.currentStep == .review {
                Button("Migrate") { viewModel.deliverOutput() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") { viewModel.nextStep() }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canGoNext)
                    .keyboardShortcut(.defaultAction)
            }
        }

        if viewModel.migrationSucceeded {
            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Step 1: Source Selection

    private var sourceSelectionStep: some View {
        Form {
            Section("Source Connection") {
                Picker("Connection", selection: $viewModel.sourceSessionID) {
                    Text("Select a connection").tag(nil as UUID?)
                    ForEach(viewModel.availableSessions, id: \.id) { session in
                        Text("\(session.connection.connectionName) (\(session.connection.databaseType.displayName))")
                            .tag(session.id as UUID?)
                    }
                }
                .onChange(of: viewModel.sourceSessionID) { _, _ in
                    viewModel.loadSourceDatabases()
                }

                if viewModel.isLoadingSourceDatabases {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.sourceDatabases.isEmpty {
                    Picker("Database", selection: $viewModel.sourceDatabaseName) {
                        ForEach(viewModel.sourceDatabases, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                }
            }

            Section {
                Text("Select the source database to migrate from. All active connections are available as sources.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding(SpacingTokens.md)
    }

    // MARK: - Step 2: Target Selection

    private var targetSelectionStep: some View {
        Form {
            Section("Target Connection") {
                Picker("Connection", selection: $viewModel.targetSessionID) {
                    Text("Select a connection").tag(nil as UUID?)
                    ForEach(viewModel.availableSessions, id: \.id) { session in
                        Text("\(session.connection.connectionName) (\(session.connection.databaseType.displayName))")
                            .tag(session.id as UUID?)
                    }
                }
                .onChange(of: viewModel.targetSessionID) { _, _ in
                    viewModel.loadTargetDatabases()
                }

                if viewModel.isLoadingTargetDatabases {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.targetDatabases.isEmpty {
                    Picker("Database", selection: $viewModel.targetDatabaseName) {
                        ForEach(viewModel.targetDatabases, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                }
            }

            Section {
                Text("Select the target database to migrate into. Schema and data will be created in this database.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding(SpacingTokens.md)
    }

    // MARK: - Step 3: Object Selection

    private var objectSelectionStep: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingObjects {
                ProgressView("Loading tables...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("\(viewModel.selectedObjectIDs.count) of \(viewModel.sourceObjects.count) tables selected")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                    Button("Select All") { viewModel.selectAll() }
                        .controlSize(.small)
                    Button("Deselect All") { viewModel.deselectAll() }
                        .controlSize(.small)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)

                List(viewModel.sourceObjects) { obj in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedObjectIDs.contains(obj.id) },
                            set: { _ in viewModel.toggleObject(obj) }
                        )) {
                            VStack(alignment: .leading) {
                                Text(obj.name)
                                    .font(TypographyTokens.standard)
                                Text(obj.schema)
                                    .font(TypographyTokens.caption)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Options

    private var optionsStep: some View {
        Form {
            Section("Migration Scope") {
                Toggle("Migrate schema (CREATE TABLE)", isOn: $viewModel.migrateSchema)
                Toggle("Migrate data (INSERT rows)", isOn: $viewModel.migrateData)
            }

            Section("Schema Options") {
                Toggle("Drop target tables if they exist", isOn: $viewModel.dropTargetIfExists)
            }

            Section("Data Options") {
                Picker("Batch size", selection: $viewModel.batchSize) {
                    Text("100 rows").tag(100)
                    Text("500 rows").tag(500)
                    Text("1,000 rows").tag(1000)
                    Text("5,000 rows").tag(5000)
                }
                Toggle("Continue on error", isOn: $viewModel.continueOnError)
            }

            Section("Output") {
                Picker("Destination", selection: $viewModel.outputDestination) {
                    ForEach(DataMigrationWizardViewModel.OutputDestination.allCases) { dest in
                        Text(dest.rawValue).tag(dest)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(SpacingTokens.md)
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        VStack(spacing: 0) {
            if viewModel.isGenerating {
                ProgressView("Generating migration script...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("Migration Script Preview")
                        .font(TypographyTokens.headline)
                    Spacer()
                    Text("\(viewModel.selectedObjectIDs.count) tables")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)

                ScrollView {
                    Text(viewModel.generatedSQL)
                        .font(TypographyTokens.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SpacingTokens.sm)
                        .textSelection(.enabled)
                }
                .background(ColorTokens.Background.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, SpacingTokens.md)
                .padding(.bottom, SpacingTokens.sm)
            }
        }
    }

    // MARK: - Migration Progress

    private var migrationProgressView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView(value: viewModel.migrationProgress)
                .progressViewStyle(.linear)

            Text(viewModel.migrationStatus)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            if !viewModel.migrationLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        ForEach(viewModel.migrationLog, id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                }
                .background(ColorTokens.Background.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(SpacingTokens.xl)
    }

    // MARK: - Migration Success

    private var migrationSuccessView: some View {
        VStack(spacing: SpacingTokens.md) {
            Label(
                viewModel.migrationError == nil ? "Migration completed successfully" : "Migration completed with errors",
                systemImage: viewModel.migrationError == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(viewModel.migrationError == nil ? ColorTokens.Status.success : ColorTokens.Status.warning)
            .font(TypographyTokens.headline)

            if let error = viewModel.migrationError {
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }

            if !viewModel.migrationLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        ForEach(viewModel.migrationLog, id: \.self) { entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.sm)
                }
                .background(ColorTokens.Background.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(SpacingTokens.lg)
    }
}
