//
//  AIAssistantVoiceManager.swift
//  MeetingIntelligence
//
//  Real-time voice interaction for the AI Assistant
//  - Push-to-talk: user controls start/stop via mic button
//  - No automatic silence cutoff — user decides when they're done
//  - Queued audio playback for gapless sentence-by-sentence TTS
//  - Audio level monitoring for avatar lip-sync animations
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class AIAssistantVoiceManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcript = ""
    @Published var audioLevel: Float = 0.0          // 0.0–1.0, drives mouth animation
    @Published var inputAudioLevel: Float = 0.0     // Mic input level for visual feedback
    @Published var error: String?
    
    // MARK: - Speech Recognition
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Audio Playback (queued for gapless sentence playback)
    
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [(data: Data, index: Int)] = []  // Ordered queue of audio chunks
    private var nextExpectedIndex: Int = 0                    // Next chunk index to play
    private var pendingChunks: [Int: Data] = [:]              // Out-of-order chunks waiting
    private var audioLevelTimer: Timer?
    private var isStreamComplete: Bool = false                // True when SSE "done" event received
    private var totalExpectedChunks: Int = -1                 // Total chunks expected (-1 = unknown)
    
    // MARK: - Callbacks
    
    var onSpeechResult: ((String) -> Void)?
    var onSpeechEnd: ((String) -> Void)?
    var onSpeechFinished: (() -> Void)?   // Called when AI finishes speaking all audio chunks
    
    override init() {
        super.init()
        requestPermissions()
    }
    
    // MARK: - Permissions
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    break
                case .denied, .restricted, .notDetermined:
                    self?.error = "Speech recognition permission is required"
                @unknown default:
                    break
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                if !granted {
                    self?.error = "Microphone permission is required"
                }
            }
        }
    }
    
    // MARK: - Start Listening
    
    func startListening() {
        guard !isListening else { return }
        
        // Stop any ongoing playback
        stopSpeaking()
        
        // Reset
        transcript = ""
        error = nil
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.addsPunctuation = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                
                let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
                Task { @MainActor in
                    self?.inputAudioLevel = level
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let result = result {
                        self.transcript = result.bestTranscription.formattedString
                        self.onSpeechResult?(self.transcript)
                        
                        if result.isFinal {
                            self.finishListening()
                        }
                    }
                    
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                            print("⚠️ Speech recognition error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            self.error = "Failed to start listening: \(error.localizedDescription)"
            isListening = false
        }
    }
    
    // MARK: - Stop Listening
    
    /// Stop listening. If suppressCallback is true, onSpeechEnd is NOT called
    /// (used when the caller already has the transcript and will handle it).
    func stopListening(suppressCallback: Bool = false) {
        guard isListening else { return }
        finishListening(suppressCallback: suppressCallback)
    }
    
    private func finishListening(suppressCallback: Bool = false) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        inputAudioLevel = 0
        
        if !suppressCallback {
            let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalTranscript.isEmpty {
                onSpeechEnd?(finalTranscript)
            }
        }
    }
    
    // MARK: - Audio Queue (gapless sentence-by-sentence playback)
    
    /// Queue an audio chunk for playback. Chunks are played in index order.
    /// If chunk 0 arrives, it plays immediately. If chunk 2 arrives before chunk 1,
    /// chunk 2 is buffered until chunk 1 finishes.
    func queueAudioChunk(data: Data, index: Int) {
        print("🔊 Received audio chunk \(index) (\(data.count) bytes), next expected: \(nextExpectedIndex), playing: \(isPlayingChunk())")
        
        if index == nextExpectedIndex && !isPlayingChunk() {
            // Play immediately
            playChunk(data: data, index: index)
        } else {
            // Buffer for later
            pendingChunks[index] = data
            // If nothing is playing and this is the next expected, play it
            if !isPlayingChunk() && pendingChunks[nextExpectedIndex] != nil {
                playNextChunk()
            }
        }
    }
    
    /// Reset the audio queue for a new response
    func resetAudioQueue() {
        audioQueue.removeAll()
        pendingChunks.removeAll()
        nextExpectedIndex = 0
        isStreamComplete = false
        totalExpectedChunks = -1
        stopSpeaking()
    }
    
    /// Called when the SSE stream sends "done" — all audio chunks have been dispatched.
    /// If we've already finished playing everything, fire onSpeechFinished immediately.
    func markStreamComplete(totalChunks: Int) {
        isStreamComplete = true
        totalExpectedChunks = totalChunks
        print("🔈 Stream complete. Total TTS chunks expected: \(totalChunks), next expected: \(nextExpectedIndex), playing: \(isPlayingChunk())")
        // If nothing is playing and we've played all chunks, we're done
        if !isPlayingChunk() && nextExpectedIndex >= totalChunks && pendingChunks.isEmpty {
            print("🔈 All audio already played. Firing onSpeechFinished.")
            isSpeaking = false
            audioLevel = 0
            stopAudioLevelMonitoring()
            onSpeechFinished?()
        }
    }
    
    private func isPlayingChunk() -> Bool {
        return audioPlayer?.isPlaying == true
    }
    
    private func playChunk(data: Data, index: Int) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isSpeaking = true
            nextExpectedIndex = index + 1
            
            startAudioLevelMonitoring()
        } catch {
            print("❌ Audio chunk \(index) playback error: \(error)")
            nextExpectedIndex = index + 1
            playNextChunk()
        }
    }
    
    private func playNextChunk() {
        if let nextData = pendingChunks.removeValue(forKey: nextExpectedIndex) {
            playChunk(data: nextData, index: nextExpectedIndex)
        } else if isStreamComplete {
            // Stream is done AND no more buffered chunks — truly finished
            print("🔈 All audio chunks played. Stream complete.")
            isSpeaking = false
            audioLevel = 0
            stopAudioLevelMonitoring()
            onSpeechFinished?()
        } else {
            // More chunks may still be arriving from the stream — wait
            print("🔈 Waiting for chunk \(nextExpectedIndex) from stream...")
            isSpeaking = true  // Keep speaking state while waiting
        }
    }
    
    // MARK: - Speak (legacy single-chunk playback)
    
    func speak(audioData: Data) {
        resetAudioQueue()
        queueAudioChunk(data: audioData, index: 0)
    }
    
    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        pendingChunks.removeAll()
        isSpeaking = false
        audioLevel = 0
        stopAudioLevelMonitoring()
    }
    
    // MARK: - Audio Level Monitoring (lip sync)
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer, player.isPlaying else {
                    self?.audioLevel = 0
                    return
                }
                
                player.updateMeters()
                let power = player.averagePower(forChannel: 0)
                let normalizedLevel = max(0, min(1, (power + 50) / 50))
                self.audioLevel = self.audioLevel * 0.3 + normalizedLevel * 0.7
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
    }
    
    // MARK: - Audio Level Calculation (mic input)
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let sample = channelData[channel][frame]
                sum += sample * sample
            }
        }
        
        let rms = sqrt(sum / Float(frameLength * channelCount))
        return min(rms * 5, 1.0)
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopListening()
        stopSpeaking()
        pendingChunks.removeAll()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AIAssistantVoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopAudioLevelMonitoring()
            // Play next queued chunk if available
            self.playNextChunk()
        }
    }
}
