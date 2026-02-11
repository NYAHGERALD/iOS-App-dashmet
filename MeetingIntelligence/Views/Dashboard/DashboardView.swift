//
//  DashboardView.swift
//  MeetingIntelligence
//
//  Enterprise Dashboard - Main Home Screen
//

import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var meetingViewModel = MeetingViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    
    @State private var showNewMeeting = false
    @State private var showQuickRecord = false
    @State private var selectedMeeting: Meeting?
    @State private var greeting: String = "Good morning"
    
    var onProfileTap: (() -> Void)?
    
    private let testUserId = "84f500d4-eb06-456f-8972-f706d89a5828"
    private let testOrganizationId = "a0f1ca04-ee78-439b-94df-95c4803ffbf7"
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    // Hero Header
                    heroHeader
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Stats Overview
                    statsSection
                    
                    // Recent Meetings
                    recentMeetingsSection
                    
                    // Pending Tasks
                    pendingTasksSection
                    
                    // Insights Teaser
                    insightsSection
                }
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                        Text("MeetingIQ")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            // Notifications
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.title3)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                // Notification badge
                                Circle()
                                    .fill(AppColors.error)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                        
                        Button {
                            onProfileTap?()
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppGradients.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewMeeting) {
                NewMeetingView(viewModel: meetingViewModel)
            }
            .fullScreenCover(isPresented: $showQuickRecord) {
                QuickRecordView(meetingViewModel: meetingViewModel)
            }
            .sheet(item: $selectedMeeting) { meeting in
                MeetingDetailTabbedView(meeting: meeting, meetingViewModel: meetingViewModel)
            }
            .task {
                updateGreeting()
                meetingViewModel.configure(userId: testUserId, organizationId: testOrganizationId)
                taskViewModel.configure(userId: testUserId, organizationId: testOrganizationId)
                await meetingViewModel.fetchMeetings()
                await taskViewModel.fetchTasks()
            }
            .refreshable {
                await meetingViewModel.refreshMeetings()
                await taskViewModel.refreshTasks()
            }
        }
    }
    
    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: AppCornerRadius.xlarge)
                .fill(AppGradients.heroBackground)
                .frame(height: 180)
            
            // Decorative elements
            GeometryReader { geometry in
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .offset(x: geometry.size.width - 80, y: -30)
                
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: geometry.size.width - 40, y: 80)
            }
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(greeting)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(getUserDisplayName())
                    .font(AppTypography.title)
                    .foregroundColor(.white)
                
                Text(getMotivationalMessage())
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, AppSpacing.xxs)
            }
            .padding(AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Quick Actions")
            
            HStack(spacing: AppSpacing.lg) {
                DashboardQuickAction(
                    title: "Record",
                    icon: "mic.fill",
                    color: AppColors.error
                ) {
                    showQuickRecord = true
                }
                
                DashboardQuickAction(
                    title: "New Meeting",
                    icon: "calendar.badge.plus",
                    color: AppColors.primary
                ) {
                    showNewMeeting = true
                }
                
                DashboardQuickAction(
                    title: "Add Task",
                    icon: "plus.circle.fill",
                    color: AppColors.success
                ) {
                    // Add task
                }
                
                DashboardQuickAction(
                    title: "Upload",
                    icon: "arrow.up.doc.fill",
                    color: AppColors.warning
                ) {
                    // Upload recording
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "This Week",
                subtitle: "Your productivity at a glance"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm)
            ], spacing: AppSpacing.sm) {
                StatCard(
                    title: "Meetings",
                    value: "\(meetingViewModel.meetings.count)",
                    icon: "video.fill",
                    color: AppColors.primary,
                    trend: "+12%",
                    trendUp: true
                )
                
                StatCard(
                    title: "Hours Recorded",
                    value: formatTotalHours(),
                    icon: "clock.fill",
                    color: AppColors.secondary,
                    trend: "+8%",
                    trendUp: true
                )
                
                StatCard(
                    title: "Action Items",
                    value: "\(taskViewModel.tasks.filter { $0.status != .completed }.count)",
                    icon: "checklist",
                    color: AppColors.warning,
                    trend: "-5%",
                    trendUp: false
                )
                
                StatCard(
                    title: "Completed",
                    value: "\(taskViewModel.tasks.filter { $0.status == .completed }.count)",
                    icon: "checkmark.circle.fill",
                    color: AppColors.success,
                    trend: "+23%",
                    trendUp: true
                )
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Recent Meetings
    private var recentMeetingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Recent Meetings",
                subtitle: "Your latest recordings",
                actionTitle: "See All"
            ) {
                // Navigate to meetings tab
            }
            
            if meetingViewModel.meetings.isEmpty {
                EmptyMeetingsCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(meetingViewModel.meetings.prefix(5)) { meeting in
                            MeetingCard(meeting: meeting) {
                                selectedMeeting = meeting
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
    }
    
    // MARK: - Pending Tasks
    private var pendingTasksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Pending Action Items",
                subtitle: "Tasks requiring your attention",
                actionTitle: "See All"
            ) {
                // Navigate to tasks tab
            }
            
            VStack(spacing: AppSpacing.xs) {
                let pendingTasks = taskViewModel.tasks.filter { $0.status != .completed }.prefix(3)
                
                if pendingTasks.isEmpty {
                    EmptyTasksCard()
                } else {
                    ForEach(pendingTasks) { task in
                        TaskRowCard(task: task) {
                            // Toggle task
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "System Insights")
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(AppGradients.primary)
                    
                    Text("Weekly Summary")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text("Coming Soon")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppGradients.primary)
                        .clipShape(Capsule())
                }
                
                Text("Get System-powered insights about your meeting patterns, speaking time distribution, and action item completion rates.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                // Preview metrics
                HStack(spacing: AppSpacing.lg) {
                    InsightMetric(icon: "waveform", label: "Avg. Duration", value: "45 min")
                    InsightMetric(icon: "person.2", label: "Participants", value: "4.2 avg")
                    InsightMetric(icon: "checkmark", label: "Completion", value: "78%")
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(AppSpacing.md)
            .cardStyle()
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Helper Methods
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            greeting = "Good morning"
        } else if hour < 17 {
            greeting = "Good afternoon"
        } else {
            greeting = "Good evening"
        }
    }
    
    private func getUserDisplayName() -> String {
        // TODO: Get from user profile
        return "Welcome back!"
    }
    
    private func getMotivationalMessage() -> String {
        let messages = [
            "Ready to make today productive?",
            "Let's capture great ideas today!",
            "Your meetings, intelligently managed.",
            "Transform conversations into action."
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    private func formatTotalHours() -> String {
        let totalMinutes = meetingViewModel.meetings.compactMap { $0.duration }.reduce(0, +)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Meeting Card
struct MeetingCard: View {
    let meeting: Meeting
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header with icon and status
                HStack {
                    Image(systemName: meeting.meetingType.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(hex: meeting.meetingType.color))
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                    
                    Spacer()
                    
                    MeetingStatusBadge(status: meeting.status)
                }
                
                // Title
                Text(meeting.displayTitle)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Meta info
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(meeting.formattedCreatedDate)
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)
                
                // Duration or action items
                if let duration = meeting.formattedDuration {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(duration)
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .frame(width: 180)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Status Badge
struct MeetingStatusBadge: View {
    let status: MeetingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: status.color))
                .frame(width: 6, height: 6)
            
            Text(status.displayName)
                .font(AppTypography.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: status.color).opacity(0.12))
        .foregroundColor(Color(hex: status.color))
        .clipShape(Capsule())
    }
}

// MARK: - Task Row Card
struct TaskRowCard: View {
    let task: TaskItem
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onToggle) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.status == .completed ? AppColors.success : AppColors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDueDate(dueDate))
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(isOverdue(dueDate) ? AppColors.error : AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            // Priority indicator
            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 8, height: 8)
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: return AppColors.error
        case .high: return AppColors.warning
        case .medium: return AppColors.info
        case .low: return AppColors.textTertiary
        }
    }
}

