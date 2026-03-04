//
//  TaskListView.swift
//  MeetingIntelligence
//
//  Action Items - Grouped by Meeting View
//

import SwiftUI

// MARK: - Meeting Group Model
struct MeetingGroup: Identifiable {
    let id: String
    let title: String
    let meetingType: String
    let meetingDate: String?
    let tasks: [TaskItem]
    
    /// Earliest createdAt among tasks — represents when action items were extracted/created
    var createdDate: Date? {
        tasks.compactMap { $0.createdAt }.min()
    }
    
    var formattedCreatedDate: String? {
        guard let date = createdDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    var pendingCount: Int {
        tasks.filter { $0.status == .pending }.count
    }
    
    var inProgressCount: Int {
        tasks.filter { $0.status == .inProgress }.count
    }
    
    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }
    
    var overdueCount: Int {
        tasks.filter { $0.isOverdue }.count
    }
}

struct TaskListView: View {
    @StateObject private var viewModel = TaskViewModel()
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTask: TaskItem?
    @State private var showAssignedItems = false
    @State private var showCreateItem = false
    @State private var expandedGroups: Set<String> = []
    @State private var showErrorAlert = false
    @State private var groupToDelete: MeetingGroup?
    @State private var showDeleteGroupAlert = false
    @State private var isDeletingGroup = false
    
    // Multi-select mode
    @State private var isSelectionMode = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var showDeleteSelectedAlert = false
    @State private var isDeletingSelected = false
    
    var onMenuTap: (() -> Void)?
    
    // Group tasks by their meeting title so users know which meeting each action item came from.
    // Tasks without a meeting go into "Standalone Items".
    private var meetingGroups: [MeetingGroup] {
        // Separate meeting tasks from standalone tasks
        let meetingTasks = viewModel.tasks.filter { $0.meetingId != nil }
        let standaloneTasks = viewModel.tasks.filter { $0.meetingId == nil }
        
        // Group meeting tasks by their actual meeting title
        let groupedByMeeting = Dictionary(grouping: meetingTasks) { task -> String in
            task.meeting?.id ?? task.meetingId ?? "unknown"
        }
        
        var groups: [MeetingGroup] = groupedByMeeting.compactMap { (meetingId, tasks) -> MeetingGroup? in
            guard !tasks.isEmpty else { return nil }
            let meetingTitle = tasks.first?.meeting?.displayTitle ?? "Meeting"
            let meetingType = tasks.first?.meeting?.formattedType ?? "Meeting"
            let meetingDate = tasks.first?.meeting?.formattedDate
            
            return MeetingGroup(
                id: meetingId,
                title: meetingTitle,
                meetingType: meetingType,
                meetingDate: meetingDate,
                tasks: tasks.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            )
        }.sorted {
            // Sort meetings by most recent task first
            let date0 = $0.tasks.first?.createdAt ?? .distantPast
            let date1 = $1.tasks.first?.createdAt ?? .distantPast
            return date0 > date1
        }
        
        // Add standalone group at the end if any
        if !standaloneTasks.isEmpty {
            groups.append(MeetingGroup(
                id: "standalone",
                title: "Standalone Items",
                meetingType: "Standalone",
                meetingDate: nil,
                tasks: standaloneTasks.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            ))
        }
        
        return groups
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content
                    if viewModel.isLoading && viewModel.tasks.isEmpty {
                        LoadingStateView()
                    } else if viewModel.hasNoTasks {
                        ActionItemsEmptyStateView()
                    } else {
                        groupedActionItemsList
                    }
                }
                
