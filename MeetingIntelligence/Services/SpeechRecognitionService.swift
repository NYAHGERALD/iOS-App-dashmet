//
//  SpeechRecognitionService.swift
//  MeetingIntelligence
//
//  Simple Live Speech Recognition with Multi-Language Support
//  No speaker identification - just continuous transcription
//

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Transcript Segment Model
struct LiveTranscriptSegment: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var speakerId: Int = 0  // Not used, kept for compatibility
    var timestamp: TimeInterval
    var isFinal: Bool
    var confidence: Float
    var correctedText: String?
    var isAICorrected: Bool = false
    var languageId: String?
    
    var displayText: String {
        correctedText ?? text
    }
    
    static func == (lhs: LiveTranscriptSegment, rhs: LiveTranscriptSegment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Speech Recognition Error
enum SpeechRecognitionError: Error {
    case notAuthorized
    case recognizerNotAvailable
    case requestCreationFailed
    case audioEngineError
}

// MARK: - Speech Recognition Service
@MainActor
class SpeechRecognitionService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SpeechRecognitionService()
    
    // MARK: - Published Properties
    @Published var isAuthorized: Bool = false
    @Published var isRecognizing: Bool = false
    @Published var transcript: [LiveTranscriptSegment] = []
    @Published var currentSegment: LiveTranscriptSegment?
    @Published var continuousText: String = ""  // Full continuous transcript
    @Published var errorMessage: String?
    @Published var recognitionConfidence: Float = 0
    @Published var currentLanguage: SupportedLanguage?
    @Published var recognizerStatus: String = "Ready"
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var startTime: Date?
    private var lastFinalText: String = ""
    
    // Language Manager
    private let languageManager = LanguageManager.shared
    
    // MARK: - Initialization
    private init() {
        // Initialize with selected language from LanguageManager
        currentLanguage = languageManager.selectedLanguage
        speechRecognizer = languageManager.createSpeechRecognizer()
        checkAuthorization()
    }
    
    // MARK: - Language Management
    func setLanguage(_ language: SupportedLanguage) {
        languageManager.selectLanguage(language)
        currentLanguage = language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.id))
        
        print("🌍 Speech recognizer set to: \(language.displayName)")
    }
    
    func getAvailableLanguages() -> [SupportedLanguage] {
        return languageManager.availableLanguages
    }
    
    func getRecentLanguages() -> [SupportedLanguage] {
        return languageManager.recentLanguages
    }
    
    func getPidginFriendlyLanguages() -> [SupportedLanguage] {
        return languageManager.pidginSupportedLanguages()
    }
    
    // MARK: - Authorization
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = status == .authorized
                if status != .authorized {
                    self?.errorMessage = "Speech recognition not authorized"
                }
            }
        }
    }
    
    // MARK: - Start Recognition
    func startRecognition(withAudioEngine engine: AVAudioEngine? = nil) async throws {
        guard isAuthorized else {
            recognizerStatus = "Not authorized"
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Ensure recognizer is using current language
        if speechRecognizer == nil || currentLanguage?.id != languageManager.selectedLanguage.id {
            currentLanguage = languageManager.selectedLanguage
            speechRecognizer = languageManager.createSpeechRecognizer()
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            recognizerStatus = "Recognizer not available"
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        // Stop any existing recognition
        stopRecognition()
        
        // Initialize - clear previous data
        transcript = []
        continuousText = ""
        lastFinalText = ""
        startTime = Date()
        errorMessage = nil
        recognizerStatus = "Starting..."
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            recognizerStatus = "Request creation failed"
            throw SpeechRecognitionError.requestCreationFailed
        }
        
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use server for better quality
        
        // Enable automatic punctuation on iOS 16+
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        
        // Configure audio session first (IMPORTANT: before creating audio engine)
        try configureAudioSession()
        
        // Create new audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            recognizerStatus = "Audio engine error"
            throw SpeechRecognitionError.audioEngineError
        }
        
        // Get input node
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            recognizerStatus = "Input node error"
            throw SpeechRecognitionError.audioEngineError
        }
        
        // Get recording format - use the hardware's native format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Verify format is valid
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            recognizerStatus = "Invalid audio format"
            throw SpeechRecognitionError.audioEngineError
        }
        
        print("🎤 Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")
        
        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            recognizerStatus = "Listening (\(currentLanguage?.flag ?? "🌍"))"
            print("🎙️ Audio engine started successfully")
        } catch {
            recognizerStatus = "Engine start failed"
            print("❌ Failed to start audio engine: \(error)")
            throw SpeechRecognitionError.audioEngineError
        }
        
        isRecognizing = true
        print("🎙️ Speech recognition started with language: \(currentLanguage?.displayName ?? "Unknown")")
    }
    
    // MARK: - Stop Recognition
    func stopRecognition() {
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // End audio request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Remove audio tap and stop engine
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        inputNode = nil
        
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
        }
        audioEngine = nil
        
        // Finalize current segment if exists
        if var segment = currentSegment {
            segment.isFinal = true
            segment.languageId = currentLanguage?.id
            transcript.append(segment)
            currentSegment = nil
        }
        
        isRecognizing = false
        recognizerStatus = "Stopped"
        print("🎙️ Speech recognition stopped")
        print("📝 Final transcript has \(transcript.count) segments, continuous text: \(continuousText.count) characters")
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Use measurement mode for better speech recognition quality
        // with high gain for distance recording
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,  // Better for speech recognition
            options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .mixWithOthers,  // Allow mixing with other audio
                .duckOthers      // Lower other audio when recording
            ]
        )
        
        // Set preferred sample rate and buffer duration for high quality
        try audioSession.setPreferredSampleRate(48000.0)  // Higher sample rate
        try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer for very low latency
        
        // Set input gain to maximum for high sensitivity (distance recording)
        if audioSession.isInputGainSettable {
            try audioSession.setInputGain(1.0)  // Maximum gain
            print("🎤 Input gain set to maximum (1.0)")
        }
        
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("✅ Audio session configured with HIGH SENSITIVITY mode")
    }
    
    // MARK: - Handle Recognition Result
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Handle errors
        if let error = error {
            let nsError = error as NSError
            
            // Ignore cancellation errors (normal when stopping)
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                return
            }
            
            print("❌ Recognition error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.recognizerStatus = "Error"
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription
        let text = transcription.formattedString
        let confidence = calculateConfidence(from: transcription)
        
        recognitionConfidence = confidence
        
        let currentTime = Date().timeIntervalSince(startTime ?? Date())
        
        // Always update continuous text with the full result
        continuousText = text
        
        if result.isFinal {
            // Store final text
            lastFinalText = text
            
            // Create segment for history
            let segment = LiveTranscriptSegment(
                text: text,
                speakerId: 0,
                timestamp: currentTime,
                isFinal: true,
                confidence: confidence,
                languageId: currentLanguage?.id
            )
            
            // Replace or add segment
            if transcript.isEmpty {
                transcript.append(segment)
            } else {
                // Update the last segment with final text
                transcript[transcript.count - 1] = segment
            }
            
            currentSegment = nil
            print("📝 Final transcript: \(text.prefix(50))...")
        } else {
            // Update current segment for partial results
            if currentSegment == nil {
                currentSegment = LiveTranscriptSegment(
                    text: text,
                    speakerId: 0,
                    timestamp: currentTime,
                    isFinal: false,
                    confidence: confidence
                )
            } else {
                currentSegment?.text = text
                currentSegment?.confidence = confidence
            }
        }
    }
    
    // MARK: - Calculate Confidence
    private func calculateConfidence(from transcription: SFTranscription) -> Float {
        guard !transcription.segments.isEmpty else { return 0 }
        
        let totalConfidence = transcription.segments.reduce(0.0) { $0 + $1.confidence }
        return Float(totalConfidence) / Float(transcription.segments.count)
    }
    
    // MARK: - Get Full Transcript Text
    func getFullTranscriptText() -> String {
        return continuousText
    }
    
    // MARK: - Export Transcript
    func exportTranscript() -> [LiveTranscriptSegment] {
        var allSegments = transcript
        if let current = currentSegment {
            allSegments.append(current)
        }
        return allSegments
    }
    
    // MARK: - Clear Transcript
    func clearTranscript() {
        transcript = []
        continuousText = ""
        lastFinalText = ""
        currentSegment = nil
    }
}
