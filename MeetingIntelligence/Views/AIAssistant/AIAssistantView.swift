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
import GLTFKit2

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

// MARK: - 3D Avatar Scene (SceneKit + GLTFKit2) — Realistic 3D Model with Blend Shapes

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
        
        context.coordinator.setupScene(scene, scnView: scnView)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateState(state: state, audioLevel: audioLevel, inputLevel: inputAudioLevel)
    }
    
    func makeCoordinator() -> AvatarCoordinator {
        AvatarCoordinator()
    }
}

// MARK: - Avatar Coordinator — 3D Model with Blend Shape Lip Sync

class AvatarCoordinator {
    var scnView: SCNView?
    private var scene: SCNScene?
    
    // Model references
    private var avatarRootNode: SCNNode?
    private var headBone: SCNNode?
    private var neckBone: SCNNode?
    
    // Morph target system
    // Maps blend shape name → list of (morpher, targetIndex) so we drive ALL meshes
    private var blendShapeMap: [String: [(morpher: SCNMorpher, index: Int)]] = [:]
    
    // Effects
    private var glowNode: SCNNode?
    
    // State
    private var blinkTimer: Timer?
    private var currentState: AssistantState = .idle
    private var isModelLoaded = false
    
    // Known ARKit blend shape names (ReadyPlayerMe order) — fallback if names aren't set
    private static let arkitBlendShapeOrder: [String] = [
        "browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight",
        "cheekPuff", "cheekSquintLeft", "cheekSquintRight",
        "eyeBlinkLeft", "eyeBlinkRight", "eyeLookDownLeft", "eyeLookDownRight",
        "eyeLookInLeft", "eyeLookInRight", "eyeLookOutLeft", "eyeLookOutRight",
        "eyeLookUpLeft", "eyeLookUpRight", "eyeSquintLeft", "eyeSquintRight",
        "eyeWideLeft", "eyeWideRight",
        "jawForward", "jawLeft", "jawOpen", "jawRight",
        "mouthClose", "mouthDimpleLeft", "mouthDimpleRight",
        "mouthFrownLeft", "mouthFrownRight", "mouthFunnel", "mouthLeft",
        "mouthLowerDownLeft", "mouthLowerDownRight",
        "mouthPressLeft", "mouthPressRight", "mouthPucker", "mouthRight",
        "mouthRollLower", "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper",
        "mouthSmileLeft", "mouthSmileRight",
        "mouthStretchLeft", "mouthStretchRight",
        "mouthUpperUpLeft", "mouthUpperUpRight",
        "noseSneerLeft", "noseSneerRight", "tongueOut"
    ]
    
    // ─── Scene Setup ────────────────────────────────────────
    
    func setupScene(_ scene: SCNScene, scnView: SCNView) {
        self.scene = scene
        self.scnView = scnView
        
        // Camera — framing head/shoulders
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.wantsDepthOfField = true
        cameraNode.camera?.focusDistance = 0.6
        cameraNode.camera?.fStop = 2.8
        // Position adjusted after model loads; start centered at origin
        cameraNode.position = SCNVector3(0, 0.55, 0.6)
        cameraNode.look(at: SCNVector3(0, 0.52, 0))
        cameraNode.name = "mainCamera"
        scene.rootNode.addChildNode(cameraNode)
        
        setupLighting(scene)
        loadAvatarModel(scene)
        buildBackground(scene)
    }
    
