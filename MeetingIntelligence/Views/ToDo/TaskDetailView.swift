import SwiftUI

struct TaskDetailView: View {
    @StateObject private var service = ToDoService.shared
    @Environment(\.dismiss) private var dismiss
    
    let item: APIToDoItem
    let colorScheme: ColorScheme
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var editedPriority: ToDoPriority = .none
    @State private var editedCategory: String = ""
    @State private var editedRecurrence: RecurrenceType = .none
    @State private var editedIsFlagged: Bool = false
    @State private var editedHasDueTime: Bool = false
    @State private var editedDueTime: Date = Date()
    @State private var editedHasReminder: Bool = false
    @State private var editedReminderDate: Date = Date()
    @State private var editedTags: [String] = []
    @State private var newTagText: String = ""
    @State private var showDeleteAlert = false
    @State private var isSaving = false
    
    private let categories = ["Personal", "Work", "Health", "Shopping", "Learning", "Home"]
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        
                        if isEditing {
                            editingContent
                        } else {
                            readOnlyContent
                        }
                        
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
                    Button("Close") { dismiss() }
                        .foregroundColor(textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isEditing {
                            Task { await saveChanges() }
                        } else {
                            loadEditFields()
                            isEditing = true
                        }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(isEditing ? "Save" : "Edit")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.purple)
                    .disabled(isSaving)
                }
            }
            .alert("Delete Task?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await MainActor.run { service.items.removeAll { $0.id == item.id } }
                        _ = await service.deleteItem(id: item.id)
                        await MainActor.run { dismiss() }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    let newCompleted = !item.completed
                    if let updated = await service.toggleCompleted(id: item.id, completed: newCompleted) {
                        await MainActor.run {
                            if let idx = service.items.firstIndex(where: { $0.id == item.id }) {
                                service.items[idx] = updated
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.completed ? Color.green : item.priorityLevel.color, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    if item.completed {
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
                Text(item.completed ? "Completed" : "In Progress")
                    .font(.headline)
                    .foregroundColor(item.completed ? .green : textPrimary)
                if item.isDueTimePast {
                    Text("Past Due")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !item.formattedDueTime.isEmpty {
                    Text("Due \(item.formattedDueTime)")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    _ = await service.toggleFlagged(id: item.id, isFlagged: !item.isFlagged)
                }
            } label: {
                Image(systemName: item.isFlagged ? "flag.fill" : "flag")
                    .font(.title3)
                    .foregroundColor(item.isFlagged ? .red : textSecondary)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Read Only Content
    private var readOnlyContent: some View {
        VStack(spacing: 16) {
            // Title & Notes
            VStack(alignment: .leading, spacing: 12) {
                Text(item.task)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(textPrimary)
                    .strikethrough(item.completed)
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundColor(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Details
            VStack(spacing: 12) {
                if let cat = item.category, !cat.isEmpty {
                    DetailRow(icon: "folder", iconColor: .purple, title: "Category", value: cat, colorScheme: colorScheme)
                }
                if item.priorityLevel != .none {
                    DetailRow(icon: item.priorityLevel.icon, iconColor: item.priorityLevel.color, title: "Priority", value: item.priorityLevel.rawValue, colorScheme: colorScheme)
                }
                if !item.formattedDueTime.isEmpty {
                    DetailRow(icon: "clock", iconColor: item.isDueTimePast ? .red : .blue, title: "Due Time", value: item.formattedDueTime, colorScheme: colorScheme)
                }
                if let reminder = item.parsedReminderDate {
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
                    DetailRow(icon: "bell.fill", iconColor: .orange, title: "Reminder", value: formatter.string(from: reminder), colorScheme: colorScheme)
                }
                if item.recurrenceType != .none {
                    DetailRow(icon: item.recurrenceType.icon, iconColor: .purple, title: "Repeat", value: item.recurrenceType.rawValue, colorScheme: colorScheme)
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Tags
            if !item.parsedTags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(textPrimary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.parsedTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Editing Content
    private var editingContent: some View {
        VStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Task Title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                TextField("Task title", text: $editedTitle)
                    .font(.body)
                    .padding()
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                TextEditor(text: $editedNotes)
                    .font(.body)
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Priority
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                HStack(spacing: 10) {
                    ForEach(ToDoPriority.allCases, id: \.self) { p in
                        Button { editedPriority = p } label: {
                            VStack(spacing: 4) {
                                Image(systemName: p.icon).font(.title3)
                                Text(p.rawValue).font(.caption)
                            }
                            .foregroundColor(editedPriority == p ? .white : p.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(editedPriority == p ? p.color : p.color.opacity(0.15))
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
                        Button { editedCategory = "" } label: {
                            Text("None").font(.caption)
                                .foregroundColor(editedCategory.isEmpty ? .white : textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(editedCategory.isEmpty ? Color.gray : cardBackground)
                                .clipShape(Capsule())
                        }
                        ForEach(categories, id: \.self) { cat in
                            Button { editedCategory = cat } label: {
                                Text(cat).font(.caption)
                                    .foregroundColor(editedCategory == cat ? .white : textPrimary)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(editedCategory == cat ? Color.purple : cardBackground)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Due Time
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $editedHasDueTime) {
                    HStack {
                        Image(systemName: "clock").foregroundColor(.blue)
                        Text("Due Time").foregroundColor(textPrimary)
                    }
                }
                .tint(.purple)
                if editedHasDueTime {
                    DatePicker("", selection: $editedDueTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .tint(.purple)
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Reminder
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $editedHasReminder) {
                    HStack {
                        Image(systemName: "bell.fill").foregroundColor(.orange)
                        Text("Reminder").foregroundColor(textPrimary)
                    }
                }
                .tint(.purple)
                if editedHasReminder {
                    DatePicker("Remind at", selection: $editedReminderDate, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(textPrimary)
                        .tint(.purple)
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Recurrence
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(RecurrenceType.allCases.filter { $0 != .custom }, id: \.self) { type in
                            Button { editedRecurrence = type } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon).font(.caption)
                                    Text(type.rawValue).font(.caption)
                                }
                                .foregroundColor(editedRecurrence == type ? .white : textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(editedRecurrence == type ? Color.purple : cardBackground)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textPrimary)
                HStack {
                    TextField("Add tag...", text: $newTagText)
                        .foregroundColor(textPrimary)
                        .onSubmit { addEditTag() }
                    Button { addEditTag() } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.purple)
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if !editedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(editedTags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag).font(.caption)
                                    Button { editedTags.removeAll { $0 == tag } } label: {
                                        Image(systemName: "xmark.circle.fill").font(.caption2)
                                    }
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.purple.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Flag
            Toggle(isOn: $editedIsFlagged) {
                HStack {
                    Image(systemName: "flag.fill").foregroundColor(.red)
                    Text("Flag as Important").foregroundColor(textPrimary)
                }
            }
            .tint(.red)
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Actions
    private var actionsSection: some View {
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
    
    // MARK: - Helpers
    
    private func loadEditFields() {
        editedTitle = item.task
        editedNotes = item.note ?? ""
        editedPriority = item.priorityLevel
        editedCategory = item.category ?? ""
        editedRecurrence = item.recurrenceType
        editedIsFlagged = item.isFlagged
        editedTags = item.parsedTags
        
        if let dueDate = item.dueDate, !dueDate.isEmpty {
            editedHasDueTime = true
            let parts = dueDate.split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = h
                comps.minute = m
                editedDueTime = Calendar.current.date(from: comps) ?? Date()
            }
        }
        
        if let reminder = item.parsedReminderDate {
            editedHasReminder = true
            editedReminderDate = reminder
        }
    }
    
    private func addEditTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !editedTags.contains(tag) else { return }
        editedTags.append(tag)
        newTagText = ""
    }
    
    private func saveChanges() async {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        var data: [String: Any] = [
            "task": trimmed,
            "priority": editedPriority.rawValue.lowercased(),
            "isFlagged": editedIsFlagged,
            "recurrence": editedRecurrence.rawValue.lowercased(),
        ]
        
        data["note"] = editedNotes.isEmpty ? NSNull() : editedNotes
        data["category"] = editedCategory.isEmpty ? NSNull() : editedCategory
        
        if editedHasDueTime {
            let cal = Calendar.current
            let h = cal.component(.hour, from: editedDueTime)
            let m = cal.component(.minute, from: editedDueTime)
            data["dueDate"] = String(format: "%02d:%02d", h, m)
        } else {
            data["dueDate"] = NSNull()
        }
        
        if editedHasReminder {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            data["reminderDate"] = formatter.string(from: editedReminderDate)
        } else {
            data["reminderDate"] = NSNull()
        }
        
        if editedTags.isEmpty {
            data["tags"] = NSNull()
        } else if let jsonData = try? JSONEncoder().encode(editedTags),
                  let jsonStr = String(data: jsonData, encoding: .utf8) {
            data["tags"] = jsonStr
        }
        
        if let updated = await service.updateItem(id: item.id, data: data) {
            await MainActor.run {
                if let idx = service.items.firstIndex(where: { $0.id == item.id }) {
                    service.items[idx] = updated
                }
                isSaving = false
                isEditing = false
            }
        } else {
            await MainActor.run { isSaving = false }
        }
    }
}

// MARK: - Detail Row (Reused from existing code)
struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let colorScheme: ColorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(textPrimary)
                .fontWeight(.medium)
        }
    }
}
