import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - Filter Type
enum ToDoFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case upcoming = "Upcoming"
    case flagged = "Flagged"
    case completed = "Completed"
    case overdue = "Overdue"
    
    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar"
        case .flagged: return "flag.fill"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .purple
        case .today: return .orange
        case .upcoming: return .blue
        case .flagged: return .red
        case .completed: return .green
        case .overdue: return .red
        }
    }
}

// MARK: - Sort Type
enum ToDoSortType: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case created = "Created"
    case alphabetical = "Alphabetical"
    case manual = "Manual"
    
    var icon: String {
        switch self {
        case .dueDate: return "calendar"
        case .priority: return "exclamationmark.triangle"
        case .created: return "clock"
        case .alphabetical: return "textformat.abc"
        case .manual: return "hand.draw"
        }
    }
}

// MARK: - To-Do Manager
class ToDoManager: ObservableObject {
    static let shared = ToDoManager()
    
    // MARK: - Published Properties
    @Published var tasks: [ToDoItem] = []
    @Published var categories: [ToDoCategory] = []
    @Published var tags: [ToDoTag] = []
    @Published var statistics: ToDoStatistics = ToDoStatistics()
    @Published var focusSessions: [FocusSession] = []
    
    // Filter & Sort
    @Published var currentFilter: ToDoFilter = .all
    @Published var selectedCategoryId: UUID? = nil
    @Published var sortType: ToDoSortType = .dueDate
    @Published var sortAscending: Bool = true
    @Published var searchText: String = ""
    
    // Focus Timer State
    @Published var isTimerRunning: Bool = false
    @Published var currentFocusSession: FocusSession?
    @Published var timerRemainingSeconds: Int = 0
    
    private var timerCancellable: AnyCancellable?
    
    // Keys for UserDefaults
    private let tasksKey = "todo_tasks"
    private let categoriesKey = "todo_categories"
    private let tagsKey = "todo_tags"
    private let statisticsKey = "todo_statistics"
    private let focusSessionsKey = "todo_focus_sessions"
    
    private init() {
        loadData()
        requestNotificationPermission()
    }
    
    // MARK: - Filtered & Sorted Tasks
    var filteredTasks: [ToDoItem] {
        var result = tasks.filter { !$0.isArchived }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        if let categoryId = selectedCategoryId {
            result = result.filter { $0.categoryId == categoryId }
        }
        
        // Apply filter
        switch currentFilter {
        case .all:
            result = result.filter { !$0.isCompleted }
        case .today:
            result = result.filter { $0.isDueToday && !$0.isCompleted }
        case .upcoming:
            result = result.filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate > Date() && !$0.isCompleted
            }
        case .flagged:
            result = result.filter { $0.isFlagged && !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .overdue:
            result = result.filter { $0.isOverdue }
        }
        
        // Apply sort
        result = sortTasks(result)
        
        return result
    }
    
