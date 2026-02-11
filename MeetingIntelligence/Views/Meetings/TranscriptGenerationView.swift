//
//  TranscriptGenerationView.swift
//  MeetingIntelligence
//
//  Post-Recording Transcript Generation UI
//  Shows real progress and professional status indicators
//

import SwiftUI
import AVFoundation

struct TranscriptGenerationView: View {
    let audioURL: URL
    let meeting: Meeting
    let onComplete: (GeneratedTranscript) -> Void
    let onCancel: () -> Void
    
    @StateObject private var generationService = TranscriptGenerationService.shared
    @State private var selectedLanguage: SupportedLanguage?
    @State private var showLanguagePicker = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var audioDuration: TimeInterval = 0
    @State private var showFullTranscript = false
    
    private let languageManager = LanguageManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 24) {
                    if !isGenerating && generationService.generatedTranscript == nil {
                        // Pre-generation state
                        preGenerationContent
                    } else if isGenerating {
                        // Generating state
                        generatingContent
                    } else if let transcript = generationService.generatedTranscript {
                        // Completed state
                        completedContent(transcript: transcript)
                    }
                }
                .padding()
            }
            .navigationTitle("Generate Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isGenerating {
                            generationService.cancel()
                        }
                        onCancel()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
            .alert("Generation Failed", isPresented: $showError) {
                Button("Try Again") {
                    startGeneration()
                }
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
            } message: {
                Text(generationService.error?.localizedDescription ?? "An unknown error occurred")
            }
            .onAppear {
                loadAudioDuration()
                selectedLanguage = languageManager.selectedLanguage
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
    
    // MARK: - Pre-Generation Content
    private var preGenerationContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Audio Info Card
            audioInfoCard
            
            // Language Selection
            languageSelectionCard
            
            // Generation Options
            optionsCard
            
            Spacer()
            
            // Generate Button
            generateButton
        }
    }
    
    private var audioInfoCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Recording Ready")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(meeting.title ?? "Meeting Recording")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Duration badge
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(formatDuration(audioDuration))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColors.primary.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var languageSelectionCard: some View {
        Button {
            showLanguagePicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcription Language")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 8) {
                        Text(selectedLanguage?.flag ?? "🌍")
                            .font(.title2)
                        Text(selectedLanguage?.displayName ?? "Select Language")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Options")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 0) {
                optionRow(icon: "text.bubble", title: "Speech Recognition", subtitle: "Convert audio to text", isEnabled: true)
                Divider().background(Color.white.opacity(0.1))
                optionRow(icon: "sparkles", title: "System Enhancement", subtitle: "Punctuation & formatting", isEnabled: true)
                Divider().background(Color.white.opacity(0.1))
                optionRow(icon: "person.2", title: "Speaker Detection", subtitle: "Coming soon", isEnabled: false)
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func optionRow(icon: String, title: String, subtitle: String, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEnabled ? AppColors.primary : .white.opacity(0.3))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .white : .white.opacity(0.5))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .white.opacity(0.6) : .white.opacity(0.3))
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
            } else {
                Text("Soon")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
    
    private var generateButton: some View {
        Button {
            startGeneration()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("Generate Transcript")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppColors.primary.opacity(0.4), radius: 12, y: 6)
        }
    }
    
    // MARK: - Generating Content
    private var generatingContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Stage indicator with animated icon
            stageIndicator
            
            // Progress bars
            progressSection
            
            // Status details
            statusDetails
            
            Spacer()
            
            // Cancel button
            Button {
                generationService.cancel()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
    
    private var stageIndicator: some View {
        VStack(spacing: 20) {
            // Animated stage icon
            ZStack {
                // Outer pulse
                Circle()
                    .stroke(stageColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isGenerating ? 1.2 : 1.0)
                    .opacity(isGenerating ? 0 : 1)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isGenerating)
                
                // Inner circle
                Circle()
                    .fill(stageColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                // Icon
                Image(systemName: generationService.progress.stage.icon)
                    .font(.system(size: 40))
                    .foregroundColor(stageColor)
                    .symbolEffect(.pulse, options: .repeating, value: isGenerating)
            }
            
            VStack(spacing: 8) {
                Text(generationService.progress.stage.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(generationService.progress.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 24) {
            // Overall progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(generationService.progress.overallProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 12)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * generationService.progress.overallProgress, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: generationService.progress.overallProgress)
                    }
                }
                .frame(height: 12)
            }
            
            // Stage progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stage Progress")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(generationService.progress.stageProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stageColor)
                            .frame(width: geometry.size.width * generationService.progress.stageProgress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: generationService.progress.stageProgress)
                    }
                }
                .frame(height: 6)
            }
            
            // Stage steps
            stageSteps
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var stageSteps: some View {
        HStack(spacing: 4) {
            ForEach(Array(TranscriptGenerationStage.allCases.prefix(4).enumerated()), id: \.offset) { index, stage in
                HStack(spacing: 4) {
                    // Stage dot
                    ZStack {
                        Circle()
                            .fill(stageCompleted(stage) ? AppColors.success : 
                                  (stageCurrent(stage) ? stageColor : Color.white.opacity(0.2)))
                            .frame(width: 24, height: 24)
                        
                        if stageCompleted(stage) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else if stageCurrent(stage) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Connector line
                    if index < 3 {
                        Rectangle()
                            .fill(stageCompleted(stage) ? AppColors.success : Color.white.opacity(0.2))
                            .frame(height: 2)
                    }
                }
            }
        }
    }
    
    private var statusDetails: some View {
        VStack(spacing: 12) {
            if let timeRemaining = generationService.progress.estimatedTimeRemaining, timeRemaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Estimated time: \(formatDuration(timeRemaining))")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Completed Content
    private func completedContent(transcript: GeneratedTranscript) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success indicator
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.success.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.success)
                }
                
                Text("Transcript Generated!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Stats
            HStack(spacing: 24) {
                statBadge(icon: "text.word.spacing", value: "\(transcript.wordCount)", label: "Words")
                statBadge(icon: "clock", value: formatDuration(transcript.duration), label: "Duration")
                statBadge(icon: "text.alignleft", value: "\(transcript.segments.count)", label: "Segments")
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    // Show Full Transcript Button - More Visible
                    Button {
                        showFullTranscript = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                            Text("View Full Transcript")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.primary.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                ScrollView {
                    Text(transcript.processedText.prefix(500) + (transcript.processedText.count > 500 ? "..." : ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                }
                .frame(maxHeight: 180)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .sheet(isPresented: $showFullTranscript) {
                FullTranscriptSheet(transcript: transcript)
            }
            
            // Info text
            Text("Tap 'Continue to Review' to process and save your transcript")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            Button {
                onComplete(transcript)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Continue to Review")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppColors.success, AppColors.success.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppColors.success.opacity(0.4), radius: 12, y: 6)
            }
        }
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
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Language Picker Sheet
    private var languagePickerSheet: some View {
        NavigationStack {
            List {
                Section("Recent") {
                    ForEach(languageManager.recentLanguages) { language in
                        languageRow(language)
                    }
                }
                
                Section("All Languages") {
                    ForEach(languageManager.availableLanguages) { language in
                        languageRow(language)
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showLanguagePicker = false
                    }
                }
            }
        }
    }
    
    private func languageRow(_ language: SupportedLanguage) -> some View {
        Button {
            selectedLanguage = language
            languageManager.selectLanguage(language)
            showLanguagePicker = false
        } label: {
            HStack {
                Text(language.flag)
                    .font(.title2)
                Text(language.displayName)
                    .foregroundColor(.primary)
                Spacer()
                if language.id == selectedLanguage?.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var stageColor: Color {
        switch generationService.progress.stage {
        case .preparing: return .blue
        case .transcribing: return AppColors.primary
        case .processingAI: return .purple
        case .finalizing: return AppColors.success
        case .complete: return AppColors.success
        case .failed: return AppColors.error
        }
    }
    
    private func stageCompleted(_ stage: TranscriptGenerationStage) -> Bool {
        generationService.progress.stage.stageIndex > stage.stageIndex
    }
    
    private func stageCurrent(_ stage: TranscriptGenerationStage) -> Bool {
        generationService.progress.stage == stage
    }
    
    private func startGeneration() {
        isGenerating = true
        Task {
            do {
                let transcript = try await generationService.generateTranscript(from: audioURL, language: selectedLanguage)
                isGenerating = false
                // Transcript will be shown via generatedTranscript published property
            } catch {
                isGenerating = false
                if generationService.error != nil {
                    showError = true
                }
            }
        }
    }
    
    private func loadAudioDuration() {
        let asset = AVURLAsset(url: audioURL)
        Task {
            do {
                let duration = try await asset.load(.duration)
                audioDuration = CMTimeGetSeconds(duration)
            } catch {
                print("Failed to load audio duration: \(error)")
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}

// MARK: - Preview
#Preview {
    TranscriptGenerationView(
        audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        meeting: Meeting.preview,
        onComplete: { _ in },
        onCancel: { }
    )
}

// MARK: - Full Transcript Sheet
struct FullTranscriptSheet: View {
    let transcript: GeneratedTranscript
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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
                
                VStack(spacing: 0) {
                    // Stats bar
                    HStack(spacing: 20) {
                        statItem(icon: "text.word.spacing", value: "\(transcript.wordCount)", label: "Words")
                        statItem(icon: "clock", value: formatDuration(transcript.duration), label: "Duration")
                        statItem(icon: "text.quote", value: "\(paragraphCount)", label: "Paragraphs")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    
                    // Full transcript with proper paragraph formatting
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                Text(paragraph)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(6)
                                    .textSelection(.enabled)
                                    .padding(.bottom, index < paragraphs.count - 1 ? 20 : 0)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Full Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
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
        }
    }
    
    private var filteredText: String {
        if searchText.isEmpty {
            return transcript.processedText
        }
        return transcript.processedText
    }
    
    /// Split transcript into paragraphs for proper display
    private var paragraphs: [String] {
        let text = searchText.isEmpty ? transcript.processedText : transcript.processedText
        return text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// Count of paragraphs (speaker turns)
    private var paragraphCount: Int {
        paragraphs.count
    }
    
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
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = transcript.processedText
    }
}
