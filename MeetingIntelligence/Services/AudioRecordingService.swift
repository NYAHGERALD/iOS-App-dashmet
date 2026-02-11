//
//  AudioRecordingService.swift
//  MeetingIntelligence
//
//  Phase 3.1 - Audio Recording Service using AVFoundation
//

import Foundation
import AVFoundation
import Combine

// MARK: - Recording State
enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopped
    case failed(String)
    
    var isActive: Bool {
        switch self {
        case .recording, .paused:
            return true
        default:
            return false
        }
    }
    
    var canRecord: Bool {
        switch self {
        case .idle, .stopped, .failed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Recording Error
enum RecordingError: LocalizedError {
    case microphonePermissionDenied
    case audioSessionSetupFailed(String)
    case recorderInitFailed(String)
    case recordingFailed(String)
    case fileNotFound
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record meetings. Please enable it in Settings."
        case .audioSessionSetupFailed(let reason):
            return "Failed to setup audio: \(reason)"
        case .recorderInitFailed(let reason):
            return "Failed to initialize recorder: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .fileNotFound:
            return "Recording file not found"
        case .exportFailed(let reason):
            return "Failed to export recording: \(reason)"
        }
    }
}

// MARK: - Audio Recording Service
@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = AudioRecordingService()
    
    // MARK: - Published Properties
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0  // 0.0 to 1.0
    @Published private(set) var peakLevel: Float = 0
    @Published private(set) var recordingURL: URL?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    
    // Recording settings optimized for speech
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVEncoderBitRateKey: 128000
    ]
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Permission Management
    
    /// Check if microphone permission is granted
    func checkMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        return await checkMicrophonePermission()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() throws {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for recording with playback capability
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession?.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Audio session setup failed: \(error)")
            throw RecordingError.audioSessionSetupFailed(error.localizedDescription)
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Recording Control
    
    /// Start a new recording for a meeting
    func startRecording(meetingId: String) async throws -> URL {
        // Check permission first
        guard await checkMicrophonePermission() else {
            state = .failed("Microphone permission denied")
            throw RecordingError.microphonePermissionDenied
        }
        
        state = .preparing
        
        // Setup audio session
        try setupAudioSession()
        
        // Create file URL
        let fileURL = getRecordingURL(for: meetingId)
        recordingURL = fileURL
        
        // Create and configure recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.prepareToRecord() == true else {
                throw RecordingError.recorderInitFailed("Failed to prepare recorder")
            }
            
            guard audioRecorder?.record() == true else {
                throw RecordingError.recordingFailed("Failed to start recording")
            }
            
            // Start timers
            startTime = Date()
            pausedDuration = 0
            startTimers()
            
            state = .recording
            print("✅ Recording started: \(fileURL.lastPathComponent)")
            
            return fileURL
        } catch let error as RecordingError {
            state = .failed(error.localizedDescription)
            throw error
        } catch {
            let recordingError = RecordingError.recorderInitFailed(error.localizedDescription)
            state = .failed(recordingError.localizedDescription)
            throw recordingError
        }
    }
    
    /// Pause the current recording
    func pauseRecording() {
        guard state == .recording, let recorder = audioRecorder else { return }
        
        recorder.pause()
        pauseStartTime = Date()
        stopTimers()
        
        state = .paused
        print("⏸️ Recording paused at \(formattedTime(currentTime))")
    }
    
    /// Resume a paused recording
    func resumeRecording() {
        guard state == .paused, let recorder = audioRecorder else { return }
        
        // Calculate paused duration
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        recorder.record()
        startTimers()
        
        state = .recording
        print("▶️ Recording resumed")
    }
    
    /// Stop the recording and return the file URL
    func stopRecording() -> URL? {
        guard state.isActive, let recorder = audioRecorder else { return nil }
        
        recorder.stop()
        stopTimers()
        deactivateAudioSession()
        
        state = .stopped
        
        let url = recordingURL
        print("⏹️ Recording stopped. Duration: \(formattedTime(currentTime))")
        
        // Reset time tracking
        currentTime = 0
        audioLevel = 0
        peakLevel = 0
        
        return url
    }
    
    /// Cancel and delete the current recording
    func cancelRecording() {
        guard let recorder = audioRecorder else { return }
        
        recorder.stop()
        recorder.deleteRecording()
        stopTimers()
        deactivateAudioSession()
        
        state = .idle
        recordingURL = nil
        currentTime = 0
        audioLevel = 0
        peakLevel = 0
        
        print("🗑️ Recording cancelled and deleted")
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Time update timer (every 0.1 seconds for smooth display)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTime()
            }
        }
        
        // Audio level timer (every 0.05 seconds for responsive meters)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
    }
    
    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateTime() {
        guard let start = startTime else { return }
        
        var elapsed = Date().timeIntervalSince(start)
        
        // Subtract paused duration
        elapsed -= pausedDuration
        
        // If currently paused, also subtract time since pause started
        if state == .paused, let pauseStart = pauseStartTime {
            elapsed -= Date().timeIntervalSince(pauseStart)
        }
        
        currentTime = max(0, elapsed)
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, state == .recording else {
            audioLevel = 0
            peakLevel = 0
            return
        }
        
        recorder.updateMeters()
        
        // Convert from dB to linear scale (0-1)
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Normalize: -60dB to 0dB -> 0 to 1
        audioLevel = normalizeAudioLevel(averagePower)
        peakLevel = normalizeAudioLevel(peakPower)
    }
    
    private func normalizeAudioLevel(_ decibels: Float) -> Float {
        // Clamp to reasonable range
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        
        let clamped = max(minDb, min(maxDb, decibels))
        let normalized = (clamped - minDb) / (maxDb - minDb)
        
        return normalized
    }
    
    // MARK: - File Management
    
    private func getRecordingURL(for meetingId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // Create recordings directory if needed
        try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "+", with: "_")
        
        let filename = "meeting_\(meetingId)_\(timestamp).m4a"
        return recordingsPath.appendingPathComponent(filename)
    }
    
    /// Get file size in bytes
    func getRecordingFileSize() -> Int64? {
        guard let url = recordingURL else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Get formatted file size
    func getFormattedFileSize() -> String? {
        guard let size = getRecordingFileSize() else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Delete a recording file
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Utilities
    
    /// Format time interval as MM:SS or HH:MM:SS
    func formattedTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Get duration in seconds (for API)
    var durationInSeconds: Int {
        Int(currentTime)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingService: AVAudioRecorderDelegate {
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("❌ Recording finished with error")
                self.state = .failed("Recording finished unexpectedly")
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            let message = error?.localizedDescription ?? "Unknown encoding error"
            print("❌ Recording encode error: \(message)")
            self.state = .failed(message)
        }
    }
}
