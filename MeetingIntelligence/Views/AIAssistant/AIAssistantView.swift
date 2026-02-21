//
//  AIAssistantView.swift
//  MeetingIntelligence
//
//  Immersive Workplace AI Assistant with animated 3D avatar,
//  real-time voice interaction, conversation memory, and TTS.
//

import SwiftUI
import AVFoundation

struct AIAssistantView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var textInput = ""
    @State private var showTextInput = false
    @State private var scrollToBottom = false
    
    var onMenuTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            // Main Content
            ZStack {
                // Avatar Area (always full height)
                avatarSection
                
                // Conversation List Overlay
                if viewModel.showConversationList {
                    conversationListOverlay
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Transcript Panel (full-screen overlay, toggled by chat icon)
                if viewModel.showTranscript {
                    transcriptPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Bottom Controls
            bottomControls
        }
        .background(backgroundGradient)
        .onTapGesture {
            // Dismiss keyboard when tapping empty space
            dismissKeyboard()
        }
        .onAppear {
            viewModel.configure(
                organizationId: appState.organizationId
            )
            Task {
                await viewModel.startNewConversation()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .overlay(alignment: .top) {
            // Error banner
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.error = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.85))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: viewModel.error != nil)
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // showTranscriptPanel removed — transcript is now a full-screen overlay
    // toggled only by viewModel.showTranscript (chat icon button)
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.18),
                Color(red: 0.04, green: 0.04, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            Button {
                onMenuTap()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("DashMet AI")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showTranscript.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.showTranscript ? "text.bubble.fill" : "text.bubble")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                }
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showConversationList.toggle()
                    }
                    if viewModel.showConversationList {
                        Task { await viewModel.loadConversations() }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - AI Visualizer Section
    
    private var avatarSection: some View {
        ZStack {
            // Audio Wave Visualizer
            AIWaveVisualizerView(
                state: viewModel.state,
                audioLevel: viewModel.audioLevel,
                inputAudioLevel: viewModel.inputAudioLevel
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)
            
            // State Indicator Overlay
            VStack {
                Spacer()
                
                stateIndicator
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            
            // Live transcript overlay (while listening)
            if viewModel.state == .listening && !viewModel.currentTranscript.isEmpty {
                VStack {
                    Spacer()
                    
                    liveTranscriptBubble
                        .padding(.horizontal, 40)
                        .padding(.bottom, 60)
                }
            }
        }
    }
    
    // MARK: - State Indicator
    
    private var stateIndicator: some View {
        HStack(spacing: 8) {
            // Animated icon
            Group {
                switch viewModel.state {
                case .idle:
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white.opacity(0.5))
                case .listening:
                    AudioWaveformView(level: viewModel.inputAudioLevel)
                        .frame(width: 24, height: 16)
                case .thinking:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.7)
                case .speaking:
                    AudioWaveformView(level: viewModel.audioLevel)
                        .frame(width: 24, height: 16)
                }
            }
            .frame(width: 24)
            
            Text(viewModel.state.displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(Capsule())
    }
    
    // MARK: - Live Transcript Bubble
    
    private var liveTranscriptBubble: some View {
        Text(viewModel.currentTranscript)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Transcript Panel
    
    private var transcriptPanel: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text("Conversation")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showTranscript = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            if viewModel.messages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No messages yet")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Tap the mic or type a message to start")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages.filter { $0.role != "system" }) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(red: 0.06, green: 0.06, blue: 0.14)
                .opacity(0.97)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Text Input (optional keyboard mode)
            if showTextInput {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Type a message...", text: $textInput, axis: .vertical)
                        .lineLimit(1...6)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                    
                    Button {
                        let text = textInput
                        textInput = ""
                        Task { await viewModel.sendTextMessage(text) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
            }
            
            // Main Action Buttons
            HStack(spacing: 24) {
                // Keyboard toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showTextInput.toggle()
                    }
                } label: {
                    Image(systemName: showTextInput ? "keyboard.fill" : "keyboard")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                
                // New conversation
                Button {
                    Task { await viewModel.startNewConversation() }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                
                // Main mic button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        viewModel.toggleListening()
                    }
                } label: {
                    ZStack {
                        // Pulse ring when listening
                        if viewModel.state == .listening {
                            Circle()
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 3)
                                .frame(width: 80, height: 80)
                                .scaleEffect(1.0 + CGFloat(viewModel.inputAudioLevel) * 0.3)
                                .animation(.easeInOut(duration: 0.1), value: viewModel.inputAudioLevel)
                            
                            Circle()
                                .stroke(AppColors.primary.opacity(0.15), lineWidth: 2)
                                .frame(width: 96, height: 96)
                                .scaleEffect(1.0 + CGFloat(viewModel.inputAudioLevel) * 0.5)
                                .animation(.easeInOut(duration: 0.15), value: viewModel.inputAudioLevel)
                        }
                        
                        Circle()
                            .fill(
                                micButtonGradient
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: micButtonShadowColor, radius: 12, y: 4)
                        
                        Image(systemName: micButtonIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.state == .thinking)
                
                // Spacer to balance layout
                Spacer()
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var micButtonGradient: LinearGradient {
        switch viewModel.state {
        case .idle:
            return LinearGradient(colors: [AppColors.primary, AppColors.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .listening:
            return LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .thinking:
            return LinearGradient(colors: [Color.gray, Color.gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .speaking:
            return LinearGradient(colors: [AppColors.accent, AppColors.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var micButtonShadowColor: Color {
        switch viewModel.state {
        case .idle: return AppColors.primary.opacity(0.4)
        case .listening: return Color.red.opacity(0.4)
        case .thinking: return Color.gray.opacity(0.2)
        case .speaking: return AppColors.accent.opacity(0.4)
        }
    }
    
    private var micButtonIcon: String {
        switch viewModel.state {
        case .idle: return "mic.fill"
        case .listening: return "arrow.up.circle.fill"   // Tap to send
        case .thinking: return "ellipsis"
        case .speaking: return "stop.fill"               // Tap to stop
        }
    }
    
    // MARK: - Conversation List Overlay
    
    private var conversationListOverlay: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showConversationList = false
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("History")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showConversationList = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding()
                
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No conversations yet")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.conversations) { conversation in
                                conversationRow(conversation)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.width * 0.8)
            .background(
                Color(red: 0.08, green: 0.08, blue: 0.14)
                    .ignoresSafeArea()
            )
        }
    }
    
    private func conversationRow(_ conversation: AIConversationListItem) -> some View {
        Button {
            Task { await viewModel.loadConversation(conversation.id) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let lastMsg = conversation.lastMessage {
                        Text(lastMsg.content)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    
                    Text(formatRelativeTime(conversation.updatedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                Spacer()
                
                Text("\(conversation.messageCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(conversation.id == viewModel.currentConversationId
                          ? AppColors.primary.opacity(0.15)
                          : Color.white.opacity(0.05))
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.deleteConversation(conversation.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatRelativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            let basic = ISO8601DateFormatter()
            guard let d = basic.date(from: dateString) else { return dateString }
            return relativeString(from: d)
        }
        return relativeString(from: date)
    }
    
    private func relativeString(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "Just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))h ago" }
        if elapsed < 604800 { return "\(Int(elapsed / 86400))d ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.isUser ? .white : .white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser
                                  ? LinearGradient(colors: [AppColors.primary, AppColors.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                    .multilineTextAlignment(message.isUser ? .trailing : .leading)
            }
            
            if message.isAssistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let level: Float
    let barCount = 5
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 0.08), value: level)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxAdditional: CGFloat = 12
        let multipliers: [Float] = [0.5, 0.8, 1.0, 0.7, 0.4]
        let effectiveLevel = level * multipliers[index % multipliers.count]
        return baseHeight + maxAdditional * CGFloat(effectiveLevel)
    }
}

// MARK: - AI Wave Visualizer — Professional Audio Reactive Animation

struct AIWaveVisualizerView: View {
    let state: AssistantState
    let audioLevel: Float
    let inputAudioLevel: Float
    
    // Number of wave bars
    private let barCount = 40
    // Continuous phase offset for idle animation
    @State private var phase: Double = 0
    
    private var activeLevel: Float {
        switch state {
        case .speaking: return audioLevel
        case .listening: return inputAudioLevel
        default: return 0
        }
    }
    
    private var accentColor: Color {
        switch state {
        case .idle: return Color(red: 0.45, green: 0.4, blue: 0.95)
        case .listening: return Color(red: 0.3, green: 0.85, blue: 0.45)
        case .thinking: return Color(red: 0.95, green: 0.72, blue: 0.25)
        case .speaking: return Color(red: 0.25, green: 0.7, blue: 0.95)
        }
    }
    
    private var glowColor: Color {
        accentColor.opacity(0.4)
    }
    
    var body: some View {
        ZStack {
            // Subtle radial gradient background
            RadialGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            
            // Outer glow ring
            Circle()
                .stroke(accentColor.opacity(0.12), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .scaleEffect(state == .speaking ? 1.0 + CGFloat(audioLevel) * 0.08 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: audioLevel)
            
            Circle()
                .stroke(accentColor.opacity(0.06), lineWidth: 1)
                .frame(width: 260, height: 260)
                .scaleEffect(state == .speaking ? 1.0 + CGFloat(audioLevel) * 0.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: audioLevel)
            
            // Main circular wave visualizer
            ZStack {
                // Glow backdrop
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(0.15),
                                accentColor.opacity(0.03),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(state == .speaking ? 1.0 + CGFloat(audioLevel) * 0.12 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
                
                // Wave bars arranged in a circle
                ForEach(0..<barCount, id: \.self) { index in
                    WaveBar(
                        index: index,
                        total: barCount,
                        level: activeLevel,
                        phase: phase,
                        state: state,
                        accentColor: accentColor
                    )
                }
                
                // Center circle with icon
                ZStack {
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                    
                    // State icon
                    stateIcon
                }
            }
            
            // AI label
            VStack {
                Spacer()
                
                Text("Iris")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .animation(.easeInOut(duration: 0.5), value: state)
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(accentColor.opacity(0.7))
                .symbolEffect(.pulse, options: .repeating)
        case .listening:
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(accentColor)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        case .thinking:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(accentColor)
                .scaleEffect(0.9)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(accentColor)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        }
    }
}

// MARK: - Individual Wave Bar

private struct WaveBar: View {
    let index: Int
    let total: Int
    let level: Float
    let phase: Double
    let state: AssistantState
    let accentColor: Color
    
    private var angle: Double {
        Double(index) / Double(total) * .pi * 2
    }
    
    private var barHeight: CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 32
        
        switch state {
        case .idle:
            // Gentle breathing sine wave
            let wave = sin(phase + angle * 2) * 0.5 + 0.5
            return baseHeight + maxHeight * 0.15 * wave
            
        case .listening, .speaking:
            // Audio-reactive with wave pattern
            let effectiveLevel = CGFloat(level)
            let wave = sin(phase * 3 + angle * 4) * 0.5 + 0.5
            let variation = sin(angle * 6 + phase * 2) * 0.3 + 0.7
            return baseHeight + maxHeight * effectiveLevel * wave * variation
            
        case .thinking:
            // Rotating chase pattern
            let chasePos = fmod(phase * 2, .pi * 2)
            let dist = abs(angle - chasePos)
            let normalizedDist = min(dist, .pi * 2 - dist) / .pi
            let intensity = max(0, 1.0 - normalizedDist * 2.5)
            return baseHeight + maxHeight * 0.5 * intensity
        }
    }
    
    private var barOpacity: Double {
        switch state {
        case .idle:
            return 0.3 + sin(phase + angle * 2) * 0.15
        case .listening, .speaking:
            return 0.4 + Double(level) * 0.5
        case .thinking:
            let chasePos = fmod(phase * 2, .pi * 2)
            let dist = abs(angle - chasePos)
            let normalizedDist = min(dist, .pi * 2 - dist) / .pi
            return max(0.15, 1.0 - normalizedDist * 2.0)
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(barOpacity),
                        accentColor.opacity(barOpacity * 0.5)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3.5, height: barHeight)
            .offset(y: -75 - barHeight / 2)
            .rotationEffect(.radians(angle))
            .animation(.easeOut(duration: 0.08), value: level)
            .animation(.easeInOut(duration: 0.3), value: state)
    }
}
