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

struct AISummaryView: View {
    let meeting: Meeting
    let transcript: String
    let onSummarySaved: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
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
    
    init(meeting: Meeting, transcript: String, onSummarySaved: (() -> Void)? = nil) {
        self.meeting = meeting
        self.transcript = transcript
        self.onSummarySaved = onSummarySaved
    }
    
    enum GenerationPhase {
        case idle
        case generatingSummary
        case generatingAudio
        case ready
        case error
    }
    
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
                        case .generatingSummary:
                            generatingView(phase: "Analyzing Meeting", subtitle: "System is reading and understanding your transcript...")
                        case .generatingAudio:
                            generatingView(phase: "Creating Voice", subtitle: "Generating realistic speech narration...")
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
                    .foregroundColor(.white)
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
                                .foregroundColor(.white)
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
                .foregroundColor(.white)
            
            Text(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
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
                    Text("System-Powered Summary")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("Our System will analyze your meeting transcript and create a professional narrative summary. It will then speak the summary aloud using a realistic voice.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                
                // Features
                VStack(alignment: .leading, spacing: 10) {
                    featureRow(icon: "doc.text.magnifyingglass", text: "Intelligent transcript analysis")
                    featureRow(icon: "list.bullet.rectangle", text: "Key points and takeaways")
                    featureRow(icon: "target", text: "Meeting objectives identified")
                    featureRow(icon: "speaker.wave.3", text: "Realistic voice narration")
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Voice")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    showVoiceOptions = true
                } label: {
                    HStack {
                        Image(systemName: selectedVoice.icon)
                            .foregroundColor(.purple)
                        Text(selectedVoice.displayName)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Generate Button
            Button {
                generateSummaryWithAudio()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate System Summary")
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
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Generating View
    
    private func generatingView(phase: String, subtitle: String) -> some View {
        VStack(spacing: 24) {
            // Animated pulse
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                        .scaleEffect(generationPhase == .idle ? 1.0 : 1.2)
                        .opacity(generationPhase == .idle ? 1.0 : 0.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: generationPhase
                        )
                }
                
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                
                Image(systemName: generationPhase == .generatingSummary ? "brain" : "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(phase)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.2)
        }
        .padding(.vertical, 60)
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
                    .foregroundColor(.white.opacity(0.7))
                Text(summary.tone.capitalized)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            
            // Objectives
            if !summary.objectives.isEmpty {
                listCard(title: "Objectives", icon: "target", items: summary.objectives, color: .blue)
            }
            
            // Key Discussions
            if !summary.keyDiscussions.isEmpty {
                listCard(title: "Key Discussions", icon: "bubble.left.and.bubble.right", items: summary.keyDiscussions, color: .purple)
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
                .foregroundColor(.white)
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
                    .foregroundColor(.white)
                Spacer()
                
                // Voice indicator
                HStack(spacing: 4) {
                    Image(systemName: selectedVoice.icon)
                        .font(.caption)
                    Text(selectedVoice.rawValue.capitalized)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
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
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(audioPlayer.durationString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
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
                        .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
                            .foregroundColor(audioPlayer.playbackSpeed == Float(speed) ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(audioPlayer.playbackSpeed == Float(speed) ? Color.purple : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
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
                    .foregroundColor(.white)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.08))
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
                    .foregroundColor(.white)
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
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.08))
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
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = narrative
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Text(narrative)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.08))
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
                .foregroundColor(.white)
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
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
                        Button {
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
                                
                                Spacer()
                                
                                if selectedVoice == voice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select Voice")
                } footer: {
                    Text("Onyx is recommended for professional meeting summaries.")
                }
            }
            .navigationTitle("Voice Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showVoiceOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Actions
    
    private func generateSummaryWithAudio() {
        Task {
            do {
                // Phase 1: Generate summary
                generationPhase = .generatingSummary
                
                let summary = try await summaryService.generateNarrativeSummary(
                    meetingTitle: meeting.title ?? "Meeting",
                    meetingType: meeting.meetingType.displayName,
                    meetingDate: meeting.createdAt,
                    duration: meeting.duration != nil ? Int(meeting.duration!) : nil,
                    transcript: transcript
                )
                
                localSummary = summary
                
                // Phase 2: Generate audio
                generationPhase = .generatingAudio
                
                let audioData = try await summaryService.generateAudio(
                    text: summary.narrative,
                    voice: selectedVoice,
                    speed: 1.0
                )
                
                // Load audio into player
                audioPlayer.loadFromData(audioData)
                
                // Done!
                generationPhase = .ready
                
            } catch {
                errorMessage = error.localizedDescription
                generationPhase = .error
                print("❌ Summary generation failed: \(error)")
            }
        }
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
class SummaryAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    
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
    
    func loadFromData(_ data: Data) {
        // Store the data for later upload
        self.audioData = data
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(data: data)
            player?.enableRate = true
            player?.prepareToPlay()
            player?.rate = playbackSpeed
            duration = player?.duration ?? 0
            
            print("✅ Summary audio loaded: \(duration)s")
        } catch {
            print("❌ Failed to load audio: \(error)")
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

// MARK: - Preview

#Preview {
    AISummaryView(
        meeting: Meeting.preview,
        transcript: "Hello everyone, welcome to our meeting. Today we'll discuss the new features..."
    )
}
