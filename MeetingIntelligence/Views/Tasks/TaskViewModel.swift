//
//  TaskViewModel.swift
//  MeetingIntelligence
//
//  Phase 2.2 - Task List ViewModel with Action Items support
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var tasks: [TaskItem] = []
    @Published var selectedTask: TaskItem?
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isExtracting: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedFilter: TaskFilter = .all
    
    // Organization users for assignment
    @Published var organizationUsers: [OrganizationUser] = []
    @Published var isLoadingUsers: Bool = false
    
    // MARK: - User Context
    private var userId: String?
    private var organizationId: String?
    
    // Expose organizationId for views
    var currentOrganizationId: String? { organizationId }
    var currentUserId: String? { userId }
    
    // MARK: - Computed Properties
    var filteredTasks: [TaskItem] {
        switch selectedFilter {
        case .all:
            return tasks
        case .pending:
            return tasks.filter { $0.status == .pending }
        case .inProgress:
            return tasks.filter { $0.status == .inProgress }
        case .completed:
            return tasks.filter { $0.status == .completed }
        case .overdue:
            return tasks.filter { $0.isOverdue }
        }
    }
    
    var hasNoTasks: Bool {
        tasks.isEmpty && !isLoading
    }
    
    var taskCountByStatus: [TaskStatus: Int] {
        var counts: [TaskStatus: Int] = [:]
        for status in TaskStatus.allCases {
            counts[status] = tasks.filter { $0.status == status }.count
        }
        return counts
    }
    
    // MARK: - Initialization
    func configure(userId: String, organizationId: String?) {
        self.userId = userId
        self.organizationId = organizationId
    }
    
    // MARK: - Error Handling Helper
    
    /// Handles errors and sets errorMessage only for non-cancelled requests
    /// Cancelled requests (code -999) are ignored as they're typically from view transitions or duplicate refreshes
    private func handleError(_ error: Error, context: String) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            print("ℹ️ \(context): Request cancelled - ignoring")
        } else {
            errorMessage = error.localizedDescription
            print("❌ \(context): \(error)")
        }
    }
    
    // MARK: - API Methods
    
    /// Fetch tasks from the API
    func fetchTasks() async {
        guard let userId = userId else {
            errorMessage = "User not configured"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.getTasks(userId: userId)
            
            if response.success {
                tasks = response.tasks ?? []
                print("✅ Fetched \(tasks.count) tasks")
            } else {
                errorMessage = response.error ?? "Failed to fetch tasks"
            }
        } catch {
            handleError(error, context: "Error fetching tasks")
        }
        
        isLoading = false
    }
    
    /// Fetch tasks for a specific meeting
    func fetchTasksForMeeting(meetingId: String) async {
        guard let userId = userId else {
            errorMessage = "User not configured"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.getTasks(userId: userId, meetingId: meetingId)
            
            if response.success {
                tasks = response.tasks ?? []
                print("✅ Fetched \(tasks.count) tasks for meeting")
            } else {
                errorMessage = response.error ?? "Failed to fetch meeting tasks"
            }
        } catch {
            handleError(error, context: "Error fetching meeting tasks")
        }
        
        isLoading = false
    }
    
    /// Refresh tasks (for pull-to-refresh)
    func refreshTasks() async {
        isRefreshing = true
        await fetchTasks()
        isRefreshing = false
    }
    
    /// Create a new task
    func createTask(
        title: String,
        description: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        assigneeId: String? = nil,
        meetingId: String? = nil,
        sourceText: String? = nil,
        isAiExtracted: Bool = false
    ) async -> TaskItem? {
        guard let userId = userId, let organizationId = organizationId else {
            errorMessage = "User not configured"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        let request = CreateTaskRequest(
            title: title,
            description: description,
            dueDate: dueDate?.ISO8601Format(),
            priority: priority.rawValue,
            assigneeId: assigneeId,
            ownerId: userId,
            organizationId: organizationId,
            facilityId: nil,
            meetingId: meetingId,
            sourceText: sourceText,
            isAiExtracted: isAiExtracted
        )
        
        do {
            let response = try await APIService.shared.createTask(request)
            
            if response.success, let newTask = response.task {
                tasks.insert(newTask, at: 0)
                print("✅ Created task: \(newTask.title)")
                isLoading = false
                return newTask
            } else {
                errorMessage = response.error ?? "Failed to create task"
            }
        } catch {
            handleError(error, context: "Error creating task")
        }
        
        isLoading = false
        return nil
    }
    
    /// Update task status
    func updateTaskStatus(taskId: String, status: TaskStatus) async -> Bool {
        errorMessage = nil
        
        let update = UpdateTaskRequest(
            title: nil,
            description: nil,
            status: status.rawValue,
            priority: nil,
            dueDate: nil,
            assigneeId: nil,
            progress: status == .completed ? 100 : nil
        )
        
        do {
            let response = try await APIService.shared.updateTask(id: taskId, update: update)
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                if selectedTask?.id == taskId {
                    selectedTask = updatedTask
                }
                print("✅ Updated task status to: \(status.displayName)")
                return true
            } else {
                errorMessage = response.error ?? "Failed to update task"
            }
        } catch {
            handleError(error, context: "Error updating task")
        }
        
        return false
    }
    
    /// Update task details
    func updateTask(
        taskId: String,
        title: String? = nil,
        description: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        assigneeId: String? = nil,
        progress: Int? = nil
    ) async -> Bool {
        errorMessage = nil
        
        let update = UpdateTaskRequest(
            title: title,
            description: description,
            status: status?.rawValue,
            priority: priority?.rawValue,
            dueDate: dueDate?.ISO8601Format(),
            assigneeId: assigneeId,
            progress: progress
        )
        
        do {
            let response = try await APIService.shared.updateTask(id: taskId, update: update)
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                if selectedTask?.id == taskId {
                    selectedTask = updatedTask
                }
                print("✅ Updated task: \(updatedTask.title)")
                return true
            } else {
                errorMessage = response.error ?? "Failed to update task"
            }
        } catch {
            handleError(error, context: "Error updating task")
        }
        
        return false
    }
    
    /// Update task progress
    func updateTaskProgress(taskId: String, progress: Int) async -> Bool {
        return await updateTask(taskId: taskId, progress: min(100, max(0, progress)))
    }
    
    /// Delete a task
    func deleteTask(taskId: String) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.deleteTask(id: taskId)
            
            if response.success {
                tasks.removeAll { $0.id == taskId }
                if selectedTask?.id == taskId {
                    selectedTask = nil
                }
                print("✅ Deleted task")
                return true
            } else {
                errorMessage = response.error ?? "Failed to delete task"
            }
        } catch {
            handleError(error, context: "Error deleting task")
        }
        
        return false
    }
    
    // MARK: - AI Extraction
    
    /// Extract action items from a transcript using AI
    func extractActionItems(meetingId: String, transcript: String) async -> [TaskItem]? {
        guard let userId = userId, let organizationId = organizationId else {
            errorMessage = "User not configured"
            return nil
        }
        
        isExtracting = true
        errorMessage = nil
        
        let request = ExtractActionItemsRequest(
            meetingId: meetingId,
            transcript: transcript,
            ownerId: userId,
            organizationId: organizationId,
            facilityId: nil
        )
        
        do {
            let response = try await APIService.shared.extractActionItems(request)
            
            if response.success, let extractedTasks = response.tasks {
                // Add extracted tasks to our list
                tasks.insert(contentsOf: extractedTasks, at: 0)
                successMessage = "Extracted \(extractedTasks.count) action items"
                print("✅ Extracted \(extractedTasks.count) action items")
                isExtracting = false
                return extractedTasks
            } else {
                errorMessage = response.error ?? "Failed to extract action items"
            }
        } catch {
            handleError(error, context: "Error extracting action items")
        }
        
        isExtracting = false
        return nil
    }
    
    // MARK: - Comments
    
    /// Add a comment to a task
    func addComment(taskId: String, content: String, parentId: String? = nil) async -> TaskComment? {
        guard let userId = userId else {
            errorMessage = "User not configured"
            return nil
        }
        
        let request = CreateCommentRequest(
            content: content,
            authorId: userId,
            parentId: parentId
        )
        
        do {
            let response = try await APIService.shared.addTaskComment(taskId: taskId, request: request)
            
            if response.success, let comment = response.comment {
                // Refresh the selected task to get updated comments
                await fetchTaskDetails(taskId: taskId)
                print("✅ Added comment to task")
                return comment
            } else {
                errorMessage = response.error ?? "Failed to add comment"
            }
        } catch {
            handleError(error, context: "Error adding comment")
        }
        
        return nil
    }
    
    /// Delete a comment
    func deleteComment(commentId: String, taskId: String) async -> Bool {
        do {
            let response = try await APIService.shared.deleteTaskComment(commentId: commentId)
            
            if response.success {
                // Refresh the selected task to get updated comments
                await fetchTaskDetails(taskId: taskId)
                print("✅ Deleted comment")
                return true
            } else {
                errorMessage = response.error ?? "Failed to delete comment"
            }
        } catch {
            handleError(error, context: "Error deleting comment")
        }
        
        return false
    }
    
    // MARK: - Evidence
    
    /// Add evidence to a task
    func addEvidence(
        taskId: String,
        title: String,
        description: String? = nil,
        fileUrl: String? = nil,
        fileType: String? = nil,
        fileName: String? = nil
    ) async -> TaskEvidence? {
        guard let userId = userId else {
            errorMessage = "User not configured"
            return nil
        }
        
        let request = CreateEvidenceRequest(
            title: title,
            description: description,
            fileUrl: fileUrl,
            fileType: fileType,
            fileName: fileName,
            uploaderId: userId
        )
        
        do {
            let response = try await APIService.shared.addTaskEvidence(taskId: taskId, request: request)
            
            if response.success, let evidence = response.evidence {
                // Refresh the selected task to get updated evidence
                await fetchTaskDetails(taskId: taskId)
                print("✅ Added evidence to task")
                return evidence
            } else {
                errorMessage = response.error ?? "Failed to add evidence"
            }
        } catch {
            handleError(error, context: "Error adding evidence")
        }
        
        return nil
    }
    
    /// Delete evidence
    func deleteEvidence(evidenceId: String, taskId: String) async -> Bool {
        do {
            let response = try await APIService.shared.deleteTaskEvidence(evidenceId: evidenceId)
            
            if response.success {
                // Refresh the selected task to get updated evidence
                await fetchTaskDetails(taskId: taskId)
                print("✅ Deleted evidence")
                return true
            } else {
                errorMessage = response.error ?? "Failed to delete evidence"
            }
        } catch {
            handleError(error, context: "Error deleting evidence")
        }
        
        return false
    }
    
    // MARK: - Task Details
    
    /// Fetch detailed task info including all comments and evidence
    func fetchTaskDetails(taskId: String) async {
        do {
            let response = try await APIService.shared.getTask(id: taskId)
            
            if response.success, let task = response.task {
                selectedTask = task
                // Also update in the main list
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = task
                }
                print("✅ Fetched task details")
            } else {
                errorMessage = response.error ?? "Failed to fetch task details"
            }
        } catch {
            handleError(error, context: "Error fetching task details")
        }
    }
    
    // MARK: - Organization Users Methods
    
    /// Fetch users in the organization for assignment
    func fetchOrganizationUsers() async {
        guard let organizationId = organizationId else {
            print("⚠️ Organization ID not configured")
            return
        }
        
        isLoadingUsers = true
        
        do {
            let response = try await APIService.shared.getOrganizationUsers(organizationId: organizationId)
            
            if response.success {
                organizationUsers = response.users ?? []
                print("✅ Fetched \(organizationUsers.count) organization users")
            } else {
                print("❌ Failed to fetch users: \(response.error ?? "Unknown error")")
            }
        } catch {
            print("❌ Error fetching organization users: \(error)")
        }
        
        isLoadingUsers = false
    }
    
    // MARK: - Assignee Management Methods
    
    /// Add assignees to a task
    func addAssignees(taskId: String, userIds: [String]) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.addTaskAssignees(
                taskId: taskId,
                userIds: userIds,
                assignedBy: userId
            )
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                if selectedTask?.id == taskId {
                    selectedTask = updatedTask
                }
                print("✅ Added \(userIds.count) assignees to task")
                return true
            } else {
                errorMessage = response.error ?? "Failed to add assignees"
            }
        } catch {
            handleError(error, context: "Error adding assignees")
        }
        
        return false
    }
    
    /// Remove an assignee from a task
    func removeAssignee(taskId: String, userId: String) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.removeTaskAssignee(taskId: taskId, userId: userId)
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                if selectedTask?.id == taskId {
                    selectedTask = updatedTask
                }
                print("✅ Removed assignee from task")
                return true
            } else {
                errorMessage = response.error ?? "Failed to remove assignee"
            }
        } catch {
            handleError(error, context: "Error removing assignee")
        }
        
        return false
    }
    
    /// Update all assignees for a task (replace)
    func updateAssignees(taskId: String, userIds: [String]) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.updateTaskAssignees(
                taskId: taskId,
                userIds: userIds,
                assignedBy: userId
            )
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                if selectedTask?.id == taskId {
                    selectedTask = updatedTask
                }
                print("✅ Updated assignees for task")
                return true
            } else {
                errorMessage = response.error ?? "Failed to update assignees"
            }
        } catch {
            handleError(error, context: "Error updating assignees")
        }
        
        return false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccess() {
        successMessage = nil
    }
}

// MARK: - Task Filter
enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case overdue = "Overdue"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .pending: return "circle"
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.circle.fill"
        }
    }
}
