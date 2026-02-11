import Foundation
import SwiftUI

// MARK: - Priority Level
enum ToDoPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case none = "None"
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        case .none: return "minus"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .none: return 3
        }
    }
}

// MARK: - Recurrence Type
enum RecurrenceType: String, Codable, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .none: return "calendar"
        case .daily: return "repeat"
        case .weekdays: return "briefcase"
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar.badge.plus"
        case .monthly: return "calendar.circle"
        case .yearly: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - Task Category
struct ToDoCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    
    init(id: UUID = UUID(), name: String, icon: String, colorHex: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    // Default categories
    static let personal = ToDoCategory(name: "Personal", icon: "person.fill", colorHex: "8B5CF6", sortOrder: 0)
    static let work = ToDoCategory(name: "Work", icon: "briefcase.fill", colorHex: "3B82F6", sortOrder: 1)
    static let health = ToDoCategory(name: "Health", icon: "heart.fill", colorHex: "EF4444", sortOrder: 2)
    static let shopping = ToDoCategory(name: "Shopping", icon: "cart.fill", colorHex: "10B981", sortOrder: 3)
    static let learning = ToDoCategory(name: "Learning", icon: "book.fill", colorHex: "F59E0B", sortOrder: 4)
    static let home = ToDoCategory(name: "Home", icon: "house.fill", colorHex: "EC4899", sortOrder: 5)
    
    static let defaults: [ToDoCategory] = [personal, work, health, shopping, learning, home]
}

// MARK: - Subtask
struct Subtask: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

// MARK: - Tag
struct ToDoTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    
    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - To-Do Item
struct ToDoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Organization
    var categoryId: UUID?
    var priority: ToDoPriority
    var tags: [ToDoTag]
    
    // Timing
    var dueDate: Date?
    var reminderDate: Date?
    var hasReminder: Bool
    
    // Recurrence
    var recurrence: RecurrenceType
    var customRecurrenceDays: Int?
    
    // Subtasks
    var subtasks: [Subtask]
    
    // Focus/Timer
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var pomodorosCompleted: Int
    
    // Metadata
    var isFlagged: Bool
    var isArchived: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        categoryId: UUID? = nil,
        priority: ToDoPriority = .none,
        tags: [ToDoTag] = [],
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        hasReminder: Bool = false,
        recurrence: RecurrenceType = .none,
        customRecurrenceDays: Int? = nil,
        subtasks: [Subtask] = [],
        estimatedMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        pomodorosCompleted: Int = 0,
        isFlagged: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryId = categoryId
        self.priority = priority
        self.tags = tags
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.hasReminder = hasReminder
        self.recurrence = recurrence
        self.customRecurrenceDays = customRecurrenceDays
        self.subtasks = subtasks
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.pomodorosCompleted = pomodorosCompleted
        self.isFlagged = isFlagged
        self.isArchived = isArchived
    }
    
    // MARK: - Computed Properties
    
    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subtasks.count)
    }
    
    var completedSubtasksCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }
    
    var isDueThisWeek: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "" }
        
        if isOverdue {
            return "Overdue"
        } else if isDueToday {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: dueDate))"
        } else if isDueTomorrow {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Tomorrow, \(formatter.string(from: dueDate))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: dueDate)
        }
    }
    
    var dueDateColor: Color {
        if isOverdue {
            return .red
        } else if isDueToday {
            return .orange
        } else if isDueTomorrow {
            return .yellow
        } else {
            return .gray
        }
    }
}

// MARK: - Focus Session
struct FocusSession: Identifiable, Codable {
    let id: UUID
    let taskId: UUID?
    let startTime: Date
    var endTime: Date?
    var durationMinutes: Int
    var isCompleted: Bool
    var type: FocusType
    
    enum FocusType: String, Codable {
        case pomodoro = "Pomodoro"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
        case custom = "Custom"
    }
    
    init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationMinutes: Int = 25,
        isCompleted: Bool = false,
        type: FocusType = .pomodoro
    ) {
        self.id = id
        self.taskId = taskId
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
        self.type = type
    }
}

// MARK: - Statistics
struct ToDoStatistics: Codable {
    var totalTasksCreated: Int
    var totalTasksCompleted: Int
    var totalPomodorosCompleted: Int
    var totalFocusMinutes: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletionDate: Date?
    
    init() {
        totalTasksCreated = 0
        totalTasksCompleted = 0
        totalPomodorosCompleted = 0
        totalFocusMinutes = 0
        currentStreak = 0
        longestStreak = 0
        lastCompletionDate = nil
    }
    
    var averageTasksPerDay: Double {
        guard totalTasksCompleted > 0 else { return 0 }
        // Simplified calculation
        return Double(totalTasksCompleted) / 7.0
    }
}
