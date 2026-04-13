//
//  FollowUpsView.swift
//  MeetingIntelligence
//
//  Follow Ups section - row cards with edit modal and WebSocket sync
//

import SwiftUI

// MARK: - Follow-Ups List (Main Screen)

struct FollowUpsView: View {
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedFollowUp: LSWFollowUp?
    @State private var showAddSheet = false
    @State private var showDeleteConfirm = false
    @State private var deleteTargetId: String?
    @State private var currentWeekOffset = 0
    
    private let accentColor = Color(hex: "F97316") // Orange
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var textTertiary: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date())!
    }
    private var currentWeekNumber: Int { lswService.orgWeekNumber(for: referenceDate) }
    private var currentYear: Int { lswService.orgYear(for: referenceDate) }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                WeekNavigatorView(currentWeekOffset: $currentWeekOffset, lswService: lswService)
                Divider()
                
                if lswService.isLoadingFollowUps {
                    Spacer()
                    loadingView
                    Spacer()
                } else if lswService.followUps.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    followUpsList
                }
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
        .navigationTitle("Follow Ups")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
            await lswService.fetchFollowUps(weekNumber: currentWeekNumber, year: currentYear)
            lswService.connectFollowUpWebSocket()
        }
        .onChange(of: currentWeekOffset) { _, _ in
            lswService.setActiveWeek(weekNumber: currentWeekNumber, year: currentYear)
            Task { await lswService.fetchFollowUps(weekNumber: currentWeekNumber, year: currentYear) }
        }
        .alert("Delete Follow Up", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetId {
                    Task { await handleDelete(id) }
                }
            }
        } message: {
            Text("This follow up will be permanently deleted.")
        }
        .sheet(isPresented: $showAddSheet) {
            FollowUpEditSheet(followUp: nil)
        }
        .sheet(item: $selectedFollowUp) { followUp in
            FollowUpEditSheet(followUp: followUp)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading follow ups...")
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
                Image(systemName: "bell.badge")
                    .font(.system(size: 32))
                    .foregroundColor(accentColor)
            }
            
            Text("No Follow Ups Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            
            Text("Tap the + button to add your first follow up item.")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Follow-Ups List
    
    private var followUpsList: some View {
        List {
            ForEach(lswService.followUps) { followUp in
                Button {
                    selectedFollowUp = followUp
                } label: {
                    followUpCard(followUp: followUp)
                }
                .buttonStyle(.plain)
                .listRowBackground(cardBackground)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await handleDelete(followUp.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        selectedFollowUp = followUp
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteTargetId = followUp.id
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Follow-Up Card
    
    private func followUpCard(followUp: LSWFollowUp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task title
            Text(followUp.task.isEmpty ? "Untitled Follow Up" : followUp.task)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(followUp.task.isEmpty ? textTertiary : textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Due date + Responsible row
            HStack(spacing: 12) {
                // Due date badge
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(followUp.dueDateFormatted)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(dueDateColor(followUp).opacity(0.15))
                .foregroundColor(dueDateColor(followUp))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Responsible
                if !followUp.displayResponsible.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(followUp.displayResponsible)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textTertiary.opacity(0.5))
            }
            
            // Comment preview
            if let comments = followUp.comments, !comments.isEmpty {
                Text(comments)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineLimit(2)
                    .padding(.top, 2)
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
            lswService.followUps.removeAll { $0.id == id }
            if selectedFollowUp?.id == id { selectedFollowUp = nil }
        }
        _ = await lswService.deleteFollowUp(id: id)
    }
    
    // MARK: - Helpers
    
    private func dueDateColor(_ followUp: LSWFollowUp) -> Color {
        if followUp.isOverdue {
            return .red
        }
        // Due within 3 days
        let raw = String(followUp.dueDate.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let date = formatter.date(from: raw) {
            var cal = Calendar.current
            cal.timeZone = TimeZone(identifier: "UTC")!
            let threeDays = cal.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            if date < threeDays { return .orange }
        }
        return textSecondary
    }
}

// MARK: - Follow-Up Edit Sheet

struct FollowUpEditSheet: View {
    let followUp: LSWFollowUp?
    @StateObject private var lswService = LSWService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var task: String = ""
    @State private var dueDate: Date = Date()
    @State private var responsible: String = ""
    @State private var comments: String = ""
    @State private var isSaving = false
    
    private let accentColor = Color(hex: "F97316")
    
    private var textPrimary: Color { colorScheme == .dark ? .white : .black }
    private var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6) }
    private var cardBackground: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.white }
    private var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08) }
    
    private var isNew: Bool { followUp == nil }
    
    // Live follow-up from service (reflects WebSocket updates)
    private var liveFollowUp: LSWFollowUp? {
        guard let id = followUp?.id else { return nil }
        return lswService.followUps.first { $0.id == id }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Task field
                        fieldSection(title: "Follow Up", icon: "doc.text") {
                            TextField("Enter follow up task...", text: $task, axis: .vertical)
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
                        
                        // Responsible field
                        fieldSection(title: "Responsible", icon: "person.fill") {
                            TextField("Enter responsible person...", text: $responsible)
                                .font(.system(size: 15))
                                .textFieldStyle(.plain)
                        }
                        
                        // Comments field
                        fieldSection(title: "Comment / Notes", icon: "text.bubble") {
                            TextField("Add comment...", text: $comments, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...8)
                                .textFieldStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "New Follow Up" : "Edit Follow Up")
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
                    .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let fu = followUp {
                    task = fu.task
                    responsible = fu.displayResponsible
                    comments = fu.comments ?? ""
                    // Parse due date
                    let raw = String(fu.dueDate.prefix(10))
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
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
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else { return }
        
        await MainActor.run { isSaving = true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dueDateStr = formatter.string(from: dueDate)
        let trimmedResponsible = responsible.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComments = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isNew {
            // Create
            if let created = await lswService.createFollowUp(
                task: trimmedTask,
                dueDate: dueDateStr,
                responsibleName: trimmedResponsible,
                comments: trimmedComments,
                weekNumber: lswService.activeWeekNumber,
                year: lswService.activeYear
            ) {
                await MainActor.run {
                    if !lswService.followUps.contains(where: { $0.id == created.id }) {
                        lswService.followUps.append(created)
                    }
                }
            }
        } else if let fu = followUp {
            // Update
            var updateData: [String: Any] = [
                "task": trimmedTask,
                "dueDate": dueDateStr,
                "responsibleName": trimmedResponsible,
                "comments": trimmedComments
            ]
            if let updated = await lswService.updateFollowUp(id: fu.id, data: updateData) {
                await MainActor.run {
                    if let idx = lswService.followUps.firstIndex(where: { $0.id == fu.id }) {
                        lswService.followUps[idx] = updated
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
