//
//  MeetingDetailTabbedView.swift
//  MeetingIntelligence
//
//  Phase 2 - Meeting Detail View with Tabs
//  Modern Apple-like design with glassmorphism
//

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth

// MARK: - Meeting Detail Tabbed View
struct MeetingDetailTabbedView: View {
    @StateObject private var viewModel: MeetingDetailViewModel
    @ObservedObject var meetingViewModel: MeetingViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: MeetingTab = .overview
    @State private var showRecording = false
    @State private var showPublishConfirmation = false
    @State private var showConsentModal = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showMenu = false
    @State private var shouldAutoExtractActionItems = false
    
    init(meeting: Meeting, meetingViewModel: MeetingViewModel) {
        _viewModel = StateObject(wrappedValue: MeetingDetailViewModel(
            meeting: meeting,
            meetingViewModel: meetingViewModel
        ))
        self.meetingViewModel = meetingViewModel
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            AppColors.background.ignoresSafeArea()
            
            // Main Content
            VStack(spacing: 0) {
                // Compact Tab Bar with blur effect
                compactTabBar
                    .opacity(scrollOffset < -50 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset < -50)
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    OverviewTab(viewModel: viewModel, meetingViewModel: meetingViewModel, selectedTab: $selectedTab, shouldExtractActionItems: $shouldAutoExtractActionItems)
                        .tag(MeetingTab.overview)
                    
                    TranscriptTab(viewModel: viewModel)
                        .tag(MeetingTab.transcript)
                    
                    SummaryTab(viewModel: viewModel)
                        .tag(MeetingTab.summary)
                    
                    ActionItemsTab(viewModel: viewModel, shouldAutoExtract: $shouldAutoExtractActionItems)
                        .tag(MeetingTab.actionItems)
                    
                    AttachmentsTab(viewModel: viewModel)
                        .tag(MeetingTab.attachments)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // Floating Header Buttons (hidden on Action Items tab which has its own header)
            if selectedTab != .actionItems {
                floatingHeader
            }
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(meeting: viewModel.meeting, meetingViewModel: viewModel.meetingViewModel) { _ in
                Task {
                    await viewModel.refreshMeeting()
                }
            }
        }
        .sheet(isPresented: $showConsentModal) {
            RecordingConsentView(
                meetingId: viewModel.meeting.id,
                userInfo: getCurrentUserInfo(),
                onConsent: {
                    showConsentModal = false
                    showRecording = true
                },
                onDecline: {
                    showConsentModal = false
                }
            )
        }
        .confirmationDialog("Meeting Options", isPresented: $showMenu, titleVisibility: .hidden) {
            if viewModel.meeting.status == .ready || viewModel.meeting.status == .needsReview {
                Button("Publish") {
                    showPublishConfirmation = true
                }
            }
            
            if viewModel.meeting.status == .draft {
                Button("Record") {
                    showConsentModal = true
                }
            }
            
            Button("Share") {
                // Share meeting
            }
            
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteMeeting()
                    dismiss()
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .alert("Publish Meeting?", isPresented: $showPublishConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Publish") {
                Task {
                    await viewModel.publishMeeting()
                }
            }
        } message: {
            Text("This will make the meeting results and action items visible to all participants.")
        }
        .task {
            await viewModel.loadFullDetails()
        }
    }
    
