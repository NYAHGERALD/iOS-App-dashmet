//
//  ScheduledTasksView.swift
//  MeetingIntelligence
//
//  Scheduled Tasks/Meetings - grouped by frequency with WebSocket sync
//

import SwiftUI

// MARK: - Scheduled Tasks List (Main Screen)

struct ScheduledTasksView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTask: LSWFrequencyTask?
    @State private var addFrequency: LSWFrequency?
    
    private let accentColor = Color(hex: "10B981") // Green
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            if lswService.isLoadingFreqTasks {
                loadingView
            } else if lswService.frequencyTasks.isEmpty {
                emptyStateView
            } else {
                tasksList
            }
            
            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addMenuButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Scheduled Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await lswService.fetchFrequencyTasks()
            lswService.connectFreqTaskWebSocket()
        }
        .sheet(item: $selectedTask) { task in
            FreqTaskEditSheet(task: task, frequency: task.frequency)
        }
        .sheet(item: $addFrequency) { freq in
            FreqTaskEditSheet(task: nil, frequency: freq)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading scheduled tasks...")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No Scheduled Tasks Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add scheduled tasks for different frequencies.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Tasks List grouped by frequency
    
    private var tasksList: some View {
        List {
            ForEach(LSWFrequency.allCases, id: \.self) { freq in
                let tasks = lswService.frequencyTasks.filter { $0.frequency == freq }
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                taskRow(task: task, color: freq.color)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(cardBackground)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await handleDelete(task.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    selectedTask = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await handleDelete(task.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        frequencySectionHeader(frequency: freq)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Frequency Section Header
    
    private func frequencySectionHeader(frequency: LSWFrequency) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(frequency.color)
                .frame(width: 4, height: 20)
            
            Text(frequency.sectionTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(textPrimary)
            
            Spacer()
            
            Button {
                addFrequency = frequency
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(frequency.color)
            }
        }
        .textCase(nil)
    }
    
    // MARK: - Task Row
    
    private func taskRow(task: LSWFrequencyTask, color: Color) -> some View {
        HStack(spacing: 0) {
            // Minutes badge
            Text("\(task.minutes)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 44, alignment: .center)
            
            // Task name
            Text(task.task.isEmpty ? "Untitled Task" : task.task)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(task.task.isEmpty ? textTertiary : textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Due date
            Text(task.dueDateFormatted)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    // MARK: - Add Menu Button
    
    private var addMenuButton: some View {
        Menu {
            ForEach(LSWFrequency.allCases, id: \.self) { freq in
                Button {
                    addFrequency = freq
                } label: {
                    Label(freq.displayName, systemImage: "plus")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(accentColor)
                .clipShape(Circle())
                .shadow(color: accentColor.opacity(0.3), radius: 8, y: 4)
        }
    }
    
    // MARK: - Actions
    
    private func handleDelete(_ id: String) async {
        await MainActor.run {
            lswService.frequencyTasks.removeAll { $0.id == id }
            if selectedTask?.id == id { selectedTask = nil }
        }
        _ = await lswService.deleteFrequencyTask(id: id)
    }
}

// MARK: - Frequency Task Edit Sheet

struct FreqTaskEditSheet: View {
    let task: LSWFrequencyTask?
    let frequency: LSWFrequency
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskText: String = ""
    @State private var minutes: Int = 60
    @State private var dueDate: Date = Date()
    @State private var isSaving = false
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var isNew: Bool { task == nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Frequency badge
                        HStack {
                            Text(frequency.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(frequency.color)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                        }
                        
                        // Task field
                        fieldSection(title: "Task/Meeting", icon: "doc.text") {
                            TextField("Enter task or meeting name...", text: $taskText, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                        }
                        
                        // Minutes field
                        fieldSection(title: "Duration (minutes)", icon: "clock") {
                            HStack {
                                TextField("60", value: $minutes, format: .number)
                                    .font(.system(size: 15))
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                
                                Spacer()
                                
                                Stepper("", value: $minutes, in: 1...480, step: 15)
                                    .labelsHidden()
                            }
                        }
                        
                        // Due Date field
                        fieldSection(title: "Due Date", icon: "calendar") {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New \(frequency.displayName) Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let t = task {
                    taskText = t.task
                    minutes = t.minutes
                    let raw = String(t.dueDate.prefix(10))
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = TimeZone(identifier: "UTC")
                    if let date = formatter.date(from: raw) {
                        dueDate = date
                    }
                }
            }
        }
    }
    
    // MARK: - Field Section
    
    @ViewBuilder
    private func fieldSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(frequency.color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textSecondary)
            }
            
            content()
                .padding(12)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Save
    
    private func save() async {
        let trimmedTask = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dueDateStr = formatter.string(from: dueDate)
        
        if isNew {
            if let created = await lswService.createFrequencyTask(
                task: trimmedTask,
                minutes: minutes,
                dueDate: dueDateStr,
                frequency: frequency
            ) {
                await MainActor.run {
                    if !lswService.frequencyTasks.contains(where: { $0.id == created.id }) {
                        lswService.frequencyTasks.append(created)
                    }
                }
            }
        } else if let t = task {
            let updateData: [String: Any] = [
                "task": trimmedTask,
                "minutes": minutes,
                "dueDate": dueDateStr,
                "frequency": frequency.rawValue
            ]
            if let updated = await lswService.updateFrequencyTask(id: t.id, data: updateData) {
                await MainActor.run {
                    if let idx = lswService.frequencyTasks.firstIndex(where: { $0.id == t.id }) {
                        lswService.frequencyTasks[idx] = updated
                    }
                }
            }
        }
        
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }
}
