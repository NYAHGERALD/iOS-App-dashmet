//
//  MeetingListView.swift
//  MeetingIntelligence
//
//  Phase 3 - Meeting List View (Enterprise Edition)
//

import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @EnvironmentObject var appState: AppState
    
    @State private var showNewMeeting = false
    @State private var selectedMeeting: Meeting?
    @State private var showMeetingDetail = false
    @State private var showQuickRecord = false
    @State private var searchText = ""
    @State private var showFilterMenu = false
    
    // TODO: Replace with actual user context from AppState
    private let testUserId = "84f500d4-eb06-456f-8972-f706d89a5828"
    private let testOrganizationId = "a0f1ca04-ee78-439b-94df-95c4803ffbf7"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if viewModel.isLoading && viewModel.meetings.isEmpty {
                    loadingView
                } else if viewModel.hasNoMeetings {
                    emptyStateView
                } else {
                    meetingList
                }
            }
            .background(AppColors.background)
            .navigationTitle("Meetings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left: Filter Menu
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(MeetingFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectedFilter = filter
                                }
                            } label: {
                                HStack {
                                    Label(filter.rawValue, systemImage: filter.icon)
                                    
                                    Spacer()
                                    
                                    Text("\(countForFilter(filter))")
                                        .foregroundColor(.secondary)
                                    
                                    if viewModel.selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.title3)
                            
                            if viewModel.selectedFilter != .all {
                                Text(viewModel.selectedFilter.rawValue)
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .foregroundColor(viewModel.selectedFilter == .all ? AppColors.textPrimary : AppColors.primary)
                    }
                }
                
                // Right: Add Menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showNewMeeting = true
                        } label: {
                            Label("New Meeting", systemImage: "calendar.badge.plus")
                        }
                        
                        Button {
                            showQuickRecord = true
                        } label: {
                            Label("Quick Record", systemImage: "mic.fill")
                        }
                        
                        Divider()
                        
                        Button {
                            // Import recording
                        } label: {
                            Label("Import Recording", systemImage: "arrow.down.doc")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppGradients.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewMeeting) {
                NewMeetingView(viewModel: viewModel) { meeting in
                    selectedMeeting = meeting
                }
            }
            .fullScreenCover(isPresented: $showQuickRecord) {
                QuickRecordView(meetingViewModel: viewModel)
            }
            .sheet(item: $selectedMeeting) { meeting in
                MeetingDetailTabbedView(meeting: meeting, meetingViewModel: viewModel)
            }
            .refreshable {
                await viewModel.refreshMeetings()
            }
            .task {
                viewModel.configure(userId: testUserId, organizationId: testOrganizationId)
                await viewModel.fetchMeetings()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
            
            TextField("Search meetings...", text: $searchText)
                .font(AppTypography.body)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button {
            showQuickRecord = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(AppColors.error)
                        .shadow(color: AppColors.error.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
        .padding(.trailing, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }
    
    private func countForFilter(_ filter: MeetingFilter) -> Int {
        switch filter {
        case .all: return viewModel.meetings.count
        case .draft: return viewModel.draftCount
        case .processing: return viewModel.processingCount
        case .ready: return viewModel.readyCount
        case .published: return viewModel.publishedCount
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            // Skeleton cards
            ForEach(0..<4, id: \.self) { _ in
                MeetingSkeletonCard()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(AppGradients.primary)
            }
            
            VStack(spacing: AppSpacing.xs) {
                Text("No Meetings Yet")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Start recording to capture your first meeting\nand unlock System-powered insights")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Button {
                    showQuickRecord = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "mic.fill")
                        Text("Start Recording")
                    }
                    .primaryButtonStyle()
                }
                .frame(width: 220)
                
                Button {
                    showNewMeeting = true
                } label: {
                    Text("Create Meeting")
                        .secondaryButtonStyle()
                }
                .frame(width: 220)
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Meeting List
    private var meetingList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.filteredMeetings) { meeting in
                    EnterpriseMeetingRow(meeting: meeting) {
                        selectedMeeting = meeting
                    }
                    .contextMenu {
                        Button {
                            selectedMeeting = meeting
                        } label: {
                            Label("View Details", systemImage: "eye")
                        }
                        
                        if meeting.status == .draft {
                            Button {
                                // Start recording
                            } label: {
                                Label("Start Recording", systemImage: "mic.fill")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteMeeting(meetingId: meeting.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

// MARK: - Enterprise Meeting Row
struct EnterpriseMeetingRow: View {
    let meeting: Meeting
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Meeting Type Icon
                Image(systemName: meeting.meetingType.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: meeting.meetingType.color),
                                Color(hex: meeting.meetingType.color).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(meeting.displayTitle)
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Status badge
                        MeetingStatusBadge(status: meeting.status)
                    }
                    
                    HStack(spacing: AppSpacing.md) {
                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(meeting.formattedCreatedDate)
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                        
                        // Duration
                        if let duration = meeting.formattedDuration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(duration)
                                    .font(AppTypography.caption)
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Counters
                        HStack(spacing: AppSpacing.sm) {
                            if meeting.actionItemCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "checklist")
                                        .font(.caption2)
                                    Text("\(meeting.actionItemCount)")
                                        .font(AppTypography.caption)
                                }
                                .foregroundColor(AppColors.textTertiary)
                            }
                            
                            if meeting.participantCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.2")
                                        .font(.caption2)
                                    Text("\(meeting.participantCount)")
                                        .font(AppTypography.caption)
                                }
                                .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Skeleton Card
struct MeetingSkeletonCard: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            SkeletonView(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SkeletonView(width: 180, height: 16)
                    Spacer()
                    SkeletonView(width: 60, height: 20)
                }
                
                HStack(spacing: AppSpacing.md) {
                    SkeletonView(width: 80, height: 12)
                    SkeletonView(width: 60, height: 12)
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(AppTypography.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : AppColors.primary.opacity(0.15))
                        .foregroundColor(isSelected ? .white : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        AppGradients.primary
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? AppColors.primary.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Meeting Row View
struct MeetingRowView: View {
    let meeting: Meeting
    
    var body: some View {
        HStack(spacing: 14) {
            // Meeting Type Icon
            meetingTypeIcon
            
            // Meeting Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meeting.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                HStack(spacing: 8) {
                    // Type
                    Label(meeting.meetingType.displayName, systemImage: meeting.meetingType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Duration
                    if let duration = meeting.formattedDuration {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Date and stats
                HStack(spacing: 12) {
                    Text(meeting.formattedCreatedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Action items count
                    if meeting.actionItemCount > 0 {
                        Label("\(meeting.actionItemCount)", systemImage: "checklist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Participants count
                    if meeting.participantCount > 0 {
                        Label("\(meeting.participantCount)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var meetingTypeIcon: some View {
        Image(systemName: meeting.meetingType.icon)
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color(hex: meeting.meetingType.color))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: meeting.status.icon)
                .font(.caption2)
            
            Text(meeting.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: meeting.status.color).opacity(0.15))
        .foregroundColor(Color(hex: meeting.status.color))
        .clipShape(Capsule())
    }
}

// MARK: - Meeting Detail View (Basic)
struct MeetingDetailView: View {
    let meeting: Meeting
    @ObservedObject var viewModel: MeetingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showRecording = false
    
    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: meeting.meetingType.icon)
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: meeting.meetingType.color))
                        
                        Text(meeting.displayTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 4) {
                            Image(systemName: meeting.status.icon)
                            Text(meeting.status.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: meeting.status.color).opacity(0.15))
                        .foregroundColor(Color(hex: meeting.status.color))
                        .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                
                // Details Section
                Section("Details") {
                    LabeledContent("Type", value: meeting.meetingType.displayName)
                    
                    if let location = meeting.location, !location.isEmpty {
                        LabeledContent("Location", value: location)
                    }
                    
                    if let duration = meeting.formattedDuration {
                        LabeledContent("Duration", value: duration)
                    }
                    
                    LabeledContent("Created", value: meeting.formattedCreatedDate)
                    
                    if let recordedDate = meeting.formattedRecordedDate {
                        LabeledContent("Recorded", value: recordedDate)
                    }
                    
                    if !meeting.tags.isEmpty {
                        LabeledContent("Tags", value: meeting.tagsFormatted)
                    }
                }
                
                // Stats Section
                Section("Statistics") {
                    LabeledContent("Participants", value: "\(meeting.participantCount)")
                    LabeledContent("Bookmarks", value: "\(meeting.bookmarkCount)")
                    LabeledContent("Action Items", value: "\(meeting.actionItemCount)")
                    
                    if meeting.hasTranscript {
                        LabeledContent("Transcript Blocks", value: "\(meeting.transcriptBlockCount)")
                    }
                }
                
                // Actions Section
                Section {
                    if meeting.status.isEditable {
                        Button {
                            // TODO: Navigate to edit view
                        } label: {
                            Label("Edit Meeting", systemImage: "pencil")
                        }
                    }
                    
                    if meeting.status == .draft || meeting.status == .recording {
                        Button {
                            showRecording = true
                        } label: {
                            Label(
                                meeting.status == .recording ? "Continue Recording" : "Start Recording",
                                systemImage: "mic.fill"
                            )
                            .foregroundColor(.red)
                        }
                    }
                    
                    if meeting.hasTranscript {
                        Button {
                            // TODO: Navigate to transcript view
                        } label: {
                            Label("View Transcript", systemImage: "text.alignleft")
                        }
                    }
                    
                    if meeting.hasSummary {
                        Button {
                            // TODO: Navigate to summary view
                        } label: {
                            Label("View Summary", systemImage: "doc.text")
                        }
                    }
                    
                    if meeting.hasActionItems {
                        Button {
                            // TODO: Navigate to action items view
                        } label: {
                            Label("View Action Items", systemImage: "checklist")
                        }
                    }
                }
                
                // Delete Section
                Section {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteMeeting(meetingId: meeting.id)
                            dismiss()
                        }
                    } label: {
                        Label("Delete Meeting", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Meeting Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView(meeting: meeting, meetingViewModel: viewModel) { _ in
                    // Recording completed
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MeetingListView()
        .environmentObject(AppState())
}
