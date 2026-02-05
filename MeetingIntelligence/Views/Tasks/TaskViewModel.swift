//
//  TaskViewModel.swift
//  MeetingIntelligence
//
//  Phase 2.2 - Task List ViewModel
//

import Foundation
import SwiftUI

@MainActor
class TaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var tasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: TaskFilter = .all
    
    // MARK: - User Context
    private var userId: String?
    private var organizationId: String?
    
    // MARK: - Computed Properties
    var filteredTasks: [Task] {
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
            errorMessage = error.localizedDescription
            print("❌ Error fetching tasks: \(error)")
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
        assigneeId: String? = nil
    ) async -> Bool {
        guard let userId = userId, let organizationId = organizationId else {
            errorMessage = "User not configured"
            return false
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
            meetingId: nil
        )
        
        do {
            let response = try await APIService.shared.createTask(request)
            
            if response.success, let newTask = response.task {
                tasks.insert(newTask, at: 0)
                print("✅ Created task: \(newTask.title)")
                isLoading = false
                return true
            } else {
                errorMessage = response.error ?? "Failed to create task"
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error creating task: \(error)")
        }
        
        isLoading = false
        return false
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
            assigneeId: nil
        )
        
        do {
            let response = try await APIService.shared.updateTask(id: taskId, update: update)
            
            if response.success, let updatedTask = response.task {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index] = updatedTask
                }
                print("✅ Updated task status to: \(status.displayName)")
                return true
            } else {
                errorMessage = response.error ?? "Failed to update task"
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error updating task: \(error)")
        }
        
        return false
    }
    
    /// Delete a task
    func deleteTask(taskId: String) async -> Bool {
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.deleteTask(id: taskId)
            
            if response.success {
                tasks.removeAll { $0.id == taskId }
                print("✅ Deleted task")
                return true
            } else {
                errorMessage = response.error ?? "Failed to delete task"
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error deleting task: \(error)")
        }
        
        return false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
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
