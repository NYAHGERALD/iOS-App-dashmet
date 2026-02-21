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
    let firstName: String?
    let lastName: String?
    let email: String?
    let profilePicture: String?
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? (email ?? "Unknown") : name
    }
    
    var initials: String {
        let first = (firstName ?? "").prefix(1).uppercased()
        let last = (lastName ?? "").prefix(1).uppercased()
        let result = "\(first)\(last)"
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Task Comment Model
struct TaskComment: Codable, Identifiable, Hashable {
    let id: String
    let content: String
    let taskId: String
    let authorId: String
    let parentId: String?
    let author: TaskUser?
    let replies: [TaskComment]?
    let createdAt: Date?
    let updatedAt: Date?
    
    var timeAgo: String {
        guard let createdAt = createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Task Evidence Model
struct TaskEvidence: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let fileUrl: String?
    let fileType: String?
    let fileName: String?
    let taskId: String
    let uploaderId: String
    let uploader: TaskUser?
    let createdAt: Date
    
    var fileIcon: String {
        guard let fileType = fileType?.lowercased() else { return "doc.fill" }
        
        if fileType.contains("image") || fileType.contains("png") || fileType.contains("jpg") || fileType.contains("jpeg") {
            return "photo.fill"
        } else if fileType.contains("pdf") {
            return "doc.text.fill"
        } else if fileType.contains("video") || fileType.contains("mp4") || fileType.contains("mov") {
            return "video.fill"
        } else if fileType.contains("audio") || fileType.contains("mp3") || fileType.contains("wav") {
            return "waveform"
        } else if fileType.contains("spreadsheet") || fileType.contains("xlsx") || fileType.contains("csv") {
            return "tablecells.fill"
        } else {
            return "doc.fill"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: createdAt)
    }
}

// MARK: - Task Count Model
struct TaskCounts: Codable, Hashable {
    let comments: Int?
    let evidence: Int?
}

// MARK: - Task Assignee Model (for multiple assignees)
struct TaskAssignee: Codable, Identifiable, Hashable {
    let id: String
    let taskId: String
    let userId: String
    let assignedAt: Date
    let assignedBy: String?
    let user: TaskUser?
    let assigner: TaskUser?
    
    var displayName: String {
        user?.fullName ?? "Unknown User"
    }
}

// MARK: - Task Meeting (embedded meeting info)
struct TaskMeeting: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let meetingType: String?
    let scheduledAt: Date?
    
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        // If no title, include meeting date for differentiation
        let typeName = meetingType?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Meeting"
        if let date = scheduledAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return "\(typeName) - \(formatter.string(from: date))"
        }
        return typeName
    }
    
    var formattedType: String {
        meetingType?.replacingOccurrences(of: "_", with: " ").lowercased().capitalized ?? "Meeting"
    }
    
    var formattedDate: String? {
        guard let date = scheduledAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Task Model
struct TaskItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let status: TaskStatus
    let priority: TaskPriority
    let dueDate: Date?
    let completedAt: Date?
    
    // Progress tracking (0-100)
    let progress: Int?
    
    // AI extraction info
    let sourceText: String?
    let isAiExtracted: Bool?
    
    // Ownership
    let ownerId: String?
    let owner: TaskUser?
    
    // Assignment (legacy single assignee)
    let assigneeId: String?
    let assignee: TaskUser?
    
    // Multiple assignees
    let assignees: [TaskAssignee]?
    
    // Organization context
    let organizationId: String?
    let facilityId: String?
    
    // Meeting reference
    let meetingId: String?
    let meeting: TaskMeeting?
    
    // Comments and evidence
    let comments: [TaskComment]?
    let evidence: [TaskEvidence]?
    let _count: TaskCounts?
    
    // Metadata
    let createdAt: Date?
    let updatedAt: Date?
    
    // MARK: - Computed Properties
    var progressValue: Int {
        progress ?? 0
    }
    
    // Get all assigned users (combines legacy assignee with multiple assignees)
    var allAssignees: [TaskUser] {
        var users: [TaskUser] = []
        
        // Add from multiple assignees
        if let assignees = assignees {
            users.append(contentsOf: assignees.compactMap { $0.user })
        }
        
        // Add legacy single assignee if not already in the list
        if let assignee = assignee, !users.contains(where: { $0.id == assignee.id }) {
            users.append(assignee)
        }
        
        return users
    }
    
    var assigneeNames: String {
        let names = allAssignees.map { $0.fullName }
        if names.isEmpty {
            return "Unassigned"
        } else if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return names.joined(separator: " & ")
        } else {
            return "\(names[0]) +\(names.count - 1) more"
        }
    }
    
    var commentsCount: Int {
        _count?.comments ?? comments?.count ?? 0
    }
    
    var evidenceCount: Int {
        _count?.evidence ?? evidence?.count ?? 0
    }
    
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
    let tasks: [TaskItem]?
    let count: Int?
    let error: String?
    let message: String?
}

