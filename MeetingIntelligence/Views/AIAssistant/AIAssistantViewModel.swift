//
//  AIAssistantViewModel.swift
//  MeetingIntelligence
//
//  ViewModel for the Workplace AI Assistant
//  Coordinates conversation logic, voice I/O, and avatar state
//  - SSE streaming: tokens appear live, audio plays per-sentence
//  - Auto-listen: starts listening after AI finishes speaking
//  - Interrupt: tap mic while AI speaks to cut in
//

import Foundation
import Combine
import AVFoundation

@MainActor
class AIAssistantViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var state: AssistantState = .idle
    @Published var messages: [AIMessage] = []
    @Published var conversations: [AIConversationListItem] = []
    @Published var currentConversationId: String?
    @Published var currentTranscript = ""
    @Published var isLoadingConversation = false
    @Published var showConversationList = false
    @Published var showTranscript = false
    @Published var error: String?
    
    // MARK: - Services
    
    let voiceManager = AIAssistantVoiceManager()
    private let service = AIAssistantService.shared
    
    // Avatar animation state
    @Published var audioLevel: Float = 0.0
    @Published var inputAudioLevel: Float = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    // Streaming state
    private var streamingText = ""
    private var streamingMsgTempId = ""
    private var audioChunkCount = 0   // Track how many audio chunks received
    
    // User info
    private var organizationId: String?
    
    // MARK: - Init
    
    init() {
        setupVoiceCallbacks()
        setupAudioLevelBindings()
    }
    
    // MARK: - Setup
    
    func configure(organizationId: String?) {
        self.organizationId = organizationId
    }
    
    private func setupVoiceCallbacks() {
        voiceManager.onSpeechResult = { [weak self] transcript in
            Task { @MainActor in
                self?.currentTranscript = transcript
            }
        }
        
        voiceManager.onSpeechEnd = { [weak self] finalTranscript in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentTranscript = finalTranscript
                // Don't auto-send — user controls via mic button tap
            }
        }
        
        // When AI finishes speaking all audio chunks → go idle
        voiceManager.onSpeechFinished = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.state = .idle
            }
        }
    }
    
    private func setupAudioLevelBindings() {
        voiceManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        voiceManager.$inputAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.inputAudioLevel = level
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Conversation Management
    
    func loadConversations() async {
        await service.fetchConversations()
        self.conversations = service.conversations
    }
    
    func startNewConversation() async {
        isLoadingConversation = true
        if let conversation = await service.createConversation(organizationId: organizationId) {
            currentConversationId = conversation.id
            messages = conversation.messages ?? []
        }
        isLoadingConversation = false
    }
    
    func loadConversation(_ conversationId: String) async {
        isLoadingConversation = true
        if let conversation = await service.fetchConversation(conversationId: conversationId) {
            currentConversationId = conversation.id
            messages = conversation.messages ?? []
        }
        showConversationList = false
        isLoadingConversation = false
    }
    
    func deleteConversation(_ conversationId: String) async {
        let success = await service.deleteConversation(conversationId: conversationId)
        if success {
            conversations.removeAll { $0.id == conversationId }
            if currentConversationId == conversationId {
                currentConversationId = nil
                messages = []
            }
        }
    }
    
    // MARK: - Voice Interaction
    
    func toggleListening() {
        if state == .listening {
            // User tapped mic to stop listening → send what they said immediately
            let transcript = voiceManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            voiceManager.stopListening(suppressCallback: true)
            
            if !transcript.isEmpty {
                // Send the transcript for processing right away
                Task {
                    await handleUserMessage(transcript)
                }
            } else {
                state = .idle
            }
            currentTranscript = ""
        } else if state == .speaking {
            // Interrupt AI — stop audio and go idle
            voiceManager.resetAudioQueue()
            state = .idle
        } else if state == .idle {
            // Start listening — auto-create conversation if needed
            if currentConversationId == nil {
                Task {
                    await startNewConversation()
                    startListening()
                }
            } else {
                startListening()
            }
        }
    }
    
    private func startListening() {
        state = .listening
        currentTranscript = ""
        voiceManager.startListening()
    }
    
    // MARK: - Send Text Message (keyboard input — no auto-listen)
    
    func sendTextMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if currentConversationId == nil {
            await startNewConversation()
        }
        
        await handleUserMessage(text)
    }
    
    // MARK: - Core Message Handling (Streaming)
    
    private func handleUserMessage(_ text: String) async {
        guard let conversationId = currentConversationId else { return }
        
        state = .thinking
        currentTranscript = ""
        streamingText = ""
        audioChunkCount = 0
        
        print("🤖 Sending message to backend: \"\(text.prefix(50))...\"")
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        // Add user message optimistically
        let tempUserMsgId = UUID().uuidString
        let tempUserMsg = AIMessage(
            id: tempUserMsgId,
            conversationId: conversationId,
            role: "user",
            content: text,
            metadata: nil,
            createdAt: now
        )
        messages.append(tempUserMsg)
        
        // Add placeholder AI message that will stream in
        streamingMsgTempId = UUID().uuidString
        let placeholderAIMsg = AIMessage(
            id: streamingMsgTempId,
            conversationId: conversationId,
            role: "assistant",
            content: "",
            metadata: nil,
            createdAt: now
        )
        messages.append(placeholderAIMsg)
        
        // Reset audio queue for new response
        voiceManager.resetAudioQueue()
        
        // Stream from backend
        await service.streamMessage(
            conversationId: conversationId,
            content: text,
            onToken: { [weak self] token in
                guard let self = self else { return }
                self.streamingText += token
                self.updateStreamingMessage(conversationId: conversationId)
            },
            onAudio: { [weak self] audioData, index in
                guard let self = self else { return }
                self.audioChunkCount += 1
                print("🤖 Audio chunk \(index) received (\(audioData.count) bytes), total: \(self.audioChunkCount)")
                // First audio chunk → switch to speaking state
                if self.state != .speaking {
                    self.state = .speaking
                }
                self.voiceManager.queueAudioChunk(data: audioData, index: index)
            },
            onUserMsgId: { [weak self] realId in
                guard let self = self else { return }
                print("🤖 User message saved with ID: \(realId)")
                // Replace temp user message ID with real server ID
                if let idx = self.messages.firstIndex(where: { $0.id == tempUserMsgId }) {
                    self.messages[idx] = AIMessage(
                        id: realId,
                        conversationId: conversationId,
                        role: "user",
                        content: text,
                        metadata: nil,
                        createdAt: now
                    )
                }
            },
            onDone: { [weak self] aiMsgId, fullText in
                guard let self = self else { return }
                print("🤖 Stream done. AI msg: \(aiMsgId), text length: \(fullText.count), audio chunks: \(self.audioChunkCount)")
                // Finalize the AI message with real ID and full text
                if let idx = self.messages.firstIndex(where: { $0.id == self.streamingMsgTempId }) {
                    self.messages[idx] = AIMessage(
                        id: aiMsgId,
                        conversationId: conversationId,
                        role: "assistant",
                        content: fullText,
                        metadata: nil,
                        createdAt: now
                    )
                }
                self.streamingText = ""
                self.streamingMsgTempId = ""
                
                // Tell voice manager that all audio chunks have been dispatched
                self.voiceManager.markStreamComplete(totalChunks: self.audioChunkCount)
                
                // If no audio was sent at all, go idle now
                if self.audioChunkCount == 0 {
                    print("🤖 No audio chunks received — going idle")
                    self.state = .idle
                }
            },
            onError: { [weak self] errorMsg in
                guard let self = self else { return }
                print("❌ Stream error: \(errorMsg)")
                self.error = errorMsg
                self.state = .idle
                // Remove placeholder AI message on error
                self.messages.removeAll { $0.id == self.streamingMsgTempId }
                self.streamingText = ""
                self.streamingMsgTempId = ""
            }
        )
    }
    
    /// Update the streaming AI message in the messages array with current text
    private func updateStreamingMessage(conversationId: String) {
        if let idx = messages.firstIndex(where: { $0.id == streamingMsgTempId }) {
            messages[idx] = AIMessage(
                id: streamingMsgTempId,
                conversationId: conversationId,
                role: "assistant",
                content: streamingText,
                metadata: nil,
                createdAt: messages[idx].createdAt
            )
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        voiceManager.cleanup()
        cancellables.removeAll()
    }
}