    private func setupLighting(_ scene: SCNScene) {
        // Ambient — warm soft fill
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.25, green: 0.22, blue: 0.3, alpha: 1.0)
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)
        
        // Key light — warm white, top-right, beauty lighting
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1.0)
        key.light?.intensity = 1000
        key.light?.castsShadow = true
        key.light?.shadowRadius = 4
        key.light?.shadowSampleCount = 8
        key.position = SCNVector3(1.5, 3.5, 3)
        key.look(at: SCNVector3(0, 0.5, 0))
        scene.rootNode.addChildNode(key)
        
        // Fill light — soft purple, left side
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = UIColor(red: 0.55, green: 0.45, blue: 0.75, alpha: 1.0)
        fill.light?.intensity = 500
        fill.position = SCNVector3(-2.5, 2, 2.5)
        fill.look(at: SCNVector3(0, 0.4, 0))
        scene.rootNode.addChildNode(fill)
        
        // Rim / hair light — cool blue, from behind
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = UIColor(red: 0.5, green: 0.55, blue: 0.95, alpha: 1.0)
        rim.light?.intensity = 650
        rim.position = SCNVector3(0.5, 2.5, -2.5)
        rim.look(at: SCNVector3(0, 0.5, 0))
        scene.rootNode.addChildNode(rim)
        
        // Under-chin bounce — warm fill to soften shadows
        let bounce = SCNNode()
        bounce.light = SCNLight()
        bounce.light?.type = .directional
        bounce.light?.color = UIColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 1.0)
        bounce.light?.intensity = 250
        bounce.position = SCNVector3(0, -1, 2)
        bounce.look(at: SCNVector3(0, 0.6, 0))
        scene.rootNode.addChildNode(bounce)
    }
    
    // MARK: - Load 3D Avatar Model
    
    private func loadAvatarModel(_ scene: SCNScene) {
        guard let url = Bundle.main.url(forResource: "avatar", withExtension: "glb") else {
            print("⚠️ avatar.glb not found in bundle — showing empty scene")
            return
        }
        
        do {
            let asset = try GLTFAsset(url: url)
            let source = GLTFSCNSceneSource(asset: asset)
            guard let avatarScene = source.defaultScene else {
                print("⚠️ No default scene in GLB asset")
                return
            }
            
            // Move all loaded nodes into a container
            let rootNode = SCNNode()
            rootNode.name = "avatarRoot"
            let children = avatarScene.rootNode.childNodes
            for child in children {
                rootNode.addChildNode(child)
            }
            
            rootNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(rootNode)
            avatarRootNode = rootNode
            
            // Find skeleton bones for head animation
            headBone = rootNode.childNode(withName: "Head", recursively: true)
            neckBone = rootNode.childNode(withName: "Neck", recursively: true)
            
            // If standard bone names not found, try alternatives
            if headBone == nil {
                headBone = findNodeByPartialName("head", in: rootNode)
            }
            if neckBone == nil {
                neckBone = findNodeByPartialName("neck", in: rootNode)
            }
            
            // Find and index all morph targets (blend shapes)
            findAllMorphTargets(in: rootNode)
            
            // Auto-frame camera on the head
            adjustCameraForModel(scene)
            
            // Add glow ring around the head
            if let head = headBone {
                buildGlowRing(head)
            } else {
                // Fallback: add glow at estimated head position
                let glowAnchor = SCNNode()
                glowAnchor.position = SCNVector3(0, 0.55, 0)
                rootNode.addChildNode(glowAnchor)
                buildGlowRing(glowAnchor)
            }
            
            // Start idle animations
            startIdleAnimations()
            isModelLoaded = true
            
            print("✅ Avatar loaded successfully")
            print("   Blend shapes found: \(blendShapeMap.count)")
            print("   Head bone: \(headBone?.name ?? "not found")")
            print("   Neck bone: \(neckBone?.name ?? "not found")")
            
        } catch {
            print("⚠️ Failed to load GLB model: \(error.localizedDescription)")
        }
    }
    
    private func findNodeByPartialName(_ partial: String, in root: SCNNode) -> SCNNode? {
        var found: SCNNode?
        root.enumerateChildNodes { node, stop in
            if let name = node.name, name.lowercased().contains(partial.lowercased()) {
                found = node
                stop.pointee = true
            }
        }
        return found
    }
    
    // MARK: - Morph Target Discovery
    
    private func findAllMorphTargets(in rootNode: SCNNode) {
        blendShapeMap.removeAll()
        
        rootNode.enumerateChildNodes { [weak self] node, _ in
            guard let self = self, let morpher = node.morpher else { return }
            
            let targetCount = morpher.targets.count
            print("📐 Found morpher on '\(node.name ?? "unnamed")' with \(targetCount) targets")
            
            // Set calculation mode for additive blending
            morpher.calculationMode = .additive
            morpher.unifiesNormals = true
            
            // Try to map targets by name first
            var hasNames = false
            for (index, target) in morpher.targets.enumerated() {
                if let name = target.name, !name.isEmpty {
                    hasNames = true
                    if self.blendShapeMap[name] == nil {
                        self.blendShapeMap[name] = []
                    }
                    self.blendShapeMap[name]?.append((morpher: morpher, index: index))
                }
            }
            
            // Fallback: if no names, use ARKit order (ReadyPlayerMe standard)
            if !hasNames && targetCount == Self.arkitBlendShapeOrder.count {
                print("   Using ARKit blend shape order fallback (\(targetCount) targets)")
                for (index, name) in Self.arkitBlendShapeOrder.enumerated() {
                    if self.blendShapeMap[name] == nil {
                        self.blendShapeMap[name] = []
                    }
                    self.blendShapeMap[name]?.append((morpher: morpher, index: index))
                }
            } else if !hasNames && targetCount > 0 {
                // Last resort: map by index with generic names
                print("   ⚠️ Unknown morph target layout (\(targetCount) targets, expected \(Self.arkitBlendShapeOrder.count))")
                for index in 0..<min(targetCount, Self.arkitBlendShapeOrder.count) {
                    let name = Self.arkitBlendShapeOrder[index]
                    if self.blendShapeMap[name] == nil {
                        self.blendShapeMap[name] = []
                    }
                    self.blendShapeMap[name]?.append((morpher: morpher, index: index))
                }
            }
        }
    }
    
    // MARK: - Camera Auto-Framing
    
    private func adjustCameraForModel(_ scene: SCNScene) {
        guard let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: false) else { return }
        
        if let head = headBone {
            // Get the head's world position
            let headWorldPos = head.worldPosition
            // Position camera in front of the head, slightly above
            camera.position = SCNVector3(headWorldPos.x, headWorldPos.y + 0.03, headWorldPos.z + 0.55)
            camera.look(at: SCNVector3(headWorldPos.x, headWorldPos.y - 0.02, headWorldPos.z))
        } else if let root = avatarRootNode {
            // Estimate from bounding box
            let (minBound, maxBound) = root.boundingBox
            let centerY = (minBound.y + maxBound.y) / 2.0
            let topY = maxBound.y
            let headEstimateY = topY - (topY - centerY) * 0.15
            camera.position = SCNVector3(0, headEstimateY, 0.6)
            camera.look(at: SCNVector3(0, headEstimateY - 0.03, 0))
        }
    }
    
    // MARK: - Blend Shape Helpers
    
    /// Set a blend shape weight by ARKit name across all meshes that have it
    private func setBlendShape(_ name: String, weight: CGFloat) {
        guard let entries = blendShapeMap[name] else { return }
        for entry in entries {
            entry.morpher.setWeight(weight, forTargetAt: entry.index)
        }
    }
    
    // MARK: - Glow Status Ring
    
    private func buildGlowRing(_ anchor: SCNNode) {
        let glowGeo = SCNTorus(ringRadius: 0.18, pipeRadius: 0.005)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.5)
        glowMat.emission.contents = UIColor(red: 0.4, green: 0.35, blue: 0.95, alpha: 0.7)
        glowMat.lightingModel = .constant
        glowGeo.materials = [glowMat]
        let glow = SCNNode(geometry: glowGeo)
        glow.position = SCNVector3(0, 0.12, 0)
        glow.eulerAngles = SCNVector3(Float.pi / 8, 0, 0)
        anchor.addChildNode(glow)
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
        // Gentle head sway (on head bone or avatar root)
        if let head = headBone ?? avatarRootNode {
            let right = SCNAction.rotateTo(x: 0, y: 0.025, z: -0.03, duration: 3.5)
            right.timingMode = .easeInEaseOut
            let left = SCNAction.rotateTo(x: 0, y: -0.025, z: 0.03, duration: 3.5)
            left.timingMode = .easeInEaseOut
            let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 2.5)
            center.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([right, center, left, center])), forKey: "headTilt")
        }
        
        // Subtle breathing on the avatar root
        if let root = avatarRootNode {
            let up = SCNAction.moveBy(x: 0, y: 0.003, z: 0, duration: 2.8)
            up.timingMode = .easeInEaseOut
            let down = up.reversed()
            root.runAction(.repeatForever(.sequence([up, down])), forKey: "breathe")
        }
        
        // Natural blinking (via blend shapes)
        startBlinking()
        
        // Glow ring rotation
        if let glow = glowNode {
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10.0)
            glow.runAction(.repeatForever(rotate), forKey: "glowRotate")
        }
        
        // Idle facial expression — subtle, pleasant
        if isModelLoaded {
            setBlendShape("mouthSmileLeft", weight: 0.05)
            setBlendShape("mouthSmileRight", weight: 0.05)
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
        guard isModelLoaded else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.06
        setBlendShape("eyeBlinkLeft", weight: 1.0)
        setBlendShape("eyeBlinkRight", weight: 1.0)
        SCNTransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.08
            self?.setBlendShape("eyeBlinkLeft", weight: 0.0)
            self?.setBlendShape("eyeBlinkRight", weight: 0.0)
            SCNTransaction.commit()
        }
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
    
    // MARK: - Lip Sync (Blend Shape Driven)
    
    private func updateMouth(audioLevel: Float) {
        guard isModelLoaded else { return }
        
        let level = max(0.0, min(1.0, audioLevel * 1.3))
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.05
        
        // Primary jaw opening — most visible movement
        setBlendShape("jawOpen", weight: CGFloat(level * 0.65))
        
        // Mouth interior opening
        setBlendShape("mouthOpen", weight: CGFloat(level * 0.35))
        
        // Add variety for natural speech shapes
        // Funnel shape (like "oh" sound)
        let funnelAmount = sin(Double(audioLevel) * 7.0) * 0.5 + 0.5
        setBlendShape("mouthFunnel", weight: CGFloat(level * Float(funnelAmount) * 0.2))
        
        // Pucker (like "oo" sound) — alternates with funnel
        let puckerAmount = cos(Double(audioLevel) * 5.0) * 0.5 + 0.5
        setBlendShape("mouthPucker", weight: CGFloat(level * Float(puckerAmount) * 0.12))
        
        // Lower lip drops more than upper
        setBlendShape("mouthLowerDownLeft", weight: CGFloat(level * 0.25))
        setBlendShape("mouthLowerDownRight", weight: CGFloat(level * 0.25))
        setBlendShape("mouthUpperUpLeft", weight: CGFloat(level * 0.08))
        setBlendShape("mouthUpperUpRight", weight: CGFloat(level * 0.08))
        
        // Subtle smile while speaking (friendly)
        setBlendShape("mouthSmileLeft", weight: CGFloat(0.05 + level * 0.06))
        setBlendShape("mouthSmileRight", weight: CGFloat(0.05 + level * 0.06))
        
        // Slight stretch for wider mouth shapes
        setBlendShape("mouthStretchLeft", weight: CGFloat(level * 0.1))
        setBlendShape("mouthStretchRight", weight: CGFloat(level * 0.1))
        
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
        guard let head = headBone ?? avatarRootNode else { return }
        
        switch state {
        case .idle:
            head.removeAction(forKey: "nod")
            let right = SCNAction.rotateTo(x: 0, y: 0.025, z: -0.03, duration: 3.5)
            right.timingMode = .easeInEaseOut
            let left = SCNAction.rotateTo(x: 0, y: -0.025, z: 0.03, duration: 3.5)
            left.timingMode = .easeInEaseOut
            let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 2.5)
            center.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([right, center, left, center])), forKey: "headTilt")
        case .listening:
            head.removeAction(forKey: "headTilt")
            head.removeAction(forKey: "nod")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            head.eulerAngles = SCNVector3(0.05, 0, 0.03)
            SCNTransaction.commit()
        case .thinking:
            head.removeAction(forKey: "headTilt")
            head.removeAction(forKey: "nod")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            head.eulerAngles = SCNVector3(0.07, -0.05, 0)
            SCNTransaction.commit()
        case .speaking:
            head.removeAction(forKey: "headTilt")
            let nodDown = SCNAction.rotateTo(x: 0.04, y: 0.015, z: 0, duration: 0.9)
            nodDown.timingMode = .easeInEaseOut
            let nodUp = SCNAction.rotateTo(x: -0.02, y: -0.015, z: 0, duration: 0.9)
            nodUp.timingMode = .easeInEaseOut
            head.runAction(.repeatForever(.sequence([nodDown, nodUp])), forKey: "nod")
        }
    }
    
    private func updateBrowExpression(state: AssistantState) {
        guard isModelLoaded else { return }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        
        switch state {
        case .idle:
            setBlendShape("browInnerUp", weight: 0)
            setBlendShape("browDownLeft", weight: 0)
            setBlendShape("browDownRight", weight: 0)
            setBlendShape("browOuterUpLeft", weight: 0)
            setBlendShape("browOuterUpRight", weight: 0)
        case .listening:
            // Slightly raised brows — attentive
            setBlendShape("browInnerUp", weight: 0.15)
            setBlendShape("browOuterUpLeft", weight: 0.1)
            setBlendShape("browOuterUpRight", weight: 0.1)
            setBlendShape("browDownLeft", weight: 0)
            setBlendShape("browDownRight", weight: 0)
        case .thinking:
            // One brow up, slight furrow — contemplative
            setBlendShape("browInnerUp", weight: 0.2)
            setBlendShape("browDownLeft", weight: 0.15)
            setBlendShape("browDownRight", weight: 0)
            setBlendShape("browOuterUpRight", weight: 0.12)
        case .speaking:
            // Natural, slightly animated
            setBlendShape("browInnerUp", weight: 0.05)
            setBlendShape("browDownLeft", weight: 0)
            setBlendShape("browDownRight", weight: 0)
        }
        
        SCNTransaction.commit()
    }
    
    private func updateListeningAnimation(level: Float) {
        guard let head = headBone ?? avatarRootNode else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        let tilt = level * 0.025
        head.eulerAngles = SCNVector3(0.05 + tilt, 0, 0.03 - tilt)
        SCNTransaction.commit()
        
        // Subtle eye widening while listening (engagement)
        if isModelLoaded {
            let wide = CGFloat(level * 0.1)
            setBlendShape("eyeWideLeft", weight: wide)
            setBlendShape("eyeWideRight", weight: wide)
        }
    }
    
    deinit {
        blinkTimer?.invalidate()
    }
}