                // Floating + Button (hidden in selection mode)
                if !isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showCreateItem = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(AppGradients.primary)
                                            .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                
                // Bottom bar in selection mode
                if isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSelectionMode = false
                                    selectedTaskIds.removeAll()
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppColors.surface)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            }
                            
                            Spacer()
                            
                            if !selectedTaskIds.isEmpty {
                                Text("\(selectedTaskIds.count) selected")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if !selectedTaskIds.isEmpty {
                                Button {
                                    showDeleteSelectedAlert = true
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(Color.red)
                                                .shadow(color: Color.red.opacity(0.4), radius: 6, y: 2)
                                        )
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            AppColors.surface
                                .shadow(color: Color.black.opacity(0.08), radius: 8, y: -2)
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Owned")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onMenuTap?()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        // Select All button
                        Button {
                            let allTaskIds = Set(meetingGroups.flatMap { $0.tasks.map { $0.id } })
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTaskIds == allTaskIds {
                                    selectedTaskIds.removeAll()
                                } else {
                                    selectedTaskIds = allTaskIds
                                }
                            }
                        } label: {
                            let allTaskIds = Set(meetingGroups.flatMap { $0.tasks.map { $0.id } })
                            Text(selectedTaskIds == allTaskIds ? "Deselect All" : "Select All")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                    } else {
                        Menu {
                            Button {
                                showAssignedItems = true
                            } label: {
                                Label("Assigned Action Items", systemImage: "person.badge.clock")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                if let latestTask = viewModel.tasks.first(where: { $0.id == task.id }) {
                    ActionItemDetailView(
                        task: latestTask,
                        viewModel: viewModel,
                        onUpdate: {
                            Task {
                                await viewModel.refreshTasks()
                            }
                        }
                    )
                } else {
                    ActionItemDetailView(
                        task: task,
                        viewModel: viewModel,
                        onUpdate: {
                            Task {
                                await viewModel.refreshTasks()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showAssignedItems) {
                AssignedActionItemsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateItem) {
                CreateActionItemView(
                    viewModel: viewModel,
                    meetingGroups: meetingGroups,
                    onCreated: { newTask in
                        // Expand the group the new task belongs to
                        let groupId = newTask.meeting?.id ?? newTask.meetingId ?? "standalone"
                        expandedGroups.insert(groupId)
                    }
                )
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Delete Selected Action Items", isPresented: $showDeleteSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete \(selectedTaskIds.count) Item\(selectedTaskIds.count == 1 ? "" : "s")", role: .destructive) {
                    isDeletingSelected = true
                    Task {
                        for taskId in selectedTaskIds {
                            let _ = await viewModel.deleteTask(taskId: taskId)
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTaskIds.removeAll()
                            isSelectionMode = false
                            isDeletingSelected = false
                        }
                    }
                }
            } message: {
                Text("⚠️ This will permanently delete \(selectedTaskIds.count) action item\(selectedTaskIds.count == 1 ? "" : "s").\n\nThis action cannot be reversed.")
            }
            .overlay {
                if isDeletingSelected {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                            Text("Deleting items...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .task {
                // Configure view model with actual logged-in user
                if let userId = appState.currentUserID {
                    viewModel.configure(userId: userId, organizationId: appState.organizationId)
                    await viewModel.fetchTasks()
                    // Expand all groups by default
                    expandedGroups = Set(meetingGroups.map { $0.id })
                } else {
                    print("⚠️ TaskListView: No user ID available")
                }
            }
        }
    }
    
    // MARK: - Grouped Action Items List
    private var groupedActionItemsList: some View {
        List {
            ForEach(meetingGroups) { group in
                MeetingGroupCard(
                    group: group,
                    isExpanded: expandedGroups.contains(group.id),
                    isSelectionMode: isSelectionMode,
                    selectedTaskIds: $selectedTaskIds,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedGroups.contains(group.id) {
                                expandedGroups.remove(group.id)
                            } else {
                                expandedGroups.insert(group.id)
                            }
                        }
                    },
                    onTaskTap: { task in
                        if isSelectionMode {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedTaskIds.contains(task.id) {
                                    selectedTaskIds.remove(task.id)
                                } else {
                                    selectedTaskIds.insert(task.id)
                                }
                            }
                        } else {
                            selectedTask = task
                        }
                    },
                    onLongPress: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSelectionMode = true
                        }
                    }
                )
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        groupToDelete = group
                        showDeleteGroupAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                    .tint(.red)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .refreshable {
            await viewModel.refreshTasks()
        }
        .alert("Delete Action Item Group", isPresented: $showDeleteGroupAlert) {
            Button("Cancel", role: .cancel) {
                groupToDelete = nil
            }
            Button("Delete All", role: .destructive) {
                if let group = groupToDelete {
                    isDeletingGroup = true
                    Task {
                        let _ = await viewModel.deleteTaskGroup(group: group)
                        isDeletingGroup = false
                        groupToDelete = nil
                    }
                }
            }
        } message: {
            if let group = groupToDelete {
                Text("⚠️ This will permanently delete \"\(group.title)\" and all \(group.tasks.count) action item\(group.tasks.count == 1 ? "" : "s") within it.\n\nThis action cannot be reversed.")
            }
        }
        .overlay {
            if isDeletingGroup {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Deleting...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

// MARK: - Meeting Group Card
struct MeetingGroupCard: View {
    let group: MeetingGroup
    let isExpanded: Bool
    var isSelectionMode: Bool = false
    @Binding var selectedTaskIds: Set<String>
    let onToggle: () -> Void
    let onTaskTap: (TaskItem) -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Meeting Header
            Button {
                onToggle()
            } label: {
                HStack(spacing: 12) {
                    // Expand/Collapse Icon
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 20)
                    
                    // Group Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        if let dateStr = group.formattedCreatedDate {
                            Text(dateStr)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status Badges
                    HStack(spacing: 6) {
                        if group.overdueCount > 0 {
                            TaskGroupStatusBadge(count: group.overdueCount, color: AppColors.error)
                        }
                        if group.inProgressCount > 0 {
                            TaskGroupStatusBadge(count: group.inProgressCount, color: Color.blue)
                        }
                        if group.pendingCount > 0 {
                            TaskGroupStatusBadge(count: group.pendingCount, color: AppColors.textSecondary)
                        }
                    }
                    
                    // Task Count
                    Text("\(group.tasks.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
                .padding(16)
                .background(AppColors.surface)
            }
            .buttonStyle(.plain)
            
            // Tasks List (when expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.tasks) { task in
                        GroupedTaskRow(
                            task: task,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedTaskIds.contains(task.id),
                            onTap: { onTaskTap(task) },
                            onLongPress: { onLongPress?() }
                        )
                        
                        if task.id != group.tasks.last?.id {
                            Divider()
                                .padding(.leading, isSelectionMode ? 84 : 52)
                        }
                    }
                }
                .background(AppColors.surface.opacity(0.5))
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceSecondary, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Task Group Status Badge (local)
private struct TaskGroupStatusBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Grouped Task Row
struct GroupedTaskRow: View {
    let task: TaskItem
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Checkbox (selection mode)
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.textTertiary)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Status Icon
                Image(systemName: task.status.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: task.status.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: task.status.color).opacity(0.15))
                    .clipShape(Circle())
                
                // Task Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(task.status == .completed ? AppColors.textSecondary : AppColors.textPrimary)
                        .strikethrough(task.status == .completed)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // Status Badge
                        Text(task.status.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: task.status.color))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: task.status.color).opacity(0.15))
                            .clipShape(Capsule())
                        
                        // Priority Badge
                        Text(task.priority.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: task.priority.color))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: task.priority.color).opacity(0.15))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Due Date or Overdue
                        if task.isOverdue {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(task.dueDateFormatted ?? "Overdue")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(AppColors.error)
                        } else if let dueFormatted = task.dueDateFormatted {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(dueFormatted)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                // Chevron (hidden in selection mode)
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? AppColors.primary.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress?()
                }
        )
    }
}

