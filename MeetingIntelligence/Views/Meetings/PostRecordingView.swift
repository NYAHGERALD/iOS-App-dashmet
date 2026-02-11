//
//  PostRecordingView.swift
//  MeetingIntelligence
//
//  Post-Recording Screen - Shows after recording stops
//  Offers options to generate transcript, upload, or discard
//

import SwiftUI
import AVFoundation

struct PostRecordingView: View {
    let meeting: Meeting
    let recordingURL: URL
    let bookmarks: [RecordingBookmark]
    let meetingNotes: String
    let meetingViewModel: MeetingViewModel
    let onComplete: () -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transcriptState = TranscriptProcessingState()
    @State private var showTranscriptGeneration = false
    @State private var showFullTranscriptView = false
    @State private var showDiscardConfirmation = false
    @State private var showUnsavedChangesWarning = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var audioDuration: TimeInterval = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var generatedTranscript: GeneratedTranscript?
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Success Header
                        successHeader
                        
                        // Audio Preview Card
                        audioPreviewCard
                        
                        // Meeting Notes (if any)
                        if !meetingNotes.isEmpty {
                            meetingNotesCard
                        }
                        
                        // Bookmarks (if any)
                        if !bookmarks.isEmpty {
                            bookmarksCard
                        }
                        
                        // Transcript Section
                        transcriptSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Recording Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        // Check for unsaved changes
                        if transcriptState.hasUnsavedChanges {
                            showUnsavedChangesWarning = true
                        } else {
                            onComplete()
                        }
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesWarning) {
                Button("Stay", role: .cancel) {}
                Button("Discard Changes", role: .destructive) {
                    onComplete()
                }
            } message: {
                Text("You have a System-processed transcript that hasn't been saved. If you close now, your processed transcript will be lost.")
            }
            .alert("Discard Recording?", isPresented: $showDiscardConfirmation) {
                Button("Keep", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    deleteRecording()
                    onDiscard()
                }
            } message: {
                Text("This will permanently delete the recording. This cannot be undone.")
            }
            .fullScreenCover(isPresented: $showTranscriptGeneration) {
                TranscriptGenerationView(
                    audioURL: recordingURL,
                    meeting: meeting,
                    onComplete: { transcript in
                        generatedTranscript = transcript
                        transcriptState.setRawTranscript(transcript)
                        showTranscriptGeneration = false
                        
                        // Auto-save raw transcript to database immediately
                        Task {
                            await autoSaveRawTranscript(transcript)
                        }
                    },
                    onCancel: {
                        showTranscriptGeneration = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showFullTranscriptView) {
                FullTranscriptProcessingView(
                    meeting: meeting,
                    transcriptState: transcriptState,
                    onDismiss: {
                        showFullTranscriptView = false
                    }
                )
            }
            .onAppear {
                loadAudioInfo()
            }
            .onDisappear {
                stopPlayback()
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "0f0c29"),
                Color(hex: "302b63"),
                Color(hex: "24243e")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Success Header
    private var successHeader: some View {
        VStack(spacing: 16) {
            // Success icon
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.success)
            }
            
            VStack(spacing: 8) {
                Text("Recording Saved!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(meeting.title ?? "Meeting Recording")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Audio Preview Card
    private var audioPreviewCard: some View {
        VStack(spacing: 16) {
            // Duration and file size
            HStack(spacing: 24) {
                statBadge(icon: "clock", value: formatDuration(audioDuration), label: "Duration")
                statBadge(icon: "doc.fill", value: formatFileSize(), label: "Size")
                statBadge(icon: "bookmark.fill", value: "\(bookmarks.count)", label: "Bookmarks")
            }
            
            // Playback controls
            VStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.primary)
                            .frame(width: geometry.size.width * playbackProgress, height: 8)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                seekTo(progress: progress)
                            }
                    )
                }
                .frame(height: 8)
                
                // Time labels
                HStack {
                    Text(formatDuration(audioDuration * playbackProgress))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(formatDuration(audioDuration))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Play/Pause button
                Button {
                    togglePlayback()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                        Text(isPlaying ? "Pause" : "Play Recording")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Meeting Notes Card
    private var meetingNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(AppColors.primary)
                Text("Meeting Notes")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(meetingNotes)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(5)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Bookmarks Card
    private var bookmarksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(AppColors.accent)
                Text("Bookmarks")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(bookmarks.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            ForEach(bookmarks.prefix(3)) { bookmark in
                HStack {
                    Text(formatDuration(Double(bookmark.timestamp)))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primary)
                        .frame(width: 50, alignment: .leading)
                    
                    Text(bookmark.note ?? "Bookmark")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            if bookmarks.count > 3 {
                Text("+ \(bookmarks.count - 3) more")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Transcript Section
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(AppColors.primary)
                Text("Transcript")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let transcript = generatedTranscript {
                // Show generated transcript preview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("Transcript Generated")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.success)
                        Spacer()
                        Text("\(transcript.wordCount) words")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Show processing status
                    if transcriptState.isProcessedTranscriptSaved {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("System Processed & Saved")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else if transcriptState.processedTranscript != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("System Processed - Not Saved")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text((transcriptState.currentTranscript ?? transcript).processedText.prefix(200) + ((transcriptState.currentTranscript ?? transcript).processedText.count > 200 ? "..." : ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                    
                    Button {
                        transcriptState.markFullTranscriptViewed()
                        showFullTranscriptView = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Full Transcript")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                // Show generate transcript option
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Transcript Generation")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Convert your recording to text with System-powered accuracy")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    
                    Button {
                        showTranscriptGeneration = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 16))
                            Text("Generate Transcript")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Upload/Save button - disabled until transcript is processed and saved
            Button {
                uploadRecording()
            } label: {
                HStack(spacing: 12) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isUploading ? "Uploading..." : "Save to Cloud")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: transcriptState.canSaveToCloud 
                            ? [AppColors.success, AppColors.success.opacity(0.8)]
                            : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: transcriptState.canSaveToCloud ? AppColors.success.opacity(0.4) : .clear, radius: 12, y: 6)
            }
            .disabled(isUploading || !transcriptState.canSaveToCloud)
            
            // Show requirements if Save to Cloud is disabled
            if !transcriptState.canSaveToCloud && generatedTranscript != nil {
                VStack(spacing: 4) {
                    if !transcriptState.hasViewedFullTranscript {
                        requirementRow(met: false, text: "View Full Transcript")
                    } else {
                        requirementRow(met: true, text: "Transcript Viewed")
                    }
                    
                    if transcriptState.processedTranscript == nil {
                        requirementRow(met: false, text: "Process with System")
                    } else {
                        requirementRow(met: true, text: "System Processed")
                    }
                    
                    if !transcriptState.isProcessedTranscriptSaved && transcriptState.processedTranscript != nil {
                        requirementRow(met: false, text: "Save Processed Transcript")
                    } else if transcriptState.isProcessedTranscriptSaved {
                        requirementRow(met: true, text: "Transcript Saved")
                    }
                }
                .padding(.top, 4)
            }
            
            // Discard button
            Button {
                showDiscardConfirmation = true
            } label: {
                Text("Discard Recording")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 8)
        }
    }
    
    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(met ? .green : .white.opacity(0.4))
            Text(text)
                .font(.caption)
                .foregroundColor(met ? .green.opacity(0.8) : .white.opacity(0.5))
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAudioInfo() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioDuration = audioPlayer?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer?.play()
            isPlaying = true
            
            // Update progress
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let player = audioPlayer {
                    playbackProgress = player.currentTime / player.duration
                    
                    if !player.isPlaying {
                        stopPlayback()
                    }
                }
            }
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func seekTo(progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = player.duration * progress
        playbackProgress = progress
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatFileSize() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: recordingURL.path)
            if let size = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size)
            }
        } catch {
            print("Failed to get file size: \(error)")
        }
        return "N/A"
    }
    
    private func uploadRecording() {
        isUploading = true
        
        // Upload the recording to Firebase Storage
        Task {
            // Save the final transcript (processed version)
            if let transcript = transcriptState.currentTranscript {
                await saveTranscript(transcript, type: "final")
            }
            
            // Update meeting status
            let _ = await meetingViewModel.updateMeeting(meetingId: meeting.id, status: .ready)
            
            // Complete
            isUploading = false
            onComplete()
        }
    }
    
    /// Auto-save raw transcript immediately after generation (for data safety)
    private func autoSaveRawTranscript(_ transcript: GeneratedTranscript) async {
        print("📦 Auto-saving raw transcript to database...")
        await saveTranscript(transcript, type: "raw")
        transcriptState.markRawTranscriptAutoSaved()
        print("✅ Raw transcript auto-saved")
    }
    
    private func saveTranscript(_ transcript: GeneratedTranscript, type: String = "raw") async {
        let transcriptData: [String: Any] = [
            "type": type,
            "rawText": transcript.rawText,
            "processedText": transcript.processedText,
            "wordCount": transcript.wordCount,
            "duration": transcript.duration,
            "generatedAt": transcript.generatedAt.timeIntervalSince1970,
            "savedAt": Date().timeIntervalSince1970
        ]
        
        // Save locally for backup
        UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: transcriptData), forKey: "transcript_\(type)_\(meeting.id)")
        
        // TODO: Also save to Firebase/backend database for cloud sync
        // await APIService.shared.saveTranscript(meetingId: meeting.id, rawText: transcript.rawText, processedText: transcript.processedText, type: type)
    }
    
    private func deleteRecording() {
        do {
            try FileManager.default.removeItem(at: recordingURL)
            print("Recording deleted")
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    PostRecordingView(
        meeting: Meeting.preview,
        recordingURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        bookmarks: [],
        meetingNotes: "Discussed project timeline and deliverables.",
        meetingViewModel: MeetingViewModel(),
        onComplete: { },
        onDiscard: { }
    )
}