    private func sortTasks(_ tasks: [ToDoItem]) -> [ToDoItem] {
        let sorted: [ToDoItem]
        
        switch sortType {
        case .dueDate:
            sorted = tasks.sorted {
                let date1 = $0.dueDate ?? Date.distantFuture
                let date2 = $1.dueDate ?? Date.distantFuture
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case .priority:
            sorted = tasks.sorted {
                return sortAscending ?
                    $0.priority.sortOrder < $1.priority.sortOrder :
                    $0.priority.sortOrder > $1.priority.sortOrder
            }
        case .created:
            sorted = tasks.sorted {
                return sortAscending ?
                    $0.createdAt < $1.createdAt :
                    $0.createdAt > $1.createdAt
            }
        case .alphabetical:
            sorted = tasks.sorted {
                return sortAscending ?
                    $0.title.localizedCompare($1.title) == .orderedAscending :
                    $0.title.localizedCompare($1.title) == .orderedDescending
            }
        case .manual:
            sorted = tasks
        }
        
        return sorted
    }
    
    // MARK: - Statistics Computed
    var todayTasksCount: Int {
        tasks.filter { $0.isDueToday && !$0.isCompleted }.count
    }
    
    var overdueTasksCount: Int {
        tasks.filter { $0.isOverdue }.count
    }
    
    var completedTodayCount: Int {
        tasks.filter {
            guard let completedAt = $0.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }
    
    var flaggedTasksCount: Int {
        tasks.filter { $0.isFlagged && !$0.isCompleted }.count
    }
    
    var upcomingTasksCount: Int {
        tasks.filter {
            guard let dueDate = $0.dueDate else { return false }
            return dueDate > Date() && !$0.isCompleted
        }.count
    }
    
    var allActiveTasksCount: Int {
        tasks.filter { !$0.isCompleted && !$0.isArchived }.count
    }
    
    // MARK: - CRUD Operations
    
    func addTask(_ task: ToDoItem) {
        tasks.append(task)
        statistics.totalTasksCreated += 1
        saveData()
        
        if task.hasReminder, let reminderDate = task.reminderDate {
            scheduleNotification(for: task, at: reminderDate)
        }
    }
    
    func updateTask(_ task: ToDoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.updatedAt = Date()
            tasks[index] = updatedTask
            saveData()
            
            // Update notification
            cancelNotification(for: task.id)
            if task.hasReminder, let reminderDate = task.reminderDate {
                scheduleNotification(for: updatedTask, at: reminderDate)
            }
        }
    }
    
    func deleteTask(_ task: ToDoItem) {
        tasks.removeAll { $0.id == task.id }
        cancelNotification(for: task.id)
        saveData()
    }
    
    func toggleTaskCompletion(_ task: ToDoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            tasks[index].updatedAt = Date()
            
            if tasks[index].isCompleted {
                tasks[index].completedAt = Date()
                statistics.totalTasksCompleted += 1
                updateStreak()
                
                // Handle recurrence
                if task.recurrence != .none {
                    createRecurringTask(from: task)
                }
            } else {
                tasks[index].completedAt = nil
            }
            
            saveData()
        }
    }
    
