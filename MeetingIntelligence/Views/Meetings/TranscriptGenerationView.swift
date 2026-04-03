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
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedLanguage: SupportedLanguage?
    @State private var showLanguagePicker = false
    @State private var isGenerating = false
    @State private var showError = false
    @State private var audioDuration: TimeInterval = 0
    @State private var showFullTranscript = false
    @State private var wavePhase: CGFloat = 0
    @State private var spinnerRotation: Double = 0
    @State private var tipIndex: Int = 0
    @State private var tipOpacity: Double = 1.0
    @State private var elapsedSeconds: Int = 0
    @State private var elapsedTimer: Timer?
    
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
                    .foregroundColor(AppColors.primary)
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
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(hex: "0f0c29"),
                        Color(hex: "302b63"),
                        Color(hex: "24243e")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: "F0ECFF"),
                        Color(hex: "E8E4F8"),
                        Color(hex: "F5F3FF")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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
                    .foregroundColor(AppColors.textPrimary)
                
                Text(meeting.title ?? "Meeting Recording")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
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
        .background(AppColors.surface)
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
                        .foregroundColor(AppColors.textTertiary)
                    
                    HStack(spacing: 8) {
                        Text(selectedLanguage?.flag ?? "🌍")
                            .font(.title2)
                        Text(selectedLanguage?.displayName ?? "Select Language")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding()
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Options")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: 0) {
                optionRow(icon: "text.bubble", title: "Speech Recognition", subtitle: "Convert audio to text", isEnabled: true)
                Divider().background(AppColors.border)
                optionRow(icon: "sparkles", title: "System Enhancement", subtitle: "Punctuation & formatting", isEnabled: true)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func optionRow(icon: String, title: String, subtitle: String, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEnabled ? AppColors.primary : AppColors.textTertiary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? AppColors.textPrimary : AppColors.textTertiary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isEnabled ? AppColors.textSecondary : AppColors.textTertiary)
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
            } else {
                Text("Soon")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.surfaceSecondary)
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
        VStack(spacing: 0) {
            Spacer()
            
            // Circular progress ring with waveform
            circularProgressRing
                .padding(.bottom, 28)
            
            // Stage label + message
            VStack(spacing: 6) {
                Text(generationService.progress.stage.rawValue)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: generationService.progress.stage)
                
                Text(generationService.progress.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .animation(.easeInOut, value: generationService.progress.statusMessage)
            }
            .padding(.bottom, 24)
            
            // Stage timeline pills
            stageTimelinePills
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            
            // Live stats strip
            liveStatsStrip
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            // Animated tips carousel
            tipsCarousel
                .padding(.horizontal, 20)
            
            Spacer()
            
            // Cancel button
            Button {
                elapsedTimer?.invalidate()
                generationService.cancel()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 40)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            // Start spinner rotation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                spinnerRotation = 360
            }
            // Start elapsed timer
            elapsedSeconds = 0
            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
            }
            // Start tip rotation
            startTipRotation()
        }
        .onDisappear {
            elapsedTimer?.invalidate()
        }
    }
    
    // MARK: - Circular Progress Ring
    private var circularProgressRing: some View {
        let progress = generationService.progress.overallProgress
        let size: CGFloat = 180
        
        return ZStack {
            // Outer glow pulse
            Circle()
                .stroke(stageColor.opacity(0.06), lineWidth: 24)
                .frame(width: size, height: size)
            
            // Background track
            Circle()
                .stroke(AppColors.surfaceSecondary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: size, height: size)
            
            // Spinning arc segment (continuously rotating)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    LinearGradient(
                        colors: [stageColor.opacity(0.0), stageColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(spinnerRotation))
            
            // Faint secondary spinning arc (opposite side, slower visual depth)
            Circle()
                .trim(from: 0, to: 0.15)
                .stroke(stageColor.opacity(0.15), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-spinnerRotation * 0.6))
            
            // Center content
            VStack(spacing: 6) {
                // Percentage
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: Int(progress * 100))
                
                // Stage icon
                Image(systemName: generationService.progress.stage.icon)
                    .font(.system(size: 16))
                    .foregroundColor(stageColor)
                    .symbolEffect(.pulse, options: .repeating, value: isGenerating)
            }
        }
    }
    
    // MARK: - Stage Timeline Pills
    private var stageTimelinePills: some View {
        let stages: [(TranscriptGenerationStage, String, String)] = [
            (.preparing, "Prepare", "waveform"),
            (.transcribing, "Transcribe", "text.bubble"),
            (.processingAI, "Enhance", "sparkles"),
            (.finalizing, "Finalize", "checkmark.circle"),
        ]
        
        return HStack(spacing: 6) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, item in
                let (stage, label, icon) = item
                let isComplete = stageCompleted(stage)
                let isCurrent = stageCurrent(stage)
                
                HStack(spacing: 4) {
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundColor(isCurrent ? .white : AppColors.textTertiary)
                    }
                    
                    Text(label)
                        .font(.system(size: 11, weight: isCurrent || isComplete ? .semibold : .regular))
                        .foregroundColor(isCurrent ? .white : isComplete ? .white : AppColors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if isComplete {
                            AppColors.success
                        } else if isCurrent {
                            stageColor
                        } else {
                            AppColors.surfaceSecondary
                        }
                    }
                )
                .clipShape(Capsule())
                .animation(.spring(response: 0.4), value: generationService.progress.stage)
                
                if index < stages.count - 1 {
                    // Connector dash
                    Rectangle()
                        .fill(isComplete ? AppColors.success : AppColors.border)
                        .frame(width: 8, height: 2)
                }
            }
        }
    }
    
    // MARK: - Live Stats Strip
    private var liveStatsStrip: some View {
        HStack(spacing: 0) {
            liveStatItem(
                icon: "clock",
                value: formatElapsed(elapsedSeconds),
                label: "Elapsed"
            )
            
            Divider()
                .frame(height: 32)
                .background(AppColors.border)
            
            liveStatItem(
                icon: "bolt.fill",
                value: generationService.progress.stage == .complete ? "Done" :
                       generationService.progress.stage == .preparing ? "Starting" : "Active",
                label: "Status"
            )
            
            Divider()
                .frame(height: 32)
                .background(AppColors.border)
            
            liveStatItem(
                icon: "chart.bar.fill",
                value: "\(Int(generationService.progress.stageProgress * 100))%",
                label: "Stage"
            )
        }
        .padding(.vertical, 14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func liveStatItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(stageColor)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tips Carousel
    private let processingTips: [String] = [
        "Dashmet turns your meetings into actionable insights automatically",
        "Tip: Shorter recordings process faster — try splitting long meetings",
        "Your transcript will include punctuation and proper formatting",
        "Audio is processed securely and never stored on external servers",
        "Dashmet generates action items, summaries, and key decisions from your transcript",
        "You can search and edit your transcript after processing",
        "Pro tip: Clear audio with minimal background noise gives best results",
    ]
    
    private var tipsCarousel: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)
            
            Text(processingTips[tipIndex % processingTips.count])
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .opacity(tipOpacity)
                .animation(.easeInOut(duration: 0.4), value: tipOpacity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func startTipRotation() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation { tipOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                tipIndex += 1
                withAnimation { tipOpacity = 1 }
            }
        }
    }
    
    private func formatElapsed(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
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
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Stats
            HStack(spacing: 16) {
                statBadge(icon: "text.word.spacing", value: "\(transcript.wordCount)", label: "Words")
                statBadge(icon: "clock", value: formatDuration(transcript.duration), label: "Duration")
                if transcript.isDiarized {
                    statBadge(icon: "person.2.wave.2", value: "\(transcript.speakerCount)", label: "Speakers")
                }
                statBadge(icon: "text.alignleft", value: "\(transcript.speakerBlocks.isEmpty ? transcript.segments.count : transcript.speakerBlocks.count)", label: "Segments")
            }
            
            // Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
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
                        .foregroundColor(AppColors.textPrimary)
                        .lineSpacing(6)
                }
                .frame(maxHeight: 180)
            }
            .padding()
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .sheet(isPresented: $showFullTranscript) {
                FullTranscriptSheet(transcript: transcript)
            }
            
            // Info text
            Text("Tap 'Continue to Review' to process and save your transcript")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
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
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.surface)
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
        case .diarizing: return .orange
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    
    // Speaker colors for visual distinction
    private let speakerColors: [Color] = [
        .blue, .orange, .green, .purple, .pink, .cyan, .yellow, .mint, .indigo, .teal
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Group {
                    if colorScheme == .dark {
                        LinearGradient(
                            colors: [
                                Color(hex: "0f0c29"),
                                Color(hex: "302b63"),
                                Color(hex: "24243e")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                Color(hex: "F0ECFF"),
                                Color(hex: "E8E4F8"),
                                Color(hex: "F5F3FF")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stats bar
                    HStack(spacing: 16) {
                        statItem(icon: "text.word.spacing", value: "\(transcript.wordCount)", label: "Words")
                        statItem(icon: "clock", value: formatDuration(transcript.duration), label: "Duration")
                        if transcript.isDiarized {
                            statItem(icon: "person.2.wave.2", value: "\(transcript.speakerCount)", label: "Speakers")
                        }
                        statItem(icon: "text.quote", value: "\(transcript.isDiarized ? transcript.speakerBlocks.count : paragraphCount)", label: transcript.isDiarized ? "Turns" : "Paragraphs")
                    }
                    .padding()
                    .background(AppColors.surface)
                    
                    // Full transcript content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if transcript.isDiarized && !transcript.speakerBlocks.isEmpty {
                                // Speaker-attributed diarized view
                                ForEach(Array(transcript.speakerBlocks.enumerated()), id: \.offset) { index, block in
                                    speakerBlockView(block: block, index: index)
                                        .padding(.bottom, index < transcript.speakerBlocks.count - 1 ? 16 : 0)
                                }
                            } else {
                                // Fallback paragraph view
                                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                    Text(paragraph)
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineSpacing(6)
                                        .textSelection(.enabled)
                                        .padding(.bottom, index < paragraphs.count - 1 ? 20 : 0)
                                }
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
    
    // MARK: - Speaker Block View
    private func speakerBlockView(block: GeneratedTranscript.SpeakerBlock, index: Int) -> some View {
        let speakerIndex = transcript.speakers.firstIndex(of: block.speaker) ?? 0
        let color = speakerColors[speakerIndex % speakerColors.count]
        
        return VStack(alignment: .leading, spacing: 6) {
            // Speaker header with timestamp
            HStack(spacing: 8) {
                // Speaker color dot
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text(block.speaker)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(block.formattedTimeRange)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textTertiary)
                
                Spacer()
                
                if block.confidence > 0 {
                    Text("\(Int(block.confidence * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            // Content
            Text(block.content)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
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
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
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
