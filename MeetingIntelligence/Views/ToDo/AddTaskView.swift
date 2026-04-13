import SwiftUI

struct AddTaskView: View {
    @StateObject private var service = ToDoService.shared
    @Environment(\.dismiss) private var dismiss
    let colorScheme: ColorScheme
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var priority: ToDoPriority = .none
    @State private var category: String = ""
    @State private var dueTime: Date = Date()
    @State private var hasDueTime: Bool = false
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var recurrence: RecurrenceType = .none
    @State private var isFlagged: Bool = false
    @State private var selectedTags: [String] = []
    @State private var newTagText: String = ""
    @State private var isSaving = false
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    
    private let categories = ["Personal", "Work", "Health", "Shopping", "Learning", "Home"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        titleSection
                        notesSection
                        prioritySection
                        categorySection
                        dateTimeSection
                        recurrenceSection
                        tagsSection
                        flagSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await addTask() }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(title.isEmpty ? textTertiary : Color.purple)
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    // MARK: - Title
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
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardBorder, lineWidth: 1))
        }
    }
    
    // MARK: - Notes
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
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
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardBorder, lineWidth: 1))
        }
    }
    
    // MARK: - Priority
    private var prioritySection: some View {
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
    }
    
    // MARK: - Category
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // None
                    Button {
                        category = ""
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                            Text("None")
                                .font(.caption)
                        }
                        .foregroundColor(category.isEmpty ? .white : textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(category.isEmpty ? Color.gray : cardBackground)
                        .clipShape(Capsule())
                    }
                    
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            Text(cat)
                                .font(.caption)
                                .foregroundColor(category == cat ? .white : textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(category == cat ? Color.purple : cardBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(category == cat ? Color.clear : cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Date/Time & Reminder
    private var dateTimeSection: some View {
        VStack(spacing: 16) {
            // Due Time Toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $hasDueTime) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Due Time")
                            .foregroundColor(textPrimary)
                    }
                }
                .tint(.purple)
                
                if hasDueTime {
                    DatePicker("", selection: $dueTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .tint(.purple)
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
    
    // MARK: - Recurrence
    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RecurrenceType.allCases.filter { $0 != .custom }, id: \.self) { type in
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
                            .overlay(Capsule().stroke(recurrence == type ? Color.clear : cardBorder, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tags
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textPrimary)
            
            // Add tag input
            HStack {
                TextField("Add tag...", text: $newTagText)
                    .foregroundColor(textPrimary)
                    .onSubmit {
                        addTag()
                    }
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Selected tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button {
                                    selectedTags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Flag
    private var flagSection: some View {
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
    }
    
    // MARK: - Actions
    
    private func addTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        newTagText = ""
    }
    
    private func addTask() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        var dueTimeStr: String? = nil
        if hasDueTime {
            let cal = Calendar.current
            let h = cal.component(.hour, from: dueTime)
            let m = cal.component(.minute, from: dueTime)
            dueTimeStr = String(format: "%02d:%02d", h, m)
        }
        
        var reminderStr: String? = nil
        if hasReminder {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            reminderStr = formatter.string(from: reminderDate)
        }
        
        // Get current week context
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let wk = cal.component(.weekOfYear, from: now)
        let yr = cal.component(.yearForWeekOfYear, from: now)
        
        if let created = await service.createItem(
            task: trimmed,
            dueDate: dueTimeStr,
            note: notes.isEmpty ? nil : notes,
            priority: priority.rawValue.lowercased(),
            category: category.isEmpty ? nil : category,
            tags: selectedTags.isEmpty ? nil : selectedTags,
            isFlagged: isFlagged,
            reminderDate: reminderStr,
            recurrence: recurrence.rawValue.lowercased(),
            weekNumber: wk,
            year: yr
        ) {
            await MainActor.run {
                if !service.items.contains(where: { $0.id == created.id }) {
                    service.items.append(created)
                }
                isSaving = false
                dismiss()
            }
        } else {
            await MainActor.run { isSaving = false }
        }
    }
}
