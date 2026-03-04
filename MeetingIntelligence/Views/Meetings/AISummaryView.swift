//
//  AISummaryView.swift
//  MeetingIntelligence
//
//  Professional AI Summary with Text-to-Speech
//  Generates intelligent narrative summaries and speaks them aloud
//

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth

struct AISummaryView: View {
    let meeting: Meeting
    let transcript: String
    let onSummarySaved: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var summaryService = MeetingSummaryService.shared
    @StateObject private var audioPlayer = SummaryAudioPlayer()
    
    @State private var selectedVoice: TTSVoice = .onyx
    @State private var playbackSpeed: Double = 1.0
    @State private var showVoiceOptions = false
    @State private var generationPhase: GenerationPhase = .idle
    @State private var localSummary: NarrativeSummary?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isSaved = false
    @State private var showSaveSuccess = false
    
    // Voice preview state
    @State private var previewingVoice: TTSVoice?
    @State private var isLoadingPreview = false
    @StateObject private var previewPlayer = SummaryAudioPlayer()
    
    init(meeting: Meeting, transcript: String, onSummarySaved: (() -> Void)? = nil) {
        self.meeting = meeting
        self.transcript = transcript
        self.onSummarySaved = onSummarySaved
    }
    
    enum GenerationPhase: Equatable {
        case idle
        case generatingSummary
        case generatingAudio
        case completing
        case ready
        case error
    }
    
