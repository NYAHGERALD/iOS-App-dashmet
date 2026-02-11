import SwiftUI

struct AddTaskView: View {
    @StateObject private var manager = ToDoManager.shared
    @Environment(\.dismiss) private var dismiss
    let colorScheme: ColorScheme
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var priority: ToDoPriority = .none
    @State private var selectedCategoryId: UUID? = nil
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var recurrence: RecurrenceType = .none
    @State private var isFlagged: Bool = false
    @State private var estimatedMinutes: String = ""
    @State private var subtasks: [String] = []
    @State private var newSubtask: String = ""
    @State private var selectedTags: [ToDoTag] = []
    @State private var showTagPicker: Bool = false
    @State private var newTagName: String = ""
    @State private var showNewTagSheet: Bool = false
    
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
                        // Title Section
                        titleSection
                        
                        // Notes Section
                        notesSection
                        
                        // Priority & Category
                        priorityCategorySection
                        
                        // Due Date & Reminder
                        dateTimeSection
                        
                        // Recurrence
                        recurrenceSection
                        
                        // Subtasks
                        subtasksSection
                        
                        // Tags
                        tagsSection
                        
                        // Additional Options
                        additionalSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTask()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(title.isEmpty ? textTertiary : Color.purple)
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showNewTagSheet) {
                newTagSheet
            }
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Title")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            
            TextField("What do you need to do?", text: $title)
                .font(.body)
                .foregroundColor(textPrimary)
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            
            TextEditor(text: $notes)
                .font(.body)
                .foregroundColor(textPrimary)
                .frame(minHeight: 80)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Priority & Category
    private var priorityCategorySection: some View {
        VStack(spacing: 16) {
            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                
                HStack(spacing: 10) {
                    ForEach(ToDoPriority.allCases, id: \.self) { p in
                        Button {
                            priority = p
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: p.icon)
                                    .font(.title3)
                                Text(p.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(priority == p ? .white : p.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(priority == p ? p.color : p.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // No category
                        CategorySelectionPill(
                            name: "None",
                            icon: "minus.circle",
                            color: .gray,
                            isSelected: selectedCategoryId == nil,
                            colorScheme: colorScheme
                        ) {
                            selectedCategoryId = nil
                        }
                        
                        ForEach(manager.categories) { category in
                            CategorySelectionPill(
                                name: category.name,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategoryId == category.id,
                                colorScheme: colorScheme
                            ) {
                                selectedCategoryId = category.id
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Date Time Section
    private var dateTimeSection: some View {
        VStack(spacing: 16) {
            // Due Date Toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $hasDueDate) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("Due Date")
                            .foregroundColor(textPrimary)
                    }
                }
                .tint(.purple)
                
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(.purple)
                        .padding()
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Reminder Toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $hasReminder) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Reminder")
                            .foregroundColor(textPrimary)
                    }
                }
                .tint(.purple)
                
                if hasReminder {
                    DatePicker("Remind me at", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(textPrimary)
                        .tint(.purple)
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Recurrence Section
    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RecurrenceType.allCases, id: \.self) { type in
                        Button {
                            recurrence = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(recurrence == type ? .white : textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(recurrence == type ? Color.purple : cardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(recurrence == type ? Color.clear : cardBorder, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subtasks Section
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtasks")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            
            VStack(spacing: 8) {
                // Add subtask field
                HStack {
                    TextField("Add subtask", text: $newSubtask)
                        .foregroundColor(textPrimary)
                    
                    Button {
                        if !newSubtask.isEmpty {
                            subtasks.append(newSubtask)
                            newSubtask = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                    .disabled(newSubtask.isEmpty)
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Subtasks list
                ForEach(subtasks.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(textSecondary)
                        
                        Text(subtasks[index])
                            .foregroundColor(textPrimary)
                        
                        Spacer()
                        
                        Button {
                            subtasks.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(textTertiary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Button {
                    showNewTagSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(manager.tags) { tag in
                        Button {
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                selectedTags.removeAll { $0.id == tag.id }
                            } else {
                                selectedTags.append(tag)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if selectedTags.contains(where: { $0.id == tag.id }) {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                }
                                Text(tag.name)
                                    .font(.caption)
                            }
                            .foregroundColor(selectedTags.contains(where: { $0.id == tag.id }) ? .white : tag.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTags.contains(where: { $0.id == tag.id }) ? tag.color : tag.color.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if manager.tags.isEmpty {
                        Text("No tags yet. Tap + to create one.")
                            .font(.caption)
                            .foregroundColor(textTertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Additional Section
    private var additionalSection: some View {
        VStack(spacing: 12) {
            // Flag toggle
            Toggle(isOn: $isFlagged) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                    Text("Flag as Important")
                        .foregroundColor(textPrimary)
                }
            }
            .tint(.red)
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Estimated time
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.green)
                Text("Estimated Time")
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                TextField("mins", text: $estimatedMinutes)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .foregroundColor(textPrimary)
                    .padding(8)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("min")
                    .foregroundColor(textSecondary)
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - New Tag Sheet
    private var newTagSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextField("Tag name", text: $newTagName)
                        .foregroundColor(textPrimary)
                        .padding()
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Color picker
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(tagColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedTagColor == hex ? textPrimary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedTagColor = hex
                                }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showNewTagSheet = false
                    }
                    .foregroundColor(textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let tag = ToDoTag(name: newTagName, colorHex: selectedTagColor)
                        manager.addTag(tag)
                        selectedTags.append(tag)
                        newTagName = ""
                        showNewTagSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(newTagName.isEmpty ? textTertiary : Color.purple)
                    .disabled(newTagName.isEmpty)
                }
            }
        }
    }
    
    @State private var selectedTagColor: String = "8B5CF6"
    
    private var tagColors: [String] {
        ["EF4444", "F59E0B", "10B981", "3B82F6", "8B5CF6", "EC4899",
         "F97316", "84CC16", "06B6D4", "6366F1", "A855F7", "F43F5E"]
    }
    
    // MARK: - Add Task
    private func addTask() {
        let task = ToDoItem(
            title: title,
            notes: notes,
            categoryId: selectedCategoryId,
            priority: priority,
            tags: selectedTags,
            dueDate: hasDueDate ? dueDate : nil,
            reminderDate: hasReminder ? reminderDate : nil,
            hasReminder: hasReminder,
            recurrence: recurrence,
            subtasks: subtasks.map { Subtask(title: $0) },
            estimatedMinutes: Int(estimatedMinutes),
            isFlagged: isFlagged
        )
        
        manager.addTask(task)
        dismiss()
    }
}

// MARK: - Category Selection Pill
struct CategorySelectionPill: View {
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
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? color : color.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    AddTaskView(colorScheme: .dark)
}
