//
//  TaskListView.swift
//  MeetingIntelligence
//
//  Phase 2.2 - Task List Screen
//

import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskViewModel()
    @EnvironmentObject var appState: AppState
    
    @State private var showingCreateTask = false
    @State private var selectedTask: Task?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Tabs
                    FilterTabsView(selectedFilter: $viewModel.selectedFilter)
                    
                    // Content
                    if viewModel.isLoading && viewModel.tasks.isEmpty {
                        LoadingStateView()
                    } else if viewModel.hasNoTasks {
                        EmptyStateView(onCreateTask: { showingCreateTask = true })
                    } else if viewModel.filteredTasks.isEmpty {
                        NoFilterResultsView(filter: viewModel.selectedFilter)
                    } else {
                        TaskListContent(
                            tasks: viewModel.filteredTasks,
                            onTaskTap: { task in selectedTask = task },
                            onStatusChange: { task, status in
                                Task {
                                    await viewModel.updateTaskStatus(taskId: task.id, status: status)
                                }
                            },
                            onDelete: { task in
                                Task {
                                    await viewModel.deleteTask(taskId: task.id)
                                }
                            },
                            onRefresh: {
                                await viewModel.refreshTasks()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(task: task, viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                // Configure with user data from AppState
                if let userId = appState.currentUserID {
                    let orgId = appState.organizationId ?? "a0f1ca04-ee78-439b-94df-95c4803ffbf7" // Fallback for testing
                    viewModel.configure(userId: userId, organizationId: orgId)
                    await viewModel.fetchTasks()
                }
            }
        }
    }
}

// MARK: - Filter Tabs
struct FilterTabsView: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task List Content
struct TaskListContent: View {
    let tasks: [Task]
    let onTaskTap: (Task) -> Void
    let onStatusChange: (Task, TaskStatus) -> Void
    let onDelete: (Task) -> Void
    let onRefresh: () async -> Void
    
    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRowView(task: task) { newStatus in
                    onStatusChange(task, newStatus)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .onTapGesture {
                    onTaskTap(task)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete(task)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Loading State
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading tasks...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let onCreateTask: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Tasks Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first task to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                onCreateTask()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Task")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - No Filter Results
struct NoFilterResultsView: View {
    let filter: TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: filter.icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No \(filter.rawValue.lowercased()) tasks")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Task Sheet
struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(3600 * 24) // Tomorrow
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .font(.body)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                }
                
                Section {
                    Toggle("Set Due Date", isOn: $hasDueDate.animation())
                    
                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
        .interactiveDismissDisabled(isCreating)
    }
    
    private func createTask() {
        isCreating = true
        
        Task {
            let success = await viewModel.createTask(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil
            )
            
            isCreating = false
            
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Task Detail Sheet
struct TaskDetailSheet: View {
    let task: Task
    @ObservedObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            StatusBadge(status: task.status)
                            Spacer()
                            PriorityBadge(priority: task.priority)
                        }
                        
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = task.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Details
                    VStack(spacing: 0) {
                        if let dueDate = task.dueDateFormatted {
                            DetailRow(
                                icon: "calendar",
                                title: "Due Date",
                                value: dueDate,
                                valueColor: task.isOverdue ? .red : .primary
                            )
                            Divider()
                        }
                        
                        if let owner = task.owner {
                            DetailRow(
                                icon: "person.fill",
                                title: "Owner",
                                value: owner.fullName
                            )
                            Divider()
                        }
                        
                        if let assignee = task.assignee {
                            DetailRow(
                                icon: "person.badge.clock",
                                title: "Assigned To",
                                value: assignee.fullName
                            )
                            Divider()
                        }
                        
                        DetailRow(
                            icon: "clock",
                            title: "Created",
                            value: task.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Quick Actions
                    VStack(spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                if status != task.status {
                                    QuickActionButton(
                                        title: status.displayName,
                                        icon: status.icon,
                                        color: Color(hex: status.color)
                                    ) {
                                        Task {
                                            let success = await viewModel.updateTaskStatus(taskId: task.id, status: status)
                                            if success {
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(valueColor)
        }
        .padding()
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#if DEBUG
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
            .environmentObject(AppState())
    }
}
#endif
