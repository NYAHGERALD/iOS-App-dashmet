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
    // NOT @ObservedObject — we only call methods on it, we don't need to observe its @Published state
    // Observing it causes the parent MeetingListView's state changes to re-render the entire detail sheet
    let meetingViewModel: MeetingViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: MeetingTab = .overview
    @State private var showRecording = false
    @State private var showPublishConfirmation = false
    @State private var showConsentModal = false
    @State private var showMenu = false
    @State private var shouldAutoExtractActionItems = false
    
    // OverviewTab presentation states (moved here to prevent reset on view recreation)
    @State private var showTranscriptReview = false
    @State private var showAISummary = false
    @State private var showAudioPlayer = false
    @State private var showAISummaryAudioPlayer = false
    
    // Data needed by presentation modifiers (synced from OverviewTab)
    @State private var rawTranscript: String = ""
    @State private var localRecordingURL: URL?
    @State private var savedAISummary: SavedAISummary?
    @StateObject private var aiSummaryAudioPlayer = URLAudioPlayer()
    
    init(meeting: Meeting, meetingViewModel: MeetingViewModel) {
        _viewModel = StateObject(wrappedValue: MeetingDetailViewModel(
            meeting: meeting,
            meetingViewModel: meetingViewModel
        ))
        self.meetingViewModel = meetingViewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Tab Bar (always visible)
            compactTabBar
            
            // Tab Content - Manual switcher
            Group {
                switch selectedTab {
                case .overview:
                    OverviewTab(
                        viewModel: viewModel,
                        meetingViewModel: meetingViewModel,
                        selectedTab: $selectedTab,
                        shouldExtractActionItems: $shouldAutoExtractActionItems,
                        showTranscriptReview: $showTranscriptReview,
                        showAISummary: $showAISummary,
                        showAudioPlayer: $showAudioPlayer,
                        showAISummaryAudioPlayer: $showAISummaryAudioPlayer,
                        showRecording: $showRecording,
                        showConsentModal: $showConsentModal,
                        rawTranscript: $rawTranscript,
                        localRecordingURL: $localRecordingURL,
                        savedAISummary: $savedAISummary,
                        aiSummaryAudioPlayer: aiSummaryAudioPlayer
                    )
                case .transcript:
                    TranscriptTab(viewModel: viewModel, rawTranscript: $rawTranscript)
                case .summary:
                    SummaryTab(
                        viewModel: viewModel,
                        savedAISummary: $savedAISummary,
                        showAISummaryAudioPlayer: $showAISummaryAudioPlayer,
                        showAISummary: $showAISummary,
                        rawTranscript: $rawTranscript
                    )
                }
            }
        }
        .task {
            await viewModel.loadFullDetails()
            // Load transcript and AI summary from local cache
            loadTranscriptFromLocalCache()
            loadSavedAISummary()
        }
        .background(AppColors.background)
        .navigationTitle(viewModel.meeting.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
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
            if viewModel.meeting.safeStatus == .ready || viewModel.meeting.safeStatus == .needsReview {
                Button("Publish") {
                    showPublishConfirmation = true
                }
            }
            
            if viewModel.meeting.safeStatus == .draft {
                Button("Record") {
                    showConsentModal = true
                }
            }
            
            if viewModel.meeting.safeStatus == .recording {
                Button("Resume Recording") {
                    showRecording = true
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
        // OverviewTab presentation modifiers (moved here to prevent reset on view recreation)
        .fullScreenCover(isPresented: $showTranscriptReview) {
            TranscriptReviewView(
                meeting: viewModel.meeting,
                rawTranscript: rawTranscript,
                recordingURL: localRecordingURL
            )
        }
        .sheet(isPresented: $showAudioPlayer) {
            AudioPlayerSheet(
                meeting: viewModel.meeting,
                recordingURL: localRecordingURL
            )
        }
        .fullScreenCover(isPresented: $showAISummary) {
            AISummaryView(
                meeting: viewModel.meeting,
                transcript: rawTranscript,
                onSummarySaved: {
                    // Reload saved AI summary from local cache so SummaryTab shows it immediately
                    loadSavedAISummary()
                    // Also refresh meeting data from backend
                    Task { await viewModel.refreshMeeting() }
                }
            )
        }
        .onChange(of: showAISummary) { _, newValue in
            if !newValue {
                // When AISummaryView dismisses, reload saved summary in case it was saved
                loadSavedAISummary()
            }
        }
        .sheet(isPresented: $showAISummaryAudioPlayer) {
            if let summary = savedAISummary, let audioUrl = summary.audioUrl, !audioUrl.isEmpty {
                AISummaryAudioPlayerSheet(
                    audioUrl: audioUrl,
                    meetingTitle: viewModel.meeting.title ?? "Meeting",
                    audioPlayer: aiSummaryAudioPlayer
                )
            }
        }
    }
    
    // MARK: - Compact Tab Bar
    private var compactTabBar: some View {
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
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.surface)
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
    
    /// Load saved transcript from local cache (UserDefaults) so it's available to all tabs
    private func loadTranscriptFromLocalCache() {
        let meetingId = viewModel.meeting.id
        
        // Try AI-processed transcript first
        if let transcriptData = UserDefaults.standard.data(forKey: "transcript_processed_\(meetingId)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["processedText"] as? String ?? json["rawText"] as? String,
           !text.isEmpty {
            rawTranscript = text
            return
        }
        
        // Then try final transcript
        if let transcriptData = UserDefaults.standard.data(forKey: "transcript_final_\(meetingId)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["processedText"] as? String ?? json["rawText"] as? String,
           !text.isEmpty {
            rawTranscript = text
            return
        }
        
        // Fall back to raw transcript
        if let transcriptData = UserDefaults.standard.data(forKey: "transcript_raw_\(meetingId)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["processedText"] as? String ?? json["rawText"] as? String,
           !text.isEmpty {
            rawTranscript = text
            return
        }
        
        // Legacy key support
        if let transcriptData = UserDefaults.standard.data(forKey: "rawTranscript_\(meetingId)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["rawText"] as? String,
           !text.isEmpty {
            rawTranscript = text
        }
    }
    
    /// Load saved AI summary from local cache (UserDefaults) or backend
    private func loadSavedAISummary() {
        let meetingId = viewModel.meeting.id
        
        // Try local cache first (AISummaryView saves here on save)
        if let data = UserDefaults.standard.data(forKey: "ai_summary_\(meetingId)"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            savedAISummary = SavedAISummary(
                id: json["id"] as? String ?? "",
                briefSummary: json["briefSummary"] as? String ?? "",
                narrative: json["narrative"] as? String ?? "",
                tone: json["tone"] as? String ?? "",
                objectives: json["objectives"] as? [String] ?? [],
                keyDiscussions: json["keyDiscussions"] as? [String] ?? [],
                actionItems: json["actionItems"] as? [String] ?? [],
                takeaways: json["takeaways"] as? [String] ?? [],
                audioUrl: json["audioUrl"] as? String,
                audioVoice: json["audioVoice"] as? String,
                generatedAt: json["generatedAt"] as? String ?? "",
                savedAt: json["savedAt"] as? Double ?? 0
            )
            return
        }
        
        // Fetch from backend if not cached
        Task {
            do {
                if let summary = try await MeetingSummaryService.shared.fetchAISummary(meetingId: meetingId) {
                    await MainActor.run {
                        savedAISummary = SavedAISummary(
                            id: summary.id,
                            briefSummary: summary.briefSummary ?? "",
                            narrative: summary.narrative ?? "",
                            tone: summary.tone ?? "",
                            objectives: summary.objectives ?? [],
                            keyDiscussions: summary.keyDiscussions ?? [],
                            actionItems: summary.actionItems ?? [],
                            takeaways: summary.takeaways ?? [],
                            audioUrl: summary.audioUrl,
                            audioVoice: summary.audioVoice,
                            generatedAt: summary.generatedAt ?? "",
                            savedAt: Date().timeIntervalSince1970
                        )
                        
                        // Cache locally
                        let localData: [String: Any] = [
                            "id": summary.id,
                            "briefSummary": summary.briefSummary ?? "",
                            "narrative": summary.narrative ?? "",
                            "tone": summary.tone ?? "",
                            "objectives": summary.objectives ?? [],
                            "keyDiscussions": summary.keyDiscussions ?? [],
                            "actionItems": summary.actionItems ?? [],
                            "takeaways": summary.takeaways ?? [],
                            "audioUrl": summary.audioUrl ?? "",
                            "audioVoice": summary.audioVoice ?? "",
                            "generatedAt": summary.generatedAt ?? "",
                            "savedAt": Date().timeIntervalSince1970
                        ]
                        if let cacheData = try? JSONSerialization.data(withJSONObject: localData) {
                            UserDefaults.standard.set(cacheData, forKey: "ai_summary_\(meetingId)")
                        }
                    }
                }
            } catch {
                print("⚠️ Failed to fetch AI summary: \(error.localizedDescription)")
            }
        }
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
            HStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : AppColors.primary.opacity(0.15))
                        .foregroundColor(isSelected ? .white : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
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
    
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .transcript: return "text.alignleft"
        case .summary: return "sparkles"
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
        await MainActor.run { isLoading = true }
        
        let detailedMeeting = await meetingViewModel.getMeetingDetails(meetingId: meeting.id)
        
        await MainActor.run {
            if let m = detailedMeeting {
                meeting = m
                if let t = m.transcript { transcript = t }
                if let s = m.summary { summary = s }
                if let a = m.actionItems { actionItems = a }
                if let att = m.attachments { attachments = att }
            }
            isLoading = false
        }
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
