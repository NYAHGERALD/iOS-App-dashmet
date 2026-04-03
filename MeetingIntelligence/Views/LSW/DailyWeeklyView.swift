//
//  DailyWeeklyView.swift
//  MeetingIntelligence
//
//  Daily & Weekly Standard Tasks/Meetings
//

import SwiftUI
import Combine

struct DailyWeeklyView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showAddTask = false
    @State private var currentWeekOffset = 0
    @State private var configLoaded = false
    @State private var activeFilter: TaskFilter = .all
    
    // Polling timer for cross-platform sync
    private let syncTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    // Early completion / uncheck modal state
    @State private var showFutureTaskAlert = false
    @State private var showUncheckConfirm = false
    @State private var pendingTaskId: String = ""
    @State private var pendingTaskName: String = ""
    @State private var pendingTaskTime: String = ""
    @State private var pendingDayIndex: Int = 0
    @State private var pendingDayKey: String = ""
    @State private var pendingDayLabel: String = ""
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case pastDue = "Past Due"
        case onTrack = "On Track"
    }
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private let allDayAbbreviations = ["M", "T", "W", "T", "F", "S", "S"]
    private let allDayKeys = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    private let allDayLabels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let allDayShortKeys = ["M", "T", "W", "H", "F", "S1", "S2"]
    
    private var visibleDayCount: Int { lswService.workDaysPerWeek }
    private var visibleDayAbbreviations: [String] { Array(allDayAbbreviations.prefix(visibleDayCount)) }
    private var visibleDayKeys: [String] { Array(allDayKeys.prefix(visibleDayCount)) }
    
    // Use org calendar for week calculation
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
    }
    
    private var currentOrgWeek: Int {
        lswService.orgWeekNumber(for: referenceDate)
    }
    
    private var currentOrgYear: Int {
        lswService.orgYear(for: referenceDate)
    }
    
    private var currentWeekDates: (start: Date, end: Date) {
        lswService.weekDates(weekNumber: currentOrgWeek, year: currentOrgYear)
    }
    
    private var isOnCurrentWeek: Bool {
        currentWeekOffset == 0
    }
    
    private var filteredTasks: [LSWDailyTask] {
        let tasks = lswService.dailyTasks
        switch activeFilter {
        case .all:
            return tasks
        case .pastDue:
            // Past due = viewing a past week (or current week) and has unchecked days up to today
            return tasks.filter { task in
                let days = [task.monday, task.tuesday, task.wednesday, task.thursday, task.friday, task.saturday, task.sunday]
                let visible = Array(days.prefix(visibleDayCount))
                let todayDayIndex = currentDayIndex()
                
                if currentWeekOffset < 0 {
                    // Past week: any unchecked visible day is past due
                    return visible.contains(false)
                } else if currentWeekOffset == 0 {
                    // Current week: unchecked days before today are past due
                    for i in 0..<min(todayDayIndex, visible.count) {
                        if !visible[i] { return true }
                    }
                    return false
                } else {
                    return false // Future weeks can't be past due
                }
            }
        case .onTrack:
            // On track = all past/current visible days are checked
            return tasks.filter { task in
                let days = [task.monday, task.tuesday, task.wednesday, task.thursday, task.friday, task.saturday, task.sunday]
                let visible = Array(days.prefix(visibleDayCount))
                let todayDayIndex = currentDayIndex()
                
                if currentWeekOffset < 0 {
                    return !visible.contains(false)
                } else if currentWeekOffset == 0 {
                    for i in 0..<min(todayDayIndex, visible.count) {
                        if !visible[i] { return false }
                    }
                    return true
                } else {
                    return true
                }
            }
        }
    }
    
    /// Returns 0-based index of today in the week (0=Monday, 6=Sunday)
    private func currentDayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // weekday: 1=Sun, 2=Mon, ... 7=Sat → convert to 0=Mon
        return weekday == 1 ? 6 : weekday - 2
    }
    
    /// Whether the day at the given index is in the future relative to today
    private func isFutureDay(_ dayIndex: Int) -> Bool {
        if currentWeekOffset > 0 { return true }
        if currentWeekOffset < 0 { return false }
        // On current week: compare day index to today
        return dayIndex > currentDayIndex()
    }
    
    /// The calendar date for a given day index in the current viewed week
    private func dateForDay(_ dayIndex: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: currentWeekDates.start)!
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar: Current Week button (left) | Week Nav (center) | Days menu (right)
                HStack(spacing: 0) {
                    // Left: "Current Week" button — only visible when away from current week
                    if !isOnCurrentWeek {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentWeekOffset = 0
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Current")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(hex: "0EA5E9"))
                            .clipShape(Capsule())
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Color.clear.frame(width: 70, height: 28)
                    }
                    
                    Spacer()
                    
                    weekNavigator
                    
                    Spacer()
                    
                    // Right: Work days selector
                    Menu {
                        ForEach([5, 6, 7], id: \.self) { days in
                            Button {
                                Task { await lswService.updateWorkDays(days) }
                            } label: {
                                if lswService.workDaysPerWeek == days {
                                    Label(workDaysLabel(days), systemImage: "checkmark")
                                } else {
                                    Text(workDaysLabel(days))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text("\(lswService.workDaysPerWeek)d")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "0EA5E9"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(hex: "0EA5E9").opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                Divider()
                
                if lswService.isLoading && lswService.dailyTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("Loading tasks...")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    Spacer()
                } else if lswService.dailyTasks.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    tasksList
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "0EA5E9"), Color(hex: "6366F1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "0EA5E9").opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Daily & Weekly")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation { activeFilter = filter }
                        } label: {
                            if activeFilter == filter {
                                Label(filter.rawValue, systemImage: "checkmark")
                            } else {
                                Text(filter.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: activeFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(activeFilter == .all ? textSecondary : Color(hex: "0EA5E9"))
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddDailyTaskView()
        }
        .onChange(of: showAddTask) { newValue in
            if !newValue {
                Task {
                    await lswService.fetchDailyTasks(weekNumber: currentOrgWeek, year: currentOrgYear)
                    await lswService.fetchEarlyCompletionLogs(weekNumber: currentOrgWeek, year: currentOrgYear)
                }
            }
        }
        .onChange(of: currentWeekOffset) { _ in
            lswService.setActiveWeek(weekNumber: currentOrgWeek, year: currentOrgYear)
            Task {
                await lswService.fetchDailyTasks(weekNumber: currentOrgWeek, year: currentOrgYear)
                await lswService.fetchEarlyCompletionLogs(weekNumber: currentOrgWeek, year: currentOrgYear)
            }
        }
        .task {
            await lswService.fetchConfig()
            configLoaded = true
            // Use explicit values from service directly — NOT computed properties
            // to avoid SwiftUI timing issues with @Published state propagation
            let refDate = Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
            let week = lswService.orgWeekNumber(for: refDate)
            let year = lswService.orgYear(for: refDate)
            lswService.setActiveWeek(weekNumber: week, year: year)
            lswService.connectWebSocket()
            await lswService.fetchDailyTasks(weekNumber: week, year: year)
            await lswService.fetchEarlyCompletionLogs(weekNumber: week, year: year)
        }
        .onDisappear {
            lswService.disconnectWebSocket()
        }
        // Cross-platform sync: refetch when app returns to foreground
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && configLoaded {
                Task {
                    await lswService.fetchDailyTasks(weekNumber: currentOrgWeek, year: currentOrgYear)
                    await lswService.fetchEarlyCompletionLogs(weekNumber: currentOrgWeek, year: currentOrgYear)
                }
            }
        }
        // Periodic polling every 15s as reliable sync fallback
        .onReceive(syncTimer) { _ in
            guard configLoaded else { return }
            Task {
                await lswService.fetchDailyTasks(weekNumber: currentOrgWeek, year: currentOrgYear)
                await lswService.fetchEarlyCompletionLogs(weekNumber: currentOrgWeek, year: currentOrgYear)
            }
        }
        // Future Task warning
        .alert("Future Task", isPresented: $showFutureTaskAlert) {
            Button("Cancel", role: .cancel) { }
            Button("⚡ Early Completed") {
                Task {
                    // Mark as completed
                    await lswService.toggleCompletion(
                        taskId: pendingTaskId,
                        weekNumber: currentOrgWeek,
                        year: currentOrgYear,
                        day: pendingDayKey,
                        value: true
                    )
                    // Log the early completion
                    await lswService.logEarlyCompletion(
                        dailyTaskId: pendingTaskId,
                        taskName: pendingTaskName,
                        taskTime: pendingTaskTime,
                        dayKey: allDayShortKeys[pendingDayIndex],
                        dayLabel: allDayLabels[pendingDayIndex],
                        weekNumber: currentOrgWeek,
                        year: currentOrgYear,
                        scheduledDate: dateForDay(pendingDayIndex)
                    )
                }
            }
        } message: {
            Text("Sorry, you cannot check off this task as completed because it is still in the future. You are allowed to check off your task if you forget to do so, but not a task or meeting that is yet to be completed.\n\nIf you think this task or meeting was completed at an earlier time prior, please click the Early Completed button.\n\n⚠️ Note: This task will be marked as early complete and logged for audit purposes.\n\n\(pendingTaskName.uppercased()) • \(formatTime(pendingTaskTime)) • \(allDayLabels[pendingDayIndex].prefix(3))")
        }
        // Confirm Uncheck
        .alert("Confirm Uncheck", isPresented: $showUncheckConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("OK, Uncheck", role: .destructive) {
                Task {
                    let wasEarly = lswService.isEarlyCompleted(taskId: pendingTaskId, dayKey: allDayShortKeys[pendingDayIndex])
                    await lswService.toggleCompletion(
                        taskId: pendingTaskId,
                        weekNumber: currentOrgWeek,
                        year: currentOrgYear,
                        day: pendingDayKey,
                        value: false
                    )
                    // If it was early-completed, delete the log from the database
                    if wasEarly {
                        await lswService.deleteEarlyCompletionLog(
                            dailyTaskId: pendingTaskId,
                            dayKey: allDayShortKeys[pendingDayIndex],
                            weekNumber: currentOrgWeek,
                            year: currentOrgYear
                        )
                    }
                }
            }
        } message: {
            let earlyText = lswService.isEarlyCompleted(taskId: pendingTaskId, dayKey: allDayShortKeys[pendingDayIndex]) ? " as early completed" : ""
            Text("Are you sure you want to uncheck \(pendingTaskName) on \(allDayLabels[pendingDayIndex])\(earlyText)?")
        }
    }
    
    // MARK: - Week Navigator
    private var weekNavigator: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { currentWeekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .frame(width: 32, height: 32)
                    .background(cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(cardBorder, lineWidth: 1))
            }
            
            VStack(spacing: 2) {
                Text("Week \(currentOrgWeek)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "0EA5E9"))
                
                Text("\(formatShortDate(currentWeekDates.start)) — \(formatShortDate(currentWeekDates.end))")
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }
            
            Button {
                withAnimation { currentWeekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .frame(width: 32, height: 32)
                    .background(cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(cardBorder, lineWidth: 1))
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "0EA5E9").opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34))
                    .foregroundColor(Color(hex: "0EA5E9"))
            }
            
            Text("No Standard Tasks Yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Tap + to add your daily or weekly recurring tasks and meetings.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }
    
    // MARK: - Tasks List
    private var tasksList: some View {
        ScrollView {
            // Day headers
            HStack(spacing: 0) {
                Text("Task")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 14)
                
                ForEach(visibleDayAbbreviations.indices, id: \.self) { i in
                    Text(visibleDayAbbreviations[i])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textTertiary)
                        .frame(width: 28)
                }
                .padding(.trailing, 2)
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
            
            VStack(spacing: 0) {
                ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task)
                    
                    if index < filteredTasks.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Task Row
    private func taskRow(_ task: LSWDailyTask) -> some View {
        HStack(spacing: 0) {
            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.task)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatTime(task.time))
                        .font(.system(size: 12, weight: .medium))
                    
                    if let mins = task.minutes {
                        Text("·")
                        Text("\(mins) min")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(Color(hex: "22C55E"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            
            // Day checkboxes (only show visible days based on workDaysPerWeek)
            let allDays = [task.monday, task.tuesday, task.wednesday, task.thursday, task.friday, task.saturday, task.sunday]
            let days = Array(allDays.prefix(visibleDayCount))
            ForEach(days.indices, id: \.self) { i in
                let isChecked = days[i]
                let isEarly = lswService.isEarlyCompleted(taskId: task.id, dayKey: allDayShortKeys[i])
                let checkColor: Color = isChecked ? (isEarly ? Color(hex: "F59E0B") : Color(hex: "0EA5E9")) : Color.gray.opacity(0.15)
                
                Button {
                    pendingTaskId = task.id
                    pendingTaskName = task.task
                    pendingTaskTime = task.time
                    pendingDayIndex = i
                    pendingDayKey = visibleDayKeys[i]
                    pendingDayLabel = allDayLabels[i]
                    
                    if isChecked {
                        // Unchecking — always confirm
                        showUncheckConfirm = true
                    } else if isFutureDay(i) {
                        // Checking a future day — show warning
                        showFutureTaskAlert = true
                    } else {
                        // Normal check (past or current day)
                        Task {
                            await lswService.toggleCompletion(
                                taskId: task.id,
                                weekNumber: currentOrgWeek,
                                year: currentOrgYear,
                                day: visibleDayKeys[i],
                                value: true
                            )
                        }
                    }
                } label: {
                    Circle()
                        .fill(checkColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            isChecked ? Image(systemName: isEarly ? "bolt.fill" : "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white) : nil
                        )
                        .frame(width: 28)
                        .animation(.easeInOut(duration: 0.15), value: isChecked)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 2)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 8)
        .contextMenu {
            Button(role: .destructive) {
                Task { let _ = await lswService.deleteDailyTask(task.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helpers
    private func workDaysLabel(_ days: Int) -> String {
        switch days {
        case 5: return "Mon – Fri (5 days)"
        case 6: return "Mon – Sat (6 days)"
        case 7: return "Mon – Sun (7 days)"
        default: return "\(days) days"
        }
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return time }
        
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

// MARK: - Add Daily Task Sheet
struct AddDailyTaskView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var taskName = ""
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var duration = 15
    @State private var selectedDays: [Bool] = [true, true, true, true, true, false, false]
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var fieldBackground: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color(.systemGray6) }
    
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let durationOptions = [15, 30, 45, 60, 90, 120]
    
    private var isFormValid: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task Name
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 2) {
                            Text("Task / Meeting Name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        TextField("e.g., Morning Production Review", text: $taskName)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Time & Duration
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 2) {
                                Text("Start Time")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(8)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 2) {
                                Text("Duration")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            
                            Menu {
                                ForEach(durationOptions, id: \.self) { mins in
                                    Button {
                                        duration = mins
                                    } label: {
                                        if duration == mins {
                                            Label("\(mins) min", systemImage: "checkmark")
                                        } else {
                                            Text("\(mins) min")
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(duration) min")
                                        .font(.system(size: 14))
                                        .foregroundColor(textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundColor(textSecondary)
                                }
                                .padding(12)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    
                    // Day Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recurring Days")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach(dayLabels.indices, id: \.self) { i in
                                Button {
                                    selectedDays[i].toggle()
                                } label: {
                                    Text(dayLabels[i])
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(selectedDays[i] ? .white : textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedDays[i]
                                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "0EA5E9"), Color(hex: "6366F1")], startPoint: .top, endPoint: .bottom))
                                            : AnyShapeStyle(fieldBackground)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Daily Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addTask()
                    } label: {
                        HStack(spacing: 4) {
                            if lswService.isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text("Add Task")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            isFormValid && !lswService.isSubmitting
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "0EA5E9"), Color(hex: "6366F1")], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(!isFormValid || lswService.isSubmitting)
                }
            }
        }
    }
    
    private func addTask() {
        let request = CreateDailyTaskRequest(
            task: taskName.trimmingCharacters(in: .whitespaces),
            time: timeString,
            minutes: duration,
            monday: selectedDays[0],
            tuesday: selectedDays[1],
            wednesday: selectedDays[2],
            thursday: selectedDays[3],
            friday: selectedDays[4],
            saturday: selectedDays[5],
            sunday: selectedDays[6]
        )
        
        Task {
            let success = await lswService.createDailyTask(request)
            if success {
                await MainActor.run { dismiss() }
            }
        }
    }
}
