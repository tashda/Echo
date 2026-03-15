import SwiftUI

extension JobDetailsView {

    // MARK: - Schedule Recurrence

    var scheduleRecurrenceHeader: String {
        switch newScheduleFrequency {
        case .daily: return "Recurrence"
        case .weekly: return "Repeat On"
        case .monthly: return "Day of Month"
        case .once: return "Date"
        }
    }

    @ViewBuilder
    var scheduleRecurrenceContent: some View {
        switch newScheduleFrequency {
        case .daily:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every day").tag(1)
                Text("Every 2 days").tag(2)
                Text("Every 3 days").tag(3)
                Text("Every 5 days").tag(5)
                Text("Every 7 days").tag(7)
                Text("Every 14 days").tag(14)
                Text("Every 30 days").tag(30)
            }

        case .weekly:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every week").tag(1)
                Text("Every 2 weeks").tag(2)
                Text("Every 3 weeks").tag(3)
                Text("Every 4 weeks").tag(4)
            }

            scheduleWeekdayPicker

        case .monthly:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every month").tag(1)
                Text("Every 2 months").tag(2)
                Text("Every 3 months").tag(3)
                Text("Every 4 months").tag(4)
                Text("Every 6 months").tag(6)
                Text("Every 12 months").tag(12)
            }

            Picker("On day", selection: $newScheduleMonthDay) {
                ForEach(1...31, id: \.self) { d in
                    Text(ordinalDay(d)).tag(d)
                }
            }

        case .once:
            DatePicker("Run on", selection: $newScheduleOneTimeDate, displayedComponents: .date)
        }
    }

    var scheduleWeekdayPicker: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach([(1, "S"), (2, "M"), (4, "T"), (8, "W"), (16, "T"), (32, "F"), (64, "S")], id: \.0) { value, label in
                Toggle(isOn: Binding(
                    get: { newScheduleWeekdays.contains(value) },
                    set: { on in
                        if on { newScheduleWeekdays.insert(value) }
                        else if newScheduleWeekdays.count > 1 { newScheduleWeekdays.remove(value) }
                    }
                )) {
                    Text(label)
                        .font(TypographyTokens.detail.weight(.medium))
                        .frame(width: 22, height: 22)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Schedule Summary

    var scheduleNaturalLanguageSummary: some View {
        let timeStr = String(format: "%02d:%02d", newScheduleStartHour, newScheduleStartMinute)
        let summary: String
        switch newScheduleFrequency {
        case .daily:
            summary = newScheduleInterval == 1
                ? "Runs every day at \(timeStr)"
                : "Runs every \(newScheduleInterval) days at \(timeStr)"
        case .weekly:
            let dayMap: [(Int, String)] = [(1, "Sunday"), (2, "Monday"), (4, "Tuesday"), (8, "Wednesday"), (16, "Thursday"), (32, "Friday"), (64, "Saturday")]
            let names = dayMap.filter { newScheduleWeekdays.contains($0.0) }.map(\.1).joined(separator: ", ")
            summary = newScheduleInterval == 1
                ? "Runs weekly on \(names.isEmpty ? "no days" : names) at \(timeStr)"
                : "Runs every \(newScheduleInterval) weeks on \(names.isEmpty ? "no days" : names) at \(timeStr)"
        case .monthly:
            let dayStr = ordinalDay(newScheduleMonthDay)
            summary = newScheduleInterval == 1
                ? "Runs on the \(dayStr) of every month at \(timeStr)"
                : "Runs on the \(dayStr) every \(newScheduleInterval) months at \(timeStr)"
        case .once:
            let dateStr = newScheduleOneTimeDate.formatted(date: .abbreviated, time: .omitted)
            summary = "Runs once on \(dateStr) at \(timeStr)"
        }

        return HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(summary)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    // MARK: - Schedule Helpers

    func ordinalDay(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10, tens = n % 100
        if tens >= 11 && tens <= 13 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }

    func createSchedule() {
        let name = newScheduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let startTime = newScheduleStartHour * 10000 + newScheduleStartMinute * 100
        let freqInterval: Int
        switch newScheduleFrequency {
        case .daily: freqInterval = newScheduleInterval
        case .weekly: freqInterval = newScheduleWeekdays.reduce(0, |)
        case .monthly: freqInterval = newScheduleMonthDay
        case .once: freqInterval = 1
        }

        let activeStartDate: Int?
        if newScheduleFrequency == .once {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: newScheduleOneTimeDate)
            activeStartDate = (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        } else {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: newScheduleStartDate)
            activeStartDate = (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        }

        Task {
            await viewModel.addAndAttachSchedule(
                name: name,
                enabled: newScheduleEnabled,
                freqType: newScheduleFrequency.freqType,
                freqInterval: freqInterval,
                activeStartTime: startTime,
                freqRecurrenceFactor: newScheduleFrequency == .weekly ? newScheduleInterval :
                    newScheduleFrequency == .monthly ? newScheduleInterval : nil,
                activeStartDate: activeStartDate
            )
            if viewModel.errorMessage == nil {
                notificationEngine?.post(category: .jobScheduleCreated, message: "Schedule created")
            }
            newScheduleName = ""
            newScheduleEnabled = true
            newScheduleFrequency = .daily
            newScheduleInterval = 1
            newScheduleWeekdays = [2]
            newScheduleMonthDay = 1
            newScheduleStartDate = Date()
        }
    }
}
