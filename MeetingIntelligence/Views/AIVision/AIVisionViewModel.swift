//
//  AIVisionViewModel.swift
//  MeetingIntelligence
//
//  Industrial Vision Assistant – Professional ViewModel with proper state management
//

import SwiftUI
import AVFoundation
import Combine
import FirebaseAuth

// MARK: - Assistant State (Clear, Sequential Flow)
enum AIVisionState: Equatable {
    case idle           // Ready for user input
    case recording      // Recording user's voice question
    case transcribing   // Whisper is processing the audio
    case analyzing      // Capturing frames + GPT-4 Vision processing
    case speaking       // AI is speaking the response
}

// MARK: - Captured Frame
struct CapturedFrame: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    let base64: String
}

// MARK: - AI Vision ViewModel
@MainActor
class AIVisionViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: AIVisionState = .idle
    @Published var transcribedQuestion: String = ""
    @Published var responseText: String = ""
    @Published var isFlashOn: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedTopic: AnalysisTopic = .safety
    @Published var recordingDuration: TimeInterval = 0
    @Published var showEndSessionModal: Bool = false
    
    // MARK: - Session Manager
    let sessionManager = VisionSessionManager.shared
    
    // MARK: - Camera Properties
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var capturedFrames: [CapturedFrame] = []
    private var isCapturingFrames = false
    private var frameCount = 0
    private let maxFrames = 5
    
    // MARK: - Audio Recording (for Whisper)
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var recordingTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 30.0
    
    // MARK: - Audio Playback with Completion
    private var audioPlayer: AVAudioPlayer?
    private var audioCompletionHandler: (() -> Void)?
    
    // MARK: - Timers
    private var frameTimer: Timer?
    
    // MARK: - OpenAI Service
    private let openAIService = OpenAIVisionService()
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupCamera()
        requestPermissions()
        setupUserIdForSessions()
    }
    
    // MARK: - Setup User ID for Session Sync
    private func setupUserIdForSessions() {
        // Set user ID for database sync (if logged in)
        if let userId = FirebaseAuthService.shared.currentUser?.uid {
            sessionManager.userId = userId
        }
    }
    
    // MARK: - Permissions
    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                Task { @MainActor in
                    self.showError(message: "Camera access is required for System Vision Assistant.")
                }
            }
        }
        
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                Task { @MainActor in
                    self.showError(message: "Microphone access is required for voice commands.")
                }
            }
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        output.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        }
        
        captureSession.commitConfiguration()
    }
    
    func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopCamera() {
        captureSession.stopRunning()
        stopRecordingImmediately()
    }
    
    func switchCamera() {
        captureSession.beginConfiguration()
        
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        captureSession.commitConfiguration()
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
        }
    }
    
    // MARK: - Main Control Button Action
    func handleMainButtonTap() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecordingAndProcess()
        case .speaking:
            // Stop AI speech and go back to idle
            stopSpeakingAndReset()
        default:
            // Ignore taps during transcribing/analyzing
            break
        }
    }
    
    // MARK: - Recording Flow
    private func startRecording() {
        // Ensure we're not playing any audio
        audioPlayer?.stop()
        audioPlayer = nil
        
        state = .recording
        transcribedQuestion = ""
        responseText = ""
        recordingDuration = 0
        
        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            showError(message: "Failed to configure audio: \(error.localizedDescription)")
            state = .idle
            return
        }
        
        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        
        guard let fileURL = audioFileURL else {
            showError(message: "Failed to create audio file.")
            state = .idle
            return
        }
        
        // Recording settings optimized for Whisper
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            // Duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, self.state == .recording else { return }
                    self.recordingDuration += 0.1
                    
                    if self.recordingDuration >= self.maxRecordingDuration {
                        self.stopRecordingAndProcess()
                    }
                }
            }
        } catch {
            showError(message: "Failed to start recording: \(error.localizedDescription)")
            state = .idle
        }
    }
    
    private func stopRecordingAndProcess() {
        guard state == .recording else { return }
        
        // Stop recording
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Validate recording
        guard let fileURL = audioFileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              recordingDuration >= 0.5 else {
            showError(message: "Recording too short. Please hold and speak your question.")
            state = .idle
            cleanupAudioFile()
            return
        }
        
        // Proceed to transcription
        transcribeAndAnalyze(fileURL: fileURL)
    }
    
    private func stopRecordingImmediately() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        cleanupAudioFile()
    }
    
    private func cleanupAudioFile() {
        if let fileURL = audioFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        audioFileURL = nil
    }
    
    // MARK: - Transcription + Analysis Flow (Sequential)
    private func transcribeAndAnalyze(fileURL: URL) {
        state = .transcribing
        
        Task {
            do {
                // Step 1: Transcribe with Whisper
                let recordedAudio = try Data(contentsOf: fileURL)
                let transcription = try await openAIService.transcribeAudio(audioData: recordedAudio)
                
                let question = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await MainActor.run {
                    self.cleanupAudioFile()
                    
                    guard !question.isEmpty else {
                        self.showError(message: "Could not understand. Please speak clearly and try again.")
                        self.state = .idle
                        return
                    }
                    
                    self.transcribedQuestion = question
                    print("✓ Transcription: \(question)")
                    
                    // Track user message in session
                    self.ensureSessionExists()
                    self.sessionManager.addMessageToCurrentSession(role: .user, content: question)
                }
                
                // Step 2: Capture frames + Analyze
                guard !question.isEmpty else { return }
                
                await MainActor.run {
                    self.state = .analyzing
                }
                
                // Capture frames
                let frames = await captureFramesForAnalysis()
                
                guard !frames.isEmpty else {
                    await MainActor.run {
                        self.showError(message: "Failed to capture frames. Please try again.")
                        self.state = .idle
                    }
                    return
                }
                
                print("✓ Captured \(frames.count) frames")
                
                // Step 3: Get AI response (still in analyzing state)
                let response = try await openAIService.analyzeFrames(
                    frames: frames,
                    question: question,
                    topic: selectedTopic.rawValue
                )
                
                print("✓ AI Response received, preparing audio...")
                
                // Step 4: Get TTS audio (still in analyzing state - user doesn't see response yet)
                let speechAudio = try await openAIService.textToSpeech(text: response)
                
                print("✓ Audio ready, now speaking")
                
                // Step 5: NOW show the response and start speaking
                await MainActor.run {
                    self.responseText = response
                    self.state = .speaking
                    
                    // Track AI response in session
                    self.sessionManager.addMessageToCurrentSession(role: .assistant, content: response)
                }
                
                // Step 6: Play audio and wait for completion
                await playAudioAndWait(speechAudio)
                
                // Step 7: Auto-listen for follow-up (only after speech completes)
                await MainActor.run {
                    print("✓ Speech completed, starting auto-listen")
                    self.state = .idle
                    // Small delay before auto-listen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        guard let self = self, self.state == .idle else { return }
                        self.startRecording()
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.showError(message: "Error: \(error.localizedDescription)")
                    self.state = .idle
                    self.cleanupAudioFile()
                }
            }
        }
    }
    
    // MARK: - Frame Capture (Synchronous)
    private func captureFramesForAnalysis() async -> [CapturedFrame] {
        await MainActor.run {
            self.capturedFrames.removeAll()
            self.frameCount = 0
            self.isCapturingFrames = true
        }
        
        // Capture frames over 1.5 seconds
        let captureTime: UInt64 = 1_500_000_000 // 1.5 seconds in nanoseconds
        let frameInterval: UInt64 = captureTime / UInt64(maxFrames)
        
        for _ in 0..<maxFrames {
            try? await Task.sleep(nanoseconds: frameInterval)
        }
        
        await MainActor.run {
            self.isCapturingFrames = false
        }
        
        return await MainActor.run {
            return self.capturedFrames
        }
    }
    
    // MARK: - Play Audio and Wait for Completion
    private func playAudioAndWait(_ audioData: Data) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                do {
                    // Configure audio session for playback
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playback, mode: .default)
                    try audioSession.setActive(true)
                    
                    self.audioPlayer = try AVAudioPlayer(data: audioData)
                    self.audioPlayer?.delegate = self
                    
                    // Store completion handler
                    self.audioCompletionHandler = {
                        continuation.resume()
                    }
                    
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                    
                } catch {
                    print("Audio playback error: \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Stop Speaking
    private func stopSpeakingAndReset() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioCompletionHandler = nil
        state = .idle
    }
    
    // MARK: - Reset
    func clearAndReset() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioCompletionHandler = nil
        stopRecordingImmediately()
        responseText = ""
        transcribedQuestion = ""
        capturedFrames.removeAll()
        state = .idle
    }
    
    // MARK: - Error Handling
    func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        showError = false
        errorMessage = ""
    }
    
    // MARK: - Session Management
    
    private func ensureSessionExists() {
        if sessionManager.currentSession == nil || sessionManager.currentSession?.topic != selectedTopic.rawValue {
            sessionManager.startNewSession(topic: selectedTopic.rawValue, topicIcon: selectedTopic.icon)
        }
    }
    
    var hasActiveSession: Bool {
        guard let session = sessionManager.currentSession else { return false }
        return !session.messages.isEmpty
    }
    
    func endSession() {
        showEndSessionModal = true
    }
    
    func saveAndEndSession() {
        sessionManager.saveCurrentSessionPermanently()
        clearAndReset()
        showEndSessionModal = false
    }
    
    func discardSession() {
        sessionManager.clearCurrentSession()
        clearAndReset()
        showEndSessionModal = false
    }
}

// MARK: - AVAudioPlayerDelegate
extension AIVisionViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.audioCompletionHandler?()
            self.audioCompletionHandler = nil
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.audioCompletionHandler?()
            self.audioCompletionHandler = nil
        }
    }
}

// MARK: - Video Capture Delegate
extension AIVisionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task { @MainActor in
            guard self.isCapturingFrames, self.capturedFrames.count < self.maxFrames else { return }
            
            // Convert to UIImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            var image = UIImage(cgImage: cgImage)
            
            // Resize to max 1200px width
            let maxWidth: CGFloat = 1200
            if image.size.width > maxWidth {
                let scale = maxWidth / image.size.width
                let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                image = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            }
            
            // Convert to base64 JPEG
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
            let base64String = jpegData.base64EncodedString()
            
            let frame = CapturedFrame(
                image: image,
                timestamp: Date(),
                base64: base64String
            )
            
            self.capturedFrames.append(frame)
        }
    }
}
