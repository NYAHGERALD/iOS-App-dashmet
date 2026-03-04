//
//  OverviewTab.swift
//  MeetingIntelligence
//
//  Phase 2 - Overview Tab for Meeting Detail
//  Modern Apple-like design with compact layout
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - SavedAISummary Model
struct SavedAISummary {
    let id: String
    let briefSummary: String
    let narrative: String
    let tone: String
    let objectives: [String]
    let keyDiscussions: [String]
    let takeaways: [String]
    let audioUrl: String?
    let audioVoice: String?
    let generatedAt: String
    let savedAt: Double
}

// MARK: - URL Audio Player for streaming audio
@MainActor
class URLAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func loadFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        
        isLoading = true
        error = nil
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            self.error = "Failed to configure audio session"
            isLoading = false
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe when ready to play
        playerItem.asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                let durationSeconds = playerItem.asset.duration.seconds
                if !durationSeconds.isNaN && !durationSeconds.isInfinite {
                    self.duration = durationSeconds
                }
                
                self.setupTimeObserver()
            }
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentTime = time.seconds
                if self.duration > 0 {
                    self.progress = time.seconds / self.duration
                }
                
                // Check if playback ended
                if let player = self.player, player.currentItem?.status == .readyToPlay {
                    if time.seconds >= self.duration - 0.1 {
                        self.isPlaying = false
                    }
                }
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let time = CMTime(seconds: progress * duration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
        currentTime = progress * duration
    }
    
    func skip(by seconds: Double) {
        guard let player = player else { return }
        let newTime = max(0, min(duration, currentTime + seconds))
        let time = CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
        currentTime = newTime
        if duration > 0 {
            progress = newTime / duration
        }
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
    }
}

struct OverviewTab: View {
    @ObservedObject var viewModel: MeetingDetailViewModel
    // NOT @ObservedObject — we never read its @Published properties in our body
    let meetingViewModel: MeetingViewModel
    @Binding var selectedTab: MeetingTab
    @Binding var shouldExtractActionItems: Bool
    
    // Presentation states (passed from parent to prevent reset on view recreation)
    @Binding var showTranscriptReview: Bool
    @Binding var showAISummary: Bool
    @Binding var showAudioPlayer: Bool
    @Binding var showAISummaryAudioPlayer: Bool
    @Binding var showRecording: Bool
    @Binding var showConsentModal: Bool
    
