//
//  RecordingPreviewView.swift
//  MeetingIntelligence
//
//  Phase 1 - Recording Playback Preview & Upload Screen
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Recording Preview View
struct RecordingPreviewView: View {
    @StateObject private var viewModel: RecordingPreviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDiscardConfirmation = false
    @State private var showLanguageSelector = false
    
    var onUploadStarted: (() -> Void)?
    var onDiscarded: (() -> Void)?
    
    init(
        meeting: Meeting,
        recordingURL: URL,
        bookmarks: [RecordingBookmark],
        meetingViewModel: MeetingViewModel,
        onUploadStarted: (() -> Void)? = nil,
        onDiscarded: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: RecordingPreviewViewModel(
            meeting: meeting,
            recordingURL: recordingURL,
            bookmarks: bookmarks,
            meetingViewModel: meetingViewModel
        ))
        self.onUploadStarted = onUploadStarted
        self.onDiscarded = onDiscarded
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Recording Info Card
                        recordingInfoCard
                        
                        // Playback Controls
                        playbackSection
                        
                        // Bookmarks
                        if !viewModel.bookmarks.isEmpty {
                            bookmarksSection
                        }
                        
                        // Options Section
                        optionsSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding(AppSpacing.md)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("Review Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.isUploading {
                            // Don't allow cancel during upload
                        } else {
                            showDiscardConfirmation = true
                        }
                    }
                    .disabled(viewModel.isUploading)
                }
            }
            .alert("Discard Recording?", isPresented: $showDiscardConfirmation) {
                Button("Keep", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    viewModel.discardRecording()
                    onDiscarded?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete your recording. This cannot be undone.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
                if viewModel.canRetry {
                    Button("Retry") {
                        Task {
                            await viewModel.uploadRecording()
                        }
                    }
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showLanguageSelector) {
                LanguageSelectorSheet(selectedLanguage: $viewModel.selectedLanguage)
            }
            .onChange(of: viewModel.uploadCompleted) { _, completed in
                if completed {
                    onUploadStarted?()
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Recording Info Card
    private var recordingInfoCard: some View {
        VStack(spacing: AppSpacing.md) {
            // Meeting type icon
            ZStack {
                Circle()
                    .fill(Color(hex: viewModel.meeting.meetingType.color).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: viewModel.meeting.meetingType.icon)
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: viewModel.meeting.meetingType.color))
            }
            
            // Meeting title
            Text(viewModel.meeting.displayTitle)
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Recording stats
            HStack(spacing: AppSpacing.lg) {
                StatItem(icon: "clock.fill", value: viewModel.formattedDuration, label: "Duration")
                StatItem(icon: "doc.fill", value: viewModel.formattedFileSize, label: "Size")
                StatItem(icon: "bookmark.fill", value: "\(viewModel.bookmarks.count)", label: "Bookmarks")
            }
        }
        .padding(AppSpacing.lg)
        .cardStyle()
    }
    
    // MARK: - Playback Section
    private var playbackSection: some View {
        VStack(spacing: AppSpacing.md) {
            SectionHeader(title: "Preview")
            
            VStack(spacing: AppSpacing.md) {
                // Waveform placeholder
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(height: 60)
                    .overlay(
                        // Simplified waveform visualization
                        HStack(spacing: 2) {
                            ForEach(0..<40, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.primary.opacity(0.6))
                                    .frame(width: 4, height: CGFloat.random(in: 10...50))
                            }
                        }
                    )
                
                // Time display
                HStack {
                    Text(viewModel.formattedCurrentTime)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    // Progress slider
                    Slider(
                        value: $viewModel.playbackProgress,
                        in: 0...1,
                        onEditingChanged: { editing in
                            if !editing {
                                viewModel.seekTo(progress: viewModel.playbackProgress)
                            }
                        }
                    )
                    .tint(AppColors.primary)
                    
                    Text(viewModel.formattedDuration)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Playback controls
                HStack(spacing: AppSpacing.xl) {
                    // Rewind 15s
                    Button {
                        viewModel.skip(seconds: -15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    // Play/Pause
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(AppGradients.primary)
                    }
                    
                    // Forward 15s
                    Button {
                        viewModel.skip(seconds: 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title2)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .cardStyle()
        }
    }
    
    // MARK: - Bookmarks Section
    private var bookmarksSection: some View {
        VStack(spacing: AppSpacing.md) {
            SectionHeader(title: "Bookmarks", subtitle: "Tap to jump to moment")
            
            VStack(spacing: AppSpacing.xs) {
                ForEach(viewModel.bookmarks) { bookmark in
                    Button {
                        viewModel.jumpToBookmark(bookmark)
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(AppColors.warning)
                            
                            Text(bookmark.formattedTimestamp)
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let label = bookmark.label {
                                Text(label)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle")
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            SectionHeader(title: "Processing Options")
            
            VStack(spacing: 0) {
                // Language selection
                Button {
                    showLanguageSelector = true
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Text(viewModel.selectedLanguage.displayName)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 56)
                
                // Speaker count hint (optional)
                HStack {
                    Label("Expected Speakers", systemImage: "person.2")
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Stepper("\(viewModel.expectedSpeakerCount)", value: $viewModel.expectedSpeakerCount, in: 1...10)
                        .labelsHidden()
                    
                    Text("\(viewModel.expectedSpeakerCount)")
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 30)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            // Upload progress (if uploading)
            if viewModel.isUploading {
                VStack(spacing: AppSpacing.xs) {
                    ProgressView(value: viewModel.uploadProgress)
                        .tint(AppColors.primary)
                    
                    Text("Uploading... \(Int(viewModel.uploadProgress * 100))%")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)
            }
            
            // Process Now button
            Button {
                Task {
                    await viewModel.uploadRecording()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if viewModel.isUploading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                    }
                    Text(viewModel.isUploading ? "Uploading..." : "Process Now")
                }
                .primaryButtonStyle()
            }
            .disabled(viewModel.isUploading)
            .padding(.horizontal, AppSpacing.md)
            
            // Save as Draft button
            Button {
                viewModel.saveAsDraft()
                dismiss()
            } label: {
                Text("Save as Draft")
                    .secondaryButtonStyle()
            }
            .disabled(viewModel.isUploading)
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

// MARK: - Stat Item
private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
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

// MARK: - Language Model
enum MeetingLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case portuguese = "pt"
    case italian = "it"
    case dutch = "nl"
    case auto = "auto"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .portuguese: return "Portuguese"
        case .italian: return "Italian"
        case .dutch: return "Dutch"
        case .auto: return "Auto-detect"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .portuguese: return "🇧🇷"
        case .italian: return "🇮🇹"
        case .dutch: return "🇳🇱"
        case .auto: return "🌐"
        }
    }
}

// MARK: - Language Selector Sheet
struct LanguageSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: MeetingLanguage
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(MeetingLanguage.allCases) { language in
                    Button {
                        selectedLanguage = language
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.flag)
                                .font(.title2)
                            
                            Text(language.displayName)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview View Model
@MainActor
class RecordingPreviewViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let meetingViewModel: MeetingViewModel
    private let storageService = FirebaseStorageService.shared
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // MARK: - Published Properties
    let meeting: Meeting
    let recordingURL: URL
    let bookmarks: [RecordingBookmark]
    
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedLanguage: MeetingLanguage = .auto
    @Published var expectedSpeakerCount: Int = 2
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0
    @Published var uploadCompleted: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var canRetry: Bool = false
    
    // MARK: - Computed Properties
    var formattedDuration: String {
        formatTime(duration)
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedFileSize: String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: recordingURL.path)
        let size = attributes?[.size] as? Int64 ?? 0
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // MARK: - Initialization
    init(
        meeting: Meeting,
        recordingURL: URL,
        bookmarks: [RecordingBookmark],
        meetingViewModel: MeetingViewModel
    ) {
        self.meeting = meeting
        self.recordingURL = recordingURL
        self.bookmarks = bookmarks
        self.meetingViewModel = meetingViewModel
        
        setupAudioPlayer()
    }
    
    deinit {
        playbackTimer?.invalidate()
        audioPlayer?.stop()
    }
    
    // MARK: - Audio Setup
    private func setupAudioPlayer() {
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            print("✅ Audio player setup complete. Duration: \(duration) seconds")
        } catch {
            print("❌ Failed to setup audio player: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        playbackProgress = 0
        playbackTimer?.invalidate()
    }
    
    func skip(seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        playbackProgress = newTime / duration
    }
    
    func seekTo(progress: Double) {
        guard let player = audioPlayer else { return }
        let newTime = duration * progress
        player.currentTime = newTime
        currentTime = newTime
    }
    
    func jumpToBookmark(_ bookmark: RecordingBookmark) {
        guard let player = audioPlayer else { return }
        let time = Double(bookmark.timestamp)
        player.currentTime = time
        currentTime = time
        playbackProgress = time / duration
        
        if !isPlaying {
            startPlayback()
        }
    }
    
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
            }
        }
    }
    
    private func updatePlaybackState() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        playbackProgress = player.currentTime / duration
        
        if !player.isPlaying && isPlaying {
            // Playback finished
            isPlaying = false
            playbackTimer?.invalidate()
        }
    }
    
    // MARK: - Upload
    func uploadRecording() async {
        // Stop playback during upload
        stopPlayback()
        
        isUploading = true
        uploadProgress = 0
        
        do {
            // Get user ID (from app state or auth)
            let userId = meetingViewModel.userId ?? "unknown"
            
            // Upload to Firebase Storage
            let downloadURL = try await storageService.uploadNow(
                meetingId: meeting.id,
                localURL: recordingURL,
                userId: userId
            )
            
            // Monitor upload progress
            Task {
                while storageService.isUploadingMeeting(meeting.id) {
                    if let progress = storageService.getUploadProgress(for: meeting.id) {
                        uploadProgress = progress
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
            }
            
            // Notify backend that audio is ready
            await notifyBackendAudioReady(downloadURL: downloadURL)
            
            // Update meeting status
            let _ = await meetingViewModel.updateMeetingWithAudio(
                meetingId: meeting.id,
                status: .uploaded,
                audioUrl: downloadURL,
                duration: Int(duration),
                language: selectedLanguage.rawValue,
                speakerCountHint: expectedSpeakerCount
            )
            
            isUploading = false
            uploadProgress = 1.0
            uploadCompleted = true
            
            print("✅ Recording uploaded and backend notified")
            
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            canRetry = true
            showError = true
            
            print("❌ Upload failed: \(error)")
        }
    }
    
    private func notifyBackendAudioReady(downloadURL: String) async {
        // Call backend API to notify audio is ready for processing
        do {
            try await APIService.shared.notifyAudioReady(
                meetingId: meeting.id,
                audioUrl: downloadURL,
                duration: Int(duration),
                language: selectedLanguage.rawValue,
                speakerCountHint: expectedSpeakerCount
            )
        } catch {
            print("⚠️ Failed to notify backend: \(error)")
            // Don't fail the whole upload if backend notification fails
            // The backend should be able to detect new uploads
        }
    }
    
    // MARK: - Draft
    func saveAsDraft() {
        Task {
            let _ = await meetingViewModel.updateMeetingWithAudio(
                meetingId: meeting.id,
                status: .draft,
                audioUrl: nil,
                duration: Int(duration)
            )
        }
        print("📝 Recording saved as draft")
    }
    
    // MARK: - Discard
    func discardRecording() {
        // Stop playback
        stopPlayback()
        
        // Delete the file
        try? FileManager.default.removeItem(at: recordingURL)
        
        // Update meeting status back to draft
        Task {
            let _ = await meetingViewModel.updateMeeting(
                meetingId: meeting.id,
                title: nil,
                meetingType: nil,
                location: nil,
                tags: nil,
                status: .draft
            )
        }
        
        print("🗑️ Recording discarded")
    }
    
    // MARK: - Utilities
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Preview removed - Meeting struct requires JSON decoding