    func toggleSubtask(_ task: ToDoItem, subtaskId: UUID) {
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
           let subtaskIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) {
            tasks[taskIndex].subtasks[subtaskIndex].isCompleted.toggle()
            tasks[taskIndex].subtasks[subtaskIndex].completedAt = tasks[taskIndex].subtasks[subtaskIndex].isCompleted ? Date() : nil
            tasks[taskIndex].updatedAt = Date()
            saveData()
        }
    }
    
    func toggleFlag(_ task: ToDoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isFlagged.toggle()
            tasks[index].updatedAt = Date()
            saveData()
        }
    }
    
    func archiveTask(_ task: ToDoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isArchived = true
            tasks[index].updatedAt = Date()
            saveData()
        }
    }
    
    // MARK: - Recurrence
    
    private func createRecurringTask(from task: ToDoItem) {
        guard let dueDate = task.dueDate else { return }
        
        var newDueDate: Date?
        let calendar = Calendar.current
        
        switch task.recurrence {
        case .daily:
            newDueDate = calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekdays:
            var nextDate = calendar.date(byAdding: .day, value: 1, to: dueDate)!
            while calendar.isDateInWeekend(nextDate) {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
            }
            newDueDate = nextDate
        case .weekly:
            newDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .biweekly:
            newDueDate = calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate)
        case .monthly:
            newDueDate = calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .yearly:
            newDueDate = calendar.date(byAdding: .year, value: 1, to: dueDate)
        case .custom:
            if let days = task.customRecurrenceDays {
                newDueDate = calendar.date(byAdding: .day, value: days, to: dueDate)
            }
        case .none:
            return
        }
        
        if let newDueDate = newDueDate {
            let newTask = ToDoItem(
                id: UUID(),
                title: task.title,
                notes: task.notes,
                isCompleted: false,
                completedAt: nil,
                createdAt: Date(),
                updatedAt: Date(),
                categoryId: task.categoryId,
                priority: task.priority,
                tags: task.tags,
                dueDate: newDueDate,
                reminderDate: task.hasReminder ? newDueDate : nil,
                hasReminder: task.hasReminder,
                recurrence: task.recurrence,
                customRecurrenceDays: task.customRecurrenceDays,
                subtasks: task.subtasks.map {
                    Subtask(id: UUID(), title: $0.title, isCompleted: false)
                },
                estimatedMinutes: task.estimatedMinutes,
                actualMinutes: nil,
                pomodorosCompleted: 0,
                isFlagged: task.isFlagged,
                isArchived: false
            )
            
            addTask(newTask)
        }
    }
    
    // MARK: - Categories
    
    func addCategory(_ category: ToDoCategory) {
        categories.append(category)
        saveData()
    }
    
    func updateCategory(_ category: ToDoCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveData()
        }
    }
    
    func deleteCategory(_ category: ToDoCategory) {
        categories.removeAll { $0.id == category.id }
        // Remove category from tasks
        for i in tasks.indices where tasks[i].categoryId == category.id {
            tasks[i].categoryId = nil
        }
        saveData()
    }
    
    func category(for id: UUID?) -> ToDoCategory? {
        guard let id = id else { return nil }
        return categories.first { $0.id == id }
    }
    
    // MARK: - Tags
    
    func addTag(_ tag: ToDoTag) {
        if !tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) {
            tags.append(tag)
            saveData()
        }
    }
    
    func deleteTag(_ tag: ToDoTag) {
        tags.removeAll { $0.id == tag.id }
        // Remove tag from tasks
        for i in tasks.indices {
            tasks[i].tags.removeAll { $0.id == tag.id }
        }
        saveData()
    }
    
    // MARK: - Focus Timer
    
    func startFocusTimer(for task: ToDoItem?, duration: Int) {
        let session = FocusSession(
            taskId: task?.id,
            durationMinutes: duration
        )
        currentFocusSession = session
        timerRemainingSeconds = duration * 60
        isTimerRunning = true
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timerRemainingSeconds > 0 {
                    self.timerRemainingSeconds -= 1
                } else {
                    self.completeFocusSession()
                }
            }
    }
    
    func pauseTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
    }
    
    func resumeTimer() {
        isTimerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.timerRemainingSeconds > 0 {
                    self.timerRemainingSeconds -= 1
                } else {
                    self.completeFocusSession()
                }
            }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
        currentFocusSession = nil
        timerRemainingSeconds = 0
    }
    
    func completeFocusSession() {
        guard var session = currentFocusSession else { return }
        
        session.endTime = Date()
        session.isCompleted = true
        focusSessions.append(session)
        
        // Update statistics
        statistics.totalPomodorosCompleted += 1
        statistics.totalFocusMinutes += session.durationMinutes
        
        // Update task if linked
        if let taskId = session.taskId,
           let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].pomodorosCompleted += 1
            tasks[index].actualMinutes = (tasks[index].actualMinutes ?? 0) + session.durationMinutes
        }
        
        stopTimer()
        saveData()
        
        // Send completion notification
        sendTimerCompletionNotification()
    }
    
    // MARK: - Streak
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = statistics.lastCompletionDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysBetween == 0 {
                // Same day, streak continues
            } else if daysBetween == 1 {
                // Consecutive day
                statistics.currentStreak += 1
                if statistics.currentStreak > statistics.longestStreak {
                    statistics.longestStreak = statistics.currentStreak
                }
            } else {
                // Streak broken
                statistics.currentStreak = 1
            }
        } else {
            statistics.currentStreak = 1
        }
        
        statistics.lastCompletionDate = today
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    func scheduleNotification(for task: ToDoItem, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title
        content.sound = .default
        content.badge = 1
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(for taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
    }
    
    private func sendTimerCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete! 🎉"
        content.body = "Great job! Take a break or start another session."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([ToDoItem].self, from: data) {
            tasks = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([ToDoCategory].self, from: data) {
            categories = decoded
        } else {
            categories = ToDoCategory.defaults
        }
        
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([ToDoTag].self, from: data) {
            tags = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: statisticsKey),
           let decoded = try? JSONDecoder().decode(ToDoStatistics.self, from: data) {
            statistics = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: focusSessionsKey),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            focusSessions = decoded
        }
    }
    
    func saveData() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
        
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
        
        if let encoded = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(encoded, forKey: tagsKey)
        }
        
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: statisticsKey)
        }
        
        if let encoded = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(encoded, forKey: focusSessionsKey)
        }
    }
    
    // MARK: - Quick Actions
    
    func addQuickTask(_ title: String, dueDate: Date? = nil, priority: ToDoPriority = .none) {
        let task = ToDoItem(
            title: title,
            priority: priority,
            dueDate: dueDate
        )
        addTask(task)
    }
    
    func completeAllSubtasks(_ task: ToDoItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            for i in tasks[index].subtasks.indices {
                tasks[index].subtasks[i].isCompleted = true
                tasks[index].subtasks[i].completedAt = Date()
            }
            tasks[index].updatedAt = Date()
            saveData()
        }
    }
}
