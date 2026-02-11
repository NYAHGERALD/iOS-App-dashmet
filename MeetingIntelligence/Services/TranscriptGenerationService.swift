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
    case transcribing = "Transcribing speech..."
    case processingAI = "System processing..."
    case finalizing = "Finalizing transcript..."
    case complete = "Complete"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .preparing: return "waveform"
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
        case .transcribing: return 1
        case .processingAI: return 2
        case .finalizing: return 3
        case .complete: return 4
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
    let duration: TimeInterval
    let wordCount: Int
    let generatedAt: Date
    
    struct TranscriptSegment: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
        let speakerId: Int?
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
    
    // Backend API endpoint for server-side transcription
    private let backendTranscriptionURL = "https://dashmet-rca-api.onrender.com/api/transcripts/transcribe"
    
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
    
    /// Generate transcript from audio file using enterprise-grade Whisper API
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
            
            // Stage 2: Transcribe using Whisper API
            updateProgress(stage: .transcribing, stageProgress: 0.0, message: "Connecting to transcription service...")
            
            let (rawTranscript, segments) = try await transcribeWithWhisper(
                from: audioURL,
                language: language,
                meetingType: meetingType
            )
            
            updateProgress(stage: .transcribing, stageProgress: 1.0, message: "Transcription complete")
            
            if cancellationRequested { throw TranscriptGenerationError.cancelled }
            
            // Stage 3: AI Processing
            updateProgress(stage: .processingAI, stageProgress: 0.0, message: "Enhancing transcript...")
            let processedText = processTranscript(rawTranscript)
            updateProgress(stage: .processingAI, stageProgress: 1.0, message: "Enhancement complete")
            
            if cancellationRequested { throw TranscriptGenerationError.cancelled }
            
            // Stage 4: Finalize
            updateProgress(stage: .finalizing, stageProgress: 0.5, message: "Creating final transcript...")
            
            let transcript = GeneratedTranscript(
                rawText: rawTranscript,
                processedText: processedText,
                segments: segments,
                duration: audioDuration,
                wordCount: processedText.split(separator: " ").count,
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
            .transcribing: (0.05, 0.80),
            .processingAI: (0.85, 0.10),
            .finalizing: (0.95, 0.05),
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
