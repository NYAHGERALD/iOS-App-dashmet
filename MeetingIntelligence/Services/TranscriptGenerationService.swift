//
//  TranscriptGenerationService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Transcript Generation
//  Uses OpenAI Whisper API for high-accuracy transcription
//

import Foundation
import AVFoundation
import Combine

// MARK: - Transcript Generation Progress
enum TranscriptGenerationStage: String, CaseIterable {
    case preparing = "Preparing audio..."
    case diarizing = "Identifying speakers..."
    case transcribing = "Transcribing speech..."
    case processingAI = "System processing..."
    case finalizing = "Finalizing transcript..."
    case complete = "Complete"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .preparing: return "waveform"
        case .diarizing: return "person.2.wave.2"
        case .transcribing: return "text.bubble"
        case .processingAI: return "sparkles"
        case .finalizing: return "checkmark.circle"
        case .complete: return "checkmark.seal.fill"
        case .failed: return "xmark.circle"
        }
    }
    
    var stageIndex: Int {
        switch self {
        case .preparing: return 0
        case .diarizing: return 1
        case .transcribing: return 2
        case .processingAI: return 3
        case .finalizing: return 4
        case .complete: return 5
        case .failed: return -1
        }
    }
}

// MARK: - Transcript Generation Progress Model
struct TranscriptProgress: Equatable {
    var stage: TranscriptGenerationStage
    var overallProgress: Double  // 0.0 to 1.0
    var stageProgress: Double    // 0.0 to 1.0 for current stage
    var statusMessage: String
    var estimatedTimeRemaining: TimeInterval?
    
    static var initial: TranscriptProgress {
        TranscriptProgress(
            stage: .preparing,
            overallProgress: 0.0,
            stageProgress: 0.0,
            statusMessage: "Initializing...",
            estimatedTimeRemaining: nil
        )
    }
}

// MARK: - Generated Transcript Model
struct GeneratedTranscript: Equatable {
    let rawText: String
    let processedText: String
    let segments: [TranscriptSegment]
    let speakerBlocks: [SpeakerBlock]
    let duration: TimeInterval
    let wordCount: Int
    let speakerCount: Int
    let speakers: [String]
    let isDiarized: Bool
    let generatedAt: Date
    
    struct TranscriptSegment: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
        let speakerId: Int?
    }
    
    /// Speaker-attributed transcript block from diarization
    struct SpeakerBlock: Identifiable, Equatable {
        let id = UUID()
        let speaker: String
        let content: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
        let wordCount: Int
        
        var formattedStartTime: String {
            let totalSeconds = Int(startTime)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        var formattedTimeRange: String {
            let startMins = Int(startTime) / 60
            let startSecs = Int(startTime) % 60
            let endMins = Int(endTime) / 60
            let endSecs = Int(endTime) % 60
            return String(format: "%d:%02d – %d:%02d", startMins, startSecs, endMins, endSecs)
        }
    }
}

// MARK: - Transcript Generation Error
enum TranscriptGenerationError: Error, LocalizedError {
    case audioFileNotFound
    case invalidAudioFormat
    case serviceUnavailable
    case transcriptionFailed(String)
    case aiProcessingFailed(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid or unsupported audio format"
        case .serviceUnavailable:
            return "Transcription service is temporarily unavailable. Please try again later."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .aiProcessingFailed(let message):
            return "System processing failed: \(message)"
        case .cancelled:
            return "Transcript generation was cancelled"
        }
    }
}