    // Progress simulation
    @State private var simulatedProgress: Double = 0
    @State private var statusMessage: String = ""
    @State private var showCompletionCheck: Bool = false
    @State private var glowPulse: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Content based on phase
                        switch generationPhase {
                        case .idle:
                            generatePrompt
                        case .generatingSummary, .generatingAudio, .completing:
                            dashmetProgressView
                        case .ready:
                            if let summary = localSummary {
                                summaryContent(summary)
                            }
                        case .error:
                            errorView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("System Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        audioPlayer.stop()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
                
                if generationPhase == .ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                regenerateSummary()
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                            
                            Button {
                                showVoiceOptions = true
                            } label: {
                                Label("Change Voice", systemImage: "person.wave.2")
                            }
                            
                            if let summary = localSummary {
                                Button {
                                    UIPasteboard.general.string = summary.narrative
                                } label: {
                                    Label("Copy Summary", systemImage: "doc.on.doc")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showVoiceOptions) {
                voiceSelectionSheet
            }
            .onDisappear {
                audioPlayer.stop()
            }
            .task {
                // Load existing saved summary if available
                await loadExistingSummary()
            }
        }
    }
    
    // MARK: - Load Existing Summary
    
    private func loadExistingSummary() async {
        // Skip if already loaded (e.g. just generated)
        guard generationPhase == .idle else { return }
        
        // Try local cache first
        if let data = UserDefaults.standard.data(forKey: "ai_summary_\(meeting.id)"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let narrative = json["narrative"] as? String, !narrative.isEmpty {
            
            localSummary = NarrativeSummary(
                narrative: narrative,
                briefSummary: json["briefSummary"] as? String ?? "",
                objectives: json["objectives"] as? [String] ?? [],
                keyDiscussions: json["keyDiscussions"] as? [String] ?? [],
                actionItems: json["actionItems"] as? [String] ?? [],
                takeaways: json["takeaways"] as? [String] ?? [],
                tone: json["tone"] as? String ?? "",
                generatedAt: json["generatedAt"] as? String ?? ""
            )
            
            if let voiceId = json["audioVoice"] as? String,
               let voice = TTSVoice(rawValue: voiceId) {
                selectedVoice = voice
            }
            
            // Load audio from saved URL
            if let audioUrl = json["audioUrl"] as? String, !audioUrl.isEmpty {
                await loadAudioFromURL(audioUrl)
            } else {
                // No saved audio — regenerate from narrative
                await regenerateAudioForExisting(narrative: narrative)
            }
            
            generationPhase = .ready
            isSaved = true
            return
        }
        
        // Try fetching from backend
        do {
            if let summary = try await MeetingSummaryService.shared.fetchAISummary(meetingId: meeting.id) {
                guard let narrative = summary.narrative, !narrative.isEmpty else { return }
                
                localSummary = NarrativeSummary(
                    narrative: narrative,
                    briefSummary: summary.briefSummary ?? "",
                    objectives: summary.objectives ?? [],
                    keyDiscussions: summary.keyDiscussions ?? [],
                    actionItems: summary.actionItems ?? [],
                    takeaways: summary.takeaways ?? [],
                    tone: summary.tone ?? "",
                    generatedAt: summary.generatedAt ?? ""
                )
                
                if let voiceId = summary.audioVoice,
                   let voice = TTSVoice(rawValue: voiceId) {
                    selectedVoice = voice
                }
                
                // Load audio from saved URL
                if let audioUrl = summary.audioUrl, !audioUrl.isEmpty {
                    await loadAudioFromURL(audioUrl)
                } else {
                    // No saved audio — regenerate from narrative
                    await regenerateAudioForExisting(narrative: narrative)
                }
                
                generationPhase = .ready
                isSaved = true
            }
        } catch {
            print("⚠️ AISummaryView: Could not load saved summary: \(error.localizedDescription)")
        }
    }
    
    private func loadAudioFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                audioPlayer.loadFromData(data)
            }
            print("✅ AISummaryView: Loaded audio from saved URL")
        } catch {
            print("⚠️ AISummaryView: Failed to load audio from URL, regenerating: \(error.localizedDescription)")
            // Fall back to regeneration
            if let summary = localSummary {
                await regenerateAudioForExisting(narrative: summary.narrative)
            }
        }
    }
    
    private func regenerateAudioForExisting(narrative: String) async {
        do {
            let audioData = try await summaryService.generateAudio(
                text: narrative,
                voice: selectedVoice,
                speed: 1.0
            )
            await MainActor.run {
                audioPlayer.loadFromData(audioData)
            }
            print("✅ AISummaryView: Regenerated audio for saved summary")
        } catch {
            print("⚠️ AISummaryView: Failed to regenerate audio: \(error.localizedDescription)")
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // AI Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .purple.opacity(0.5), radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            Text(meeting.title ?? "Meeting Summary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Generate Prompt
    
    private var generatePrompt: some View {
        VStack(spacing: 24) {
            // Info Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Dashmet-Powered Summary")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text("Dashmet will analyze your meeting transcript and create a professional narrative summary with key insights, action items, and a realistic voice narration.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                
                // Features
                VStack(alignment: .leading, spacing: 10) {
                    featureRow(icon: "doc.text.magnifyingglass", text: "Intelligent transcript analysis")
                    featureRow(icon: "list.bullet.rectangle", text: "Key points, takeaways & action items")
                    featureRow(icon: "target", text: "Meeting objectives identified")
                    featureRow(icon: "speaker.wave.3", text: "Realistic voice narration")
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(AppColors.surfaceSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Voice")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Button {
                    showVoiceOptions = true
                } label: {
                    HStack {
                        Image(systemName: selectedVoice.icon)
                            .foregroundColor(.purple)
                        Text(selectedVoice.displayName)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding()
                    .background(AppColors.surfaceSecondary.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Generate Button
            Button {
                generateSummaryWithAudio()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Dashmet Summary")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Dashmet Progress View
    
    private var dashmetProgressView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 10)
            
            // ── Circular Progress Ring ──────────────────────
            ZStack {
                // Pulsing ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 155
                        )
                    )
                    .frame(width: 290, height: 290)
                    .scaleEffect(glowPulse ? 1.12 : 0.88)
                    .opacity(glowPulse ? 0.55 : 0.2)
                    .onAppear {
                        glowPulse = false
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            glowPulse = true
                        }
                    }

                // Orbiting particle dots
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.cyan.opacity(0.5))
                        .frame(width: CGFloat(6 - i), height: CGFloat(6 - i))
                        .offset(y: -106)
                        .rotationEffect(.degrees(glowPulse ? 360 : 0) + .degrees(Double(i) * 120))
                        .animation(
                            .linear(duration: Double(8 + i * 4)).repeatForever(autoreverses: false),
                            value: glowPulse
                        )
                }
                
                // Background track ring
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.purple.opacity(0.1),
                        lineWidth: 12
                    )
                    .frame(width: 200, height: 200)
                
                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: simulatedProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "8B5CF6"),
                                Color(hex: "7C3AED"),
                                Color(hex: "6366F1"),
                                Color(hex: "06B6D4"),
                                Color(hex: "8B5CF6")
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .purple.opacity(0.5), radius: 8)
                
                // Glowing tip dot
                if simulatedProgress > 0.01 && !showCompletionCheck {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 18, height: 18)
                        .shadow(color: .cyan.opacity(0.8), radius: 8)
                        .offset(y: -100)
                        .rotationEffect(.degrees(360 * simulatedProgress - 90))
                }
                
                // Center content
                VStack(spacing: 2) {
                    if showCompletionCheck {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(Int(simulatedProgress * 100))")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCompletionCheck)
            }
            
            // ── Stage Info ──────────────────────────────────
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: currentStageIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    
                    Text(currentStageTitle)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }
                .animation(.easeInOut(duration: 0.3), value: generationPhase)
                
                // Rotating friendly message
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .id(statusMessage)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
            .animation(.easeInOut(duration: 0.4), value: statusMessage)
            
            // ── Stage Progress Pills ────────────────────────
            HStack(spacing: 8) {
                progressPill(
                    title: "Analyze",
                    icon: "brain.head.profile",
                    isActive: generationPhase == .generatingSummary,
                    isComplete: generationPhase == .generatingAudio || generationPhase == .completing
                )
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                
                progressPill(
                    title: "Narrate",
                    icon: "waveform",
                    isActive: generationPhase == .generatingAudio,
                    isComplete: generationPhase == .completing
                )
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                
                progressPill(
                    title: "Complete",
                    icon: "checkmark",
                    isActive: generationPhase == .completing,
                    isComplete: showCompletionCheck
                )
            }
            
            Spacer().frame(height: 10)
        }
        .padding(.vertical, 20)
    }
    
    // Stage icon based on phase
    private var currentStageIcon: String {
        switch generationPhase {
        case .generatingSummary: return "brain.head.profile"
        case .generatingAudio: return "waveform"
        case .completing: return showCompletionCheck ? "checkmark.seal.fill" : "sparkles"
        default: return "sparkles"
        }
    }
    
    // Stage title based on phase
    private var currentStageTitle: String {
        switch generationPhase {
        case .generatingSummary: return "Analyzing Meeting"
        case .generatingAudio: return "Creating Narration"
        case .completing: return showCompletionCheck ? "Summary Complete!" : "Finalizing..."
        default: return "Processing"
        }
    }
    
    // Stage pill component
    private func progressPill(title: String, icon: String, isActive: Bool, isComplete: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : icon)
                .font(.system(size: 10))
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(
            isComplete ? .green :
            isActive ? .white :
            AppColors.textTertiary
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isComplete ? Color.green.opacity(0.2) :
            isActive ? Color.purple :
            AppColors.surfaceSecondary.opacity(0.5)
        )
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isComplete)
    }
    
    // MARK: - Summary Content
    
    private func summaryContent(_ summary: NarrativeSummary) -> some View {
        VStack(spacing: 20) {
            // Audio Player Card
            audioPlayerCard(summary)
            
            // Brief Summary
            summaryCard(title: "Brief Summary", icon: "text.quote", content: summary.briefSummary)
            
            // Tone Badge
            HStack {
                Image(systemName: "theatermasks")
                    .foregroundColor(.purple)
                Text("Meeting Tone: ")
                    .foregroundColor(AppColors.textSecondary)
                Text(summary.tone.capitalized)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.surfaceSecondary.opacity(0.8))
            .clipShape(Capsule())
            
            // Objectives
            if !summary.objectives.isEmpty {
                listCard(title: "Objectives", icon: "target", items: summary.objectives, color: .blue)
            }
            
            // Key Discussions
            if !summary.keyDiscussions.isEmpty {
                listCard(title: "Key Discussions", icon: "bubble.left.and.bubble.right", items: summary.keyDiscussions, color: .purple)
            }
            
            // Action Items
            if !summary.actionItems.isEmpty {
                listCard(title: "Action Items", icon: "checkmark.circle", items: summary.actionItems, color: .red)
            }
            
            // Takeaways
            if !summary.takeaways.isEmpty {
                listCard(title: "Key Takeaways", icon: "lightbulb", items: summary.takeaways, color: .orange)
            }
            
            // Full Narrative (expandable)
            narrativeCard(summary.narrative)
            
            // Save Button
            if !isSaved {
                Button {
                    saveSummaryToDatabase(summary)
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Saving..." : "Save Summary")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .green.opacity(0.4), radius: 10, y: 5)
                }
                .disabled(isSaving)
            } else {
                // Saved confirmation
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Summary Saved")
                        .fontWeight(.medium)
                }
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Audio Player Card
    
    private func audioPlayerCard(_ summary: NarrativeSummary) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Listen to Summary")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                // Voice indicator
                HStack(spacing: 4) {
                    Image(systemName: selectedVoice.icon)
                        .font(.caption)
                    Text(selectedVoice.rawValue.capitalized)
                        .font(.caption)
                }
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.surfaceSecondary.opacity(0.8))
                .clipShape(Capsule())
            }
            
            // Progress
            VStack(spacing: 8) {
                Slider(
                    value: $audioPlayer.progress,
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.progress)
                        }
                    }
                )
                .accentColor(.purple)
                
                HStack {
                    Text(audioPlayer.currentTimeString)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text(audioPlayer.durationString)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            // Controls
            HStack(spacing: 32) {
                // Rewind
                Button {
                    audioPlayer.skip(by: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // Play/Pause
                Button {
                    audioPlayer.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 64, height: 64)
                            .shadow(color: .purple.opacity(0.4), radius: 10)
                        
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                // Forward
                Button {
                    audioPlayer.skip(by: 10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            
            // Speed Controls
            HStack(spacing: 12) {
                ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) { speed in
                    Button {
                        audioPlayer.setSpeed(Float(speed))
                    } label: {
                        Text("\(speed, specifier: speed == 1.0 ? "%.0f" : "%.2g")x")
                            .font(.caption)
                            .fontWeight(audioPlayer.playbackSpeed == Float(speed) ? .bold : .regular)
                            .foregroundColor(audioPlayer.playbackSpeed == Float(speed) ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(audioPlayer.playbackSpeed == Float(speed) ? Color.purple : AppColors.surfaceSecondary.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.surfaceSecondary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Summary Card
    
    private func summaryCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.surfaceSecondary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - List Card
    
    private func listCard(title: String, icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                            .frame(width: 20, height: 20)
                            .background(color.opacity(0.2))
                            .clipShape(Circle())
                        
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.surfaceSecondary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Narrative Card
    
    private func narrativeCard(_ narrative: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                Text("Full Narrative")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = narrative
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Text(narrative)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.surfaceSecondary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Generation Failed")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                generationPhase = .idle
                errorMessage = nil
            } label: {
                Text("Try Again")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Voice Selection Sheet
    
    private var voiceSelectionSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TTSVoice.allCases, id: \.self) { voice in
                        HStack {
                            // Voice info (tap to select)
                            Button {
                                // Stop any playing preview
                                previewPlayer.stop()
                                previewingVoice = nil
                                
                                selectedVoice = voice
                                showVoiceOptions = false
                                
                                // If already have audio, regenerate with new voice
                                if generationPhase == .ready, let summary = localSummary {
                                    regenerateAudio(for: summary)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: voice.icon)
                                        .foregroundColor(.purple)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(voice.rawValue.capitalized)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(voice.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Preview button
                            Button {
                                playVoicePreview(voice: voice)
                            } label: {
                                Group {
                                    if isLoadingPreview && previewingVoice == voice {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if previewingVoice == voice && previewPlayer.isPlaying {
                                        Image(systemName: "stop.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.purple)
                                    } else {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.purple.opacity(0.7))
                                    }
                                }
                                .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingPreview && previewingVoice != voice)
                            
                            // Selection checkmark
                            if selectedVoice == voice {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                } header: {
                    Text("Select Voice")
                } footer: {
                    Text("Tap the play button to preview each voice. Onyx is recommended for professional meeting summaries.")
                }
            }
            .navigationTitle("Voice Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Stop preview when closing
                        previewPlayer.stop()
                        previewingVoice = nil
                        showVoiceOptions = false
                    }
                }
            }
            .onDisappear {
                // Clean up preview when sheet closes
                previewPlayer.stop()
                previewingVoice = nil
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Voice Preview
    
    private func playVoicePreview(voice: TTSVoice) {
        // If this voice is already playing, stop it
        if previewingVoice == voice && previewPlayer.isPlaying {
            previewPlayer.stop()
            previewingVoice = nil
            return
        }
        
        // Stop any current preview
        previewPlayer.stop()
        previewingVoice = voice
        isLoadingPreview = true
        
        Task {
            do {
                // Generate a short sample audio
                let sampleText = "Hello! This is how I sound when reading your meeting summaries. I hope you enjoy this voice."
                
                let audioData = try await summaryService.generateAudio(
                    text: sampleText,
                    voice: voice,
                    speed: 1.0
                )
                
                // Load and play
                previewPlayer.loadFromData(audioData)
                previewPlayer.togglePlayPause()
                isLoadingPreview = false
                
                // Auto-stop tracking when playback ends
                Task {
                    // Wait for playback to potentially finish (sample is ~5 seconds)
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    if !previewPlayer.isPlaying {
                        await MainActor.run {
                            previewingVoice = nil
                        }
                    }
                }
                
            } catch {
                print("❌ Voice preview failed: \(error)")
                isLoadingPreview = false
                previewingVoice = nil
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateSummaryWithAudio() {
        Task {
            do {
                // Reset progress state
                await MainActor.run {
                    simulatedProgress = 0
                    statusMessage = "Hang on while Dashmet analyzes your meeting..."
                    showCompletionCheck = false
                }
                
                // Phase 1: Generate summary
                generationPhase = .generatingSummary
                
                // Start progress simulation concurrently
                let progressTask = Task { await simulateProgress() }
                
                let summary = try await summaryService.generateNarrativeSummary(
                    meetingTitle: meeting.title ?? "Meeting",
                    meetingType: meeting.safeMeetingType.displayName,
                    meetingDate: meeting.createdAt,
                    duration: meeting.duration != nil ? Int(meeting.duration!) : nil,
                    transcript: transcript
                )
                
                localSummary = summary
                
                // Phase 2: Generate audio
                await MainActor.run {
                    generationPhase = .generatingAudio
                }
                
                let audioData = try await summaryService.generateAudio(
                    text: summary.narrative,
                    voice: selectedVoice,
                    speed: 1.0
                )
                
                // Stop simulation
                progressTask.cancel()
                
                // Phase 3: Professional completion animation
                await MainActor.run {
                    generationPhase = .completing
                }
                
                await animateCompletion()
                
                // Load audio with auto-play and transition to ready
                await MainActor.run {
                    audioPlayer.loadFromData(audioData, autoPlay: true)
                    generationPhase = .ready
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    generationPhase = .error
                }
                print("❌ Summary generation failed: \(error)")
            }
        }
    }
    
    // MARK: - Progress Simulation
    
    private func simulateProgress() async {
        let summaryMessages = [
            "Hang on while Dashmet analyzes your meeting...",
            "Dashmet is reading through your transcript...",
            "Identifying key discussion points...",
            "Extracting meeting objectives and outcomes...",
            "Analyzing conversation patterns and insights...",
            "Dashmet is organizing your meeting data...",
            "Crafting a comprehensive narrative..."
        ]
        
        let audioMessages = [
            "Dashmet is preparing voice narration...",
            "Generating realistic speech output...",
            "Creating your audio summary..."
        ]
        
        var tickCount = 0
        var msgIndex = 0
        
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            guard !Task.isCancelled else { break }
            
            await MainActor.run {
                let maxProgress: Double
                let increment: Double
                let messages: [String]
                
                switch generationPhase {
                case .generatingSummary:
                    maxProgress = 0.52
                    increment = Double.random(in: 0.004...0.016)
                    messages = summaryMessages
                case .generatingAudio:
                    maxProgress = 0.80
                    increment = Double.random(in: 0.008...0.022)
                    messages = audioMessages
                default:
                    return
                }
                
                if simulatedProgress < maxProgress {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        simulatedProgress = min(simulatedProgress + increment, maxProgress)
                    }
                }
                
                // Rotate message every ~12 ticks (3 seconds)
                tickCount += 1
                if tickCount % 12 == 0 {
                    msgIndex += 1
                    statusMessage = messages[msgIndex % messages.count]
                }
            }
        }
    }
    
    // MARK: - Completion Animation
    
    private func animateCompletion() async {
        let startProgress = await MainActor.run { simulatedProgress }
        
        // Phase A: Ramp to ~92%
        await MainActor.run {
            statusMessage = "Wrapping up the final details..."
        }
        
        let targetA = 0.92
        if startProgress < targetA {
            let steps = 20
            let stepAmount = (targetA - startProgress) / Double(steps)
            for i in 1...steps {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                let value = startProgress + stepAmount * Double(i)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        simulatedProgress = min(value, targetA)
                    }
                }
            }
        }
        
        // Brief pause
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Phase B: Slow ease-out push to 100%
        await MainActor.run {
            statusMessage = "Almost there..."
        }
        
        let steps2 = 16
        let startB = await MainActor.run { simulatedProgress }
        let remainingB = 1.0 - startB
        for i in 1...steps2 {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(nanoseconds: 60_000_000) // 60ms
            let t = Double(i) / Double(steps2)
            let easedT = 1 - pow(1 - t, 2.5) // cubic ease-out
            let value = startB + remainingB * easedT
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.1)) {
                    simulatedProgress = min(value, 1.0)
                }
            }
        }
        
        // Ensure 100%
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                simulatedProgress = 1.0
            }
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Show completion checkmark
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showCompletionCheck = true
                statusMessage = "Your Dashmet summary is ready!"
            }
        }
        
        // Hold for a moment to admire the success
        try? await Task.sleep(nanoseconds: 1_800_000_000)
    }
    
    private func regenerateSummary() {
        generationPhase = .idle
        localSummary = nil
        audioPlayer.stop()
    }
    
    private func regenerateAudio(for summary: NarrativeSummary) {
        Task {
            do {
                generationPhase = .generatingAudio
                
                let audioData = try await summaryService.generateAudio(
                    text: summary.narrative,
                    voice: selectedVoice,
                    speed: 1.0
                )
                
                audioPlayer.loadFromData(audioData)
                generationPhase = .ready
                
            } catch {
                errorMessage = error.localizedDescription
                generationPhase = .error
            }
        }
    }
    
    private func saveSummaryToDatabase(_ summary: NarrativeSummary) {
        isSaving = true
        
        Task {
            do {
                // Save to backend database with audio uploaded to Firebase Storage
                let savedSummary = try await MeetingSummaryService.shared.saveAISummaryToDatabase(
                    meetingId: meeting.id,
                    summary: summary,
                    audioData: audioPlayer.audioData,
                    voice: selectedVoice
                )
                
                print("✅ AI Summary saved to database. ID: \(savedSummary.id)")
                if let audioUrl = savedSummary.audioUrl {
                    print("✅ AI Audio URL: \(audioUrl)")
                }
                
                // Also save locally for quick access
                let localData: [String: Any] = [
                    "id": savedSummary.id,
                    "briefSummary": summary.briefSummary,
                    "narrative": summary.narrative,
                    "tone": summary.tone,
                    "objectives": summary.objectives,
                    "keyDiscussions": summary.keyDiscussions,
                    "actionItems": summary.actionItems,
                    "takeaways": summary.takeaways,
                    "audioUrl": savedSummary.audioUrl ?? "",
                    "audioVoice": selectedVoice.rawValue,
                    "generatedAt": summary.generatedAt,
                    "savedAt": Date().timeIntervalSince1970
                ]
                
                if let data = try? JSONSerialization.data(withJSONObject: localData) {
                    UserDefaults.standard.set(data, forKey: "ai_summary_\(meeting.id)")
                }
                
                await MainActor.run {
                    isSaving = false
                    isSaved = true
                    showSaveSuccess = true
                    
                    // Notify parent that summary was saved
                    onSummarySaved?()
                }
                
                // ─── Dashmet Audio Recording Policy ───────────────────────
                // After AI summary is saved, delete the original meeting
                // audio recording from Firebase Storage, the local file,
                // and clear the URL from the backend database.
                do {
                    if let userId = FirebaseAuthService.shared.currentUser?.uid {
                        try await FirebaseStorageService.shared.deleteMeetingRecording(
                            meetingId: meeting.id,
                            userId: userId
                        )
                    }
                    try await APIService.shared.clearMeetingRecordingUrl(meetingId: meeting.id)
                    
                    // Also delete local recording file
                    let fileManager = FileManager.default
                    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings")
                    
                    let legacyURL = recordingsDirectory.appendingPathComponent("\(meeting.id).m4a")
                    if fileManager.fileExists(atPath: legacyURL.path) {
                        try? fileManager.removeItem(at: legacyURL)
                    }
                    
                    // Also check timestamped format
                    if let files = try? fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil) {
                        let meetingPrefix = "meeting_\(meeting.id)_"
                        for file in files where file.lastPathComponent.hasPrefix(meetingPrefix) && file.pathExtension == "m4a" {
                            try? fileManager.removeItem(at: file)
                        }
                    }
                    
                    print("🗑️ Original recording deleted per Dashmet Audio Recording Policy")
                } catch {
                    print("⚠️ Failed to delete original recording: \(error.localizedDescription)")
                }
                
            } catch {
                print("❌ Failed to save AI summary: \(error.localizedDescription)")
                
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Summary Audio Player

@MainActor
class SummaryAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var isLoaded = false
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // Store the audio data so we can upload it to Firebase Storage
    private(set) var audioData: Data?
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func loadFromData(_ data: Data, autoPlay: Bool = false) {
        // Store the data for later upload
        self.audioData = data
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.enableRate = true
            player?.prepareToPlay()
            player?.rate = playbackSpeed
            duration = player?.duration ?? 0
            isLoaded = true
            
            print("✅ Summary audio loaded: \(duration)s, autoPlay: \(autoPlay)")
            
            if autoPlay {
                player?.play()
                isPlaying = true
                startTimer()
            }
        } catch {
            print("❌ Failed to load audio: \(error)")
            isLoaded = false
        }
    }
    
    func togglePlayPause() {
        guard let player = player else {
            print("⚠️ SummaryAudioPlayer: No player available")
            return
        }
        
        // If playback finished, reset to beginning
        if !isPlaying && currentTime >= duration - 0.2 {
            player.currentTime = 0
            currentTime = 0
            progress = 0
        }
        
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            // Re-activate audio session before playing
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("⚠️ Failed to activate audio session: \(error)")
            }
            player.play()
            startTimer()
        }
        isPlaying = player.isPlaying
    }
    
    func stop() {
        player?.stop()
        stopTimer()
        isPlaying = false
        progress = 0
        currentTime = 0
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
        
        let wasPlaying = player.isPlaying
        if wasPlaying { player.pause() }
        player.rate = speed
        if wasPlaying { player.play() }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            if flag {
                self.progress = 1.0
                self.currentTime = self.duration
            }
            print("🔊 Audio playback finished (success: \(flag))")
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
    
    private func startTimer() {
        stopTimer()
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

// MARK: - Preview

#Preview {
    AISummaryView(
        meeting: Meeting.preview,
        transcript: "Hello everyone, welcome to our meeting. Today we'll discuss the new features..."
    )
}
