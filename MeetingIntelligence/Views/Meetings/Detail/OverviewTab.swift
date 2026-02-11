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
    @ObservedObject var meetingViewModel: MeetingViewModel
    @Binding var selectedTab: MeetingTab
    @Binding var shouldExtractActionItems: Bool
    
    @State private var showAudioPlayer = false
    @State private var showTranscriptReview = false
    @State private var showRecording = false
    @State private var showAISummary = false
    @State private var rawTranscript: String = ""
    @State private var localRecordingURL: URL?
    @State private var savedAISummary: SavedAISummary?
    @State private var isTranscriptFromDatabase: Bool = false
    @State private var showAISummaryAudioPlayer = false
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var aiSummaryAudioPlayer = URLAudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Spacer for floating header (larger buttons need more space)
                Color.clear.frame(height: 80)
                
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
                    
                    // Transcript Section
                    if hasTranscript {
                        compactTranscriptSection
                        thinSeparator
                    }
                    
                    // AI Summary Section
                    if let summary = savedAISummary, !summary.briefSummary.isEmpty {
                        compactAISummarySection(summary)
                        thinSeparator
                    }
                    
                    // Action Items
                    if viewModel.actionItems.count > 0 {
                        compactActionItemsSection
                        thinSeparator
                    }
                    
                    // Timeline
                    compactTimelineSection
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                
                // Bottom spacing
                Color.clear.frame(height: 100)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named("scroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .refreshable {
            await viewModel.refreshMeeting()
            loadLocalData()
        }
        .onAppear {
            loadLocalData()
        }
        .onChange(of: showAudioPlayer) { _, newValue in
            if !newValue { loadLocalData() }
        }
        .onChange(of: showTranscriptReview) { _, newValue in
            if !newValue { loadLocalData() }
        }
        .onChange(of: showRecording) { _, newValue in
            if !newValue { loadLocalData() }
        }
        .fullScreenCover(isPresented: $showTranscriptReview) {
            TranscriptReviewView(
                meeting: viewModel.meeting,
                rawTranscript: rawTranscript,
                recordingURL: localRecordingURL ?? getLocalRecordingURL()
            )
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(meeting: viewModel.meeting, meetingViewModel: meetingViewModel) { _ in
                Task {
                    await viewModel.refreshMeeting()
                    loadLocalData()
                }
            }
        }
        .sheet(isPresented: $showAudioPlayer) {
            AudioPlayerSheet(
                meeting: viewModel.meeting,
                recordingURL: localRecordingURL ?? getLocalRecordingURL()
            )
        }
        .fullScreenCover(isPresented: $showAISummary) {
            AISummaryView(
                meeting: viewModel.meeting,
                transcript: rawTranscript,
                onSummarySaved: { loadLocalData() }
            )
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
                Text(viewModel.meeting.meetingType.displayName)
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
            
            // Quick actions
            if hasRecording {
                Button {
                    showAudioPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                }
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
                detailRow(icon: "globe", label: "Language", value: languageName(for: viewModel.meeting.language))
                
                if let location = viewModel.meeting.location, !location.isEmpty {
                    detailRow(icon: "location", label: "Location", value: location)
                }
                
                if !viewModel.meeting.tags.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "tag")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 20)
                        
                        Text("Tags")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 70, alignment: .leading)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(viewModel.meeting.tags, id: \.self) { tag in
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
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Actions - Second Row (Extract Action Items)
            Button {
                // Set flag to trigger AI extraction when navigating to Action Items tab
                shouldExtractActionItems = true
                withAnimation {
                    selectedTab = .actionItems
                }
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
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
                .frame(width: 70, alignment: .leading)
            
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
        viewModel.meeting.recordingUrl != nil || getLocalRecordingURL() != nil
    }
    
    private var hasTranscript: Bool {
        !viewModel.transcript.isEmpty || !rawTranscript.isEmpty
    }
    
    private var isTranscriptProcessed: Bool {
        isTranscriptFromDatabase || UserDefaults.standard.data(forKey: "transcript_processed_\(viewModel.meeting.id)") != nil
    }
    
    private var meetingTypeIcon: String {
        viewModel.meeting.meetingType.icon
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: viewModel.meeting.recordedAt ?? viewModel.meeting.createdAt)
    }
    
    private var statusColor: Color {
        if hasRecording || hasTranscript {
            return AppColors.success
        }
        switch viewModel.meeting.status {
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
        switch viewModel.meeting.status {
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
        let recordingsDirectory = documentsDirectory.appendingPathComponent("recordings")
        let meetingRecordingURL = recordingsDirectory.appendingPathComponent("\(viewModel.meeting.id).m4a")
        
        if fileManager.fileExists(atPath: meetingRecordingURL.path) {
            return meetingRecordingURL
        }
        return nil
    }
    
    // MARK: - Data Loading
    private func loadLocalData() {
        loadTranscriptFromCache()
        fetchTranscriptFromDatabase()
        localRecordingURL = getLocalRecordingURL()
        
        if localRecordingURL != nil {
            print("🎙️ Found local recording at: \(localRecordingURL!.path)")
        }
        
        loadSavedAISummary()
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
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
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
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true  // Enable rate BEFORE prepareToPlay
            player?.prepareToPlay()
            player?.rate = playbackSpeed
            duration = player?.duration ?? 0
            print("✅ Loaded audio: \(url.lastPathComponent), duration: \(duration)s")
        } catch {
            print("❌ Failed to load audio: \(error.localizedDescription)")
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying = player.isPlaying
    }
    
    func stop() {
        player?.stop()
        stopTimer()
        isPlaying = false
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let time = progress * duration
        player.currentTime = time
        currentTime = time
    }
    
    func skip(by seconds: Double) {
        guard let player = player else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        updateProgress()
    }
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        guard let player = player else { return }
        
        // If playing, we need to pause, set rate, and resume
        let wasPlaying = player.isPlaying
        if wasPlaying {
            player.pause()
        }
        
        player.rate = speed
        
        if wasPlaying {
            player.play()
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
        currentTime = player.currentTime
        progress = currentTime / duration
        
        if !player.isPlaying && currentTime >= duration - 0.1 {
            isPlaying = false
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

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
