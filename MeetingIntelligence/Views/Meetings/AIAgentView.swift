//
//  AIAgentView.swift
//  MeetingIntelligence
//
//  Live AI Agent that listens to audio and processes conversation in real-time
//  Provides continuous transcript without speaker identification
//

import SwiftUI
import Combine

// MARK: - AI Agent State
enum AIAgentState: Equatable {
    case idle
    case listening
    case processing
    case paused
    case error(String)
    
    var statusText: String {
        switch self {
        case .idle: return "Ready to listen"
        case .listening: return "System is listening..."
        case .processing: return "Processing audio..."
        case .paused: return "Paused"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "brain"
        case .listening: return "ear.fill"
        case .processing: return "sparkles"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .listening: return .green
        case .processing: return .blue
        case .paused: return .orange
        case .error: return .red
        }
    }
}

// MARK: - AI Agent View
struct AIAgentView: View {
    @ObservedObject var speechService: SpeechRecognitionService
    
    @State private var agentState: AIAgentState = .idle
    @State private var continuousTranscript: String = ""
    @State private var audioQualityIndicator: Double = 0.8
    @State private var noiseLevel: Double = 0.1
    @State private var showSettings = false
    
    private let gradientColors = [
        Color(hex: "1a1a2e"),
        Color(hex: "16213e"),
        Color(hex: "0f3460")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // AI Agent Header
            agentHeader
            
            // Main Transcript Area
            transcriptArea
                .frame(maxHeight: .infinity)
            
            // Audio Quality Indicators
            audioQualityBar
        }
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: speechService.isRecognizing) { _, isRecognizing in
            updateAgentState(isRecognizing: isRecognizing)
        }
        .onChange(of: speechService.continuousText) { _, newText in
            continuousTranscript = newText
            if let confidence = speechService.transcript.last?.confidence {
                audioQualityIndicator = Double(confidence)
            }
        }
        .sheet(isPresented: $showSettings) {
            AISettingsSheet(speechService: speechService)
        }
    }
    
    // MARK: - Agent Header
    private var agentHeader: some View {
        HStack(spacing: 16) {
            // AI Status Indicator
            HStack(spacing: 10) {
                ZStack {
                    // Outer glow when active
                    if agentState == .listening {
                        Circle()
                            .fill(agentState.color.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .modifier(PulsingGlow())
                    }
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [agentState.color, agentState.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: agentState.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Agent")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(agentState.statusText)
                        .font(.system(size: 11))
                        .foregroundColor(agentState.color)
                }
            }
            
            Spacer()
            
            // Language & Settings
            HStack(spacing: 12) {
                // Language badge
                HStack(spacing: 4) {
                    Text(speechService.currentLanguage?.flag ?? "🌍")
                        .font(.system(size: 16))
                    Text(speechService.currentLanguage?.name.components(separatedBy: " (").first ?? "English")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                // Settings button
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Transcript Area
    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if continuousTranscript.isEmpty && agentState != .listening {
                        // Empty state
                        emptyStateView
                    } else if continuousTranscript.isEmpty && agentState == .listening {
                        // Listening state
                        listeningStateView
                    } else {
                        // Transcript content
                        transcriptContent
                            .id("transcript")
                    }
                    
                    Color.clear.frame(height: 20)
                        .id("bottom")
                }
                .padding(20)
            }
            .onChange(of: continuousTranscript) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("System Agent Ready")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Start recording and the System will listen\nand transcribe the conversation")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            // Features list
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "ear.fill", text: "High sensitivity microphone")
                featureRow(icon: "waveform.path", text: "Noise & music filtering")
                featureRow(icon: "text.bubble.fill", text: "Real-time transcription")
                featureRow(icon: "sparkles", text: "System-powered formatting")
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var listeningStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated listening indicator
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 80 + CGFloat(i * 30), height: 80 + CGFloat(i * 30))
                        .modifier(ExpandingRing(delay: Double(i) * 0.3))
                }
                
                Image(systemName: "ear.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.primary)
            }
            
            Text("Listening...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Speak clearly • System is processing audio")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Live indicator
            if agentState == .listening {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .modifier(PulsingGlow())
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
            }
            
            // The continuous transcript
            Text(continuousTranscript)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white.opacity(0.95))
                .lineSpacing(6)
                .textSelection(.enabled)
            
            // Processing indicator
            if agentState == .listening && !continuousTranscript.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .modifier(TypingIndicator(delay: Double(i) * 0.2))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    agentState == .listening ? AppColors.primary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Audio Quality Bar
    private var audioQualityBar: some View {
        HStack(spacing: 16) {
            // Audio quality
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                
                Text("Audio")
                    .font(.system(size: 10, weight: .medium))
                
                QualityBar(value: audioQualityIndicator)
                    .frame(width: 40, height: 4)
            }
            .foregroundColor(.white.opacity(0.6))
            
            // Noise level
            HStack(spacing: 6) {
                Image(systemName: noiseLevel > 0.3 ? "speaker.wave.3.fill" : "speaker.fill")
                    .font(.system(size: 12))
                
                Text("Noise")
                    .font(.system(size: 10, weight: .medium))
                
                QualityBar(value: 1 - noiseLevel, color: noiseLevel > 0.3 ? .orange : .green)
                    .frame(width: 40, height: 4)
            }
            .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            // Word count
            if !continuousTranscript.isEmpty {
                let wordCount = continuousTranscript.split(separator: " ").count
                HStack(spacing: 4) {
                    Image(systemName: "text.word.spacing")
                        .font(.system(size: 10))
                    Text("\(wordCount) words")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Helper Methods
    private func updateAgentState(isRecognizing: Bool) {
        if isRecognizing {
            agentState = .listening
        } else if !continuousTranscript.isEmpty {
            agentState = .processing
            // After a brief moment, go to idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                agentState = .idle
            }
        } else {
            agentState = .idle
        }
    }
}

// MARK: - Quality Bar
struct QualityBar: View {
    let value: Double
    var color: Color = .green
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
            }
        }
    }
}

// MARK: - Pulsing Glow Animation
struct PulsingGlow: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.5 : 1.0)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - Expanding Ring Animation
struct ExpandingRing: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

// MARK: - Typing Indicator Animation
struct TypingIndicator: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -4 : 0)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - AI Settings Sheet
struct AISettingsSheet: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLanguage: SupportedLanguage?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Language selection
                    NavigationLink {
                        LanguagePickerSheet(
                            languageManager: LanguageManager.shared,
                            onSelect: { language in
                                speechService.setLanguage(language)
                                dismiss()
                            }
                        )
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Text(speechService.currentLanguage?.name ?? "English")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Recognition")
                }
                
                Section {
                    HStack {
                        Label("Microphone Sensitivity", systemImage: "mic.fill")
                        Spacer()
                        Text("High")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Label("Noise Filtering", systemImage: "waveform.path.ecg")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Label("Background Audio", systemImage: "speaker.wave.2.fill")
                        Spacer()
                        Text("Filtered")
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Audio Processing")
                } footer: {
                    Text("High sensitivity mode allows the System to hear conversations from a distance. Background noise, music, and non-speech sounds are automatically filtered.")
                }
                
                Section {
                    HStack {
                        Label("Real-time Processing", systemImage: "brain")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Label("Auto-punctuation", systemImage: "textformat")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("System Features")
                }
            }
            .navigationTitle("System Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AIAgentView(speechService: SpeechRecognitionService.shared)
        .preferredColorScheme(.dark)
}