    // MARK: - Floating Header
    private var floatingHeader: some View {
        ZStack {
            // Centered Title
            Text(viewModel.meeting.displayTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 200)
            
            // Buttons on sides
            HStack {
                // Close Button - Glassmorphism style
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Spacer()
                
                // More Options Button - Glassmorphism style
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Safe area top
        .padding(.bottom, 12)
        .background(
            // Blur background that appears on scroll
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(scrollOffset < -50 ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: scrollOffset < -50)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Compact Tab Bar
    private var compactTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(MeetingTab.allCases, id: \.self) { tab in
                    CompactTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        badge: viewModel.badgeCount(for: tab)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
    
    // MARK: - Helpers
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
}

// MARK: - Compact Tab Button
struct CompactTabButton: View {
    let tab: MeetingTab
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : AppColors.primary.opacity(0.15))
                        .foregroundColor(isSelected ? .white : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppColors.primary)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Tabs
enum MeetingTab: String, CaseIterable {
    case overview = "Overview"
    case transcript = "Transcript"
    case summary = "Summary"
    case actionItems = "Action Items"
    case attachments = "Attachments"
    
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .transcript: return "text.alignleft"
        case .summary: return "sparkles"
        case .actionItems: return "checklist"
        case .attachments: return "paperclip"
        }
    }
}

// MARK: - Meeting Detail View Model
@MainActor
class MeetingDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    let meetingViewModel: MeetingViewModel
    
    // MARK: - Published Properties
    @Published var meeting: Meeting
    @Published var transcript: [TranscriptBlock] = []
    @Published var summary: MeetingSummary?
    @Published var actionItems: [TaskItem] = []
    @Published var attachments: [MeetingAttachment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Audio playback
    @Published var isPlaying: Bool = false
    @Published var currentPlaybackTime: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // Search
    @Published var transcriptSearchText: String = ""
    
    // MARK: - User Context (for action items)
    var userId: String? {
        meetingViewModel.userId
    }
    
    // MARK: - Computed Properties
    var filteredTranscript: [TranscriptBlock] {
        if transcriptSearchText.isEmpty {
            return transcript
        }
        return transcript.filter { 
            $0.content.localizedCaseInsensitiveContains(transcriptSearchText) ||
            $0.speakerLabel.localizedCaseInsensitiveContains(transcriptSearchText)
        }
    }
    
    var uniqueSpeakers: [String] {
        Array(Set(transcript.map { $0.speakerLabel })).sorted()
    }
    
    var pendingActionItems: [TaskItem] {
        actionItems.filter { $0.status != .completed }
    }
    
    var completedActionItems: [TaskItem] {
        actionItems.filter { $0.status == .completed }
    }
    
    // MARK: - Initialization
    init(meeting: Meeting, meetingViewModel: MeetingViewModel) {
        self.meeting = meeting
        self.meetingViewModel = meetingViewModel
        
        // Load inline data if available
        if let inlineTranscript = meeting.transcript {
            self.transcript = inlineTranscript
        }
        if let inlineSummary = meeting.summary {
            self.summary = inlineSummary
        }
        if let inlineActionItems = meeting.actionItems {
            self.actionItems = inlineActionItems
        }
        if let inlineAttachments = meeting.attachments {
            self.attachments = inlineAttachments
        }
    }
    
    // MARK: - Public Methods
    
    func loadFullDetails() async {
        isLoading = true
        
        do {
            if let detailedMeeting = await meetingViewModel.getMeetingDetails(meetingId: meeting.id) {
                meeting = detailedMeeting
                
                if let t = detailedMeeting.transcript {
                    transcript = t
                }
                if let s = detailedMeeting.summary {
                    summary = s
                }
                if let a = detailedMeeting.actionItems {
                    actionItems = a
                }
                if let att = detailedMeeting.attachments {
                    attachments = att
                }
            }
        }
        
        isLoading = false
    }
    
    func refreshMeeting() async {
        await loadFullDetails()
    }
    
    func deleteMeeting() async {
        let _ = await meetingViewModel.deleteMeeting(meetingId: meeting.id)
    }
    
    func publishMeeting() async {
        let _ = await meetingViewModel.updateMeeting(
            meetingId: meeting.id,
            status: .published
        )
        await refreshMeeting()
    }
    
    func badgeCount(for tab: MeetingTab) -> Int? {
        switch tab {
        case .transcript:
            return transcript.isEmpty ? nil : transcript.count
        case .actionItems:
            return actionItems.isEmpty ? nil : actionItems.count
        case .attachments:
            return attachments.isEmpty ? nil : attachments.count
        default:
            return nil
        }
    }
    
    // MARK: - Audio Playback
    
    func playFromTimestamp(_ timestamp: Int) {
        // TODO: Implement audio playback from timestamp
        // This would require the audio file to be downloaded first
        print("▶️ Play from \(timestamp) seconds")
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        playbackTimer?.invalidate()
    }
}

// MARK: - Preview
#Preview {
    Text("Meeting Detail Preview")
}
