import MySQLKit
import SwiftUI

struct MySQLAdvancedObjectsContent: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        switch viewModel.selectedAdvancedObjectSection {
        case .functions:
            routineSection(title: "Functions", routines: viewModel.filteredFunctions, kind: .function)
        case .procedures:
            routineSection(title: "Procedures", routines: viewModel.filteredProcedures, kind: .procedure)
        case .triggers:
            triggerSection
        case .events:
            eventSection
        }
    }

    private func routineSection(
        title: String,
        routines: [MySQLRoutineInfo],
        kind: MySQLProgrammableObjectScriptBuilder.RoutineDraft.Kind
    ) -> some View {
        HSplitView {
            Table(routines, selection: $viewModel.selectedRoutineID) {
                TableColumn("Name") { routine in
                    Text(routine.name).font(TypographyTokens.Table.name)
                }.width(min: 180, ideal: 240)

                TableColumn("Schema") { routine in
                    Text(routine.schema)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 120, ideal: 160)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .onChange(of: viewModel.selectedRoutineID) { _, _ in
                Task { await viewModel.loadSelectedAdvancedObjectDefinition() }
            }

            advancedDetailView(
                emptyTitle: "No \(title.dropLast()) Selected",
                emptyMessage: "Select a MySQL \(title.dropLast().lowercased()) to inspect its definition or open a matching script template.",
                dropSQL: viewModel.selectedRoutine.map {
                    MySQLProgrammableObjectScriptBuilder.dropScript(kind: kind, schema: $0.schema, name: $0.name)
                }
            )
        }
    }

    private var triggerSection: some View {
        HSplitView {
            Table(viewModel.triggers, selection: $viewModel.selectedTriggerID) {
                TableColumn("Name") { trigger in
                    Text(trigger.name).font(TypographyTokens.Table.name)
                }.width(min: 180, ideal: 220)

                TableColumn("Table") { trigger in
                    Text(trigger.table).font(TypographyTokens.Table.secondaryName)
                }.width(min: 140, ideal: 180)

                TableColumn("When") { trigger in
                    Text("\(trigger.timing) \(trigger.event)")
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 110, ideal: 150)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .onChange(of: viewModel.selectedTriggerID) { _, _ in
                Task { await viewModel.loadSelectedAdvancedObjectDefinition() }
            }

            advancedDetailView(
                emptyTitle: "No Trigger Selected",
                emptyMessage: "Select a MySQL trigger to inspect its definition or open a matching script template.",
                dropSQL: viewModel.selectedTrigger.map {
                    MySQLProgrammableObjectScriptBuilder.dropTriggerScript(schema: $0.schema, name: $0.name)
                }
            )
        }
    }

    private var eventSection: some View {
        HSplitView {
            Table(viewModel.events, selection: $viewModel.selectedEventID) {
                TableColumn("Name") { event in
                    Text(event.name).font(TypographyTokens.Table.name)
                }.width(min: 180, ideal: 220)

                TableColumn("Status") { event in
                    Text(event.status ?? "Unknown")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle((event.status ?? "").caseInsensitiveCompare("ENABLED") == .orderedSame ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                }.width(min: 90, ideal: 110)

                TableColumn("Schedule") { event in
                    Text(event.schedule ?? "Custom")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 180, ideal: 240)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .onChange(of: viewModel.selectedEventID) { _, _ in
                Task { await viewModel.loadSelectedAdvancedObjectDefinition() }
            }

            advancedDetailView(
                emptyTitle: "No Event Selected",
                emptyMessage: "Select a MySQL event to inspect its definition or open a matching script template.",
                dropSQL: viewModel.selectedEvent.map {
                    MySQLProgrammableObjectScriptBuilder.dropEventScript(schema: $0.schema, name: $0.name)
                }
            )
        }
    }

    private func advancedDetailView(
        emptyTitle: String,
        emptyMessage: String,
        dropSQL: String?
    ) -> some View {
        Group {
            if let definition = viewModel.selectedAdvancedObjectDefinition {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            Text(definition.name).font(TypographyTokens.title3)
                            Text("\(definition.kind.rawValue.capitalized) in \(definition.schema)")
                                .font(TypographyTokens.subheadline)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                        Spacer()
                        HStack(spacing: SpacingTokens.sm) {
                            Button("Script DROP") {
                                if let dropSQL { openScriptTab(dropSQL) }
                            }
                            .buttonStyle(.borderless)

                            Button("Open Definition") {
                                openScriptTab(definition.definition)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    ScrollView {
                        Text(definition.definition)
                            .font(TypographyTokens.code)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(SpacingTokens.md)
                    .background(ColorTokens.Background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "scroll",
                    description: Text(emptyMessage)
                )
            }
        }
    }

    private func openScriptTab(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}
