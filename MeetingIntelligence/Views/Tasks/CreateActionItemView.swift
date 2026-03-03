//
//  CreateActionItemView.swift
//  MeetingIntelligence
//
//  Manual Action Item Creation - Add standalone or meeting-linked action items
//

import SwiftUI

struct CreateActionItemView: View {
    @ObservedObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Form fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedMeetingId: String? = nil
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false
    @State private var errorText: String = ""
    
    // Available meeting groups from existing tasks
    let meetingGroups: [MeetingGroup]
    
    // Callback after creation
    var onCreated: ((TaskItem) -> Void)?
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title Section
                        titleSection
                        
                        // Description Section
                        descriptionSection
                        
                        // Priority Section
                        prioritySection
                        
                        // Due Date Section
                        dueDateSection
                        
                        // Meeting Group Section
                        meetingGroupSection
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                
                // Bottom Create Button
                VStack {
                    Spacer()
                    createButton
                }
            }
            .navigationTitle("New Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Title", systemImage: "pencil.line")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            TextField("What needs to be done?", text: $title)
                .font(.system(size: 16))
                .padding(14)
                .background(AppColors.surface)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(title.isEmpty ? AppColors.border : AppColors.primary.opacity(0.5), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Description", systemImage: "text.alignleft")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            TextEditor(text: $description)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(10)
                .background(AppColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Add details about this action item...")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    // MARK: - Priority Section
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Priority", systemImage: "flag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 10) {
                ForEach([TaskPriority.low, .medium, .high, .urgent], id: \.self) { p in
                    PriorityChip(
                        priority: p,
                        isSelected: priority == p,
                        onTap: { priority = p }
                    )
                }
            }
        }
    }
    
    // MARK: - Due Date Section
    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Due Date", systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Toggle("", isOn: $hasDueDate)
                    .labelsHidden()
                    .tint(AppColors.primary)
            }
            
            if hasDueDate {
                DatePicker(
                    "Select date",
                    selection: $dueDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.primary)
                .padding(12)
                .background(AppColors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Meeting Group Section
    private var meetingGroupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add to Group", systemImage: "folder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            VStack(spacing: 0) {
                // Standalone option
                MeetingGroupOption(
                    title: "Standalone Item",
                    subtitle: "Not linked to any meeting",
                    icon: "tray",
                    isSelected: selectedMeetingId == nil,
                    onTap: { selectedMeetingId = nil }
                )
                
                // Existing meeting groups
                let existingMeetings = meetingGroups.filter { $0.id != "no-meeting" }
                if !existingMeetings.isEmpty {
                    Divider().padding(.leading, 52)
                    
                    ForEach(existingMeetings) { group in
                        MeetingGroupOption(
                            title: group.title,
                            subtitle: [group.meetingType, group.meetingDate].compactMap { $0 }.joined(separator: " • "),
                            icon: "person.3",
                            isSelected: selectedMeetingId == group.id,
                            onTap: { selectedMeetingId = group.id }
                        )
                        
                        if group.id != existingMeetings.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .background(AppColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Create Button
    private var createButton: some View {
        VStack {
            Button {
                Task {
                    await createActionItem()
                }
            } label: {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isCreating ? "Creating..." : "Create Action Item")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isFormValid
                        ? AnyShapeStyle(AppGradients.primary)
                        : AnyShapeStyle(AppColors.textTertiary)
                )
                .cornerRadius(14)
            }
            .disabled(!isFormValid || isCreating)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color.clear, colorScheme == .dark ? AppColors.background : AppColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Create Action
    private func createActionItem() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorText = "Title cannot be empty"
            showError = true
            return
        }
        
        isCreating = true
        
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newTask = await viewModel.createTask(
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            meetingId: selectedMeetingId,
            isAiExtracted: false
        )
        
        isCreating = false
        
        if let task = newTask {
            onCreated?(task)
            dismiss()
        } else {
            errorText = viewModel.errorMessage ?? "Failed to create action item"
            showError = true
        }
    }
}

// MARK: - Priority Chip
private struct PriorityChip: View {
    let priority: TaskPriority
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Text(priority.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: priority.color))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color(hex: priority.color)
                        : Color(hex: priority.color).opacity(0.12)
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: priority.color).opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Group Option
private struct MeetingGroupOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? AppColors.primary.opacity(0.12) : AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
