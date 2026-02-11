import SwiftUI

struct ToDoView: View {
    @StateObject private var manager = ToDoManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddTask = false
    @State private var showFocusTimer = false
    @State private var selectedTask: ToDoItem?
    @State private var showTaskDetail = false
    @State private var showCategoryPicker = false
    @State private var showSortOptions = false
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Stats Cards
                        quickStatsSection
                        
                        // Filter Pills
                        filterSection
                        
                        // Category Pills
                        if !manager.categories.isEmpty {
                            categorySection
                        }
                        
                        // Search Bar
                        searchBar
                        
                        // Tasks List
                        tasksSection
                    }
                    .padding(.bottom, 100)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingActionButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("To Do")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showFocusTimer = true
                        } label: {
                            Label("Focus Timer", systemImage: "timer")
                        }
                        
                        Divider()
                        
                        Menu {
                            ForEach(ToDoSortType.allCases, id: \.self) { sortType in
                                Button {
                                    if manager.sortType == sortType {
                                        manager.sortAscending.toggle()
                                    } else {
                                        manager.sortType = sortType
                                        manager.sortAscending = true
                                    }
                                } label: {
                                    HStack {
                                        Label(sortType.rawValue, systemImage: sortType.icon)
                                        if manager.sortType == sortType {
                                            Image(systemName: manager.sortAscending ? "arrow.up" : "arrow.down")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Sort By", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(colorScheme: colorScheme)
            }
            .sheet(isPresented: $showFocusTimer) {
                FocusTimerView(colorScheme: colorScheme)
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task, colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickStatCard(
                    title: "Today",
                    count: manager.todayTasksCount,
                    icon: "sun.max.fill",
                    color: .orange,
                    colorScheme: colorScheme
                )
                
                QuickStatCard(
                    title: "Overdue",
                    count: manager.overdueTasksCount,
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    colorScheme: colorScheme
                )
                
                QuickStatCard(
                    title: "Completed",
                    count: manager.completedTodayCount,
                    icon: "checkmark.circle.fill",
                    color: .green,
                    colorScheme: colorScheme
                )
                
                QuickStatCard(
                    title: "Streak",
                    count: manager.statistics.currentStreak,
                    icon: "flame.fill",
                    color: .orange,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ToDoFilter.allCases, id: \.self) { filter in
                    ToDoFilterPill(
                        filter: filter,
                        isSelected: manager.currentFilter == filter,
                        count: countForFilter(filter),
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            manager.currentFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func countForFilter(_ filter: ToDoFilter) -> Int {
        switch filter {
        case .all: return manager.allActiveTasksCount
        case .today: return manager.todayTasksCount
        case .upcoming: return manager.upcomingTasksCount
        case .flagged: return manager.flaggedTasksCount
        case .completed: return manager.tasks.filter { $0.isCompleted }.count
        case .overdue: return manager.overdueTasksCount
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All categories
                ToDoCategoryPill(
                    name: "All",
                    icon: "square.grid.2x2",
                    color: .purple,
                    isSelected: manager.selectedCategoryId == nil,
                    colorScheme: colorScheme
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        manager.selectedCategoryId = nil
                    }
                }
                
                ForEach(manager.categories) { category in
                    ToDoCategoryPill(
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        isSelected: manager.selectedCategoryId == category.id,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            manager.selectedCategoryId = category.id
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(textSecondary)
            
            TextField("Search tasks...", text: $manager.searchText)
                .foregroundColor(textPrimary)
            
            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text("\(manager.currentFilter.rawValue) Tasks")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(manager.filteredTasks.count)")
                    .font(.subheadline)
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cardBackground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            if manager.filteredTasks.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(manager.filteredTasks) { task in
                        ToDoTaskRowView(
                            task: task,
                            colorScheme: colorScheme,
                            onToggle: {
                                withAnimation(.spring(response: 0.3)) {
                                    manager.toggleTaskCompletion(task)
                                }
                            },
                            onTap: {
                                selectedTask = task
                            },
                            onFlag: {
                                manager.toggleFlag(task)
                            },
                            onDelete: {
                                withAnimation {
                                    manager.deleteTask(task)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: manager.currentFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(textTertiary)
            
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundColor(textSecondary)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(textTertiary)
                .multilineTextAlignment(.center)
            
            if manager.currentFilter != .completed {
                Button {
                    showAddTask = true
                } label: {
                    Text("Add Task")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }
    
    private var emptyStateTitle: String {
        switch manager.currentFilter {
        case .all: return "No Tasks Yet"
        case .today: return "Nothing Due Today"
        case .upcoming: return "No Upcoming Tasks"
        case .flagged: return "No Flagged Tasks"
        case .completed: return "No Completed Tasks"
        case .overdue: return "Nothing Overdue"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch manager.currentFilter {
        case .all: return "Tap the + button to create your first task"
        case .today: return "Enjoy your free day or add some tasks"
        case .upcoming: return "Plan ahead by adding tasks with due dates"
        case .flagged: return "Flag important tasks to see them here"
        case .completed: return "Complete some tasks to see them here"
        case .overdue: return "Great job staying on top of your tasks!"
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button {
            showAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(textPrimary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(textPrimary.opacity(0.6))
        }
        .padding()
        .frame(width: 100)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Filter Pill
struct ToDoFilterPill: View {
    let filter: ToDoFilter
    let isSelected: Bool
    let count: Int
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.3) : filter.color.opacity(0.2)
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? filter.color : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Category Pill
struct ToDoCategoryPill: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(name)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Task Row View
struct ToDoTaskRowView: View {
    let task: ToDoItem
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    let onTap: () -> Void
    let onFlag: () -> Void
    let onDelete: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? Color.green : task.priority.color, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if task.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(task.isCompleted ? textSecondary : textPrimary)
                            .strikethrough(task.isCompleted)
                            .lineLimit(2)
                        
                        if task.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        // Due date
                        if let _ = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(task.formattedDueDate)
                                    .font(.caption)
                            }
                            .foregroundColor(task.dueDateColor)
                        }
                        
                        // Subtasks progress
                        if !task.subtasks.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.caption2)
                                Text("\(task.completedSubtasksCount)/\(task.subtasks.count)")
                                    .font(.caption)
                            }
                            .foregroundColor(textSecondary)
                        }
                        
                        // Recurrence
                        if task.recurrence != .none {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundColor(textSecondary)
                        }
                    }
                    
                    // Tags
                    if !task.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(task.tags.prefix(3)) { tag in
                                    Text(tag.name)
                                        .font(.caption2)
                                        .foregroundColor(tag.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tag.color.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                
                                if task.tags.count > 3 {
                                    Text("+\(task.tags.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(textSecondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Priority indicator
                if task.priority != .none && !task.isCompleted {
                    Circle()
                        .fill(task.priority.color)
                        .frame(width: 8, height: 8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(task.isOverdue ? Color.red.opacity(0.5) : cardBorder, lineWidth: task.isOverdue ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onFlag) {
                Label(task.isFlagged ? "Unflag" : "Flag", systemImage: task.isFlagged ? "flag.slash" : "flag.fill")
            }
            .tint(.red)
        }
    }
}

#Preview {
    ToDoView()
}