struct TaskResponse: Codable {
    let success: Bool
    let task: TaskItem?
    let error: String?
}

struct TaskDeleteResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

struct TaskCommentResponse: Codable {
    let success: Bool
    let comment: TaskComment?
    let error: String?
}

struct TaskCommentsListResponse: Codable {
    let success: Bool
    let comments: [TaskComment]?
    let count: Int?
    let error: String?
}

struct TaskEvidenceResponse: Codable {
    let success: Bool
    let evidence: TaskEvidence?
    let error: String?
}

struct TaskEvidenceListResponse: Codable {
    let success: Bool
    let evidence: [TaskEvidence]?
    let count: Int?
    let error: String?
}

// MARK: - Organization User for Assignment
struct OrganizationUser: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let role: String?
    let profilePicture: String?
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? email : name
    }
    
    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        let result = "\(first)\(last)"
        return result.isEmpty ? String(email.prefix(2)).uppercased() : result
    }
}

struct OrganizationUsersResponse: Codable {
    let success: Bool
    let users: [OrganizationUser]?
    let count: Int?
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
    let sourceText: String?
    let isAiExtracted: Bool?
}

struct UpdateTaskRequest: Codable {
    let title: String?
    let description: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let assigneeId: String?
    let progress: Int?
}

struct ExtractActionItemsRequest: Codable {
    let meetingId: String
    let transcript: String
    let ownerId: String
    let organizationId: String
    let facilityId: String?
}

struct CreateCommentRequest: Codable {
    let content: String
    let authorId: String
    let parentId: String?
}

struct CreateEvidenceRequest: Codable {
    let title: String
    let description: String?
    let fileUrl: String?
    let fileType: String?
    let fileName: String?
    let uploaderId: String
}

struct BulkCreateTasksRequest: Codable {
    let tasks: [BulkTaskItem]
    let ownerId: String
    let organizationId: String
    let facilityId: String?
    let meetingId: String?
}

struct BulkTaskItem: Codable {
    let title: String
    let description: String?
    let priority: String?
    let dueDate: String?
    let assigneeId: String?
    let sourceText: String?
    let isAiExtracted: Bool?
}

struct BulkUpdateStatusRequest: Codable {
    let taskIds: [String]
    let status: String
}

// MARK: - Task Activity Log Model
enum TaskActivityAction: String, Codable {
    case create = "CREATE"
    case updateStatus = "UPDATE_STATUS"
    case updatePriority = "UPDATE_PRIORITY"
    case updateProgress = "UPDATE_PROGRESS"
    case updateTitle = "UPDATE_TITLE"
    case updateDescription = "UPDATE_DESCRIPTION"
    case updateDueDate = "UPDATE_DUE_DATE"
    case addAssignee = "ADD_ASSIGNEE"
    case removeAssignee = "REMOVE_ASSIGNEE"
    case addComment = "ADD_COMMENT"
    case deleteComment = "DELETE_COMMENT"
    case addEvidence = "ADD_EVIDENCE"
    case deleteEvidence = "DELETE_EVIDENCE"
    case unknown = "UNKNOWN"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TaskActivityAction(rawValue: rawValue) ?? .unknown
    }
    
    var displayName: String {
        switch self {
        case .create: return "Created"
        case .updateStatus: return "Status Changed"
        case .updatePriority: return "Priority Changed"
        case .updateProgress: return "Progress Updated"
        case .updateTitle: return "Title Updated"
        case .updateDescription: return "Description Updated"
        case .updateDueDate: return "Due Date Changed"
        case .addAssignee: return "Assignee Added"
        case .removeAssignee: return "Assignee Removed"
        case .addComment: return "Comment Added"
        case .deleteComment: return "Comment Deleted"
        case .addEvidence: return "Evidence Added"
        case .deleteEvidence: return "Evidence Deleted"
        case .unknown: return "Updated"
        }
    }
    
    var icon: String {
        switch self {
        case .create: return "plus.circle.fill"
        case .updateStatus: return "arrow.triangle.2.circlepath"
        case .updatePriority: return "exclamationmark.triangle.fill"
        case .updateProgress: return "chart.bar.fill"
        case .updateTitle: return "pencil"
        case .updateDescription: return "text.alignleft"
        case .updateDueDate: return "calendar"
        case .addAssignee: return "person.badge.plus"
        case .removeAssignee: return "person.badge.minus"
        case .addComment: return "bubble.left.fill"
        case .deleteComment: return "bubble.left.and.exclamationmark.bubble.right"
        case .addEvidence: return "paperclip"
        case .deleteEvidence: return "trash"
        case .unknown: return "pencil.circle"
        }
    }
    
    var color: String {
        switch self {
        case .create: return "10B981" // Green
        case .updateStatus: return "3B82F6" // Blue
        case .updatePriority: return "F59E0B" // Amber
        case .updateProgress: return "8B5CF6" // Purple
        case .updateTitle, .updateDescription: return "6B7280" // Gray
        case .updateDueDate: return "EC4899" // Pink
        case .addAssignee: return "10B981" // Green
        case .removeAssignee: return "EF4444" // Red
        case .addComment: return "06B6D4" // Cyan
        case .deleteComment: return "EF4444" // Red
        case .addEvidence: return "10B981" // Green
        case .deleteEvidence: return "EF4444" // Red
        case .unknown: return "6B7280" // Gray
        }
    }
}