    // Data synced to parent for presentation modifiers
    @Binding var rawTranscript: String
    @Binding var localRecordingURL: URL?
    @Binding var savedAISummary: SavedAISummary?
    var aiSummaryAudioPlayer: URLAudioPlayer
    @State private var showTranscriptGeneration = false
    @State private var isTranscriptFromDatabase: Bool = false
    @State private var hasLoadedInitialData = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Resume Recording Banner (when status is recording)
                if viewModel.meeting.safeStatus == .recording {
                    resumeRecordingBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Compact Hero Section
                compactHeroSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                
                // Content Sections with thin separators
                VStack(spacing: 0) {
                    // Status & Quick Info
                    if hasRecording || hasTranscript {
                        compactStatusSection
                        thinSeparator
                    }
                    
                    // Meeting Details
                    compactDetailsSection
                    thinSeparator
                    
                    // Recording Actions (when recording exists but no transcript)
                    if hasRecording && !hasTranscript {
                        recordingActionsSection
                        thinSeparator
                    }
                    
                    // Timeline
                    compactTimelineSection
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                
                // Meeting Type & Status Card
                meetingTypeStatusCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                // Created By Card
                if viewModel.meeting.creator != nil {
                    createdByCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                
                // Stats Cards
                statsCardsSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                // Record Meeting button for Draft meetings
                if viewModel.meeting.safeStatus == .draft {
                    Button {
                        showConsentModal = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 22))
                            Text("Record Meeting")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.49, green: 0.32, blue: 0.95),
                                    Color(red: 0.35, green: 0.22, blue: 0.89)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                // Bottom spacing
                Color.clear.frame(height: 100)
            }
        }
        .refreshable {
            await viewModel.refreshMeeting()
            await loadLocalDataAsync()
        }
        .task {
            guard !hasLoadedInitialData else { return }
            hasLoadedInitialData = true
            await loadLocalDataAsync()
        }
        .onChange(of: showAudioPlayer) { _, newValue in
            if !newValue {
                Task { await loadLocalDataAsync() }
            }
        }
        .onChange(of: showTranscriptReview) { _, newValue in
            if !newValue {
                Task { await loadLocalDataAsync() }
            }
        }
        .onChange(of: showAISummary) { _, newValue in
            if !newValue {
                Task { await loadLocalDataAsync() }
            }
        }
        .onChange(of: showRecording) { _, newValue in
            if !newValue {
                Task { await loadLocalDataAsync() }
            }
        }
        .fullScreenCover(isPresented: $showTranscriptGeneration) {
            if let recordingURL = localRecordingURL {
                TranscriptGenerationView(
                    audioURL: recordingURL,
                    meeting: viewModel.meeting,
                    onComplete: { generatedTranscript in
                        // Save generated transcript and navigate to review
                        let text = generatedTranscript.processedText.isEmpty ? generatedTranscript.rawText : generatedTranscript.processedText
                        rawTranscript = text
                        
                        // Persist to UserDefaults immediately so transcript survives
                        // view dismissal and fresh opens (don't rely on "Save & Continue")
                        let meetingId = viewModel.meeting.id
                        
                        // Write to "rawTranscript_" key (legacy, read by all loaders)
                        let rawData: [String: Any] = [
                            "rawText": generatedTranscript.rawText,
                            "timestamp": Date().timeIntervalSince1970,
                            "wordCount": generatedTranscript.wordCount
                        ]
                        if let data = try? JSONSerialization.data(withJSONObject: rawData) {
                            UserDefaults.standard.set(data, forKey: "rawTranscript_\(meetingId)")
                        }
                        
                        // Write to "transcript_processed_" key (primary key read by loaders)
                        let processedData: [String: Any] = [
                            "type": "processed",
                            "rawText": generatedTranscript.rawText,
                            "processedText": generatedTranscript.processedText,
                            "wordCount": generatedTranscript.wordCount,
                            "duration": generatedTranscript.duration,
                            "savedAt": Date().timeIntervalSince1970
                        ]
                        if let data = try? JSONSerialization.data(withJSONObject: processedData) {
                            UserDefaults.standard.set(data, forKey: "transcript_processed_\(meetingId)")
                        }
                        
                        showTranscriptGeneration = false
                        
                        // Navigate to transcript review after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showTranscriptReview = true
                        }
                    },
                    onCancel: {
                        showTranscriptGeneration = false
                    }
                )
            }
        }
    }
    
    // MARK: - Resume Recording Banner
    private var resumeRecordingBanner: some View {
        Button {
            showRecording = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "record.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording in Progress")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Tap to resume recording")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Thin Separator
    private var thinSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
    
    // MARK: - Compact Hero Section
    private var compactHeroSection: some View {
        VStack(alignment: .center, spacing: 12) {
            // Meeting Type Badge - Centered
            HStack(spacing: 6) {
                Image(systemName: meetingTypeIcon)
                    .font(.system(size: 13))
                Text(viewModel.meeting.safeMeetingType.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.primary.opacity(0.15))
            .clipShape(Capsule())
            
            // Date & Time - Centered
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                    Text(formattedDate)
                        .font(.system(size: 15))
                }
                
                if let duration = viewModel.meeting.duration {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text(formatDuration(duration))
                            .font(.system(size: 15))
                    }
                }
            }
            .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Compact Status Section
    private var compactStatusSection: some View {
        HStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            // Quick actions - only show play button if local file exists
            if localRecordingURL != nil && viewModel.meeting.recordingUrl != nil {
                Button {
                    showAudioPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            } else if let summary = savedAISummary, !summary.narrative.isEmpty {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(16)
    }
    
    // MARK: - Compact Details Section
    private var compactDetailsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            sectionHeader(title: "Details", icon: "info.circle")
            
            VStack(spacing: 12) {
                // Language (from DB)
                detailRow(icon: "globe", label: "Language", value: {
                    if let lang = viewModel.meeting.language, !lang.isEmpty {
                        return languageName(for: lang)
                    }
                    return "None"
                }())
                
                // Location Type (from DB)
                detailRow(icon: "building.2", label: "Type", value: {
                    if let locType = viewModel.meeting.locationType, !locType.isEmpty {
                        return locType
                    }
                    return "None"
                }())
                
                // Location (from DB)
                detailRow(icon: "location", label: "Location", value: {
                    if let location = viewModel.meeting.location, !location.isEmpty {
                        return location
                    }
                    return "None"
                }())
                
                // Department (from DB)
                detailRow(icon: "person.3", label: "Department", value: {
                    if let dept = viewModel.meeting.department?.name, !dept.isEmpty {
                        return dept
                    }
                    return "None"
                }())
                
                // Objective (from DB)
                detailRow(icon: "target", label: "Objective", value: {
                    if let objective = viewModel.meeting.objective, !objective.isEmpty {
                        return objective
                    }
                    return "None"
                }())
                
                // Scheduled At (from DB)
                detailRow(icon: "calendar", label: "Scheduled", value: {
                    if let scheduledDate = viewModel.meeting.formattedScheduledDate {
                        return scheduledDate
                    }
                    return "None"
                }())
                
                // Duration (from DB)
                detailRow(icon: "timer", label: "Duration", value: {
                    if let duration = viewModel.meeting.duration, duration > 0 {
                        return formatDuration(duration)
                    }
                    return "None"
                }())
                
                // Confidentiality Level (from DB)
                detailRow(icon: "lock.shield", label: "Visibility", value: {
                    if let level = viewModel.meeting.confidentialityLevel, !level.isEmpty {
                        return level.replacingOccurrences(of: "_", with: " ").capitalized
                    }
                    return "None"
                }())
                
                // Tags (from DB)
                if viewModel.meeting.safeTags.isEmpty {
                    detailRow(icon: "tag", label: "Tags", value: "None")
                } else {
                    HStack(alignment: .top) {
                        Image(systemName: "tag")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 20)
                        
                        Text("Tags")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(viewModel.meeting.safeTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppColors.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Agenda Items (from DB)
                if viewModel.meeting.safeAgendaItems.isEmpty {
                    detailRow(icon: "list.bullet", label: "Agenda", value: "None")
                } else {
                    HStack(alignment: .top) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 20)
                        
                        Text("Agenda")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(viewModel.meeting.safeAgendaItems.enumerated()), id: \.offset) { index, item in
                                Text("\(index + 1). \(item)")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Recording Actions Section (when recording exists but no transcript)
    private var recordingActionsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            sectionHeader(title: "Recording", icon: "waveform")
            
            VStack(spacing: 12) {
                // Info message
                if viewModel.meeting.recordingUrl == nil, let summary = savedAISummary, !summary.narrative.isEmpty {
                    // Dashmet Audio Recording Policy compliance notice
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.success)
                        
                        Text("Original meeting audio recording has been deleted from the system completely as per Dashmet Audio Recording Policy.")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.success)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color(red: 0.106, green: 0.227, blue: 0.176))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.info)
                        
                        Text("Your recording is saved. Generate a transcript to unlock AI features.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(AppColors.info.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Action buttons
                HStack(spacing: 10) {
                    // Play Recording button
                    if localRecordingURL != nil && viewModel.meeting.recordingUrl != nil {
                        Button {
                            showAudioPlayer = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 16))
                                Text("Play Recording")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(AppColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Generate Transcript button
                    if localRecordingURL != nil {
                        Button {
                            showTranscriptGeneration = true
                        } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 16))
                            Text("Generate Transcript")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Recording exists on another device
                        HStack(spacing: 6) {
                            Image(systemName: "icloud.slash")
                                .font(.system(size: 16))
                            Text("Audio on another device")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.textSecondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Compact Transcript Section
    private var compactTranscriptSection: some View {
        VStack(spacing: 0) {
            // Header with badge
            HStack {
                sectionHeaderContent(title: "Transcript", icon: "doc.text")
                
                Spacer()
                
                if isTranscriptProcessed {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("System")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.success.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                Text("\(rawTranscript.split(separator: " ").count) words")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            
            // Preview
            if !rawTranscript.isEmpty {
                Text(rawTranscript.prefix(200) + (rawTranscript.count > 200 ? "..." : ""))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            
            // Actions - First Row
            HStack(spacing: 8) {
                Button {
                    showTranscriptReview = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 14))
                        Text("Full Transcript")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                // AI Summary button
                if let summary = savedAISummary, !summary.briefSummary.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text("System Summary")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(AppColors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Button {
                        showAISummary = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("System Summary")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            // Actions - Second Row (Extract Action Items) - only show if no action items exist
            if viewModel.actionItems.isEmpty {
                Button {
                    // Trigger AI extraction of action items
                    shouldExtractActionItems = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Extract Action Items")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "6366F1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Compact AI Summary Section
    private func compactAISummarySection(_ summary: SavedAISummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                sectionHeaderContent(title: "System Summary", icon: "sparkles")
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Saved")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppColors.success)
            }
            .padding(16)
            
            // Audio Player Button (if available)
            if let audioUrl = summary.audioUrl, !audioUrl.isEmpty {
                Button {
                    showAISummaryAudioPlayer = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "headphones")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Listen to System Summary")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Text("Audio narration available")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.purple)
                    }
                    .padding(14)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            
            // Brief Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                    .textCase(.uppercase)
                
                Text(summary.briefSummary)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Tone (if available)
            if !summary.tone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 14))
                    Text("Tone:")
                        .font(.system(size: 14, weight: .medium))
                    Text(summary.tone)
                        .font(.system(size: 14))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            
            // Objectives (if available)
            if !summary.objectives.isEmpty {
                summaryListSection(title: "Objectives", icon: "target", items: summary.objectives, color: .blue)
            }
            
            // Key Discussions (if available)
            if !summary.keyDiscussions.isEmpty {
                summaryListSection(title: "Key Discussions", icon: "bubble.left.and.bubble.right", items: summary.keyDiscussions, color: .orange)
            }
            
            // Takeaways (if available)
            if !summary.takeaways.isEmpty {
                summaryListSection(title: "Key Takeaways", icon: "lightbulb", items: summary.takeaways, color: .yellow)
            }
            
            // Narrative (if available)
            if !summary.narrative.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Detailed Narrative")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                            .textCase(.uppercase)
                    }
                    
                    Text(summary.narrative)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    // Helper for summary list sections
    private func summaryListSection(title: String, icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color.opacity(0.8))
                            .frame(width: 7, height: 7)
                            .padding(.top, 7)
                        
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Compact Action Items Section
    private var compactActionItemsSection: some View {
        VStack(spacing: 0) {
            HStack {
                sectionHeaderContent(title: "Action Items", icon: "checklist")
                
                Spacer()
                
                Text("\(viewModel.actionItems.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
            }
            .padding(16)
            
            // Show first 3 action items
            VStack(spacing: 10) {
                ForEach(viewModel.actionItems.prefix(3)) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(item.status == .completed ? AppColors.success : AppColors.textTertiary)
                        
                        Text(item.title)
                            .font(.system(size: 15))
                            .foregroundColor(item.status == .completed ? AppColors.textTertiary : AppColors.textPrimary)
                            .strikethrough(item.status == .completed)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Compact Timeline Section
    private var compactTimelineSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Timeline", icon: "clock")
            
            VStack(spacing: 0) {
                timelineItem(
                    icon: "plus.circle.fill",
                    title: "Created",
                    time: viewModel.meeting.createdAt,
                    color: AppColors.primary
                )
                
                if let recordedAt = viewModel.meeting.recordedAt {
                    timelineItem(
                        icon: "mic.fill",
                        title: "Recorded",
                        time: recordedAt,
                        color: .red
                    )
                }
                
                if hasTranscript {
                    timelineItem(
                        icon: "doc.text.fill",
                        title: "Transcribed",
                        time: Date(),
                        color: AppColors.success,
                        isLast: true
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Meeting Type & Status Card
    private var meetingTypeStatusCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    // Meeting type icon in rounded box
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: meetingTypeIcon)
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.meeting.safeMeetingType.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Meeting Type")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                Text(statusTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(16)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Created By Card
    private var createdByCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created By")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            if let creator = viewModel.meeting.creator {
                HStack(spacing: 10) {
                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text(String(creator.fullName.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(creator.fullName)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textPrimary)
                        Text(creator.email)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Stats Cards
    private var statsCardsSection: some View {
        HStack(spacing: 12) {
            // Transcript Blocks stat
            statCard(
                icon: "doc.text",
                label: "Transcript Blocks",
                value: "\(viewModel.meeting.transcriptBlockCount)",
                color: AppColors.info
            )
            
            // Action Items stat
            statCard(
                icon: "checkmark.circle",
                label: "Action Items",
                value: "\(viewModel.meeting.actionItemCount)",
                color: AppColors.success
            )
        }
    }
    
    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
    
    private func sectionHeaderContent(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
        }
    }
    
    private func timelineItem(icon: String, title: String, time: Date, color: Color, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 24)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(time, style: .relative)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.bottom, isLast ? 0 : 10)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var hasRecording: Bool {
        // Use the already-loaded localRecordingURL binding — do NOT call getLocalRecordingURL() here!
        // getLocalRecordingURL() does a synchronous FileManager directory scan, and hasRecording
        // is called 5+ times per body evaluation. With multiple body re-evaluations from @Published
        // changes, this was causing 50+ file system scans on the main thread, blocking the UI.
        if viewModel.meeting.recordingUrl != nil || localRecordingURL != nil {
            return true
        }
        // Check meeting status — these statuses mean a recording was uploaded/processed
        let recordingStatuses: [MeetingStatus] = [.uploading, .uploaded, .processing, .ready, .published]
        if let status = viewModel.meeting.status, recordingStatuses.contains(status) {
            return true
        }
        // recordedAt alone is NOT enough if the meeting is still draft —
        // it means recording was started but may have been discarded without saving
        if viewModel.meeting.recordedAt != nil && viewModel.meeting.safeStatus != .draft {
            return true
        }
        return false
    }
    
    private var hasTranscript: Bool {
        !viewModel.transcript.isEmpty || !rawTranscript.isEmpty
    }
    
    private var isTranscriptProcessed: Bool {
        isTranscriptFromDatabase || UserDefaults.standard.data(forKey: "transcript_processed_\(viewModel.meeting.id)") != nil
    }
    
    private var meetingTypeIcon: String {
        viewModel.meeting.safeMeetingType.icon
    }
    
    private static let sharedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var formattedDate: String {
        Self.sharedDateFormatter.string(from: viewModel.meeting.recordedAt ?? viewModel.meeting.createdAt)
    }
    
    private var statusColor: Color {
        if hasRecording || hasTranscript {
            return AppColors.success
        }
        switch viewModel.meeting.safeStatus {
        case .draft: return AppColors.textSecondary
        case .recording: return .red
        case .uploading, .uploaded: return AppColors.info
        case .processing: return AppColors.warning
        case .ready, .needsReview: return AppColors.success
        case .published: return AppColors.primary
        case .failed: return AppColors.error
        }
    }
    
    private var statusTitle: String {
        if hasRecording || hasTranscript {
            return "Recording Complete"
        }
        switch viewModel.meeting.safeStatus {
        case .draft: return "Draft"
        case .recording: return "Recording"
        case .uploading: return "Uploading"
        case .uploaded: return "Uploaded"
        case .processing: return "Processing"
        case .ready: return "Ready"
        case .needsReview: return "Needs Review"
        case .published: return "Published"
        case .failed: return "Failed"
        }
    }
    
    // MARK: - Helper Functions
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
    
    private func getLocalRecordingURL() -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings")
        
        // First check for exact match (legacy format): {meetingId}.m4a
        let legacyURL = recordingsDirectory.appendingPathComponent("\(viewModel.meeting.id).m4a")
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        
        // Search for timestamped format: meeting_{meetingId}_{timestamp}.m4a
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)
            let meetingPrefix = "meeting_\(viewModel.meeting.id)_"
            if let recording = files.first(where: { $0.lastPathComponent.hasPrefix(meetingPrefix) && $0.pathExtension == "m4a" }) {
                return recording
            }
        } catch {
            print("⚠️ Error scanning recordings directory: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Data Loading
    
    /// Async version: moves FileManager I/O off the main thread, yields to let UI settle
    private func loadLocalDataAsync() async {
        // Step 1: Read UserDefaults (fast, on main thread is OK)
        await MainActor.run {
            loadTranscriptFromCache()
        }
        
        // Step 2: Kick off async DB fetch (does not block)
        await MainActor.run {
            fetchTranscriptFromDatabase()
        }
        
        // Step 3: FileManager directory scan — do this OFF the main thread
        let cloudUrlString = await MainActor.run { viewModel.meeting.recordingUrl }
        let meetingId = await MainActor.run { viewModel.meeting.id }
        
        let resolvedURL: URL? = await Task.detached(priority: .userInitiated) {
            if let cloudUrlString = cloudUrlString,
               let cloudUrl = URL(string: cloudUrlString) {
                return cloudUrl
            }
            return Self.getLocalRecordingURLBackground(meetingId: meetingId)
        }.value
        
        await MainActor.run {
            localRecordingURL = resolvedURL
        }
        
        // Step 4: Load AI summary from cache/DB
        await MainActor.run {
            loadSavedAISummary()
        }
    }
    
    /// Background-safe file system scan (no main thread dependency)
    private static func getLocalRecordingURLBackground(meetingId: String) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings")
        
        let legacyURL = recordingsDirectory.appendingPathComponent("\(meetingId).m4a")
        if fileManager.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil)
            let meetingPrefix = "meeting_\(meetingId)_"
            if let recording = files.first(where: { $0.lastPathComponent.hasPrefix(meetingPrefix) && $0.pathExtension == "m4a" }) {
                return recording
            }
        } catch {
            // Directory doesn't exist or can't be read — not an error for our purposes
        }
        
        return nil
    }
    
    private func loadTranscriptFromCache() {
        if let transcriptData = UserDefaults.standard.data(forKey: "transcript_processed_\(viewModel.meeting.id)"),
           let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
           let text = json["processedText"] as? String ?? json["rawText"] as? String {
            rawTranscript = text
            print("📝 Loaded AI-processed transcript from cache: \(text.prefix(100))...")
        }
        // Fall back to raw transcript
        else if let transcriptData = UserDefaults.standard.data(forKey: "transcript_raw_\(viewModel.meeting.id)"),
                let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
                let text = json["processedText"] as? String ?? json["rawText"] as? String {
            rawTranscript = text
            print("📝 Loaded raw transcript from cache: \(text.prefix(100))...")
        }
        // Legacy key support
        else if let transcriptData = UserDefaults.standard.data(forKey: "rawTranscript_\(viewModel.meeting.id)"),
                let json = try? JSONSerialization.jsonObject(with: transcriptData) as? [String: Any],
                let text = json["rawText"] as? String {
            rawTranscript = text
            print("📝 Loaded legacy transcript from cache: \(text.prefix(100))...")
        }
    }
    
    private func fetchTranscriptFromDatabase() {
        Task {
            do {
                if let transcript = try await MeetingSummaryService.shared.fetchProcessedTranscript(meetingId: viewModel.meeting.id) {
                    await MainActor.run {
                        // Use processed transcript if available, otherwise raw
                        let text = transcript.processedTranscript ?? transcript.rawTranscript ?? ""
                        if !text.isEmpty {
                            rawTranscript = text
                            isTranscriptFromDatabase = true
                            
                            // Cache locally for faster access next time
                            let cacheData: [String: Any] = [
                                "id": transcript.id,
                                "type": "processed",
                                "rawText": transcript.rawTranscript ?? "",
                                "processedText": transcript.processedTranscript ?? "",
                                "wordCount": transcript.wordCount ?? 0,
                                "duration": transcript.duration ?? 0,
                                "savedAt": Date().timeIntervalSince1970
                            ]
                            
                            if let data = try? JSONSerialization.data(withJSONObject: cacheData) {
                                UserDefaults.standard.set(data, forKey: "transcript_processed_\(viewModel.meeting.id)")
                            }
                            
                            print("📝 Loaded transcript from database: \(text.prefix(100))...")
                        }
                    }
                }
            } catch {
                print("⚠️ Failed to fetch transcript from database: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSavedAISummary() {
        // First try to load from local cache (faster)
        if let data = UserDefaults.standard.data(forKey: "ai_summary_\(viewModel.meeting.id)"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            savedAISummary = SavedAISummary(
                id: json["id"] as? String ?? "",
                briefSummary: json["briefSummary"] as? String ?? "",
                narrative: json["narrative"] as? String ?? "",
                tone: json["tone"] as? String ?? "",
                objectives: json["objectives"] as? [String] ?? [],
                keyDiscussions: json["keyDiscussions"] as? [String] ?? [],
                takeaways: json["takeaways"] as? [String] ?? [],
                audioUrl: json["audioUrl"] as? String,
                audioVoice: json["audioVoice"] as? String,
                generatedAt: json["generatedAt"] as? String ?? "",
                savedAt: json["savedAt"] as? Double ?? 0
            )
            
            print("✨ Loaded AI Summary from local cache for meeting: \(viewModel.meeting.id)")
            return
        }
        
        // If not in cache, try fetching from database
        Task {
            do {
                if let summary = try await MeetingSummaryService.shared.fetchAISummary(meetingId: viewModel.meeting.id) {
                    await MainActor.run {
                        savedAISummary = SavedAISummary(
                            id: summary.id,
                            briefSummary: summary.briefSummary ?? "",
                            narrative: summary.narrative ?? "",
                            tone: summary.tone ?? "",
                            objectives: summary.objectives ?? [],
                            keyDiscussions: summary.keyDiscussions ?? [],
                            takeaways: summary.takeaways ?? [],
                            audioUrl: summary.audioUrl,
                            audioVoice: summary.audioVoice,
                            generatedAt: summary.generatedAt ?? "",
                            savedAt: Date().timeIntervalSince1970
                        )
                        
                        // Cache locally for faster access next time
                        let localData: [String: Any] = [
                            "id": summary.id,
                            "briefSummary": summary.briefSummary ?? "",
                            "narrative": summary.narrative ?? "",
                            "tone": summary.tone ?? "",
                            "objectives": summary.objectives ?? [],
                            "keyDiscussions": summary.keyDiscussions ?? [],
                            "takeaways": summary.takeaways ?? [],
                            "audioUrl": summary.audioUrl ?? "",
                            "audioVoice": summary.audioVoice ?? "",
                            "generatedAt": summary.generatedAt ?? "",
                            "savedAt": Date().timeIntervalSince1970
                        ]
                        
                        if let cacheData = try? JSONSerialization.data(withJSONObject: localData) {
                            UserDefaults.standard.set(cacheData, forKey: "ai_summary_\(viewModel.meeting.id)")
                        }
                        
                        print("✨ Loaded AI Summary from database for meeting: \(viewModel.meeting.id)")
                    }
                } else {
                    print("ℹ️ No AI Summary found for meeting: \(viewModel.meeting.id)")
                }
            } catch {
                print("⚠️ Failed to fetch AI Summary: \(error.localizedDescription)")
            }
        }
    }
}
struct AudioPlayerSheet: View {
    let meeting: Meeting
    let recordingURL: URL?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = OverviewAudioPlayer()
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xl) {
                    // Album Art Style Display
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(AppGradients.primary)
                                .frame(width: 200, height: 200)
                                .shadow(color: AppColors.primary.opacity(0.4), radius: 20)
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text(meeting.displayTitle)
                                .font(AppTypography.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.top, AppSpacing.xl)
                    
                    Spacer()
                    
                    // Progress Bar
                    VStack(spacing: AppSpacing.sm) {
                        Slider(
                            value: $audioPlayer.progress,
                            in: 0...1,
                            onEditingChanged: { editing in
                                if !editing {
                                    audioPlayer.seek(to: audioPlayer.progress)
                                }
                            }
                        )
                        .accentColor(AppColors.primary)
                        
                        HStack {
                            Text(audioPlayer.currentTimeString)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Spacer()
                            
                            Text(audioPlayer.durationString)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    
                    // Playback Controls
                    HStack(spacing: AppSpacing.xl) {
                        // Rewind 15s
                        Button {
                            audioPlayer.skip(by: -15)
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        // Play/Pause
                        Button {
                            audioPlayer.togglePlayPause()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppGradients.primary)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Forward 15s
                        Button {
                            audioPlayer.skip(by: 15)
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.bottom, AppSpacing.xl)
                    
                    // Playback Speed
                    HStack(spacing: AppSpacing.md) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button {
                                audioPlayer.setSpeed(Float(speed))
                            } label: {
                                Text("\(speed, specifier: "%.1f")x")
                                    .font(AppTypography.caption)
                                    .fontWeight(audioPlayer.playbackSpeed == Float(speed) ? .bold : .regular)
                                    .foregroundColor(audioPlayer.playbackSpeed == Float(speed) ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(audioPlayer.playbackSpeed == Float(speed) ? AppColors.primary : AppColors.surfaceSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Share Button
                    if let url = recordingURL {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Audio")
                            }
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppColors.primary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Spacer().frame(height: AppSpacing.xl)
                }
            }
            .navigationTitle("Audio Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        audioPlayer.stop()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if recordingURL != nil {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = recordingURL {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                if let url = recordingURL {
                    audioPlayer.load(url: url)
                }
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }
}

// MARK: - Overview Audio Player
@MainActor
class OverviewAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timer: Timer?
    private var statusObserver: NSKeyValueObservation?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set audio session: \(error.localizedDescription)")
        }
        
        let item = AVPlayerItem(url: url)
        playerItem = item
        player = AVPlayer(playerItem: item)
        player?.rate = 0 // Start paused
        
        // Observe when the item is ready to play
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    let dur = CMTimeGetSeconds(item.duration)
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                    print("✅ Loaded audio: \(url.lastPathComponent), duration: \(self.duration)s")
                } else if item.status == .failed {
                    print("❌ Failed to load audio: \(item.error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.rate = playbackSpeed
            startTimer()
        }
        isPlaying = !isPlaying
    }
    
    func stop() {
        player?.pause()
        stopTimer()
        isPlaying = false
        statusObserver?.invalidate()
        statusObserver = nil
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = progress * duration
    }
    
    func skip(by seconds: Double) {
        guard let player = player else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let newTime = max(0, min(duration, current + seconds))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
        updateProgress()
    }
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        guard let player = player else { return }
        if isPlaying {
            player.rate = speed
        }
        print("🎚️ Playback speed set to \(speed)x")
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProgress() {
        guard let player = player, duration > 0 else { return }
        currentTime = CMTimeGetSeconds(player.currentTime())
        progress = currentTime / duration
        
        if currentTime >= duration - 0.1 {
            isPlaying = false
            player.pause()
            stopTimer()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Overview Stat Card
struct OverviewStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
    }
}

// MARK: - Meeting Type Badge
struct MeetingTypeBadge: View {
    let type: MeetingType
    
    private var typeColor: Color {
        Color(hex: type.color)
    }
    
    var body: some View {
        Label(type.displayName, systemImage: type.icon)
            .font(AppTypography.caption)
            .foregroundColor(typeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(typeColor.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Participant Row
struct MeetingParticipantRow: View {
    let participant: MeetingParticipant
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            initialsView
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                
                if let email = participant.email {
                    Text(email)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Speaker Label Badge
            if let speakerLabel = participant.speakerLabel {
                Text(speakerLabel)
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.info)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.info.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
    
    private var initialsView: some View {
        Circle()
            .fill(AppGradients.primary)
            .frame(width: 36, height: 36)
            .overlay(
                Text(participant.displayInitials)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
            )
    }
}
struct AISummaryAudioPlayerSheet: View {
    let audioUrl: String
    let meetingTitle: String
    @ObservedObject var audioPlayer: URLAudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: audioPlayer.isPlaying ? "waveform" : "headphones")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                            .symbolEffect(.variableColor, isActive: audioPlayer.isPlaying)
                    }
                    
                    Text("System Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(meetingTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Loading or Error
                if audioPlayer.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading audio...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = audioPlayer.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Player Controls
                    VStack(spacing: 24) {
                        // Progress Bar
                        VStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { audioPlayer.progress },
                                set: { audioPlayer.seek(to: $0) }
                            ))
                            .accentColor(.purple)
                            
                            HStack {
                                Text(audioPlayer.currentTimeString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(audioPlayer.durationString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Playback Controls
                        HStack(spacing: 40) {
                            // Skip Back
                            Button {
                                audioPlayer.skip(by: -15)
                            } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            // Play/Pause
                            Button {
                                audioPlayer.togglePlayPause()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 70, height: 70)
                                    
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Skip Forward
                            Button {
                                audioPlayer.skip(by: 15)
                            } label: {
                                Image(systemName: "goforward.15")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        audioPlayer.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                audioPlayer.loadFromURL(audioUrl)
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    Text("Overview Tab Preview")
}