// MARK: - Assigned Action Items View
struct AssignedActionItemsView: View {
    @ObservedObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var assignedTasks: [TaskItem] = []
    @State private var isLoading = true
    @State private var selectedTask: TaskItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading assigned items...")
                } else if assignedTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.clock")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No Assigned Action Items")
                            .font(.headline)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Action items assigned to you will appear here")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(assignedTasks) { item in
                                OwnedActionItemCard(item: item) {
                                    selectedTask = item
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Assigned to Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                ActionItemDetailView(
                    task: task,
                    viewModel: viewModel,
                    isReadOnly: true,
                    onUpdate: {
                        Task {
                            await fetchAssignedTasks()
                        }
                    }
                )
            }
            .task {
                await fetchAssignedTasks()
            }
        }
    }
    
    private func fetchAssignedTasks() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getTasks(
                userId: viewModel.currentUserId ?? "",
                filter: "assigned"
            )
            if response.success {
                assignedTasks = response.tasks ?? []
            }
        } catch {
            print("Error fetching assigned tasks: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Owned Action Item Card
struct OwnedActionItemCard: View {
    let item: TaskItem
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status icon and title
                HStack(alignment: .top, spacing: 12) {
                    // Status icon
                    Image(systemName: item.status.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: item.status.color))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: item.status.color).opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(item.status == .completed ? AppColors.textSecondary : AppColors.textPrimary)
                            .strikethrough(item.status == .completed)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Status and priority badges
                        HStack(spacing: 8) {
                            Text(item.status.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: item.status.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: item.status.color).opacity(0.15))
                                .clipShape(Capsule())
                            
                            Text(item.priority.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: item.priority.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: item.priority.color).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // Progress bar (if not completed and progress > 0)
                if item.progressValue > 0 && item.status != .completed {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(item.progressValue)%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(progressGradient(for: item.progressValue))
                                    .frame(width: geometry.size.width * CGFloat(item.progressValue) / 100, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                
                // Due date or assignee info
                HStack(spacing: 16) {
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: item.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                                .font(.system(size: 12))
                            Text(item.dueDateFormatted ?? "")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(item.isOverdue ? AppColors.error : AppColors.textSecondary)
                    }
                    
                    if let assignee = item.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                            Text(assignee.fullName)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    private func progressGradient(for value: Int) -> LinearGradient {
        let color: Color
        switch value {
        case 0..<20:
            color = .red
        case 20..<50:
            color = .orange
        case 50..<80:
            color = .green
        default:
            color = .blue
        }
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Loading State
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading action items...")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State for Action Items
struct ActionItemsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Action Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Action items will appear here when extracted from your meeting transcripts")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
