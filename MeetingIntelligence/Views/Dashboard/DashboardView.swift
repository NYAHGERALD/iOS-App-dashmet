//
//  DashboardView.swift
//  MeetingIntelligence
//
//  Enterprise Dashboard - Main Home Screen
//  Professional design with real-time backend data
//

import SwiftUI
import FirebaseAuth
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var dashboardService = DashboardService.shared
    @StateObject private var meetingViewModel = MeetingViewModel()
    
    @State private var showNewMeeting = false
    @State private var showQuickRecord = false
    @State private var selectedMeeting: Meeting?
    @State private var selectedPeriod: DashboardPeriodOption = .week
    @State private var greeting: String = "Good morning"
    
    var onProfileTap: (() -> Void)?
    var onMenuTap: (() -> Void)?
    
    enum DashboardPeriodOption: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var apiValue: String {
            switch self {
            case .today: return "today"
            case .week: return "week"
            case .month: return "month"
            case .all: return "all"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if dashboardService.isLoading && dashboardService.dashboardData == nil {
                    loadingView
                } else if let error = dashboardService.errorMessage, dashboardService.dashboardData == nil {
                    errorView(message: error)
                } else {
                    mainContent
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onMenuTap?()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        Menu {
                            ForEach(DashboardPeriodOption.allCases, id: \.self) { period in
                                Button {
                                    selectedPeriod = period
                                    Task { await loadDashboard() }
                                } label: {
                                    HStack {
                                        Text(period.rawValue)
                                        if period == selectedPeriod {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "calendar")
                                .font(.title3)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Button {
                            onProfileTap?()
                        } label: {
                            if let profileUrl = appState.profilePictureUrl,
                               let url = URL(string: profileUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill").font(.title2)
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppGradients.primary)
                            }
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
                await initializeDashboard()
            }
            .refreshable {
                await loadDashboard()
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                heroHeader
                quickActionsSection
                keyMetricsSection
                
                if let meetings = dashboardService.dashboardData?.meetings.recentMeetings, !meetings.isEmpty {
                    recentMeetingsSection(meetings: meetings)
                }
                
                if let pendingItems = dashboardService.dashboardData?.tasks.pendingItems, !pendingItems.isEmpty {
                    pendingTasksSection(tasks: pendingItems)
                }
                
                if let conflict = dashboardService.dashboardData?.conflictResolution, conflict.totalCases > 0 {
                    conflictResolutionSection(stats: conflict)
                }
                
                if let productivity = dashboardService.dashboardData?.productivity {
                    productivitySection(stats: productivity)
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
    }
    
    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppCornerRadius.xlarge)
                .fill(AppGradients.heroBackground)
                .frame(height: 160)
            
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
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(greeting)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                if let firstName = appState.firstName {
                    Text("Welcome, \(firstName)!")
                        .font(AppTypography.title)
                        .foregroundColor(.white)
                } else {
                    Text("Welcome back!")
                        .font(AppTypography.title)
                        .foregroundColor(.white)
                }
                
                Text(selectedPeriod.rawValue + " • " + getMotivationalMessage())
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
                DashboardQuickAction(title: "Record", icon: "mic.fill", color: AppColors.error) {
                    showQuickRecord = true
                }
                DashboardQuickAction(title: "New Meeting", icon: "calendar.badge.plus", color: AppColors.primary) {
                    showNewMeeting = true
                }
                DashboardQuickAction(title: "Add Task", icon: "plus.circle.fill", color: AppColors.success) { }
                DashboardQuickAction(title: "Upload", icon: "arrow.up.doc.fill", color: AppColors.warning) { }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: selectedPeriod.rawValue, subtitle: "Your productivity at a glance")
            
            if let data = dashboardService.dashboardData {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: AppSpacing.sm),
                    GridItem(.flexible(), spacing: AppSpacing.sm)
                ], spacing: AppSpacing.sm) {
                    StatCard(title: "Meetings", value: "\(data.meetings.total)", icon: "video.fill", color: AppColors.primary, trend: formatTrend(data.meetings.trend), trendUp: data.meetings.trendDirection == "up")
                    StatCard(title: "Hours Recorded", value: data.meetings.totalDurationFormatted, icon: "clock.fill", color: AppColors.secondary, trend: formatTrend(data.meetings.durationTrend), trendUp: data.meetings.durationTrendDirection == "up")
                    StatCard(title: "Action Items", value: "\(data.tasks.pending)", icon: "checklist", color: data.tasks.overdue > 0 ? AppColors.error : AppColors.warning, trend: formatTrend(data.tasks.pendingTrend), trendUp: data.tasks.pendingTrendDirection == "up")
                    StatCard(title: "Completed", value: "\(data.tasks.completed)", icon: "checkmark.circle.fill", color: AppColors.success, trend: formatTrend(data.tasks.completedTrend), trendUp: data.tasks.completedTrendDirection == "up")
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppColors.surface)
                            .frame(height: 100)
                            .shimmer()
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Recent Meetings Section
    private func recentMeetingsSection(meetings: [RecentMeeting]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Recent Meetings", subtitle: "\(meetings.count) meetings", actionTitle: "See All") { }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(meetings.prefix(5)) { meeting in
                        RecentMeetingCard(meeting: meeting) { }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }
    
    // MARK: - Pending Tasks Section
    private func pendingTasksSection(tasks: [PendingTaskItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            let overdueCount = tasks.filter { $0.isOverdue }.count
            SectionHeader(title: "Pending Action Items", subtitle: overdueCount > 0 ? "\(overdueCount) overdue" : "\(tasks.count) items", actionTitle: "See All") { }
            
            VStack(spacing: AppSpacing.xs) {
                ForEach(tasks.prefix(5)) { task in
                    PendingTaskRow(task: task)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Conflict Resolution Section
    private func conflictResolutionSection(stats: ConflictResolutionStats) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "HR & Conflict Resolution", subtitle: "\(stats.activeCases) active cases")
            
            HStack(spacing: AppSpacing.sm) {
                ConflictStatMiniCard(title: "Total", value: "\(stats.totalCases)", color: .blue)
                ConflictStatMiniCard(title: "Active", value: "\(stats.activeCases)", color: .orange)
                ConflictStatMiniCard(title: "Closed", value: "\(stats.closedCases)", color: .green)
                ConflictStatMiniCard(title: "Rate", value: "\(stats.resolutionRate)%", color: .purple)
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Productivity Section
    private func productivitySection(stats: ProductivityStats) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Productivity Insights")
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(AppGradients.primary)
                    Text("Performance Summary")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
                
                HStack(spacing: AppSpacing.lg) {
                    InsightMetric(icon: "checkmark.seal.fill", label: "Completion", value: "\(stats.completionRate)%")
                    InsightMetric(icon: "clock.fill", label: "Avg Duration", value: stats.avgMeetingDurationFormatted)
                    InsightMetric(icon: "list.bullet.clipboard", label: "Items/Meeting", value: String(format: "%.1f", stats.actionItemsPerMeeting))
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(AppSpacing.md)
            .cardStyle()
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text("Loading Dashboard...")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Unable to Load Dashboard")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadDashboard() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    private func initializeDashboard() async {
        updateGreeting()
        if let userId = appState.currentUserID, let orgId = appState.organizationId {
            meetingViewModel.configure(userId: userId, organizationId: orgId)
        }
        await loadDashboard()
    }
    
    private func loadDashboard() async {
        guard let userId = appState.currentUserID,
              let organizationId = appState.organizationId else {
            print("❌ Cannot load dashboard: Missing user context")
            return
        }
        
        do {
            try await dashboardService.fetchDashboardStats(
                userId: userId,
                organizationId: organizationId,
                facilityId: appState.facilityId,
                period: selectedPeriod.apiValue
            )
            try await dashboardService.fetchActivityFeed(userId: userId, organizationId: organizationId)
        } catch {
            print("❌ Dashboard load error: \(error)")
        }
    }
    
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { greeting = "Good morning" }
        else if hour < 17 { greeting = "Good afternoon" }
        else { greeting = "Good evening" }
    }
    
    private func getMotivationalMessage() -> String {
        ["Ready to make progress", "Let's capture great ideas", "Meetings, intelligently managed", "Transform conversations to action"].randomElement() ?? "Ready to make progress"
    }
    
    private func formatTrend(_ value: Int) -> String {
        value >= 0 ? "+\(value)%" : "\(value)%"
    }
}

// MARK: - Recent Meeting Card
struct RecentMeetingCard: View {
    let meeting: RecentMeeting
    let onTap: () -> Void
    
    private var meetingTypeColor: Color {
        switch meeting.meetingType {
        case "GENERAL": return .blue
        case "STANDUP": return .green
        case "ONE_ON_ONE": return .purple
        case "CLIENT": return .orange
        case "INTERVIEW": return .pink
        case "TRAINING": return .teal
        case "BRAINSTORM": return .yellow
        case "REVIEW": return .indigo
        default: return .gray
        }
    }
    
    private var meetingTypeIcon: String {
        switch meeting.meetingType {
        case "GENERAL": return "video.fill"
        case "STANDUP": return "person.3.fill"
        case "ONE_ON_ONE": return "person.2.fill"
        case "CLIENT": return "building.2.fill"
        case "INTERVIEW": return "person.badge.key.fill"
        case "TRAINING": return "graduationcap.fill"
        case "BRAINSTORM": return "lightbulb.fill"
        case "REVIEW": return "doc.text.magnifyingglass"
        default: return "video.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Image(systemName: meetingTypeIcon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(meetingTypeColor)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                    Spacer()
                    MeetingStatusBadge(status: meeting.status)
                }
                
                Text(meeting.displayTitle)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(meeting.formattedDate).font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: AppSpacing.sm) {
                    if let duration = meeting.durationFormatted {
                        HStack(spacing: 2) {
                            Image(systemName: "clock").font(.caption2)
                            Text(duration).font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.textTertiary)
                    }
                    if meeting.actionItemsCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist").font(.caption2)
                            Text("\(meeting.actionItemsCount)").font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.warning)
                    }
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
    let status: String
    
    private var statusColor: Color {
        switch status {
        case "DRAFT": return .gray
        case "RECORDING": return .red
        case "PROCESSING": return .orange
        case "COMPLETED": return .green
        case "PUBLISHED": return .blue
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case "DRAFT": return "Draft"
        case "RECORDING": return "Recording"
        case "PROCESSING": return "Processing"
        case "COMPLETED": return "Complete"
        case "PUBLISHED": return "Published"
        default: return status
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(statusText).font(AppTypography.caption2).fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }
}

// MARK: - Pending Task Row
struct PendingTaskRow: View {
    let task: PendingTaskItem
    
    private var priorityColor: Color {
        switch task.priority {
        case "URGENT": return .red
        case "HIGH": return .orange
        case "MEDIUM": return .yellow
        case "LOW": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(task.isOverdue ? AppColors.error : AppColors.textTertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: AppSpacing.xs) {
                    if let dueDate = task.dueDateFormatted {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar").font(.caption2)
                            Text(dueDate).font(AppTypography.caption)
                        }
                        .foregroundColor(task.isOverdue ? AppColors.error : AppColors.textSecondary)
                    }
                    if task.isAiExtracted {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles").font(.caption2)
                            Text("AI").font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
            Spacer()
            Circle().fill(priorityColor).frame(width: 8, height: 8)
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

// MARK: - Conflict Stat Mini Card
struct ConflictStatMiniCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(title).font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
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