struct TaskActivityLog: Codable, Identifiable {
    let id: String
    let taskId: String
    let userId: String
    let action: TaskActivityAction
    let field: String?
    let previousValue: String?
    let newValue: String?
    let metadata: ActivityLogMetadata?
    let createdAt: Date
    let user: TaskUser?
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: createdAt)
    }
    
    var changeDescription: String {
        switch action {
        case .create:
            return "Created this action item"
        case .updateStatus:
            if let prev = previousValue, let new = newValue {
                return "Changed status from \(formatStatus(prev)) to \(formatStatus(new))"
            }
            return "Updated status"
        case .updatePriority:
            if let prev = previousValue, let new = newValue {
                return "Changed priority from \(formatPriority(prev)) to \(formatPriority(new))"
            }
            return "Updated priority"
        case .updateProgress:
            if let prev = previousValue, let new = newValue {
                return "Updated progress from \(prev)% to \(new)%"
            }
            return "Updated progress"
        case .updateTitle:
            return "Updated the title"
        case .updateDescription:
            return "Updated the description"
        case .updateDueDate:
            if let new = newValue {
                return "Set due date to \(formatDate(new))"
            } else if previousValue != nil {
                return "Removed due date"
            }
            return "Updated due date"
        case .addAssignee:
            if let new = newValue {
                return "Added assignee: \(new)"
            }
            return "Added an assignee"
        case .removeAssignee:
            if let prev = previousValue {
                return "Removed assignee: \(prev)"
            }
            return "Removed an assignee"
        case .addComment:
            return "Added a comment"
        case .deleteComment:
            return "Deleted a comment"
        case .addEvidence:
            if let new = newValue {
                return "Added evidence: \(new)"
            }
            return "Added evidence"
        case .deleteEvidence:
            if let prev = previousValue {
                return "Deleted evidence: \(prev)"
            }
            return "Deleted evidence"
        case .unknown:
            return "Made changes"
        }
    }
    
    private func formatStatus(_ value: String) -> String {
        switch value.uppercased() {
        case "PENDING": return "Pending"
        case "IN_PROGRESS": return "In Progress"
        case "COMPLETED": return "Completed"
        case "CANCELLED": return "Cancelled"
        default: return value
        }
    }
    
    private func formatPriority(_ value: String) -> String {
        switch value.uppercased() {
        case "LOW": return "Low"
        case "MEDIUM": return "Medium"
        case "HIGH": return "High"
        case "URGENT": return "Urgent"
        default: return value
        }
    }
    
    private func formatDate(_ value: String) -> String {
        // Try to parse ISO date and format nicely
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: value) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: value) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        
        return value
    }
}

struct ActivityLogMetadata: Codable {
    // Can be extended based on the actual metadata structure
    let additionalInfo: String?
    
    init(from decoder: Decoder) throws {
        // Handle flexible JSON metadata
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: String].self) {
            additionalInfo = dict["additionalInfo"]
        } else {
            additionalInfo = nil
        }
    }
}

struct TaskActivityLogsResponse: Codable {
    let success: Bool
    let logs: [TaskActivityLog]?
    let count: Int?
    let error: String?
}

// MARK: - JSON Decoding Strategy
extension TaskItem {
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
