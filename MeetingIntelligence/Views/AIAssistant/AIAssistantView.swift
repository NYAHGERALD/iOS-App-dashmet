//
//  AIAssistantView.swift
//  MeetingIntelligence
//
//  Immersive Workplace AI Assistant with animated 3D avatar,
//  real-time voice interaction, conversation memory, and TTS.
//

import SwiftUI
import SceneKit
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
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        ZStack {
            // 3D Avatar
            AvatarSceneView(
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

// MARK: - 3D Avatar Scene (SceneKit) — Realistic Female Avatar

struct AvatarSceneView: UIViewRepresentable {
    let state: AssistantState
    let audioLevel: Float
    let inputAudioLevel: Float
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        
        let scene = SCNScene()
        scnView.scene = scene
        
        context.coordinator.setupScene(scene)
        context.coordinator.scnView = scnView
        context.coordinator.startIdleAnimations()
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateState(state: state, audioLevel: audioLevel, inputLevel: inputAudioLevel)
    }
    
    func makeCoordinator() -> AvatarCoordinator {
        AvatarCoordinator()
    }
}

// MARK: - Avatar Coordinator — Realistic Female

class AvatarCoordinator {
    var scnView: SCNView?
    private var scene: SCNScene?
    
    // Body references
    private var bodyNode: SCNNode?
    private var shoulderNode: SCNNode?
    private var headNode: SCNNode?
    
    // Face references
    private var leftEyeNode: SCNNode?
    private var rightEyeNode: SCNNode?
    private var leftBrowNode: SCNNode?
    private var rightBrowNode: SCNNode?
    private var upperLipNode: SCNNode?
    private var lowerLipNode: SCNNode?
    private var mouthNode: SCNNode?       // Combined for backward compat
    private var jawNode: SCNNode?
    
    // Effects
    private var glowNode: SCNNode?
    private var hairNodes: [SCNNode] = []
    
    // State
    private var blinkTimer: Timer?
    private var currentState: AssistantState = .idle
    
    // ─── Shared Materials ───────────────────────────────────
    
    private func makeSkinMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        // Warm medium-brown skin tone
        m.diffuse.contents = UIColor(red: 0.62, green: 0.44, blue: 0.34, alpha: 1.0)
        m.specular.contents = UIColor(white: 0.18, alpha: 1.0)
        m.roughness.contents = 0.75
        // Subsurface scattering approximation — warm glow from within
        m.emission.contents = UIColor(red: 0.12, green: 0.06, blue: 0.04, alpha: 1.0)
        m.fresnelExponent = 2.0
        m.lightingModel = .physicallyBased
        return m
    }
    
    private func makeHairMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        // Rich dark brown/black hair
        m.diffuse.contents = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1.0)
        m.specular.contents = UIColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
        m.roughness.contents = 0.45
        m.metalness.contents = 0.05
        m.lightingModel = .physicallyBased
        return m
    }
    
    // ─── Scene Setup ────────────────────────────────────────
    
    func setupScene(_ scene: SCNScene) {
        self.scene = scene
        
        // Camera — slightly closer, centered on face
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 32
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        // Depth of field for portrait-like blur
        cameraNode.camera?.wantsDepthOfField = true
        cameraNode.camera?.focusDistance = 3.2
        cameraNode.camera?.fStop = 2.8
        cameraNode.position = SCNVector3(0, 0.35, 3.2)
        cameraNode.look(at: SCNVector3(0, 0.12, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        setupLighting(scene)
        buildAvatar(scene)
        buildBackground(scene)
    }
    
    private func setupLighting(_ scene: SCNScene) {
        // Ambient — warm soft fill
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.25, green: 0.22, blue: 0.3, alpha: 1.0)
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)
        
        // Key light — warm white, top-right, beauty lighting
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1.0)
        key.light?.intensity = 900
        key.light?.castsShadow = true
        key.light?.shadowRadius = 4
        key.light?.shadowSampleCount = 8
        key.position = SCNVector3(1.5, 3.5, 3)
        key.look(at: SCNVector3(0, 0.2, 0))
        scene.rootNode.addChildNode(key)
        
        // Fill light — soft purple, left side
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = UIColor(red: 0.55, green: 0.45, blue: 0.75, alpha: 1.0)
        fill.light?.intensity = 450
        fill.position = SCNVector3(-2.5, 2, 2.5)
        fill.look(at: SCNVector3(0, 0.1, 0))
        scene.rootNode.addChildNode(fill)
        
        // Rim / hair light — cool blue, from behind
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = UIColor(red: 0.5, green: 0.55, blue: 0.95, alpha: 1.0)
        rim.light?.intensity = 600
        rim.position = SCNVector3(0.5, 2.5, -2.5)
        rim.look(at: SCNVector3(0, 0.3, 0))
        scene.rootNode.addChildNode(rim)
        
        // Under-chin bounce — very subtle warm fill to soften shadows
        let bounce = SCNNode()
        bounce.light = SCNLight()
        bounce.light?.type = .directional
        bounce.light?.color = UIColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 1.0)
        bounce.light?.intensity = 200
        bounce.position = SCNVector3(0, -1, 2)
        bounce.look(at: SCNVector3(0, 0.4, 0))
        scene.rootNode.addChildNode(bounce)
    }
    
    // MARK: - Build Avatar
    
    private func buildAvatar(_ scene: SCNScene) {
        let skinMat = makeSkinMaterial()
        let hairMat = makeHairMaterial()
        
        let rootNode = SCNNode()
        rootNode.position = SCNVector3(0, -0.6, 0)
        scene.rootNode.addChildNode(rootNode)
        bodyNode = rootNode
        
        // ── Upper Body / Blouse ──────────────────────────
        
        // Shoulders — wider, feminine shape
        let shoulderGeo = SCNCapsule(capRadius: 0.30, height: 0.55)
        let blouseMat = SCNMaterial()
        blouseMat.diffuse.contents = UIColor(red: 0.18, green: 0.22, blue: 0.38, alpha: 1.0)
        blouseMat.specular.contents = UIColor(white: 0.15, alpha: 1.0)
        blouseMat.roughness.contents = 0.8
        blouseMat.lightingModel = .physicallyBased
        shoulderGeo.materials = [blouseMat]
        let shoulders = SCNNode(geometry: shoulderGeo)
        shoulders.position = SCNVector3(0, -0.02, 0)
        shoulders.scale = SCNVector3(1.0, 1.0, 0.85)
        rootNode.addChildNode(shoulders)
        shoulderNode = shoulders
        
        // V-neckline accent
        let necklineGeo = SCNCapsule(capRadius: 0.04, height: 0.15)
        let necklineAccentMat = SCNMaterial()
        necklineAccentMat.diffuse.contents = UIColor(red: 0.22, green: 0.26, blue: 0.44, alpha: 1.0)
        necklineAccentMat.roughness.contents = 0.7
        necklineAccentMat.lightingModel = .physicallyBased
        necklineGeo.materials = [necklineAccentMat]
        
        let necklineLeft = SCNNode(geometry: necklineGeo)
        necklineLeft.position = SCNVector3(-0.06, 0.30, 0.18)
        necklineLeft.eulerAngles = SCNVector3(0.3, 0, 0.25)
        rootNode.addChildNode(necklineLeft)
        
        let necklineRight = SCNNode(geometry: necklineGeo)
        necklineRight.position = SCNVector3(0.06, 0.30, 0.18)
        necklineRight.eulerAngles = SCNVector3(0.3, 0, -0.25)
        rootNode.addChildNode(necklineRight)
        
        // Visible collarbone / décolletage area
        let chestSkinGeo = SCNSphere(radius: 0.14)
        chestSkinGeo.materials = [skinMat]
        let chestSkin = SCNNode(geometry: chestSkinGeo)
        chestSkin.position = SCNVector3(0, 0.30, 0.12)
        chestSkin.scale = SCNVector3(1.5, 0.5, 0.6)
        rootNode.addChildNode(chestSkin)
        
        // ── Neck ─────────────────────────────────────────
        
        let neckGeo = SCNCylinder(radius: 0.065, height: 0.16)
        neckGeo.materials = [skinMat]
        let neck = SCNNode(geometry: neckGeo)
        neck.position = SCNVector3(0, 0.42, 0.01)
        rootNode.addChildNode(neck)
        
        // ── Head ─────────────────────────────────────────
        
        let headGeo = SCNSphere(radius: 0.22)
        headGeo.segmentCount = 48
        headGeo.materials = [skinMat]
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0, 0.60, 0)
        // Feminine proportions — slightly narrower, taller oval
        head.scale = SCNVector3(0.95, 1.12, 0.92)
        rootNode.addChildNode(head)
        headNode = head
        
        // Chin definition (subtle sphere at bottom)
        let chinGeo = SCNSphere(radius: 0.06)
        chinGeo.materials = [skinMat]
        let chin = SCNNode(geometry: chinGeo)
        chin.position = SCNVector3(0, -0.17, 0.10)
        chin.scale = SCNVector3(0.85, 0.6, 0.7)
        head.addChildNode(chin)
        
        // Cheek highlights (subtle)
        for side: Float in [-1, 1] {
            let cheekGeo = SCNSphere(radius: 0.06)
            let cheekMat = makeSkinMaterial()
            // Slightly rosier cheeks
            cheekMat.diffuse.contents = UIColor(red: 0.68, green: 0.46, blue: 0.38, alpha: 1.0)
            cheekMat.emission.contents = UIColor(red: 0.08, green: 0.03, blue: 0.02, alpha: 1.0)
            cheekGeo.materials = [cheekMat]
            let cheek = SCNNode(geometry: cheekGeo)
            cheek.position = SCNVector3(side * 0.12, -0.04, 0.14)
            cheek.scale = SCNVector3(0.7, 0.5, 0.4)
            head.addChildNode(cheek)
        }
        
        // ── Hair ─────────────────────────────────────────
        buildHair(head, hairMat: hairMat)
        
        // ── Eyes ─────────────────────────────────────────
        buildEyes(head)
        
        // ── Eyebrows ─────────────────────────────────────
        buildEyebrows(head, hairMat: hairMat)
        
        // ── Nose ─────────────────────────────────────────
        buildNose(head, skinMat: skinMat)
        
        // ── Mouth ────────────────────────────────────────
        buildMouth(head)
        
        // ── Ears + Earrings ──────────────────────────────
        buildEars(head, skinMat: skinMat)
        
        // ── Glow Indicator Ring ──────────────────────────
        buildGlowRing(head)
    }
    
    // MARK: - Hair (layered, flowing)
    
    private func buildHair(_ head: SCNNode, hairMat: SCNMaterial) {
        hairNodes.removeAll()
        
        // Main hair cap (top of head)
        let capGeo = SCNSphere(radius: 0.235)
        capGeo.segmentCount = 36
        capGeo.materials = [hairMat]
        let cap = SCNNode(geometry: capGeo)
        cap.position = SCNVector3(0, 0.04, -0.015)
        cap.scale = SCNVector3(1.06, 0.58, 1.04)
        head.addChildNode(cap)
        hairNodes.append(cap)
        
        // Side hair — left
        let sideLeftGeo = SCNCapsule(capRadius: 0.09, height: 0.42)
        sideLeftGeo.materials = [hairMat]
        let sideLeft = SCNNode(geometry: sideLeftGeo)
        sideLeft.position = SCNVector3(-0.18, -0.06, -0.02)
        sideLeft.eulerAngles = SCNVector3(0.08, 0, 0.12)
        head.addChildNode(sideLeft)
        hairNodes.append(sideLeft)
        
        // Side hair — right
        let sideRightGeo = SCNCapsule(capRadius: 0.09, height: 0.42)
        sideRightGeo.materials = [hairMat]
        let sideRight = SCNNode(geometry: sideRightGeo)
        sideRight.position = SCNVector3(0.18, -0.06, -0.02)
        sideRight.eulerAngles = SCNVector3(0.08, 0, -0.12)
        head.addChildNode(sideRight)
        hairNodes.append(sideRight)
        
        // Back hair — long, flowing behind
        let backGeo = SCNCapsule(capRadius: 0.15, height: 0.65)
        backGeo.materials = [hairMat]
        let back = SCNNode(geometry: backGeo)
        back.position = SCNVector3(0, -0.18, -0.14)
        back.eulerAngles = SCNVector3(0.15, 0, 0)
        head.addChildNode(back)
        hairNodes.append(back)
        
        // Hair highlight strands (subtle sheen)
        let highlightMat = SCNMaterial()
        highlightMat.diffuse.contents = UIColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 0.6)
        highlightMat.specular.contents = UIColor(red: 0.5, green: 0.4, blue: 0.35, alpha: 1.0)
        highlightMat.roughness.contents = 0.35
        highlightMat.lightingModel = .physicallyBased
        
        for i in 0..<3 {
            let strandGeo = SCNCapsule(capRadius: 0.02, height: 0.28)
            strandGeo.materials = [highlightMat]
            let strand = SCNNode(geometry: strandGeo)
            let xOff = Float(i - 1) * 0.08
            strand.position = SCNVector3(xOff, 0.02 + Float(i) * 0.01, -0.06)
            strand.eulerAngles = SCNVector3(Float.pi / 6, 0, Float(i - 1) * 0.05)
            head.addChildNode(strand)
            hairNodes.append(strand)
        }
        
        // Bangs / fringe — softly swept to side
        let bangGeo = SCNCapsule(capRadius: 0.04, height: 0.12)
        let bangMat = makeHairMaterial()
        bangGeo.materials = [bangMat]
        
        let bangLeft = SCNNode(geometry: bangGeo)
        bangLeft.position = SCNVector3(-0.08, 0.10, 0.17)
        bangLeft.eulerAngles = SCNVector3(0.2, 0, Float.pi / 2 + 0.3)
        head.addChildNode(bangLeft)
        hairNodes.append(bangLeft)
        
        let bangRight = SCNNode(geometry: bangGeo)
        bangRight.position = SCNVector3(0.05, 0.11, 0.16)
        bangRight.eulerAngles = SCNVector3(0.15, 0, Float.pi / 2 - 0.15)
        head.addChildNode(bangRight)
        hairNodes.append(bangRight)
    }
    
    // MARK: - Eyes (detailed with iris, pupil, highlight)
    
    private func buildEyes(_ head: SCNNode) {
        let eyeSpacing: Float = 0.078
        let eyeY: Float = 0.02
        let eyeZ: Float = 0.175
        
        for side: Float in [-1, 1] {
            // Eye socket (subtle depth)
            let socketGeo = SCNSphere(radius: 0.045)
            let socketMat = makeSkinMaterial()
            socketMat.diffuse.contents = UIColor(red: 0.55, green: 0.38, blue: 0.30, alpha: 1.0)
            socketGeo.materials = [socketMat]
            let socket = SCNNode(geometry: socketGeo)
            socket.position = SCNVector3(side * eyeSpacing, eyeY, eyeZ - 0.01)
            socket.scale = SCNVector3(1.2, 0.7, 0.5)
            head.addChildNode(socket)
            
            // Eyeball (white, almond-shaped)
            let eyeGeo = SCNSphere(radius: 0.038)
            eyeGeo.segmentCount = 32
            let eyeWhiteMat = SCNMaterial()
            eyeWhiteMat.diffuse.contents = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
            eyeWhiteMat.specular.contents = UIColor(white: 0.9, alpha: 1.0)
            eyeWhiteMat.roughness.contents = 0.2
            eyeWhiteMat.lightingModel = .physicallyBased
            eyeGeo.materials = [eyeWhiteMat]
            let eye = SCNNode(geometry: eyeGeo)
            eye.position = SCNVector3(side * eyeSpacing, eyeY, eyeZ)
            eye.scale = SCNVector3(1.1, 0.75, 0.5)
            head.addChildNode(eye)
            
            if side < 0 { leftEyeNode = eye } else { rightEyeNode = eye }
            
            // Iris (dark brown with golden ring)
            let irisGeo = SCNSphere(radius: 0.022)
            irisGeo.segmentCount = 24
            let irisMat = SCNMaterial()
            irisMat.diffuse.contents = UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1.0)
            irisMat.specular.contents = UIColor(white: 0.6, alpha: 1.0)
            irisMat.roughness.contents = 0.3
            irisMat.lightingModel = .physicallyBased
            irisGeo.materials = [irisMat]
            let iris = SCNNode(geometry: irisGeo)
            iris.position = SCNVector3(0, 0, 0.018)
            eye.addChildNode(iris)
            
            // Pupil (deep black center)
            let pupilGeo = SCNSphere(radius: 0.012)
            let pupilMat = SCNMaterial()
            pupilMat.diffuse.contents = UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1.0)
            pupilMat.specular.contents = UIColor(white: 0.9, alpha: 1.0)
            pupilMat.roughness.contents = 0.1
            pupilGeo.materials = [pupilMat]
            let pupil = SCNNode(geometry: pupilGeo)
            pupil.position = SCNVector3(0, 0, 0.012)
            iris.addChildNode(pupil)
            
            // Eye highlight (catch light — simulates window reflection)
            let highlightGeo = SCNSphere(radius: 0.006)
            let highlightMat = SCNMaterial()
            highlightMat.diffuse.contents = UIColor.white
            highlightMat.emission.contents = UIColor(white: 0.95, alpha: 1.0)
            highlightGeo.materials = [highlightMat]
            let highlight = SCNNode(geometry: highlightGeo)
            highlight.position = SCNVector3(side * 0.008, 0.008, 0.02)
            iris.addChildNode(highlight)
            
            // Upper eyelid (skin-colored, creates almond shape)
            let lidGeo = SCNCapsule(capRadius: 0.012, height: 0.05)
            lidGeo.materials = [makeSkinMaterial()]
            let lid = SCNNode(geometry: lidGeo)
            lid.position = SCNVector3(side * eyeSpacing, eyeY + 0.028, eyeZ + 0.015)
            lid.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            lid.scale = SCNVector3(1.0, 1.0, 0.5)
            head.addChildNode(lid)
            
            // Eyelashes (thin dark line on upper lid)
            let lashGeo = SCNCapsule(capRadius: 0.005, height: 0.055)
            let lashMat = SCNMaterial()
            lashMat.diffuse.contents = UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1.0)
            lashGeo.materials = [lashMat]
            let lash = SCNNode(geometry: lashGeo)
            lash.position = SCNVector3(side * eyeSpacing, eyeY + 0.032, eyeZ + 0.02)
            lash.eulerAngles = SCNVector3(-0.15, 0, Float.pi / 2)
            head.addChildNode(lash)
            
            // Lower lash line (thinner)
            let lowerLashGeo = SCNCapsule(capRadius: 0.003, height: 0.04)
            lowerLashGeo.materials = [lashMat]
            let lowerLash = SCNNode(geometry: lowerLashGeo)
            lowerLash.position = SCNVector3(side * eyeSpacing, eyeY - 0.022, eyeZ + 0.018)
            lowerLash.eulerAngles = SCNVector3(0.1, 0, Float.pi / 2)
            head.addChildNode(lowerLash)
        }
    }
    
    // MARK: - Eyebrows (arched, feminine)
    
    private func buildEyebrows(_ head: SCNNode, hairMat: SCNMaterial) {
        let browMat = SCNMaterial()
        browMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1.0)
        browMat.roughness.contents = 0.6
        browMat.lightingModel = .physicallyBased
        
        for side: Float in [-1, 1] {
            // Main brow arc — thicker inner, tapered outer
            let browInnerGeo = SCNCapsule(capRadius: 0.009, height: 0.035)
            browInnerGeo.materials = [browMat]
            let browInner = SCNNode(geometry: browInnerGeo)
            browInner.position = SCNVector3(side * 0.055, 0.068, 0.19)
            browInner.eulerAngles = SCNVector3(0, 0, Float.pi / 2 + side * 0.12)
            head.addChildNode(browInner)
            
            let browOuterGeo = SCNCapsule(capRadius: 0.006, height: 0.03)
            browOuterGeo.materials = [browMat]
            let browOuter = SCNNode(geometry: browOuterGeo)
            browOuter.position = SCNVector3(side * 0.095, 0.065, 0.185)
            browOuter.eulerAngles = SCNVector3(0, 0, Float.pi / 2 + side * 0.25)
            head.addChildNode(browOuter)
            
            // Combined reference node (invisible) for animation
            let browRef = SCNNode()
            browRef.position = SCNVector3(side * 0.075, 0.068, 0.19)
            browRef.addChildNode({
                let n = SCNNode()
                browInner.removeFromParentNode()
                browOuter.removeFromParentNode()
                n.addChildNode(browInner)
                n.addChildNode(browOuter)
                browInner.position = SCNVector3(side * -0.02, 0, 0)
                browOuter.position = SCNVector3(side * 0.02, -0.003, -0.005)
                return n
            }())
            head.addChildNode(browRef)
            
            if side < 0 { leftBrowNode = browRef } else { rightBrowNode = browRef }
        }
    }
    
    // MARK: - Nose (delicate, feminine)
    
    private func buildNose(_ head: SCNNode, skinMat: SCNMaterial) {
        // Nose bridge (very subtle)
        let bridgeGeo = SCNCapsule(capRadius: 0.012, height: 0.06)
        bridgeGeo.materials = [skinMat]
        let bridge = SCNNode(geometry: bridgeGeo)
        bridge.position = SCNVector3(0, 0.0, 0.19)
        bridge.scale = SCNVector3(0.6, 1.0, 0.5)
        head.addChildNode(bridge)
        
        // Nose tip (small, slightly upturned)
        let tipGeo = SCNSphere(radius: 0.022)
        tipGeo.materials = [skinMat]
        let tip = SCNNode(geometry: tipGeo)
        tip.position = SCNVector3(0, -0.03, 0.20)
        tip.scale = SCNVector3(0.8, 0.65, 0.7)
        head.addChildNode(tip)
        
        // Nostrils (tiny)
        for side: Float in [-1, 1] {
            let nostrilGeo = SCNSphere(radius: 0.008)
            let nostrilMat = makeSkinMaterial()
            nostrilMat.diffuse.contents = UIColor(red: 0.52, green: 0.36, blue: 0.28, alpha: 1.0)
            nostrilGeo.materials = [nostrilMat]
            let nostril = SCNNode(geometry: nostrilGeo)
            nostril.position = SCNVector3(side * 0.015, -0.04, 0.195)
            head.addChildNode(nostril)
        }
    }
    
    // MARK: - Mouth (full lips, detailed)
    
    private func buildMouth(_ head: SCNNode) {
        // Upper lip
        let upperLipGeo = SCNCapsule(capRadius: 0.014, height: 0.055)
        let upperLipMat = SCNMaterial()
        upperLipMat.diffuse.contents = UIColor(red: 0.65, green: 0.35, blue: 0.32, alpha: 1.0)
        upperLipMat.specular.contents = UIColor(white: 0.35, alpha: 1.0)
        upperLipMat.roughness.contents = 0.4
        upperLipMat.lightingModel = .physicallyBased
        upperLipGeo.materials = [upperLipMat]
        let upperLip = SCNNode(geometry: upperLipGeo)
        upperLip.position = SCNVector3(0, -0.072, 0.19)
        upperLip.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        head.addChildNode(upperLip)
        upperLipNode = upperLip
        
        // Lower lip (slightly fuller)
        let lowerLipGeo = SCNCapsule(capRadius: 0.016, height: 0.05)
        let lowerLipMat = SCNMaterial()
        lowerLipMat.diffuse.contents = UIColor(red: 0.68, green: 0.38, blue: 0.35, alpha: 1.0)
        lowerLipMat.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        lowerLipMat.roughness.contents = 0.35
        lowerLipMat.lightingModel = .physicallyBased
        // Subtle lip gloss shine
        lowerLipMat.emission.contents = UIColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 1.0)
        lowerLipGeo.materials = [lowerLipMat]
        let lowerLip = SCNNode(geometry: lowerLipGeo)
        lowerLip.position = SCNVector3(0, -0.090, 0.185)
        lowerLip.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        head.addChildNode(lowerLip)
        lowerLipNode = lowerLip
        
        // Combined mouth reference for lip-sync (backward compat)
        mouthNode = lowerLip
        
        // Cupid's bow (tiny highlight on upper lip center)
        let cupidGeo = SCNSphere(radius: 0.008)
        let cupidMat = makeSkinMaterial()
        cupidMat.diffuse.contents = UIColor(red: 0.60, green: 0.34, blue: 0.30, alpha: 1.0)
        cupidGeo.materials = [cupidMat]
        let cupid = SCNNode(geometry: cupidGeo)
        cupid.position = SCNVector3(0, -0.065, 0.195)
        cupid.scale = SCNVector3(1.0, 0.5, 0.5)
        head.addChildNode(cupid)
        
        // Jaw anchor (invisible)
        let jaw = SCNNode()
        jaw.position = SCNVector3(0, -0.10, 0.16)
        head.addChildNode(jaw)
        jawNode = jaw
    }
    
    // MARK: - Ears + Earrings
    
    private func buildEars(_ head: SCNNode, skinMat: SCNMaterial) {
        for side: Float in [-1, 1] {
            // Ear
            let earGeo = SCNSphere(radius: 0.03)
            earGeo.materials = [skinMat]
            let ear = SCNNode(geometry: earGeo)
            ear.position = SCNVector3(side * 0.20, -0.01, 0.02)
            ear.scale = SCNVector3(0.35, 0.7, 0.5)
            head.addChildNode(ear)
            
            // Small gold stud earring
            let earringGeo = SCNSphere(radius: 0.008)
            let earringMat = SCNMaterial()
            earringMat.diffuse.contents = UIColor(red: 0.85, green: 0.72, blue: 0.35, alpha: 1.0)
            earringMat.specular.contents = UIColor(white: 0.95, alpha: 1.0)
            earringMat.metalness.contents = 0.9
            earringMat.roughness.contents = 0.15
            earringMat.lightingModel = .physicallyBased
            earringGeo.materials = [earringMat]
            let earring = SCNNode(geometry: earringGeo)
            earring.position = SCNVector3(side * 0.205, -0.03, 0.04)
            head.addChildNode(earring)
            
            // Drop pendant
            let dropGeo = SCNSphere(radius: 0.006)
            dropGeo.materials = [earringMat]
            let drop = SCNNode(geometry: dropGeo)
            drop.position = SCNVector3(side * 0.205, -0.045, 0.04)
            head.addChildNode(drop)
        }
    }
    
    // MARK: - Glow Status Ring
    
    private func buildGlowRing(_ head: SCNNode) {
        let glowGeo = SCNTorus(ringRadius: 0.30, pipeRadius: 0.006)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.5)
        glowMat.emission.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.7)
        glowMat.lightingModel = .constant
        glowGeo.materials = [glowMat]
        let glow = SCNNode(geometry: glowGeo)
        glow.position = SCNVector3(0, 0.16, 0)
        glow.eulerAngles = SCNVector3(Float.pi / 8, 0, 0)
        head.addChildNode(glow)
        glowNode = glow
    }
    
    // MARK: - Background Particles
    
    private func buildBackground(_ scene: SCNScene) {
        for _ in 0..<25 {
            let dotGeo = SCNSphere(radius: CGFloat.random(in: 0.008...0.025))
            let dotMat = SCNMaterial()
            dotMat.diffuse.contents = UIColor(
                red: CGFloat.random(in: 0.3...0.5),
                green: CGFloat.random(in: 0.3...0.5),
                blue: CGFloat.random(in: 0.7...1.0),
                alpha: CGFloat.random(in: 0.15...0.4)
            )
            dotMat.emission.contents = dotMat.diffuse.contents
            dotMat.lightingModel = .constant
            dotGeo.materials = [dotMat]
            
            let dot = SCNNode(geometry: dotGeo)
            dot.position = SCNVector3(
                Float.random(in: -2.5...2.5),
                Float.random(in: -1.5...2.5),
                Float.random(in: -4...(-1.2))
            )
            scene.rootNode.addChildNode(dot)
            
            let dur = Double.random(in: 3...7)
            let up = SCNAction.moveBy(x: 0, y: CGFloat.random(in: 0.3...0.8), z: 0, duration: dur)
            let down = up.reversed()
            dot.runAction(.repeatForever(.sequence([up, down])))
            
            let fadeOut = SCNAction.fadeOpacity(to: 0.05, duration: dur * 0.8)
            let fadeIn = SCNAction.fadeOpacity(to: CGFloat.random(in: 0.2...0.5), duration: dur * 0.8)
            dot.runAction(.repeatForever(.sequence([fadeOut, fadeIn])))
        }
    }
    
    // ─── Idle Animations ────────────────────────────────────
    
    func startIdleAnimations() {
        // Breathing — subtle rise/fall
        if let body = bodyNode {
            let up = SCNAction.moveBy(x: 0, y: 0.008, z: 0, duration: 2.8)
            up.timingMode = .easeInEaseOut
            let down = up.reversed()
            body.runAction(.repeatForever(.sequence([up, down])), forKey: "breathe")
        }
        
        // Gentle head sway
        if let head = headNode {
            let right = SCNAction.rotateTo(x: 0, y: 0.02, z: -0.03, duration: 3.5)
            right.timingMode = .easeInEaseOut
            let left = SCNAction.rotateTo(x: 0, y: -0.02, z: 0.03, duration: 3.5)
            left.timingMode = .easeInEaseOut
            let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 2.5)
            center.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([right, center, left, center])), forKey: "headTilt")
        }
        
        // Natural blinking
        startBlinking()
        
        // Glow ring gentle rotation
        if let glow = glowNode {
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10.0)
            glow.runAction(.repeatForever(rotate), forKey: "glowRotate")
        }
        
        // Subtle hair sway (flowing effect)
        for (i, node) in hairNodes.enumerated() {
            let delay = Double(i) * 0.3
            let swayRight = SCNAction.rotateTo(x: 0, y: 0, z: -0.02, duration: 2.5 + Double(i) * 0.2)
            swayRight.timingMode = .easeInEaseOut
            let swayLeft = SCNAction.rotateTo(x: 0, y: 0, z: 0.02, duration: 2.5 + Double(i) * 0.2)
            swayLeft.timingMode = .easeInEaseOut
            let seq = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.repeatForever(.sequence([swayRight, swayLeft]))
            ])
            node.runAction(seq, forKey: "hairSway")
        }
    }
    
    private func startBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.5...5.0), repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performBlink()
                self?.startBlinking()
            }
        }
    }
    
    private func performBlink() {
        guard let leftEye = leftEyeNode, let rightEye = rightEyeNode else { return }
        let close = SCNAction.scaleY(to: 0.1, duration: 0.06)
        let open = SCNAction.scaleY(to: 0.75, duration: 0.08) // Return to almond shape
        let blink = SCNAction.sequence([close, open])
        leftEye.runAction(blink)
        rightEye.runAction(blink)
    }
    
    // ─── State Updates ──────────────────────────────────────
    
    func updateState(state: AssistantState, audioLevel: Float, inputLevel: Float) {
        let prev = currentState
        currentState = state
        
        updateMouth(audioLevel: state == .speaking ? audioLevel : 0)
        updateGlow(state: state)
        
        if prev != state {
            updateHeadBehavior(state: state)
            updateBrowExpression(state: state)
        }
        
        if state == .listening {
            updateListeningAnimation(level: inputLevel)
        }
    }
    
    private func updateMouth(audioLevel: Float) {
        guard let lower = lowerLipNode, let upper = upperLipNode else { return }
        
        let openAmount = max(0.0, min(1.0, audioLevel * 1.2))
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.05
        // Lower lip drops down; upper lip rises slightly
        lower.position.y = -0.090 - openAmount * 0.015
        upper.position.y = -0.072 + openAmount * 0.005
        // Slight width change for vowel shapes
        lower.scale = SCNVector3(1.0 + openAmount * 0.15, 1.0, 1.0 + openAmount * 0.2)
        upper.scale = SCNVector3(1.0 + openAmount * 0.1, 1.0, 1.0)
        SCNTransaction.commit()
    }
    
    private func updateGlow(state: AssistantState) {
        guard let glow = glowNode, let mat = glow.geometry?.firstMaterial else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        switch state {
        case .idle:
            mat.diffuse.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.4)
            mat.emission.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.3)
        case .listening:
            mat.diffuse.contents = UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.7)
            mat.emission.contents = UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.6)
        case .thinking:
            mat.diffuse.contents = UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.7)
            mat.emission.contents = UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.5)
        case .speaking:
            mat.diffuse.contents = UIColor(red: 0.2, green: 0.7, blue: 0.95, alpha: 0.7)
            mat.emission.contents = UIColor(red: 0.2, green: 0.7, blue: 0.95, alpha: 0.6)
        }
        
        SCNTransaction.commit()
    }
    
    private func updateHeadBehavior(state: AssistantState) {
        guard let head = headNode else { return }
        
        switch state {
        case .idle:
            head.removeAction(forKey: "nod")
            // Restore gentle sway
            let right = SCNAction.rotateTo(x: 0, y: 0.02, z: -0.03, duration: 3.5)
            right.timingMode = .easeInEaseOut
            let left = SCNAction.rotateTo(x: 0, y: -0.02, z: 0.03, duration: 3.5)
            left.timingMode = .easeInEaseOut
            let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 2.5)
            center.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([right, center, left, center])), forKey: "headTilt")
        case .listening:
            head.removeAction(forKey: "headTilt")
            head.removeAction(forKey: "nod")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            head.eulerAngles = SCNVector3(0.04, 0, 0.025)
            SCNTransaction.commit()
        case .thinking:
            head.removeAction(forKey: "headTilt")
            head.removeAction(forKey: "nod")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            head.eulerAngles = SCNVector3(0.06, -0.04, 0)
            SCNTransaction.commit()
        case .speaking:
            head.removeAction(forKey: "headTilt")
            let nodDown = SCNAction.rotateTo(x: 0.035, y: 0.01, z: 0, duration: 0.9)
            nodDown.timingMode = .easeInEaseOut
            let nodUp = SCNAction.rotateTo(x: -0.015, y: -0.01, z: 0, duration: 0.9)
            nodUp.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([nodDown, nodUp])), forKey: "nod")
        }
    }
    
    private func updateBrowExpression(state: AssistantState) {
        guard let leftBrow = leftBrowNode, let rightBrow = rightBrowNode else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        
        switch state {
        case .idle:
            leftBrow.position.y = 0.068
            rightBrow.position.y = 0.068
            leftBrow.eulerAngles = SCNVector3.zero
            rightBrow.eulerAngles = SCNVector3.zero
        case .listening:
            leftBrow.position.y = 0.074
            rightBrow.position.y = 0.074
        case .thinking:
            leftBrow.position.y = 0.064
            rightBrow.position.y = 0.064
            leftBrow.eulerAngles = SCNVector3(0, 0, 0.1)
            rightBrow.eulerAngles = SCNVector3(0, 0, -0.1)
        case .speaking:
            leftBrow.position.y = 0.070
            rightBrow.position.y = 0.070
            leftBrow.eulerAngles = SCNVector3.zero
            rightBrow.eulerAngles = SCNVector3.zero
        }
        
        SCNTransaction.commit()
    }
    
    private func updateListeningAnimation(level: Float) {
        guard let head = headNode else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        let tilt = level * 0.025
        head.eulerAngles = SCNVector3(0.04 + tilt, 0, 0.025 - tilt)
        SCNTransaction.commit()
    }
    
    deinit {
        blinkTimer?.invalidate()
    }
}

// MARK: - SCNAction Extensions

extension SCNAction {
    static func scaleY(to yScale: CGFloat, duration: TimeInterval) -> SCNAction {
        return SCNAction.customAction(duration: duration) { node, elapsedTime in
            let progress = elapsedTime / CGFloat(duration)
            let currentY = 1.0 + (yScale - 1.0) * progress
            node.scale = SCNVector3(node.scale.x, Float(currentY), node.scale.z)
        }
    }
}