// MARK: - Insight Metric
struct InsightMetric: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.primary)
            
            Text(value)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Empty States
struct EmptyMeetingsCard: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "mic.slash")
                .font(.system(size: 32))
                .foregroundStyle(AppGradients.primary)
            
            Text("No meetings yet")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Start recording to see your meetings here")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct EmptyTasksCard: View {
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("All caught up!")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("No pending action items")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

// MARK: - Quick Record View
struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var meetingViewModel: MeetingViewModel
    
    @State private var selectedType: MeetingType = .general
    @State private var isCreating = false
    @State private var createdMeeting: Meeting?
    @State private var showRecording = false
    @State private var showConsentModal = false
    @State private var pendingMeetingForConsent: Meeting?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                // Large mic icon
                ZStack {
                    Circle()
                        .fill(AppColors.error.opacity(0.15))
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .fill(AppColors.error.opacity(0.25))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.error)
                }
                
                Text("Quick Record")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.textPrimary)
                
                // Selected meeting type display
                HStack(spacing: 8) {
                    Image(systemName: selectedType.icon)
                        .foregroundColor(Color(hex: selectedType.color))
                    Text(selectedType.displayName)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: selectedType.color).opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                // Start button
                Button {
                    Task {
                        await startQuickRecord()
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "record.circle")
                            Text("Start Recording")
                        }
                    }
                    .primaryButtonStyle()
                }
                .disabled(isCreating)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                // Meeting type selector in hamburger menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                HStack {
                                    Label(type.displayName, systemImage: type.icon)
                                    
                                    if selectedType == type {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                if let meeting = createdMeeting {
                    RecordingView(meeting: meeting, meetingViewModel: meetingViewModel) { _ in
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showConsentModal) {
                if let meeting = pendingMeetingForConsent {
                    RecordingConsentView(
                        meetingId: meeting.id,
                        userInfo: getCurrentUserInfo(),
                        onConsent: {
                            // Consent given - proceed with recording
                            showConsentModal = false
                            createdMeeting = meeting
                            showRecording = true
                        },
                        onDecline: {
                            // User declined - close consent modal
                            showConsentModal = false
                            pendingMeetingForConsent = nil
                        }
                    )
                }
            }
        }
    }
    
    private func getCurrentUserInfo() -> ConsentUserInfo {
        let authService = FirebaseAuthService.shared
        
        return ConsentUserInfo(
            uid: authService.currentUser?.uid ?? "",
            email: authService.currentUser?.email ?? "",
            firstName: appState.firstName ?? "",
            lastName: appState.lastName ?? "",
            phoneNumber: authService.currentUser?.phoneNumber
        )
    }
    
    private func startQuickRecord() async {
        isCreating = true
        
        if let meeting = await meetingViewModel.createMeeting(
            title: nil,
            meetingType: selectedType,
            location: nil,
            tags: []
        ) {
            isCreating = false
            // Show consent modal instead of directly showing recording
            pendingMeetingForConsent = meeting
            showConsentModal = true
        } else {
            isCreating = false
        }
    }
}

struct QuickTypeButton: View {
    let type: MeetingType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(hex: type.color))
                    .frame(width: 56, height: 56)
                    .background(
                        isSelected ? Color(hex: type.color) : Color(hex: type.color).opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                
                Text(type.displayName)
                    .font(AppTypography.caption)
                    .foregroundColor(isSelected ? Color(hex: type.color) : AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(AppState())
}
