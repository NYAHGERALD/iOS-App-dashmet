import SwiftUI

struct ToDoView: View {
    @StateObject private var service = ToDoService.shared
    @ObservedObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAddTask = false
    @State private var selectedItem: APIToDoItem?
    @State private var currentWeekOffset = 0
    
    var onMenuTap: (() -> Void)?
    
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
    }
    private var currentWeekNumber: Int { lswService.orgWeekNumber(for: referenceDate) }
    private var currentYear: Int { lswService.orgYear(for: referenceDate) }
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    WeekNavigatorView(currentWeekOffset: $currentWeekOffset, lswService: lswService)
                    Divider()
                    
                    if service.isLoading && service.items.isEmpty {
                        Spacer()
                        loadingView
                        Spacer()
                    } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            quickStatsSection
                            filterSection
                            searchBar
                            tasksSection
                        }
                        .padding(.bottom, 100)
                    }
                }
                } // end VStack
                
                // Floating Add button
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onMenuTap?()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                    }
                }
            }
            .task {
                lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
                await service.fetchItems(weekNumber: currentWeekNumber, year: currentYear)
                service.connectWebSocket()
            }
            .onChange(of: currentWeekOffset) { _, _ in
                lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
                Task { await service.fetchItems(weekNumber: currentWeekNumber, year: currentYear) }
            }
            .fullScreenCover(isPresented: $showAddTask) {
                AddTaskView(colorScheme: colorScheme)
            }
            .sheet(item: $selectedItem) { item in
                TaskDetailView(item: item, colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Loading tasks...")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickStatCard(title: "Active", count: service.todayCount, icon: "sun.max.fill", color: .orange, colorScheme: colorScheme)
                QuickStatCard(title: "Overdue", count: service.overdueCount, icon: "exclamationmark.triangle.fill", color: .red, colorScheme: colorScheme)
                QuickStatCard(title: "Completed", count: service.completedCount, icon: "checkmark.circle.fill", color: .green, colorScheme: colorScheme)
                QuickStatCard(title: "Flagged", count: service.flaggedCount, icon: "flag.fill", color: .red, colorScheme: colorScheme)
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
                        isSelected: service.currentFilter == filter,
                        count: countForFilter(filter),
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            service.currentFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func countForFilter(_ filter: ToDoFilter) -> Int {
        switch filter {
        case .all: return service.items.filter { !$0.completed }.count
        case .today: return service.todayCount
        case .upcoming: return service.items.filter { !$0.completed && $0.dueDate != nil }.count
        case .flagged: return service.flaggedCount
        case .completed: return service.completedCount
        case .overdue: return service.overdueCount
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(textSecondary)
            TextField("Search tasks...", text: $service.searchText)
                .foregroundColor(textPrimary)
            if !service.searchText.isEmpty {
                Button {
                    service.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }
    
    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(service.currentFilter.rawValue) Tasks")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
                Text("\(service.filteredItems.count)")
                    .font(.subheadline)
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cardBackground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            if service.filteredItems.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(service.filteredItems) { item in
                        ToDoTaskRow(
                            item: item,
                            colorScheme: colorScheme,
                            onToggle: { Task { await handleToggle(item) } },
                            onTap: { selectedItem = item },
                            onFlag: { Task { await handleFlag(item) } },
                            onDelete: { Task { await handleDelete(item) } }
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
            Image(systemName: service.currentFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(textTertiary)
            Text("No tasks found")
                .font(.headline)
                .foregroundColor(textSecondary)
            Text("Tap the + button to add a task")
                .font(.subheadline)
                .foregroundColor(textTertiary)
            if service.currentFilter != .completed {
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
                    LinearGradient(colors: [Color.purple, Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Actions
    
    private func handleToggle(_ item: APIToDoItem) async {
        let newCompleted = !item.completed
        // Optimistic
        await MainActor.run {
            if let idx = service.items.firstIndex(where: { $0.id == item.id }) {
                let updated = APIToDoItem(
                    id: item.id, task: item.task, completed: newCompleted, completedAt: item.completedAt,
                    dueDate: item.dueDate, note: item.note, priority: item.priority,
                    category: item.category, tags: item.tags, isFlagged: item.isFlagged,
                    reminderDate: item.reminderDate, recurrence: item.recurrence,
                    weekNumber: item.weekNumber, year: item.year, sortOrder: item.sortOrder,
                    isActive: item.isActive, createdAt: item.createdAt, updatedAt: item.updatedAt
                )
                service.items[idx] = updated
            }
        }
        _ = await service.toggleCompleted(id: item.id, completed: newCompleted)
    }
    
    private func handleFlag(_ item: APIToDoItem) async {
        let newFlagged = !item.isFlagged
        await MainActor.run {
            if let idx = service.items.firstIndex(where: { $0.id == item.id }) {
                let updated = APIToDoItem(
                    id: item.id, task: item.task, completed: item.completed, completedAt: item.completedAt,
                    dueDate: item.dueDate, note: item.note, priority: item.priority,
                    category: item.category, tags: item.tags, isFlagged: newFlagged,
                    reminderDate: item.reminderDate, recurrence: item.recurrence,
                    weekNumber: item.weekNumber, year: item.year, sortOrder: item.sortOrder,
                    isActive: item.isActive, createdAt: item.createdAt, updatedAt: item.updatedAt
                )
                service.items[idx] = updated
            }
        }
        _ = await service.toggleFlagged(id: item.id, isFlagged: newFlagged)
    }
    
    private func handleDelete(_ item: APIToDoItem) async {
        await MainActor.run {
            service.items.removeAll { $0.id == item.id }
        }
        _ = await service.deleteItem(id: item.id)
    }
}

// MARK: - Task Row View
struct ToDoTaskRow: View {
    let item: APIToDoItem
    let colorScheme: ColorScheme
    let onToggle: () -> Void
    let onTap: () -> Void
    let onFlag: () -> Void
    let onDelete: () -> Void
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(item.completed ? Color.green : item.priorityLevel.color, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if item.completed {
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
                        Text(item.task.isEmpty ? "Untitled" : item.task)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(item.completed ? textSecondary : textPrimary)
                            .strikethrough(item.completed)
                            .lineLimit(2)
                        if item.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        // Past due badge
                        if item.isDueTimePast {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("Past Due")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundColor(.red)
                        }
                        
                        // Due time
                        if !item.formattedDueTime.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(item.formattedDueTime)
                                    .font(.caption)
                            }
                            .foregroundColor(item.isDueTimePast ? .red : textSecondary)
                        }
                        
                        // Recurrence
                        if item.recurrenceType != .none {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundColor(textSecondary)
                        }
                        
                        // Priority
                        if item.priorityLevel != .none {
                            HStack(spacing: 2) {
                                Image(systemName: item.priorityLevel.icon)
                                    .font(.caption2)
                            }
                            .foregroundColor(item.priorityLevel.color)
                        }
                    }
                    
                    // Tags
                    if !item.parsedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(item.parsedTags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                if item.parsedTags.count > 3 {
                                    Text("+\(item.parsedTags.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(textSecondary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(item.isDueTimePast ? Color.red.opacity(0.5) : cardBorder, lineWidth: item.isDueTimePast ? 2 : 1)
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
                Label(item.isFlagged ? "Unflag" : "Flag", systemImage: item.isFlagged ? "flag.slash" : "flag.fill")
            }
            .tint(.red)
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
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textPrimary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(textSecondary)
        }
        .frame(width: 80)
        .padding(.vertical, 14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Pill
struct ToDoFilterPill: View {
    let filter: ToDoFilter
    let isSelected: Bool
    let count: Int
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? filter.color : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    ToDoView()
}