// MARK: - Transcript Generation Service
@MainActor
class TranscriptGenerationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TranscriptGenerationService()
    
    // MARK: - Published Properties
    @Published var isGenerating: Bool = false
    @Published var progress: TranscriptProgress = .initial
    @Published var generatedTranscript: GeneratedTranscript?
    @Published var error: TranscriptGenerationError?
    
    // MARK: - Private Properties
    private var cancellationRequested = false
    private var transcriptionStartTime: Date?
    private var audioDuration: TimeInterval = 0
    private var currentTask: URLSessionTask?
    
    // Backend API endpoints
    private let backendTranscriptionURL = "https://dashmet-rca-api.onrender.com/api/transcripts/transcribe"
    private let backendDiarizationURL = "https://dashmet-rca-api.onrender.com/api/transcripts/diarize"
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Configuration
    
    /// Enterprise transcription is always available (uses backend)
    var isEnterpriseTranscriptionAvailable: Bool {
        return true  // Backend handles API key
    }
    
    /// API key configuration is handled server-side
    func configureAPIKey(_ key: String) {
        // API key is now managed on the backend server
        // This method kept for backwards compatibility
        print("ℹ️ API key is managed server-side. No client configuration needed.")
    }
    
    // MARK: - Public Methods
    
    /// Generate transcript from audio file using server-side Whisper transcription
    /// Pipeline: Upload audio → OpenAI Whisper API → Formatted transcript
    func generateTranscript(
        from audioURL: URL,
        language: SupportedLanguage? = nil,
        meetingType: String? = nil
    ) async throws -> GeneratedTranscript {
        guard !isGenerating else {
            throw TranscriptGenerationError.transcriptionFailed("Generation already in progress")
        }
        
        // Reset state
        isGenerating = true
        cancellationRequested = false
        error = nil
        generatedTranscript = nil
        transcriptionStartTime = Date()
        
        defer {
            isGenerating = false
        }
        
        do {
            // Stage 1: Prepare audio
            updateProgress(stage: .preparing, stageProgress: 0.0, message: "Validating audio file...")
            try await prepareAudio(from: audioURL)
            updateProgress(stage: .preparing, stageProgress: 1.0, message: "Audio validated")
            
            if cancellationRequested { throw TranscriptGenerationError.cancelled }
            
            // Stage 2: Transcription via server-side Whisper
            updateProgress(stage: .transcribing, stageProgress: 0.0, message: "Uploading audio for transcription...")
            
            let (transcriptText, segments) = try await transcribeWithWhisper(
                from: audioURL,
                language: language,
                meetingType: meetingType
            )
            
            updateProgress(stage: .transcribing, stageProgress: 1.0, message: "Transcription complete")
            
            if cancellationRequested { throw TranscriptGenerationError.cancelled }
            
            // Stage 3: Process & Format
            updateProgress(stage: .processingAI, stageProgress: 0.0, message: "Formatting transcript...")
            
            let processedText = processTranscript(transcriptText)
            
            updateProgress(stage: .processingAI, stageProgress: 1.0, message: "Processing complete")
            
            if cancellationRequested { throw TranscriptGenerationError.cancelled }
            
            // Stage 4: Finalize
            updateProgress(stage: .finalizing, stageProgress: 0.5, message: "Creating final transcript...")
            
            let transcript = GeneratedTranscript(
                rawText: transcriptText,
                processedText: processedText,
                segments: segments,
                speakerBlocks: [],
                duration: audioDuration,
                wordCount: processedText.split(separator: " ").count,
                speakerCount: 0,
                speakers: [],
                isDiarized: false,
                generatedAt: Date()
            )
            
            updateProgress(stage: .complete, stageProgress: 1.0, message: "Transcript ready!")
            generatedTranscript = transcript
            
            return transcript
            
        } catch let error as TranscriptGenerationError {
            updateProgress(stage: .failed, stageProgress: 0.0, message: error.localizedDescription)
            self.error = error
            throw error
        } catch {
            let genError = TranscriptGenerationError.transcriptionFailed(error.localizedDescription)
            updateProgress(stage: .failed, stageProgress: 0.0, message: error.localizedDescription)
            self.error = genError
            throw genError
        }
    }
    
    /// Cancel ongoing transcript generation
    func cancel() {
        cancellationRequested = true
        currentTask?.cancel()
    }
    
    /// Reset service state
    func reset() {
        cancel()
        isGenerating = false
        progress = .initial
        generatedTranscript = nil
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(stage: TranscriptGenerationStage, stageProgress: Double, message: String) {
        let stageWeights: [TranscriptGenerationStage: (start: Double, weight: Double)] = [
            .preparing: (0.0, 0.05),
            .diarizing: (0.05, 0.40),
            .transcribing: (0.45, 0.35),
            .processingAI: (0.80, 0.10),
            .finalizing: (0.90, 0.10),
            .complete: (1.0, 0.0),
            .failed: (0.0, 0.0)
        ]
        
        let stageInfo = stageWeights[stage] ?? (0.0, 0.0)
        let overallProgress = stageInfo.start + (stageInfo.weight * stageProgress)
        
        var estimatedTime: TimeInterval? = nil
        if stage == .transcribing && stageProgress > 0.1 {
            let elapsed = Date().timeIntervalSince(transcriptionStartTime ?? Date())
            let totalEstimated = elapsed / stageProgress
            estimatedTime = max(0, totalEstimated - elapsed)
        }
        
        progress = TranscriptProgress(
            stage: stage,
            overallProgress: min(1.0, overallProgress),
            stageProgress: stageProgress,
            statusMessage: message,
            estimatedTimeRemaining: estimatedTime
        )
    }
    
    private func prepareAudio(from url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptGenerationError.audioFileNotFound
        }
        
        // Get file size
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        print("============================================")
        print("📼 PREPARING AUDIO FILE")
        print("============================================")
        print("📁 Path: \(url.path)")
        print("📁 File size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1024.0 / 1024.0))MB)")
        
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            audioDuration = CMTimeGetSeconds(duration)
            let minutes = Int(audioDuration) / 60
            let seconds = Int(audioDuration) % 60
            print("⏱️ Audio duration: \(String(format: "%.1f", audioDuration)) seconds (\(minutes)m \(seconds)s)")
        } catch {
            print("⚠️ Could not load audio duration: \(error)")
            audioDuration = 0
        }
        
        do {
            let tracks = try await asset.load(.tracks)
            print("🎵 Audio tracks: \(tracks.count)")
            for (index, track) in tracks.enumerated() {
                print("   Track \(index): \(track.mediaType.rawValue)")
            }
            guard !tracks.isEmpty else {
                throw TranscriptGenerationError.invalidAudioFormat
            }
        } catch {
            throw TranscriptGenerationError.invalidAudioFormat
        }
        print("============================================")
    }
    
    // MARK: - Enterprise Speaker Diarization
    
    /// Transcribe with Pyannote+Whisper speaker diarization via backend
    /// Returns raw JSON dict with blocks, speakers, durations
    private func transcribeWithDiarization(
        from url: URL,
        language: SupportedLanguage?,
        meetingType: String?
    ) async throws -> [String: Any] {
        
        print("============================================")
        print("🔊 STARTING SPEAKER DIARIZATION (Pyannote + Whisper)")
        print("============================================")
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw TranscriptGenerationError.audioFileNotFound
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
        
        let languageCode = language?.id.components(separatedBy: "-").first ?? "en"
        
        // ── Step 1: Upload audio and get job ID ──
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: backendDiarizationURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes for upload only
        
        // Add Firebase auth token
        let authToken = try await FirebaseAuthService.shared.getIDToken()
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Read audio file
        updateProgress(stage: .diarizing, stageProgress: 0.05, message: "Reading audio file...")
        let audioData = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let mimeType = getMimeType(for: url)
        
        print("📤 Audio: \(audioData.count) bytes (\(String(format: "%.2f", fileSizeMB))MB)")
        
        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(languageCode)\r\n".data(using: .utf8)!)
        
        if let meetingType = meetingType {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"meetingType\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(meetingType)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        updateProgress(stage: .diarizing, stageProgress: 0.1, message: "Uploading \(String(format: "%.1f", fileSizeMB))MB for analysis...")
        
        let uploadConfig = URLSessionConfiguration.default
        uploadConfig.timeoutIntervalForRequest = 120
        uploadConfig.timeoutIntervalForResource = 120
        let uploadSession = URLSession(configuration: uploadConfig)
        
        print("📡 Submitting to: \(backendDiarizationURL)")
        
        let (submitData, submitResponse) = try await uploadSession.data(for: request)
        
        guard let submitHttp = submitResponse as? HTTPURLResponse else {
            throw TranscriptGenerationError.transcriptionFailed("Invalid response from server")
        }
        
        print("📊 Submit HTTP Status: \(submitHttp.statusCode)")
        
        guard submitHttp.statusCode == 200 else {
            if submitHttp.statusCode == 401 {
                throw TranscriptGenerationError.transcriptionFailed("Authentication required. Please log in again.")
            } else if submitHttp.statusCode == 503 {
                let errJson = try? JSONSerialization.jsonObject(with: submitData) as? [String: Any]
                let errorMsg = errJson?["error"] as? String ?? "Speaker diarization service is not available"
                throw TranscriptGenerationError.transcriptionFailed(errorMsg)
            }
            let errJson = try? JSONSerialization.jsonObject(with: submitData) as? [String: Any]
            let errorMsg = errJson?["error"] as? String ?? "Failed to submit diarization (HTTP \(submitHttp.statusCode))"
            throw TranscriptGenerationError.transcriptionFailed(errorMsg)
        }
        
        guard let submitJson = try JSONSerialization.jsonObject(with: submitData) as? [String: Any],
              let jobId = submitJson["jobId"] as? String else {
            throw TranscriptGenerationError.transcriptionFailed("Server did not return a job ID")
        }
        
        print("✅ Job submitted: \(jobId)")
        updateProgress(stage: .diarizing, stageProgress: 0.2, message: "Processing audio (this may take several minutes)...")
        
        // ── Step 2: Poll for results ──
        let pollURL = "\(backendDiarizationURL)/jobs/\(jobId)"
        let pollInterval: TimeInterval = 5.0  // Poll every 5 seconds
        let maxPollTime: TimeInterval = 1800  // 30 minutes max
        let pollStart = Date()
        
        let pollConfig = URLSessionConfiguration.default
        pollConfig.timeoutIntervalForRequest = 15
        pollConfig.timeoutIntervalForResource = 15
        let pollSession = URLSession(configuration: pollConfig)
        
        while true {
            let elapsed = Date().timeIntervalSince(pollStart)
            if elapsed > maxPollTime {
                throw TranscriptGenerationError.transcriptionFailed("Diarization timed out after \(Int(maxPollTime/60)) minutes")
            }
            
            // Wait before polling
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            
            // Build poll request with fresh auth token
            var pollRequest = URLRequest(url: URL(string: pollURL)!)
            pollRequest.httpMethod = "GET"
            pollRequest.timeoutInterval = 15
            let freshToken = try await FirebaseAuthService.shared.getIDToken()
            pollRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
            
            let (pollData, pollResponse) = try await pollSession.data(for: pollRequest)
            
            guard let pollHttp = pollResponse as? HTTPURLResponse,
                  pollHttp.statusCode == 200,
                  let pollJson = try JSONSerialization.jsonObject(with: pollData) as? [String: Any],
                  let status = pollJson["status"] as? String else {
                // Non-200 or parse error — keep trying
                print("⚠️ Poll returned unexpected response, retrying...")
                continue
            }
            
            let progress = pollJson["progress"] as? String ?? ""
            let progressPct = min(0.2 + (elapsed / maxPollTime) * 0.7, 0.9) // Scale 0.2 → 0.9
            updateProgress(stage: .diarizing, stageProgress: progressPct, message: progress.isEmpty ? "Processing..." : progress)
            
            print("🔄 Job \(jobId): status=\(status) progress=\"\(progress)\" (\(Int(elapsed))s)")
            
            if status == "complete" {
                guard let result = pollJson["result"] as? [String: Any],
                      let success = result["success"] as? Bool, success else {
                    let errorMsg = (pollJson["result"] as? [String: Any])?["error"] as? String ?? "Diarization failed"
                    throw TranscriptGenerationError.transcriptionFailed(errorMsg)
                }
                
                let blockCount = (result["blocks"] as? [[String: Any]])?.count ?? 0
                let speakerCount = result["speakerCount"] as? Int ?? 0
                let totalWords = result["totalWords"] as? Int ?? 0
                let procTime = result["processingTimeSeconds"] as? Double ?? 0
                
                print("============================================")
                print("✅ DIARIZATION COMPLETE")
                print("============================================")
                print("📝 Blocks: \(blockCount)")
                print("🔊 Speakers: \(speakerCount)")
                print("📊 Words: \(totalWords)")
                print("⏱️ Processing: \(String(format: "%.1f", procTime))s")
                print("============================================")
                
                updateProgress(stage: .diarizing, stageProgress: 1.0, message: "\(speakerCount) speakers identified")
                
                return result
            }
            
            if status == "failed" {
                let errorMsg = (pollJson["result"] as? [String: Any])?["error"] as? String ?? "Diarization processing failed"
                print("❌ Job failed: \(errorMsg)")
                throw TranscriptGenerationError.transcriptionFailed(errorMsg)
            }
            
            // status == "processing" — continue polling
        }
    }
    
    /// Process diarization result into formatted text and speaker blocks
    private func processeDiarizedResult(_ result: [String: Any]) -> (String, [GeneratedTranscript.SpeakerBlock]) {
        guard let blocksArray = result["blocks"] as? [[String: Any]] else {
            return ("", [])
        }
        
        var speakerBlocks: [GeneratedTranscript.SpeakerBlock] = []
        var formattedLines: [String] = []
        
        for blockDict in blocksArray {
            let speaker = blockDict["speaker"] as? String ?? "Speaker"
            let content = blockDict["content"] as? String ?? ""
            let startTime = blockDict["startTime"] as? Double ?? 0.0
            let endTime = blockDict["endTime"] as? Double ?? 0.0
            let confidence = blockDict["confidence"] as? Double ?? 0.0
            let wordCount = blockDict["wordCount"] as? Int ?? content.split(separator: " ").count
            
            let block = GeneratedTranscript.SpeakerBlock(
                speaker: speaker,
                content: content,
                startTime: startTime,
                endTime: endTime,
                confidence: Float(confidence),
                wordCount: wordCount
            )
            speakerBlocks.append(block)
            
            // Format: [00:00] Speaker 1: content
            let timestamp = block.formattedStartTime
            formattedLines.append("[\(timestamp)] \(speaker):\n\(content)")
        }
        
        let processedText = formattedLines.joined(separator: "\n\n")
        return (processedText, speakerBlocks)
    }
    
    private func transcribeWithWhisper(
        from url: URL,
        language: SupportedLanguage?,
        meetingType: String?
    ) async throws -> (String, [GeneratedTranscript.TranscriptSegment]) {
        
        print("============================================")
        print("🚀 STARTING SERVER-SIDE WHISPER TRANSCRIPTION")
        print("============================================")
        
        // Verify the audio file exists and get its attributes
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw TranscriptGenerationError.audioFileNotFound
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
        
        print("📁 File path: \(url.path)")
        print("📁 File size on disk: \(fileSize) bytes (\(String(format: "%.2f", fileSizeMB))MB)")
        
        // Prepare the multipart form data request
        let languageCode = language?.id.components(separatedBy: "-").first ?? "en"
        let meetingTypeParam = meetingType ?? "general"
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: backendTranscriptionURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "language", value: languageCode),
            URLQueryItem(name: "meetingType", value: meetingTypeParam)
        ]
        
        guard let requestURL = urlComponents.url else {
            throw TranscriptGenerationError.transcriptionFailed("Invalid URL")
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Set extended timeout for long audio files (15 minutes)
        request.timeoutInterval = 900
        
        // Add Firebase auth token
        do {
            let token = try await FirebaseAuthService.shared.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("⚠️ Failed to get auth token: \(error)")
            throw TranscriptGenerationError.transcriptionFailed("Authentication required. Please log in again.")
        }
        
        // Read audio file - read ALL data
        print("📖 Reading audio file into memory...")
        let audioData = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let mimeType = getMimeType(for: url)
        let loadedSizeMB = Double(audioData.count) / 1024.0 / 1024.0
        
        print("📤 Audio data loaded: \(audioData.count) bytes (\(String(format: "%.2f", loadedSizeMB))MB)")
        
        // Verify data integrity
        if audioData.count != Int(fileSize) {
            print("⚠️ WARNING: Data size mismatch! Disk: \(fileSize), Loaded: \(audioData.count)")
        } else {
            print("✅ Data size verified: matches disk size")
        }
        
        // Build multipart body
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        print("📦 Multipart body size: \(body.count) bytes")
        
        request.httpBody = body
        
        // Update progress
        updateProgress(stage: .transcribing, stageProgress: 0.1, message: "Uploading \(String(format: "%.1f", loadedSizeMB))MB to server...")
        
        // Create a custom URLSession with extended timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 900 // 15 minutes
        config.timeoutIntervalForResource = 900
        let session = URLSession(configuration: config)
        
        print("📡 Sending request to: \(requestURL.absoluteString)")
        
        // Perform request
        updateProgress(stage: .transcribing, stageProgress: 0.2, message: "Processing audio with System...")
        let (data, response) = try await session.data(for: request)
        
        print("📥 Response received: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptGenerationError.transcriptionFailed("Invalid response")
        }
        
        print("📊 HTTP Status: \(httpResponse.statusCode)")
        
        updateProgress(stage: .transcribing, stageProgress: 0.9, message: "Finalizing transcription...")
        
        // Parse response
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let success = json?["success"] as? Bool, success,
               let transcript = json?["transcript"] as? String {
                
                let duration = json?["duration"] as? Double ?? audioDuration
                
                // Detailed logging for debugging
                print("============================================")
                print("✅ SERVER TRANSCRIPTION RESPONSE")
                print("============================================")
                print("📝 Transcript length: \(transcript.count) characters")
                print("📝 Word count: \(transcript.split(separator: " ").count) words")
                print("⏱️ Duration from server: \(String(format: "%.1f", duration))s")
                print("⏱️ Local audio duration: \(String(format: "%.1f", audioDuration))s")
                
                // Log first and last 200 characters
                if transcript.count > 400 {
                    print("📄 Start: \(String(transcript.prefix(200)))...")
                    print("📄 End: ...\(String(transcript.suffix(200)))")
                } else {
                    print("📄 Full: \(transcript)")
                }
                print("============================================")
                
                // Create basic segment from full transcript
                let segments = [GeneratedTranscript.TranscriptSegment(
                    text: transcript,
                    startTime: 0,
                    endTime: audioDuration,
                    confidence: 0.95,
                    speakerId: nil
                )]
                
                return (transcript, segments)
            } else {
                let errorMsg = json?["error"] as? String ?? "Unknown error"
                throw TranscriptGenerationError.transcriptionFailed(errorMsg)
            }
        } else if httpResponse.statusCode == 401 {
            throw TranscriptGenerationError.transcriptionFailed("Authentication required. Please log in again.")
        } else if httpResponse.statusCode == 503 {
            throw TranscriptGenerationError.transcriptionFailed("Transcription service unavailable. Please try again later.")
        } else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMsg = json?["error"] as? String ?? "Server error (\(httpResponse.statusCode))"
            throw TranscriptGenerationError.transcriptionFailed(errorMsg)
        }
    }
    
    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "audio/mpeg"
        }
    }
    
    // MARK: - Text Processing (Local Enhancement)
    
    private func processTranscript(_ text: String) -> String {
        var result = text
        
        // Clean up whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize "I"
        result = result.replacingOccurrences(of: " i ", with: " I ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: " i'", with: " I'", options: .caseInsensitive)
        
        // Fix double spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Ensure proper spacing after punctuation
        result = result.replacingOccurrences(of: "([.!?,])([A-Za-z])", with: "$1 $2", options: .regularExpression)
        
        // Format into paragraphs for long transcripts
        if result.count > 500 {
            result = formatIntoParagraphs(result)
        }
        
        return result
    }
    
    private func formatIntoParagraphs(_ text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
        guard sentences.count > 4 else { return text }
        
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            currentParagraph.append(trimmed)
            
            if currentParagraph.count >= 4 || index == sentences.count - 1 {
                var paragraph = currentParagraph.joined(separator: ". ")
                if !paragraph.hasSuffix(".") {
                    paragraph += "."
                }
                paragraphs.append(paragraph)
                currentParagraph = []
            }
        }
        
        if !currentParagraph.isEmpty {
            var paragraph = currentParagraph.joined(separator: ". ")
            if !paragraph.hasSuffix(".") {
                paragraph += "."
            }
            paragraphs.append(paragraph)
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
}

// MARK: - Preview Support
extension TranscriptGenerationService {
    static var preview: TranscriptGenerationService {
        let service = TranscriptGenerationService.shared
        service.progress = TranscriptProgress(
            stage: .transcribing,
            overallProgress: 0.45,
            stageProgress: 0.65,
            statusMessage: "Uploading... 65%",
            estimatedTimeRemaining: 30
        )
        return service
    }
}
