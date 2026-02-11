//
//  ActionItemsTab.swift
//  MeetingIntelligence
//
//  Full Action Items Management with create, edit, extract, and tracking
//

import SwiftUI

struct ActionItemsTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    @StateObject private var taskViewModel = TaskViewModel()
    
    // External trigger for auto-extraction (from OverviewTab)
    @Binding var shouldAutoExtract: Bool
    
    @State private var filterStatus: ActionItemFilter = .all
    @State private var sortOrder: ActionItemSort = .priority
    @State private var selectedTask: TaskItem?
    @State private var showCreateSheet = false
    @State private var showExtractAlert = false
    @State private var isExtracting = false
    @State private var extractionMessage: String?
    @State private var showNoItemsFoundModal = false
    @State private var hasAttemptedExtraction = false
    
    // AI-processed transcript from database
    @State private var aiProcessedTranscript: String = ""
    @State private var isLoadingTranscript = false
    
    // Create form fields
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var newPriority: TaskPriority = .medium
    @State private var newDueDate = Date()
    @State private var hasDueDate = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            actionItemsHeader
            
            // Content
            if viewModel.actionItems.isEmpty && !taskViewModel.isLoading && !isExtracting {
                emptyState
            } else if isExtracting {
                extractingState
            } else {
                actionItemsList
            }
        }
        .background(AppColors.background)
        .onAppear {
            taskViewModel.configure(
                userId: viewModel.userId ?? "",
                organizationId: viewModel.meeting.organizationId
            )
            // Load AI-processed transcript
            Task {
                await loadAIProcessedTranscript()
            }
        }
        .onChange(of: shouldAutoExtract) { _, newValue in
            if newValue {
                // Reset the flag immediately
                shouldAutoExtract = false
                
                // Only auto-extract if no action items exist yet
                // If items already exist, just navigate without re-extracting
                if viewModel.actionItems.isEmpty {
                    Task {
                        // Make sure transcript is loaded first
                        if aiProcessedTranscript.isEmpty {
                            await loadAIProcessedTranscript()
                        }
                        if hasTranscript {
                            await extractActionItems()
                        } else {
                            // No transcript available - show modal
                            showNoItemsFoundModal = true
                        }
                    }
                }
                // If items exist, do nothing - user just navigated to see existing items
            }
        }
        .sheet(item: $selectedTask) { task in
            ActionItemDetailView(
                task: task,
                viewModel: taskViewModel,
                onUpdate: {
                    Task { await viewModel.refreshMeeting() }
                }
            )
        }
        .sheet(isPresented: $showCreateSheet) {
            createActionItemSheet
        }
        .alert("Extract Action Items", isPresented: $showExtractAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Extract") {
                Task { await extractActionItems() }
            }
        } message: {
            Text("System will analyze the transcript to identify issues, opportunities, and items needing follow-up. This may take a moment.")
        }
        .sheet(isPresented: $showNoItemsFoundModal) {
            noActionItemsFoundSheet
        }
    }
    
    // MARK: - No Action Items Found Sheet
    private var noActionItemsFoundSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "8B5CF6").opacity(0.6))
                
                // Title and Message
                VStack(spacing: 12) {
                    Text("No Action Items Found")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Our System analyzed the meeting transcript but couldn't identify any issues, opportunities, or items needing follow-up.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text("This could happen if:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    suggestionRow(icon: "checkmark.circle", text: "The meeting was purely informational with no issues discussed")
                    suggestionRow(icon: "waveform", text: "The transcript quality was too low to analyze")
                    suggestionRow(icon: "doc.text", text: "The transcript content was very short or incomplete")
                }
                .padding(20)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Create Manually Button
                Button {
                    showNoItemsFoundModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreateSheet = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Action Item Manually")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppColors.background)
            .navigationTitle("Extraction Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showNoItemsFoundModal = false
                    }
                }
            }
        }
    }
    
    private func suggestionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Full Header for Action Items Tab (with navigation + toolbar)
    @Environment(\.dismiss) private var dismiss
    
    private var actionItemsHeader: some View {
        VStack(spacing: 0) {
            // Navigation bar with Close, title, sparkles, and + button
            HStack(spacing: 16) {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Text("Action Items")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Extract from Transcript button
                if hasTranscript {
                    Button {
                        showExtractAlert = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(isExtracting ? AppColors.textTertiary : Color(hex: "8B5CF6"))
                    }
                    .disabled(isExtracting)
                } else {
                    // Placeholder for alignment
                    Color.clear.frame(width: 18)
                }
                
                // New Action Item Button (blue circle +)
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Secondary toolbar with filter and sort only (no duplicate + button)
            HStack(spacing: 12) {
                // Filter pill
                Menu {
                    ForEach(ActionItemFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterStatus = filter
                            }
                        } label: {
                            HStack {
                                Image(systemName: filter.icon)
                                Text(filter.title)
                                let count = countForFilter(filter)
                                if count > 0 {
                                    Text("(\(count))")
                                }
                                if filterStatus == filter {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12))
                        Text(filterStatus.title)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(filterStatus == .all ? AppColors.textSecondary : AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(filterStatus == .all ? AppColors.surfaceSecondary : AppColors.primary.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Item count
                Text("\(filteredItems.count) items")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                // Sort Menu
                Menu {
                    ForEach(ActionItemSort.allCases, id: \.self) { sort in
                        Button {
                            sortOrder = sort
                        } label: {
                            HStack {
                                Text(sort.title)
                                if sortOrder == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                        Text(sortOrder.title)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.surface)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No Action Items")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Create action items manually or extract them from the meeting transcript.")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            if viewModel.meeting.status == .processing {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    Text("Processing meeting...")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                }
                .padding(.top, AppSpacing.md)
            } else {
                VStack(spacing: 12) {
                    if hasTranscript {
                        Button {
                            showExtractAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("Extract from Transcript")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Manually")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
    
    // MARK: - Extracting State
    private var extractingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
            
            Text("Extracting Action Items...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("System is analyzing the transcript to identify action items")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
    
    // MARK: - Action Items List
    private var actionItemsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Extraction Success Message
                if let message = extractionMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.success)
                        Spacer()
                        Button {
                            extractionMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(12)
                    .background(AppColors.success.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Overdue Section
                let overdueItems = filteredItems.filter { isOverdue($0) }
                if !overdueItems.isEmpty {
                    ActionItemSection(
                        title: "Overdue",
                        icon: "exclamationmark.triangle.fill",
                        color: AppColors.error,
                        items: overdueItems,
                        onSelect: { selectedTask = $0 }
                    )
                }
                
                // Due Today Section
                let todayItems = filteredItems.filter { isDueToday($0) && !isOverdue($0) }
                if !todayItems.isEmpty {
                    ActionItemSection(
                        title: "Due Today",
                        icon: "clock.fill",
                        color: AppColors.warning,
                        items: todayItems,
                        onSelect: { selectedTask = $0 }
                    )
                }
                
                // Upcoming Section
                let upcomingItems = filteredItems.filter { isUpcoming($0) }
                if !upcomingItems.isEmpty {
                    ActionItemSection(
                        title: "Upcoming",
                        icon: "calendar",
                        color: AppColors.info,
                        items: upcomingItems,
                        onSelect: { selectedTask = $0 }
                    )
                }
                
                // No Due Date Section
                let noDueDateItems = filteredItems.filter { $0.dueDate == nil && $0.status != .completed }
                if !noDueDateItems.isEmpty {
                    ActionItemSection(
                        title: "No Due Date",
                        icon: "calendar.badge.minus",
                        color: AppColors.textTertiary,
                        items: noDueDateItems,
                        onSelect: { selectedTask = $0 }
                    )
                }
                
                // Completed Section
                let completedItems = filteredItems.filter { $0.status == .completed }
                if !completedItems.isEmpty && (filterStatus == .all || filterStatus == .completed) {
                    ActionItemSection(
                        title: "Completed",
                        icon: "checkmark.circle.fill",
                        color: AppColors.success,
                        items: completedItems,
                        isCollapsible: true,
                        onSelect: { selectedTask = $0 }
                    )
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
        .refreshable {
            await viewModel.refreshMeeting()
        }
    }
    
    // MARK: - Create Action Item Sheet
    private var createActionItemSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $newTitle)
                    
                    TextField("Description (optional)", text: $newDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $newPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetCreateForm()
                        showCreateSheet = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createActionItem() }
                    }
                    .fontWeight(.semibold)
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if there's transcript content available (AI-processed or raw blocks)
    private var hasTranscript: Bool {
        // First check AI-processed transcript
        if !aiProcessedTranscript.isEmpty {
            return true
        }
        // Fall back to transcript blocks
        if let transcriptBlocks = viewModel.meeting.transcript, !transcriptBlocks.isEmpty {
            return true
        }
        // Also check hasTranscript computed property on Meeting
        return viewModel.meeting.hasTranscript
    }
    
    /// Get the best available transcript for AI extraction
    /// Prefers AI-processed transcript, falls back to raw transcript blocks
    private var transcriptForExtraction: String {
        // Prefer AI-processed transcript (better quality for extraction)
        if !aiProcessedTranscript.isEmpty {
            print("📝 Using AI-processed transcript for extraction (\(aiProcessedTranscript.count) chars)")
            return aiProcessedTranscript
        }
        
        // Fall back to combining transcript blocks
        guard let transcriptBlocks = viewModel.meeting.transcript else { return "" }
        let combined = transcriptBlocks
            .sorted { $0.startTime < $1.startTime }
            .map { block in
                "\(block.speakerLabel): \(block.content)"
            }
            .joined(separator: "\n")
        print("📝 Using raw transcript blocks for extraction (\(combined.count) chars)")
        return combined
    }
    
    /// Load AI-processed transcript from database
    private func loadAIProcessedTranscript() async {
        isLoadingTranscript = true
        
        // First check local cache
        if let transcriptData = UserDefaults.standard.data(forKey: "transcript_processed_\(viewModel.meeting.id)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["processedText"] as? String, !text.isEmpty {
            await MainActor.run {
                aiProcessedTranscript = text
                isLoadingTranscript = false
            }
            print("📝 Loaded AI-processed transcript from cache: \(text.prefix(100))...")
            return
        }
        
        // Fetch from database
        do {
            if let transcript = try await MeetingSummaryService.shared.fetchProcessedTranscript(meetingId: viewModel.meeting.id) {
                let text = transcript.processedTranscript ?? transcript.rawTranscript ?? ""
                if !text.isEmpty {
                    await MainActor.run {
                        aiProcessedTranscript = text
                        isLoadingTranscript = false
                    }
                    print("✅ Loaded AI-processed transcript from database: \(text.prefix(100))...")
                    return
                }
            }
        } catch {
            print("⚠️ Failed to fetch AI-processed transcript: \(error)")
        }
        
        await MainActor.run {
            isLoadingTranscript = false
        }
    }
    
    private func extractActionItems() async {
        isExtracting = true
        hasAttemptedExtraction = true
        
        // Use the best available transcript
        let transcriptText = transcriptForExtraction
        
        guard !transcriptText.isEmpty else {
            isExtracting = false
            // Only show modal if no action items exist
            if viewModel.actionItems.isEmpty {
                showNoItemsFoundModal = true
            }
            return
        }
        
        let extracted = await taskViewModel.extractActionItems(
            meetingId: viewModel.meeting.id,
            transcript: transcriptText
        )
        
        isExtracting = false
        
        if let tasks = extracted, !tasks.isEmpty {
            extractionMessage = "Extracted \(tasks.count) action items"
            await viewModel.refreshMeeting()
        } else {
            // Only show "no items found" modal if there are truly no action items
            // (either existing or newly extracted)
            if viewModel.actionItems.isEmpty {
                showNoItemsFoundModal = true
            }
        }
    }
    
    private func createActionItem() async {
        let task = await taskViewModel.createTask(
            title: newTitle,
            description: newDescription.isEmpty ? nil : newDescription,
            priority: newPriority,
            dueDate: hasDueDate ? newDueDate : nil,
            meetingId: viewModel.meeting.id
        )
        
        if task != nil {
            resetCreateForm()
            showCreateSheet = false
            await viewModel.refreshMeeting()
        }
    }
    
    private func resetCreateForm() {
        newTitle = ""
        newDescription = ""
        newPriority = .medium
        newDueDate = Date()
        hasDueDate = false
    }
    
    // MARK: - Computed Properties
    private var filteredItems: [TaskItem] {
        var items = viewModel.actionItems
        
        // Apply status filter
        switch filterStatus {
        case .all:
            break
        case .pending:
            items = items.filter { $0.status != .completed }
        case .completed:
            items = items.filter { $0.status == .completed }
        case .highPriority:
            items = items.filter { $0.priority == .urgent || $0.priority == .high }
        }
        
        // Apply sort
        switch sortOrder {
        case .priority:
            items.sort { $0.priority.sortOrder < $1.priority.sortOrder }
        case .dueDate:
            items.sort { (lhs: TaskItem, rhs: TaskItem) -> Bool in
                guard let date1 = lhs.dueDate else { return false }
                guard let date2 = rhs.dueDate else { return true }
                return date1 < date2
            }
        case .assignee:
            items.sort { ($0.assignee?.fullName ?? "") < ($1.assignee?.fullName ?? "") }
        case .status:
            items.sort { $0.status.rawValue < $1.status.rawValue }
        }
        
        return items
    }
    
    private func countForFilter(_ filter: ActionItemFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.actionItems.count
        case .pending:
            return viewModel.actionItems.filter { $0.status != .completed }.count
        case .completed:
            return viewModel.actionItems.filter { $0.status == .completed }.count
        case .highPriority:
            return viewModel.actionItems.filter { $0.priority == .urgent || $0.priority == .high }.count
        }
    }
    
    // MARK: - Date Helpers
    private func isOverdue(_ item: TaskItem) -> Bool {
        guard let dueDate = item.dueDate else { return false }
        return dueDate < Date() && item.status != .completed
    }
    
    private func isDueToday(_ item: TaskItem) -> Bool {
        guard let dueDate = item.dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    private func isUpcoming(_ item: TaskItem) -> Bool {
        guard let dueDate = item.dueDate else { return false }
        return dueDate > Date() && !Calendar.current.isDateInToday(dueDate) && item.status != .completed
    }
}

// MARK: - Filter Enum
enum ActionItemFilter: CaseIterable {
    case all
    case pending
    case completed
    case highPriority
    
    var title: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .highPriority: return "High Priority"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .pending: return "clock"
        case .completed: return "checkmark.circle"
        case .highPriority: return "exclamationmark.circle"
        }
    }
}

// MARK: - Sort Enum
enum ActionItemSort: CaseIterable {
    case priority
    case dueDate
    case assignee
    case status
    
    var title: String {
        switch self {
        case .priority: return "Priority"
        case .dueDate: return "Due Date"
        case .assignee: return "Assignee"
        case .status: return "Status"
        }
    }
}

// MARK: - Action Item Section
struct ActionItemSection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [TaskItem]
    var isCollapsible: Bool = false
    var onSelect: ((TaskItem) -> Void)? = nil
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section Header
            Button {
                if isCollapsible {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(items.count)")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if isCollapsible {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isCollapsible)
            
            // Items
            if isExpanded {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ActionItemCard(item: item) {
                        onSelect?(item)
                    }
                    
                    // Visible divider between all items
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(AppColors.border.opacity(0.8))
                            .frame(height: 1)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Action Item Card
struct ActionItemCard: View {
    let item: TaskItem
    let onTap: () -> Void
    
    private var priorityColor: Color {
        switch item.priority {
        case .urgent: return AppColors.error
        case .high: return AppColors.warning
        case .medium: return AppColors.info
        case .low: return AppColors.textTertiary
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .completed: return AppColors.success
        case .inProgress: return AppColors.primary
        case .cancelled: return AppColors.error
        case .pending: return AppColors.textSecondary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header Row
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    // Priority Indicator
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(item.status == .completed ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(item.status == .completed)
                            .multilineTextAlignment(.leading)
                        
                        if let description = item.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    Text(item.status.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Progress Bar (if has progress)
                if item.progressValue > 0 && item.status != .completed {
                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.primary)
                                    .frame(width: geometry.size.width * CGFloat(item.progressValue) / 100, height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(item.progressValue)%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // Footer Row
                HStack(spacing: AppSpacing.md) {
                    // Assignee
                    if let assignee = item.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 12))
                            Text(assignee.fullName)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // Due Date
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(dueDateColor(dueDate))
                    }
                    
                    Spacer()
                    
                    // Meta badges
                    HStack(spacing: 8) {
                        // Comments count
                        if item.commentsCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 10))
                                Text("\(item.commentsCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.textTertiary)
                        }
                        
                        // Evidence count
                        if item.evidenceCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10))
                                Text("\(item.evidenceCount)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.textTertiary)
                        }
                        
                        // AI Badge
                        if item.isAiExtracted == true {
                            HStack(spacing: 2) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("System")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        // Priority Badge
                        HStack(spacing: 2) {
                            Image(systemName: priorityIcon)
                                .font(.system(size: 10))
                            Text(item.priority.displayName)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(priorityColor)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
    
    private var priorityIcon: String {
        switch item.priority {
        case .urgent: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "exclamationmark"
        case .low: return "minus"
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d overdue"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private func dueDateColor(_ date: Date) -> Color {
        if date < Date() && item.status != .completed {
            return AppColors.error
        } else if Calendar.current.isDateInToday(date) {
            return AppColors.warning
        }
        return AppColors.textSecondary
    }
}

// MARK: - TaskPriority Extension
extension TaskPriority {
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Preview
#Preview {
    Text("Action Items Tab Preview")
}
