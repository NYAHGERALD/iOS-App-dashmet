//
//  TranscriptReviewView.swift
//  MeetingIntelligence
//
//  Transcript Review Screen - Shows processed transcript with dropdown options
//  AI Summary | Processed Transcript | Raw Transcript
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Transcript View Type
enum TranscriptViewType: String, CaseIterable, Identifiable {
    case processed = "Processed Transcript"
    case summary = "System Summary"
    case raw = "Raw Transcript"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .processed: return "text.alignleft"
        case .summary: return "sparkles"
        case .raw: return "doc.text"
        }
    }
    
    var description: String {
        switch self {
        case .processed: return "System corrected and formatted"
        case .summary: return "Key points and highlights"
        case .raw: return "Original transcription"
        }
    }
}

// MARK: - Transcript Review View
struct TranscriptReviewView: View {
    let meeting: Meeting
    let rawTranscript: String
    let recordingURL: URL?
    
    @StateObject private var viewModel: TranscriptReviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedViewType: TranscriptViewType = .processed
    @State private var showAudioReview = false
    @State private var showShareSheet = false
    
    init(meeting: Meeting, rawTranscript: String, recordingURL: URL?) {
        self.meeting = meeting
        self.rawTranscript = rawTranscript
        self.recordingURL = recordingURL
        _viewModel = StateObject(wrappedValue: TranscriptReviewViewModel(
            meeting: meeting,
            rawTranscript: rawTranscript
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    // View Type Selector
                    viewTypeSelector
                    
                    // Content Area
                    contentArea
                    
                    // Bottom Actions
                    bottomActions
                }
            }
            .navigationTitle("Transcript Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showAudioReview) {
                if let url = recordingURL {
                    AudioReviewSheet(recordingURL: url, meeting: meeting)
                }
            }
            .onAppear {
                Task {
                    await viewModel.processTranscript()
                }
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
    
    // MARK: - View Type Selector
    private var viewTypeSelector: some View {
        VStack(spacing: 12) {
            // Dropdown Menu
            Menu {
                ForEach(TranscriptViewType.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedViewType = type
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(type.rawValue)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: type.icon)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedViewType.icon)
                        .foregroundColor(AppColors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedViewType.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(selectedViewType.description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            
            // Processing Status
            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(AppColors.primary)
                    Text("System is processing transcript...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Meeting Info Header
                meetingHeader
                
                // Transcript Content
                transcriptContent
                
                Spacer(minLength: 100)
            }
            .padding(16)
        }
    }
    
    private var meetingHeader: some View {
        HStack(spacing: 12) {
            // Meeting icon
            ZStack {
                Circle()
                    .fill(Color(hex: meeting.meetingType.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: meeting.meetingType.icon)
                    .foregroundColor(Color(hex: meeting.meetingType.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(meeting.formattedCreatedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Word count badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentContent.split(separator: " ").count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primary)
                Text("words")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content based on selected type
            switch selectedViewType {
            case .processed:
                processedTranscriptView
            case .summary:
                summaryView
            case .raw:
                rawTranscriptView
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var processedTranscriptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.primary)
                Text("System Processed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                
                Spacer()
                
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            if viewModel.processedTranscript.isEmpty && !viewModel.isProcessing {
                Text("Processing will begin shortly...")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
            } else {
                Text(viewModel.processedTranscript.isEmpty ? rawTranscript : viewModel.processedTranscript)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(6)
            }
        }
    }
    
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.orange)
                Text("System Summary")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if viewModel.isGeneratingSummary {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            if viewModel.summary.isEmpty {
                VStack(spacing: 12) {
                    if viewModel.isGeneratingSummary {
                        Text("Generating summary...")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                    } else {
                        Button {
                            Task {
                                await viewModel.generateSummary()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate System Summary")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppGradients.primary)
                            .cornerRadius(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text(viewModel.summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(6)
            }
        }
    }
    
    private var rawTranscriptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.gray)
                Text("Raw Transcript")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("Original")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            Text(rawTranscript.isEmpty ? "No transcript recorded" : rawTranscript)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(6)
        }
    }
    
    private var currentContent: String {
        switch selectedViewType {
        case .processed:
            return viewModel.processedTranscript.isEmpty ? rawTranscript : viewModel.processedTranscript
        case .summary:
            return viewModel.summary
        case .raw:
            return rawTranscript
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Review Audio Button
            if recordingURL != nil {
                Button {
                    showAudioReview = true
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                        Text("Review Audio Recording")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            
            // Save & Continue Button
            Button {
                Task {
                    await viewModel.saveToDatabase()
                    dismiss()
                }
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(viewModel.isSaving ? "Saving..." : "Save & Continue")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppGradients.primary)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Functions
    private func copyToClipboard() {
        UIPasteboard.general.string = currentContent
    }
}

// MARK: - Transcript Review ViewModel
@MainActor
class TranscriptReviewViewModel: ObservableObject {
    let meeting: Meeting
    let rawTranscript: String
    
    @Published var processedTranscript: String = ""
    @Published var summary: String = ""
    @Published var isProcessing: Bool = false
    @Published var isGeneratingSummary: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    init(meeting: Meeting, rawTranscript: String) {
        self.meeting = meeting
        self.rawTranscript = rawTranscript
    }
    
    // MARK: - Process Transcript with AI
    func processTranscript() async {
        guard !rawTranscript.isEmpty else {
            processedTranscript = ""
            return
        }
        
        isProcessing = true
        
        do {
            // Call AI to process and correct the transcript
            let processed = try await processWithAI(text: rawTranscript, type: "correct")
            processedTranscript = processed
            print("✅ Transcript processed successfully")
        } catch {
            print("❌ Failed to process transcript: \(error)")
            // Fallback to raw transcript if processing fails
            processedTranscript = rawTranscript
        }
        
        isProcessing = false
    }
    
    // MARK: - Generate Summary
    func generateSummary() async {
        guard !rawTranscript.isEmpty else { return }
        
        isGeneratingSummary = true
        
        do {
            let summaryText = try await processWithAI(text: rawTranscript, type: "summarize")
            summary = summaryText
            print("✅ Summary generated successfully")
        } catch {
            print("❌ Failed to generate summary: \(error)")
            errorMessage = "Failed to generate summary"
        }
        
        isGeneratingSummary = false
    }
    
    // MARK: - Save to Database
    func saveToDatabase() async {
        isSaving = true
        
        do {
            // 1. Save transcript to backend database
            try await apiService.saveTranscript(
                meetingId: meeting.id,
                rawText: rawTranscript,
                processedText: processedTranscript.isEmpty ? nil : processedTranscript,
                type: processedTranscript.isEmpty ? "raw" : "processed"
            )
            
            // 2. Save summary if generated
            if !summary.isEmpty {
                try await apiService.saveSummary(
                    meetingId: meeting.id,
                    executiveSummary: summary
                )
            }
            
            // 3. Update meeting status to READY
            try await apiService.updateMeeting(
                meetingId: meeting.id,
                status: .ready
            )
            
            // 4. Also keep local cache in UserDefaults (for offline access)
            // Save in both formats that different parts of the app use
            let transcriptData: [String: Any] = [
                "rawTranscript": rawTranscript,
                "processedTranscript": processedTranscript,
                "summary": summary,
                "processedAt": Date().ISO8601Format(),
                "savedToServer": true
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: transcriptData) {
                UserDefaults.standard.set(data, forKey: "transcript_\(meeting.id)")
            }
            
            // Also save the raw transcript in the format OverviewTab reads
            let rawData: [String: Any] = [
                "rawText": rawTranscript,
                "timestamp": Date().timeIntervalSince1970,
                "wordCount": rawTranscript.split(separator: " ").count
            ]
            if let data = try? JSONSerialization.data(withJSONObject: rawData) {
                UserDefaults.standard.set(data, forKey: "rawTranscript_\(meeting.id)")
            }
            
            print("✅ Transcript saved to database successfully")
        } catch {
            print("❌ Failed to save transcript to database: \(error)")
            errorMessage = "Failed to save transcript: \(error.localizedDescription)"
            
            // Still save locally even if server fails
            let transcriptData: [String: Any] = [
                "rawTranscript": rawTranscript,
                "processedTranscript": processedTranscript,
                "summary": summary,
                "processedAt": Date().ISO8601Format(),
                "savedToServer": false
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: transcriptData) {
                UserDefaults.standard.set(data, forKey: "transcript_\(meeting.id)")
            }
            
            // Also save raw transcript locally
            let rawData: [String: Any] = [
                "rawText": rawTranscript,
                "timestamp": Date().timeIntervalSince1970,
                "wordCount": rawTranscript.split(separator: " ").count
            ]
            if let data = try? JSONSerialization.data(withJSONObject: rawData) {
                UserDefaults.standard.set(data, forKey: "rawTranscript_\(meeting.id)")
            }
        }
        
        isSaving = false
    }
    
    // MARK: - AI Processing Helper
    private func processWithAI(text: String, type: String) async throws -> String {
        // Use local AI processing for now
        // This can be replaced with backend API call
        
        switch type {
        case "correct":
            return correctTranscript(text)
        case "summarize":
            return generateLocalSummary(text)
        default:
            return text
        }
    }
    
    // MARK: - Local Transcript Correction
    private func correctTranscript(_ text: String) -> String {
        var corrected = text
        
        // Basic corrections
        // 1. Capitalize first letter of sentences
        let sentences = corrected.components(separatedBy: ". ")
        corrected = sentences.map { sentence in
            guard !sentence.isEmpty else { return sentence }
            return sentence.prefix(1).uppercased() + sentence.dropFirst()
        }.joined(separator: ". ")
        
        // 2. Add proper spacing after punctuation
        corrected = corrected.replacingOccurrences(of: ",", with: ", ")
        corrected = corrected.replacingOccurrences(of: ",  ", with: ", ")
        
        // 3. Fix common speech recognition errors
        let corrections: [String: String] = [
            " i ": " I ",
            " i'm ": " I'm ",
            " i'll ": " I'll ",
            " i've ": " I've ",
            " i'd ": " I'd ",
            "dont ": "don't ",
            "cant ": "can't ",
            "wont ": "won't ",
            "didnt ": "didn't ",
            "doesnt ": "doesn't ",
            "isnt ": "isn't ",
            "wasnt ": "wasn't ",
            "werent ": "weren't ",
            "havent ": "haven't ",
            "hasnt ": "hasn't ",
            "couldnt ": "couldn't ",
            "wouldnt ": "wouldn't ",
            "shouldnt ": "shouldn't "
        ]
        
        for (wrong, right) in corrections {
            corrected = corrected.replacingOccurrences(of: wrong, with: right)
        }
        
        // 4. Ensure proper paragraph breaks (add breaks after long segments)
        let words = corrected.split(separator: " ")
        var result = ""
        var wordCount = 0
        
        for word in words {
            result += String(word) + " "
            wordCount += 1
            
            // Add paragraph break every ~50-80 words at natural break points
            if wordCount > 60 && (word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!")) {
                result += "\n\n"
                wordCount = 0
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Local Summary Generation
    private func generateLocalSummary(_ text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
        let wordCount = text.split(separator: " ").count
        
        var summary = "📊 **Meeting Overview**\n\n"
        summary += "• Duration: Approximately \(wordCount / 150) minutes of speech\n"
        summary += "• Total words: \(wordCount)\n"
        summary += "• Sentences: \(sentences.count)\n\n"
        
        summary += "📝 **Key Points**\n\n"
        
        // Extract first few sentences as key points
        let keyPoints = sentences.prefix(5)
        for (index, point) in keyPoints.enumerated() {
            let cleanPoint = point.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanPoint.isEmpty {
                summary += "\(index + 1). \(cleanPoint).\n"
            }
        }
        
        if sentences.count > 5 {
            summary += "\n... and \(sentences.count - 5) more points discussed.\n"
        }
        
        summary += "\n💡 **Note**: For more detailed System analysis, the full transcript will be processed when uploaded."
        
        return summary
    }
}

// MARK: - Audio Review Sheet
struct AudioReviewSheet: View {
    let recordingURL: URL
    let meeting: Meeting
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Audio Waveform
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        HStack(spacing: 2) {
                            ForEach(0..<50, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.primary.opacity(0.6))
                                    .frame(width: 4, height: CGFloat.random(in: 20...80))
                            }
                        }
                    )
                    .padding(.horizontal)
                
                // Time Display
                HStack {
                    Text(audioPlayer.formattedCurrentTime)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Slider(value: $audioPlayer.progress, in: 0...1) { editing in
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.progress)
                        }
                    }
                    .tint(AppColors.primary)
                    
                    Text(audioPlayer.formattedDuration)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal)
                
                // Playback Controls
                HStack(spacing: 40) {
                    Button {
                        audioPlayer.skip(seconds: -15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        audioPlayer.togglePlayback()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(AppGradients.primary)
                    }
                    
                    Button {
                        audioPlayer.skip(seconds: 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .background(
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Audio Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                audioPlayer.setup(url: recordingURL)
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }
}

// MARK: - Audio Player ViewModel
@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    func setup(url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("❌ Audio setup error: \(error)")
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        progress = 0
        timer?.invalidate()
    }
    
    func skip(seconds: Double) {
        guard let player = player else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        progress = newTime / duration
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let newTime = duration * progress
        player.currentTime = newTime
        currentTime = newTime
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.progress = player.currentTime / self.duration
                
                if !player.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
