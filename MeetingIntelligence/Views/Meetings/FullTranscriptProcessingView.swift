//
//  FullTranscriptProcessingView.swift
//  MeetingIntelligence
//
//  Full Transcript View with AI Processing
//  Allows user to view, process, and save transcripts
//  Enforces 3 AI processing attempts limit
//

import SwiftUI
import FirebaseAuth

struct FullTranscriptProcessingView: View {
    let meeting: Meeting
    @ObservedObject var transcriptState: TranscriptProcessingState
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showCancelWarning = false
    @State private var showSaveSuccess = false
    @State private var showProcessingError = false
    @State private var isSaving = false
    @State private var showComplianceDeletion = false
    @State private var localRecordingURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    // Stats bar
                    statsBar
                    
                    // Processing status bar
                    processingStatusBar
                    
                    // Transcript content
                    transcriptContent
                    
                    // Action buttons at bottom
                    actionButtonsBar
                }
            }
            .navigationTitle("Full Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        handleDismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search transcript")
            .alert("Unsaved Changes", isPresented: $showCancelWarning) {
                Button("Stay", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    onDismiss()
                }
            } message: {
                Text("Your System-processed transcript hasn't been saved. If you leave now, you'll lose the processed version.")
            }
            .alert("Saved Successfully!", isPresented: $showSaveSuccess) {
                Button("OK") {}
            } message: {
                Text("Your processed transcript has been saved to the cloud.")
            }
            .alert("Processing Failed", isPresented: $showProcessingError) {
                Button("OK") {}
            } message: {
                Text(transcriptState.aiProcessingError ?? "An error occurred while processing the transcript.")
            }
            .fullScreenCover(isPresented: $showComplianceDeletion) {
                ComplianceAudioDeletionView(
                    meetingId: meeting.id,
                    userId: FirebaseAuthService.shared.currentUser?.uid ?? "",
                    onComplete: {
                        showComplianceDeletion = false
                        // Show success alert after compliance deletion completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSaveSuccess = true
                        }
                    }
                )
            }
            .onAppear {
                localRecordingURL = getLocalRecordingURL()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getLocalRecordingURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        // First check for exact match (legacy format)
        let exactPath = recordingsPath.appendingPathComponent("\(meeting.id).m4a")
        if FileManager.default.fileExists(atPath: exactPath.path) {
            return exactPath
        }
        
        // Then look for files with timestamp format: meeting_{meetingId}_{timestamp}.m4a
        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsPath, includingPropertiesForKeys: nil)
            let matchingFile = files.first { url in
                let filename = url.lastPathComponent
                return filename.hasPrefix("meeting_\(meeting.id)_") && filename.hasSuffix(".m4a")
            }
            return matchingFile
        } catch {
            return nil
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
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 20) {
            statItem(icon: "text.word.spacing", value: "\(currentTranscript?.wordCount ?? 0)", label: "Words")
            statItem(icon: "clock", value: formatDuration(currentTranscript?.duration ?? 0), label: "Duration")
            statItem(icon: "text.quote", value: "\(paragraphCount)", label: "Paragraphs")
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
    
    // MARK: - Processing Status Bar
    private var processingStatusBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // AI Processing status
                if transcriptState.isProcessedTranscriptSaved {
                    Label("System Processed & Saved", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else if transcriptState.processedTranscript != nil {
                    Label("System Processed - Unsaved", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                } else {
                    Label("Not Processed", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Attempts counter
                HStack(spacing: 4) {
                    ForEach(0..<TranscriptProcessingState.maxAIAttempts, id: \.self) { index in
                        Circle()
                            .fill(index < transcriptState.aiProcessingAttempts ? Color.orange : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    Text("\(transcriptState.remainingAttempts) left")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Transcript Content
    private var transcriptContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(highlightedText(paragraph))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .padding(.bottom, index < paragraphs.count - 1 ? 20 : 0)
                }
            }
            .padding()
            .padding(.bottom, 100) // Space for buttons
        }
    }
    
    // MARK: - Action Buttons Bar
    private var actionButtonsBar: some View {
        VStack(spacing: 12) {
            // Process with AI button
            Button {
                processWithAI()
            } label: {
                HStack(spacing: 10) {
                    if transcriptState.isProcessingAI {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: transcriptState.processedTranscript != nil ? "arrow.triangle.2.circlepath" : "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    if transcriptState.isProcessingAI {
                        Text("Processing...")
                    } else if !transcriptState.canProcessWithAI {
                        if transcriptState.isProcessedTranscriptSaved {
                            Text("Processing Complete")
                        } else if transcriptState.remainingAttempts == 0 {
                            Text("No Attempts Left")
                        } else {
                            Text("Process with System")
                        }
                    } else {
                        Text(transcriptState.processedTranscript != nil ? "Reprocess (\(transcriptState.remainingAttempts) left)" : "Process with System")
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: transcriptState.canProcessWithAI
                            ? [Color.purple.opacity(0.8), Color.blue.opacity(0.7)]
                            : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!transcriptState.canProcessWithAI)
            
            // Save button - only shows after AI processing
            if transcriptState.processedTranscript != nil {
                Button {
                    saveProcessedTranscript()
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: transcriptState.isProcessedTranscriptSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(transcriptState.isProcessedTranscriptSaved ? "Saved ✓" : (isSaving ? "Saving..." : "Save Processed Transcript"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: transcriptState.canSaveProcessedTranscript
                                ? [AppColors.success, AppColors.success.opacity(0.8)]
                                : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!transcriptState.canSaveProcessedTranscript || isSaving)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color(hex: "0f0c29").opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Views
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentTranscript: GeneratedTranscript? {
        transcriptState.currentTranscript
    }
    
    private var paragraphs: [String] {
        guard let transcript = currentTranscript else { return [] }
        return transcript.processedText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var paragraphCount: Int {
        paragraphs.count
    }
    
    // MARK: - Helper Methods
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if !searchText.isEmpty {
            let lowercasedText = text.lowercased()
            let lowercasedSearch = searchText.lowercased()
            var searchStartIndex = lowercasedText.startIndex
            
            while let range = lowercasedText.range(of: lowercasedSearch, range: searchStartIndex..<lowercasedText.endIndex) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].backgroundColor = .yellow.opacity(0.5)
                    attributedString[attributedRange].foregroundColor = .black
                }
                searchStartIndex = range.upperBound
            }
        }
        
        return attributedString
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    private func copyToClipboard() {
        if let text = currentTranscript?.processedText {
            UIPasteboard.general.string = text
        }
    }
    
    private func handleDismiss() {
        if transcriptState.hasUnsavedChanges {
            showCancelWarning = true
        } else {
            onDismiss()
        }
    }
    
    private func processWithAI() {
        Task {
            do {
                try await transcriptState.processWithAI()
            } catch {
                showProcessingError = true
            }
        }
    }
    
    private func saveProcessedTranscript() {
        guard let transcript = transcriptState.processedTranscript else { return }
        
        // Check if audio has already been deleted for compliance
        let audioAlreadyDeleted = ComplianceService.shared.isAudioDeletedForCompliance(meetingId: meeting.id)
        
        isSaving = true
        
        Task {
            do {
                // Save to backend database
                let savedTranscript = try await MeetingSummaryService.shared.saveProcessedTranscriptToDatabase(
                    meetingId: meeting.id,
                    rawTranscript: transcript.rawText,
                    processedTranscript: transcript.processedText,
                    wordCount: transcript.wordCount,
                    duration: Int(transcript.duration)
                )
                
                print("✅ Transcript saved to database. ID: \(savedTranscript.id)")
                
                // Also cache locally for quick access
                let transcriptData: [String: Any] = [
                    "id": savedTranscript.id,
                    "type": "processed",
                    "rawText": transcript.rawText,
                    "processedText": transcript.processedText,
                    "wordCount": transcript.wordCount,
                    "duration": transcript.duration,
                    "generatedAt": transcript.generatedAt.timeIntervalSince1970,
                    "savedAt": Date().timeIntervalSince1970,
                    "aiProcessingAttempts": transcriptState.aiProcessingAttempts
                ]
                
                UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: transcriptData), forKey: "transcript_processed_\(meeting.id)")
                
                await MainActor.run {
                    transcriptState.markProcessedTranscriptSaved()
                    isSaving = false
                    
                    // Queue audio deletion IMMEDIATELY (happens in background even if app closes)
                    // This ensures deletion continues even if user turns off phone
                    if !audioAlreadyDeleted {
                        let userId = FirebaseAuthService.shared.currentUser?.uid ?? ""
                        ComplianceService.shared.queueAudioForDeletion(
                            meetingId: meeting.id,
                            userId: userId,
                            localRecordingURL: localRecordingURL ?? getLocalRecordingURL()
                        )
                        // Show compliance notification modal
                        showComplianceDeletion = true
                    } else {
                        showSaveSuccess = true
                    }
                }
                
            } catch {
                print("❌ Failed to save transcript to database: \(error.localizedDescription)")
                
                // Still save locally as fallback
                let transcriptData: [String: Any] = [
                    "type": "processed",
                    "rawText": transcript.rawText,
                    "processedText": transcript.processedText,
                    "wordCount": transcript.wordCount,
                    "duration": transcript.duration,
                    "generatedAt": transcript.generatedAt.timeIntervalSince1970,
                    "savedAt": Date().timeIntervalSince1970,
                    "aiProcessingAttempts": transcriptState.aiProcessingAttempts,
                    "savedToDatabase": false
                ]
                
                UserDefaults.standard.set(try? JSONSerialization.data(withJSONObject: transcriptData), forKey: "transcript_processed_\(meeting.id)")
                
                await MainActor.run {
                    transcriptState.markProcessedTranscriptSaved()
                    isSaving = false
                    
                    // Queue audio deletion IMMEDIATELY (even if DB save failed - transcript saved locally)
                    if !audioAlreadyDeleted {
                        let userId = FirebaseAuthService.shared.currentUser?.uid ?? ""
                        ComplianceService.shared.queueAudioForDeletion(
                            meetingId: meeting.id,
                            userId: userId,
                            localRecordingURL: localRecordingURL ?? getLocalRecordingURL()
                        )
                        showComplianceDeletion = true
                    } else {
                        showSaveSuccess = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let state = TranscriptProcessingState()
    state.setRawTranscript(GeneratedTranscript(
        rawText: "Hello, how are you? I'm doing great, thanks for asking.",
        processedText: "Hello, how are you?\n\nI'm doing great, thanks for asking.",
        segments: [],
        duration: 120,
        wordCount: 12,
        generatedAt: Date()
    ))
    
    return FullTranscriptProcessingView(
        meeting: Meeting.preview,
        transcriptState: state,
        onDismiss: {}
    )
}
