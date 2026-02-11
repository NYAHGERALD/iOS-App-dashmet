//
//  TaskListView.swift
//  MeetingIntelligence
//
//  Action Items grouped by Meeting
//

import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskViewModel()
    @StateObject private var meetingViewModel = MeetingViewModel()
    @EnvironmentObject var appState: AppState
    
    @State private var selectedMeetingGroup: MeetingActionItemGroup?
    
    // Group tasks by meeting
    var meetingGroups: [MeetingActionItemGroup] {
        let grouped = Dictionary(grouping: viewModel.filteredTasks) { $0.meetingId ?? "unknown" }
        
        return grouped.map { meetingId, tasks in
            let meeting = meetingViewModel.meetings.first { $0.id == meetingId }
            return MeetingActionItemGroup(
                meetingId: meetingId,
                meetingTitle: meeting?.displayTitle ?? "Meeting",
                meetingDate: meeting?.createdAt,
                actionItems: tasks
            )
        }
        .sorted { ($0.meetingDate ?? Date.distantPast) > ($1.meetingDate ?? Date.distantPast) }
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
                    } else if meetingGroups.isEmpty {
                        NoFilterResultsView(filter: viewModel.selectedFilter)
                    } else {
                        meetingGroupsList
                    }
                }
            }
            .navigationTitle("Action Items")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    FilterMenuButton(selectedFilter: $viewModel.selectedFilter)
                }
            }
            .navigationDestination(item: $selectedMeetingGroup) { group in
                MeetingActionItemsListView(
                    meetingId: group.meetingId,
                    meetingTitle: group.meetingTitle,
                    viewModel: viewModel,
                    onRefresh: {
                        await viewModel.refreshTasks()
                    }
                )
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                let orgId = appState.organizationId ?? "a0f1ca04-ee78-439b-94df-95c4803ffbf7"
                viewModel.configure(userId: "84f500d4-eb06-456f-8972-f706d89a5828", organizationId: orgId)
                meetingViewModel.configure(userId: "84f500d4-eb06-456f-8972-f706d89a5828", organizationId: orgId)
                
                await viewModel.fetchTasks()
                await meetingViewModel.fetchMeetings()
            }
        }
    }
    
    // MARK: - Meeting Groups List
    private var meetingGroupsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(meetingGroups) { group in
                    MeetingGroupCard(group: group)
                        .onTapGesture {
                            selectedMeetingGroup = group
                        }
                }
            }
            .padding(16)
        }
        .refreshable {
            await viewModel.refreshTasks()
            await meetingViewModel.fetchMeetings()
        }
    }
}

// MARK: - Meeting Action Item Group Model
struct MeetingActionItemGroup: Identifiable, Hashable {
    let id = UUID()
    let meetingId: String
    let meetingTitle: String
    let meetingDate: Date?
    let actionItems: [TaskItem]
    
    var itemCount: Int { actionItems.count }
    var pendingCount: Int { actionItems.filter { $0.status == .pending }.count }
    var inProgressCount: Int { actionItems.filter { $0.status == .inProgress }.count }
    var completedCount: Int { actionItems.filter { $0.status == .completed }.count }
    var overdueCount: Int { actionItems.filter { $0.isOverdue }.count }
    
    static func == (lhs: MeetingActionItemGroup, rhs: MeetingActionItemGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Meeting Group Card
struct MeetingGroupCard: View {
    let group: MeetingActionItemGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Meeting icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.meetingTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    if let date = group.meetingDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Item count badge
                Text("\(group.itemCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(AppColors.primary)
                    .clipShape(Circle())
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            
            // Status summary
            HStack(spacing: 16) {
                if group.overdueCount > 0 {
                    StatusPill(count: group.overdueCount, label: "Overdue", color: AppColors.error)
                }
                if group.pendingCount > 0 {
                    StatusPill(count: group.pendingCount, label: "Pending", color: AppColors.warning)
                }
                if group.inProgressCount > 0 {
                    StatusPill(count: group.inProgressCount, label: "In Progress", color: AppColors.info)
                }
                if group.completedCount > 0 {
                    StatusPill(count: group.completedCount, label: "Done", color: AppColors.success)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusPill: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(size: 12))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Meeting Action Items List View (Detail)
struct MeetingActionItemsListView: View {
    let meetingId: String
    let meetingTitle: String
    @ObservedObject var viewModel: TaskViewModel
    let onRefresh: () async -> Void
    
    @State private var selectedTask: TaskItem?
    
    // MARK: - Reactive: Always get fresh data from viewModel
    private var currentActionItems: [TaskItem] {
        viewModel.filteredTasks.filter { $0.meetingId == meetingId }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if currentActionItems.isEmpty {
                    // Empty state when all items filtered or deleted
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No action items match the current filter")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(currentActionItems) { item in
                        ActionItemCard(item: item) {
                            selectedTask = item
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppColors.background)
        .navigationTitle(meetingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTask) { task in
            // MARK: - Get the latest task data from viewModel
            if let latestTask = viewModel.tasks.first(where: { $0.id == task.id }) {
                ActionItemDetailView(
                    task: latestTask,
                    viewModel: viewModel,
                    onUpdate: {
                        Task {
                            await onRefresh()
                        }
                    }
                )
            } else {
                // Fallback if task was deleted
                ActionItemDetailView(
                    task: task,
                    viewModel: viewModel,
                    onUpdate: {
                        Task {
                            await onRefresh()
                        }
                    }
                )
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Filter Menu Button
struct FilterMenuButton: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        Menu {
            ForEach(TaskFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack {
                        Image(systemName: filter.icon)
                        Text(filter.rawValue)
                        if selectedFilter == filter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18))
                if selectedFilter != .all {
                    Text(selectedFilter.rawValue)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(selectedFilter == .all ? AppColors.textPrimary : AppColors.primary)
        }
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
            .background(isSelected ? AppColors.primary : AppColors.surfaceSecondary)
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
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

// MARK: - No Filter Results
struct NoFilterResultsView: View {
    let filter: TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: filter.icon)
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No \(filter.rawValue.lowercased()) action items")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
