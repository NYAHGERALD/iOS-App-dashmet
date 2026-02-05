//
//  Task.swift
//  MeetingIntelligence
//
//  Task model for the Meeting Intelligence app
//

import Foundation

// MARK: - Task Status
enum TaskStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "6B7280"      // Gray
        case .inProgress: return "3B82F6"   // Blue
        case .completed: return "10B981"    // Green
        case .cancelled: return "EF4444"    // Red
        }
    }
}

// MARK: - Task Priority
enum TaskPriority: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case urgent = "URGENT"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "6B7280"       // Gray
        case .medium: return "F59E0B"    // Amber
        case .high: return "F97316"      // Orange
        case .urgent: return "EF4444"    // Red
        }
    }
}

// MARK: - Task User (Lightweight user info)
struct TaskUser: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
}

// MARK: - Task Model
struct Task: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let status: TaskStatus
    let priority: TaskPriority
    let dueDate: Date?
    let completedAt: Date?
    
    // Ownership
    let ownerId: String
    let owner: TaskUser?
    
    // Assignment
    let assigneeId: String?
    let assignee: TaskUser?
    
    // Organization context
    let organizationId: String
    let facilityId: String?
    
    // Meeting reference
    let meetingId: String?
    
    // Metadata
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Computed Properties
    var isOverdue: Bool {
        guard let dueDate = dueDate, status != .completed && status != .cancelled else {
            return false
        }
        return dueDate < Date()
    }
    
    var isDueSoon: Bool {
        guard let dueDate = dueDate, status != .completed && status != .cancelled else {
            return false
        }
        let hoursUntilDue = Calendar.current.dateComponents([.hour], from: Date(), to: dueDate).hour ?? 0
        return hoursUntilDue >= 0 && hoursUntilDue <= 24
    }
    
    var dueDateFormatted: String? {
        guard let dueDate = dueDate else { return nil }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dueDate) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(dueDate) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if calendar.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: dueDate)
    }
}

// MARK: - API Response Models
struct TaskListResponse: Codable {
    let success: Bool
    let tasks: [Task]?
    let count: Int?
    let error: String?
}

struct TaskResponse: Codable {
    let success: Bool
    let task: Task?
    let error: String?
}

struct TaskDeleteResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - API Request Models
struct CreateTaskRequest: Codable {
    let title: String
    let description: String?
    let dueDate: String?
    let priority: String?
    let assigneeId: String?
    let ownerId: String
    let organizationId: String
    let facilityId: String?
    let meetingId: String?
}

struct UpdateTaskRequest: Codable {
    let title: String?
    let description: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let assigneeId: String?
}

// MARK: - JSON Decoding Strategy
extension Task {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            )
        }
        return decoder
    }
}
