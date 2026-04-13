//
//  PersonalGoalsView.swift
//  MeetingIntelligence
//
//  Personal Objectives/Goals - with progress tracking and WebSocket sync
//

import SwiftUI

// MARK: - Personal Goals List (Main Screen)

struct PersonalGoalsView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedGoal: LSWPersonalGoal?
    @State private var showAddSheet = false
    
    private let accentColor = Color(hex: "F59E0B") // Amber
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            if lswService.isLoadingGoals {
                loadingView
            } else if lswService.personalGoals.isEmpty {
                emptyStateView
            } else {
                goalsList
            }
            
            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Personal Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await lswService.fetchPersonalGoals()
            lswService.connectGoalWebSocket()
        }
        .sheet(isPresented: $showAddSheet) {
            GoalEditSheet(goal: nil)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalEditSheet(goal: goal)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading goals...")
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
                Image(systemName: "target")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No Personal Goals Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first personal objective or goal.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Goals List
    
    private var goalsList: some View {
        List {
            ForEach(lswService.personalGoals) { goal in
                Button {
                    selectedGoal = goal
                } label: {
                    goalCard(goal: goal)
                }
                .buttonStyle(.plain)
                .listRowBackground(cardBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await handleDelete(goal.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        selectedGoal = goal
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        Task { await handleDelete(goal.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Goal Card
    
    private func goalCard(goal: LSWPersonalGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: objective + due date
            HStack(alignment: .top) {
                Text(goal.objective.isEmpty ? "Untitled Goal" : goal.objective)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(goal.objective.isEmpty ? textTertiary : textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text(goal.dueDateFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)
            }
            
            // Progress bar
            HStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(goal.progressColor.opacity(0.15))
                            .frame(height: 8)
                        
                        // Fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(goal.progressColor)
                            .frame(width: geometry.size.width * CGFloat(min(goal.progress, 100)) / 100.0, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("\(goal.progress)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(goal.progressColor)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            showAddSheet = true
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
            lswService.personalGoals.removeAll { $0.id == id }
            if selectedGoal?.id == id { selectedGoal = nil }
        }
        _ = await lswService.deletePersonalGoal(id: id)
    }
}

// MARK: - Goal Edit Sheet

struct GoalEditSheet: View {
    let goal: LSWPersonalGoal?
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var objectiveText: String = ""
    @State private var dueDate: Date = Date()
    @State private var progress: Double = 0
    @State private var isSaving = false
    
    private let accentColor = Color(hex: "F59E0B")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var isNew: Bool { goal == nil }
    
    private var progressColor: Color {
        let p = Int(progress)
        if p >= 80 { return Color(hex: "10B981") }
        if p >= 50 { return Color(hex: "3B82F6") }
        return Color(hex: "EF4444")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Objective field
                        fieldSection(title: "Objective / Goal", icon: "target") {
                            TextField("Enter your objective...", text: $objectiveText, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(2...6)
                                .textFieldStyle(.plain)
                        }
                        
                        // Due Date field
                        fieldSection(title: "Due Date", icon: "calendar") {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        
                        // Progress field
                        fieldSection(title: "Progress", icon: "chart.bar.fill") {
                            VStack(spacing: 12) {
                                HStack {
                                    Slider(value: $progress, in: 0...100, step: 5)
                                        .tint(progressColor)
                                    
                                    Text("\(Int(progress))%")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(progressColor)
                                        .frame(width: 50, alignment: .trailing)
                                }
                                
                                // Progress bar preview
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(progressColor.opacity(0.15))
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(progressColor)
                                            .frame(width: geometry.size.width * CGFloat(min(progress, 100)) / 100.0, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New Goal" : "Edit Goal")
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
                    .disabled(objectiveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let g = goal {
                    objectiveText = g.objective
                    progress = Double(g.progress)
                    let raw = String(g.dueDate.prefix(10))
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
                    .foregroundColor(accentColor)
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
        let trimmedObjective = objectiveText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedObjective.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dueDateStr = formatter.string(from: dueDate)
        
        if isNew {
            if let created = await lswService.createPersonalGoal(
                objective: trimmedObjective,
                dueDate: dueDateStr,
                progress: Int(progress)
            ) {
                await MainActor.run {
                    if !lswService.personalGoals.contains(where: { $0.id == created.id }) {
                        lswService.personalGoals.append(created)
                    }
                }
            }
        } else if let g = goal {
            let updateData: [String: Any] = [
                "objective": trimmedObjective,
                "dueDate": dueDateStr,
                "progress": Int(progress)
            ]
            if let updated = await lswService.updatePersonalGoal(id: g.id, data: updateData) {
                await MainActor.run {
                    if let idx = lswService.personalGoals.firstIndex(where: { $0.id == g.id }) {
                        lswService.personalGoals[idx] = updated
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
