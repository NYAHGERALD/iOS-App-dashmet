import SwiftUI

struct TaskDetailView: View {
    @StateObject private var manager = ToDoManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State var task: ToDoItem
    let colorScheme: ColorScheme
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var showDeleteAlert = false
    @State private var newSubtask: String = ""
    @State private var showFocusTimer = false
    
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
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with completion status
                        headerSection
                        
                        // Title & Notes
                        titleNotesSection
                        
                        // Details Section
                        detailsSection
                        
                        // Subtasks
                        if !task.subtasks.isEmpty || isEditing {
                            subtasksSection
                        }
                        
                        // Tags
                        if !task.tags.isEmpty {
                            tagsSection
                        }
                        
                        // Statistics
                        if task.pomodorosCompleted > 0 || task.actualMinutes != nil {
                            statisticsSection
                        }
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                }
            }
            .alert("Delete Task?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    manager.deleteTask(task)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showFocusTimer) {
                FocusTimerView(colorScheme: colorScheme, linkedTask: task)
            }
            .onAppear {
                editedTitle = task.title
                editedNotes = task.notes
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Completion button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    manager.toggleTaskCompletion(task)
                    task.isCompleted.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : task.priority.color, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.isCompleted ? "Completed" : "In Progress")
                    .font(.headline)
                    .foregroundColor(task.isCompleted ? .green : textPrimary)
                
                if let completedAt = task.completedAt {
                    Text("Completed \(formattedDate(completedAt))")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                } else if let dueDate = task.dueDate {
                    Text(task.isOverdue ? "Overdue" : "Due \(task.formattedDueDate)")
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : textSecondary)
                }
            }
            
            Spacer()
            
            // Flag button
            Button {
                manager.toggleFlag(task)
                task.isFlagged.toggle()
            } label: {
                Image(systemName: task.isFlagged ? "flag.fill" : "flag")
                    .font(.title3)
                    .foregroundColor(task.isFlagged ? .red : textSecondary)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Title Notes Section
    private var titleNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                TextField("Task title", text: $editedTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(textPrimary)
                    .padding()
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                TextEditor(text: $editedNotes)
                    .font(.body)
                    .foregroundColor(textPrimary)
                    .frame(minHeight: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(task.title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(textPrimary)
                    .strikethrough(task.isCompleted)
                
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.body)
                        .foregroundColor(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(spacing: 12) {
            // Category
            if let categoryId = task.categoryId,
               let category = manager.category(for: categoryId) {
                DetailRow(
                    icon: category.icon,
                    iconColor: category.color,
                    title: "Category",
                    value: category.name,
                    colorScheme: colorScheme
                )
            }
            
            // Priority
            if task.priority != .none {
                DetailRow(
                    icon: task.priority.icon,
                    iconColor: task.priority.color,
                    title: "Priority",
                    value: task.priority.rawValue,
                    colorScheme: colorScheme
                )
            }
            
            // Due Date
            if let dueDate = task.dueDate {
                DetailRow(
                    icon: "calendar",
                    iconColor: task.dueDateColor,
                    title: "Due Date",
                    value: fullFormattedDate(dueDate),
                    colorScheme: colorScheme
                )
            }
            
            // Reminder
            if task.hasReminder, let reminderDate = task.reminderDate {
                DetailRow(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: "Reminder",
                    value: fullFormattedDate(reminderDate),
                    colorScheme: colorScheme
                )
            }
            
            // Recurrence
            if task.recurrence != .none {
                DetailRow(
                    icon: task.recurrence.icon,
                    iconColor: .purple,
                    title: "Repeat",
                    value: task.recurrence.rawValue,
                    colorScheme: colorScheme
                )
            }
            
            // Estimated time
            if let estimated = task.estimatedMinutes {
                DetailRow(
                    icon: "clock",
                    iconColor: .green,
                    title: "Estimated",
                    value: "\(estimated) minutes",
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Subtasks Section
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subtasks")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                if !task.subtasks.isEmpty {
                    Text("\(task.completedSubtasksCount)/\(task.subtasks.count)")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
            }
            
            // Progress bar
            if !task.subtasks.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cardBorder)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geo.size.width * task.subtaskProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Subtasks list
            ForEach(task.subtasks) { subtask in
                HStack(spacing: 12) {
                    Button {
                        manager.toggleSubtask(task, subtaskId: subtask.id)
                        if let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) {
                            task.subtasks[index].isCompleted.toggle()
                        }
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : textSecondary)
                    }
                    
                    Text(subtask.title)
                        .foregroundColor(subtask.isCompleted ? textSecondary : textPrimary)
                        .strikethrough(subtask.isCompleted)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Add subtask (when editing)
            if isEditing {
                HStack {
                    TextField("Add subtask", text: $newSubtask)
                        .foregroundColor(textPrimary)
                    
                    Button {
                        if !newSubtask.isEmpty {
                            let subtask = Subtask(title: newSubtask)
                            task.subtasks.append(subtask)
                            newSubtask = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                    .disabled(newSubtask.isEmpty)
                }
                .padding(10)
                .background(cardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            ToDoFlowLayout(spacing: 8) {
                ForEach(task.tags) { tag in
                    Text(tag.name)
                        .font(.subheadline)
                        .foregroundColor(tag.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tag.color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Statistics")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            HStack(spacing: 16) {
                StatBox(
                    icon: "flame.fill",
                    value: "\(task.pomodorosCompleted)",
                    label: "Pomodoros",
                    color: .orange,
                    colorScheme: colorScheme
                )
                
                if let actual = task.actualMinutes {
                    StatBox(
                        icon: "clock.fill",
                        value: "\(actual)",
                        label: "Minutes",
                        color: .blue,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Start Focus
            Button {
                showFocusTimer = true
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text("Start Focus Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Archive
            Button {
                manager.archiveTask(task)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "archivebox")
                    Text("Archive Task")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(textSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Delete
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Task")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func fullFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private func saveChanges() {
        task.title = editedTitle
        task.notes = editedNotes
        manager.updateTask(task)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(textSecondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(textPrimary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(textPrimary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout
struct ToDoFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = ToDoFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = ToDoFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct ToDoFlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            height = currentY + lineHeight
        }
    }
}

#Preview {
    TaskDetailView(
        task: ToDoItem(title: "Sample Task", notes: "This is a sample note"),
        colorScheme: .dark
    )
}
