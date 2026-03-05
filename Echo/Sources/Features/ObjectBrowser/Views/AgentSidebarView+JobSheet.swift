import SwiftUI
import SQLServerKit

extension AgentSidebarView {
    @ViewBuilder
    var newJobSheetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New SQL Server Agent Job").font(.headline)
            if let err = newJobError, !err.isEmpty { Text(err).font(.footnote).foregroundStyle(.red) }
            TabView {
                generalTab
                stepsTab
                schedulesTab
                notificationsTab
            }
            HStack { Spacer(); Button("Cancel") { showNewJobSheet = false }; Button("Create") { Task { await createJobWithBuilder() } }.keyboardShortcut(.defaultAction) }
        }
        .padding(SpacingTokens.md2)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if newJobOwner.isEmpty, let session = selectedSession {
                Task {
                    do {
                        let rs = try await session.session.simpleQuery("SELECT SUSER_SNAME() AS name;")
                        let val = rs.rows.first?[0] ?? ""
                        await MainActor.run { newJobOwner = val ?? "" }
                    } catch { }
                }
            }
        }
    }

    var generalTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $newJobName)
            TextField("Description (optional)", text: $newJobDescription)
            Toggle("Enabled", isOn: $newJobEnabled)
            Toggle("Start job after creation", isOn: $startAfterCreate)
            Divider()
            Text("Owner and Category").font(.subheadline)
            TextField("Owner (default current login)", text: $newJobOwner)
            TextField("Category (optional)", text: $newJobCategory)
        }
        .tabItem { Text("General") }
    }

    var stepsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(wizardSteps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { TextField("Step name", text: $wizardSteps[index].name); Picker("Subsystem", selection: $wizardSteps[index].subsystem) { ForEach(SubsystemChoice.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 180) }
                            if step.subsystem == .tsql { TextField("Database", text: $wizardSteps[index].database) }
                            TextField("Command", text: $wizardSteps[index].command, axis: .vertical).lineLimit(2...5)
                            HStack { TextField("Run As (Proxy)", text: $wizardSteps[index].proxyName); TextField("Output file", text: $wizardSteps[index].outputFile); Toggle("Append", isOn: $wizardSteps[index].appendOutput) }
                            HStack {
                                Picker("On success", selection: $wizardSteps[index].onSuccess) { ForEach(StepActionChoice.allCases) { Text($0.rawValue).tag($0) } }
                                if step.onSuccess == .goToStep { TextField("Step ID", value: $wizardSteps[index].onSuccessGoTo, formatter: NumberFormatter()).frame(width: 80) }
                            }
                            HStack {
                                Picker("On failure", selection: $wizardSteps[index].onFail) { ForEach(StepActionChoice.allCases) { Text($0.rawValue).tag($0) } }
                                if step.onFail == .goToStep { TextField("Step ID", value: $wizardSteps[index].onFailGoTo, formatter: NumberFormatter()).frame(width: 80) }
                            }
                            HStack { TextField("Retry attempts", value: $wizardSteps[index].retryAttempts, formatter: NumberFormatter()).frame(width: 120); TextField("Retry interval (min)", value: $wizardSteps[index].retryInterval, formatter: NumberFormatter()).frame(width: 160) }
                            HStack { Button("Remove", role: .destructive) { wizardSteps.remove(at: index); if let sid = startStepId, sid > wizardSteps.count { startStepId = wizardSteps.count } } ; Spacer() }
                        }
                        .padding(SpacingTokens.xs)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            }
            HStack { Button("Add step") { wizardSteps.append(WizardStep(name: "Step \(wizardSteps.count+1)")) } ; Spacer() }
            HStack { Text("Start step ID: "); TextField("", value: Binding(get: { startStepId ?? 1 }, set: { startStepId = $0 }), formatter: NumberFormatter()).frame(width: 60) }
        }
        .tabItem { Text("Steps") }
    }

    var schedulesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(wizardSchedules.enumerated()), id: \.element.id) { index, _ in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { TextField("Name", text: $wizardSchedules[index].name); Toggle("Enabled", isOn: $wizardSchedules[index].enabled) }
                            Picker("Mode", selection: $wizardSchedules[index].mode) { ForEach(ScheduleMode.allCases) { Text($0.rawValue).tag($0) } }
                            HStack { TextField("Start time (HHMMSS)", text: $wizardSchedules[index].startHHMMSS).frame(width: 120); TextField("End time (HHMMSS)", text: $wizardSchedules[index].endHHMMSS).frame(width: 120) }
                            HStack { TextField("Start date (YYYYMMDD)", text: $wizardSchedules[index].startDateYYYYMMDD).frame(width: 150); TextField("End date (YYYYMMDD)", text: $wizardSchedules[index].endDateYYYYMMDD).frame(width: 150) }
                            if wizardSchedules[index].mode == .daily {
                                HStack { Text("Every"); TextField("Days", value: $wizardSchedules[index].everyDays, formatter: NumberFormatter()).frame(width: 60); Text("days") }
                            } else if wizardSchedules[index].mode == .weekly {
                                HStack { Text("Every"); TextField("Weeks", value: $wizardSchedules[index].weeklyEveryWeeks, formatter: NumberFormatter()).frame(width: 60); Text("weeks on:") }
                                HStack { ForEach(WeeklyDayChoice.allCases) { day in Toggle(day.rawValue, isOn: Binding(get: { wizardSchedules[index].weeklyDays.contains(day) }, set: { checked in if checked { wizardSchedules[index].weeklyDays.insert(day) } else { wizardSchedules[index].weeklyDays.remove(day) } })) } }
                            } else if wizardSchedules[index].mode == .monthly {
                                HStack { Text("Day"); TextField("", value: $wizardSchedules[index].everyDays, formatter: NumberFormatter()).frame(width: 60); Text("of every"); TextField("", value: $wizardSchedules[index].weeklyEveryWeeks, formatter: NumberFormatter()).frame(width: 60); Text("month(s)") }
                            }
                            Divider()
                            Text("Subday frequency").font(.subheadline)
                            HStack { Text("Occurs every"); TextField("", value: $wizardSchedules[index].subdayInterval, formatter: NumberFormatter()).frame(width: 80); Picker("", selection: $wizardSchedules[index].subdayUnit) { Text("(none)").tag(0); Text("Minutes").tag(4); Text("Hours").tag(8) }.pickerStyle(.segmented).frame(width: 240) }
                            HStack { Button("Remove", role: .destructive) { wizardSchedules.remove(at: index) } ; Spacer() }
                        }
                        .padding(SpacingTokens.xs)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            }
            HStack { Button("Add schedule") { wizardSchedules.append(WizardSchedule()) } ; Spacer() }
        }
        .tabItem { Text("Schedules") }
    }

    var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Operator name", text: $notifyOperatorName)
            Picker("Notify", selection: $notifyLevel) { ForEach(NotifyLevel.allCases) { Text($0.rawValue).tag($0) } }
        }
        .tabItem { Text("Notifications") }
    }
}
