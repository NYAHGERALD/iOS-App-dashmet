//
//  WhisperTranscriptionService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Transcription using OpenAI Whisper API
//  Provides high-accuracy speech-to-text with speaker awareness
//

import Foundation
import AVFoundation
import Combine

// MARK: - Whisper API Response Models
struct WhisperTranscriptionResponse: Codable {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [WhisperSegment]?
    let words: [WhisperWord]?
}

struct WhisperSegment: Codable {
    let id: Int
    let seek: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]
    let temperature: Double
    let avgLogprob: Double
    let compressionRatio: Double
    let noSpeechProb: Double
    
    enum CodingKeys: String, CodingKey {
        case id, seek, start, end, text, tokens, temperature
        case avgLogprob = "avg_logprob"
        case compressionRatio = "compression_ratio"
        case noSpeechProb = "no_speech_prob"
    }
}

struct WhisperWord: Codable {
    let word: String
    let start: Double
    let end: Double
}

struct WhisperErrorResponse: Codable {
    let error: WhisperError
}

struct WhisperError: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Transcription Configuration
struct WhisperConfig: Sendable {
    let model: WhisperModel
    let language: String?
    let prompt: String?
    let temperature: Double
    let responseFormat: ResponseFormat
    let timestampGranularities: [TimestampGranularity]
    
    enum WhisperModel: String, Sendable {
        case whisper1 = "whisper-1"
        // Future models can be added here
    }
    
    enum ResponseFormat: String, Sendable {
        case json = "json"
        case verboseJson = "verbose_json"
        case text = "text"
        case srt = "srt"
        case vtt = "vtt"
    }
    
    enum TimestampGranularity: String, Sendable {
        case word = "word"
        case segment = "segment"
    }
    
    nonisolated static var `default`: WhisperConfig {
        WhisperConfig(
            model: .whisper1,
            language: nil, // Auto-detect
            prompt: "This is a professional meeting recording. Please transcribe accurately with proper punctuation and formatting.",
            temperature: 0.0, // Most deterministic
            responseFormat: .verboseJson,
            timestampGranularities: [.segment, .word]
        )
    }
    
    nonisolated static func forMeeting(type: String? = nil, language: String? = nil) -> WhisperConfig {
        var prompt = "This is a professional meeting recording with multiple speakers. "
        
        if let type = type {
            prompt += "Meeting type: \(type). "
        }
        
        prompt += "Please transcribe accurately with proper punctuation, speaker attribution when possible, and professional formatting."
        
        return WhisperConfig(
            model: .whisper1,
            language: language,
            prompt: prompt,
            temperature: 0.0,
            responseFormat: .verboseJson,
            timestampGranularities: [.segment, .word]
        )
    }
}

// MARK: - Whisper Transcription Service
@MainActor
class WhisperTranscriptionService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = WhisperTranscriptionService()
    
    // MARK: - API Configuration
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private var apiKey: String {
        // In production, this should be fetched securely from your backend
        // NEVER hardcode API keys in production apps
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    // MARK: - Published Properties
    @Published var isTranscribing: Bool = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var error: Error?
    
    // MARK: - Private Properties
    private var uploadTask: URLSessionUploadTask?
    private var progressObservation: NSKeyValueObservation?
    
    // File size limits
    private let maxFileSizeMB: Double = 25.0 // Whisper API limit
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if API key is configured
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    /// Set API key (for testing or manual configuration)
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }
    
    /// Transcribe audio file using OpenAI Whisper API
    /// - Parameters:
    ///   - audioURL: Local URL to the audio file
    ///   - config: Whisper configuration options
    /// - Returns: Transcription response with text and optional segments
    func transcribe(audioURL: URL, config: WhisperConfig = .default) async throws -> WhisperTranscriptionResponse {
        guard isConfigured else {
            throw WhisperTranscriptionError.apiKeyMissing
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperTranscriptionError.fileNotFound
        }
        
        // Reset state
        isTranscribing = true
        progress = 0.0
        error = nil
        statusMessage = "Preparing audio file..."
        
        defer {
            isTranscribing = false
        }
        
        do {
            // Step 1: Prepare and validate audio file
            progress = 0.05
            statusMessage = "Validating audio..."
            let audioData = try await prepareAudioFile(at: audioURL)
            
            // Step 2: Upload and transcribe
            progress = 0.1
            statusMessage = "Uploading to Whisper API..."
            let response = try await uploadAndTranscribe(audioData: audioData, originalURL: audioURL, config: config)
            
            progress = 1.0
            statusMessage = "Transcription complete!"
            
            return response
            
        } catch {
            self.error = error
            statusMessage = "Transcription failed"
            throw error
        }
    }
    
    /// Cancel ongoing transcription
    func cancel() {
        uploadTask?.cancel()
        uploadTask = nil
        isTranscribing = false
        statusMessage = "Cancelled"
    }
    
    // MARK: - Private Methods
    
    private func prepareAudioFile(at url: URL) async throws -> Data {
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Double ?? 0
        let fileSizeMB = fileSize / (1024 * 1024)
        
        print("📁 Audio file size: \(String(format: "%.2f", fileSizeMB)) MB")
        
        // Check file size limit
        if fileSizeMB > maxFileSizeMB {
            // Need to compress or split the file
            print("⚠️ File too large, compressing...")
            statusMessage = "Compressing audio..."
            return try await compressAudioFile(at: url)
        }
        
        // Check if format is supported (mp3, mp4, mpeg, mpga, m4a, wav, webm)
        let supportedExtensions = ["mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm", "ogg", "flac"]
        let fileExtension = url.pathExtension.lowercased()
        
        if !supportedExtensions.contains(fileExtension) {
            print("⚠️ Unsupported format, converting...")
            statusMessage = "Converting audio format..."
            return try await convertAudioToM4A(at: url)
        }
        
        return try Data(contentsOf: url)
    }
    
    private func compressAudioFile(at url: URL) async throws -> Data {
        // Convert to compressed m4a with lower bitrate
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        let asset = AVURLAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw WhisperTranscriptionError.conversionFailed
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .spectral
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw WhisperTranscriptionError.conversionFailed
        }
        
        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        
        return data
    }
    
    private func convertAudioToM4A(at url: URL) async throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        let asset = AVURLAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw WhisperTranscriptionError.conversionFailed
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw WhisperTranscriptionError.conversionFailed
        }
        
        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        
        return data
    }
    
    private func uploadAndTranscribe(audioData: Data, originalURL: URL, config: WhisperConfig) async throws -> WhisperTranscriptionResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file
        let filename = originalURL.lastPathComponent
        let mimeType = mimeTypeForExtension(originalURL.pathExtension)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.model.rawValue)\r\n".data(using: .utf8)!)
        
        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.responseFormat.rawValue)\r\n".data(using: .utf8)!)
        
        // Add language if specified
        if let language = config.language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }
        
        // Add prompt if specified
        if let prompt = config.prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }
        
        // Add temperature
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.temperature)\r\n".data(using: .utf8)!)
        
        // Add timestamp granularities for verbose_json
        if config.responseFormat == .verboseJson {
            for granularity in config.timestampGranularities {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(granularity.rawValue)\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Perform upload with progress tracking
        let session = URLSession.shared
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: body) { [weak self] data, response, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: WhisperTranscriptionError.networkError(error.localizedDescription))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: WhisperTranscriptionError.invalidResponse)
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: WhisperTranscriptionError.noData)
                        return
                    }
                    
                    // Check for API errors
                    if httpResponse.statusCode != 200 {
                        if let errorResponse = try? JSONDecoder().decode(WhisperErrorResponse.self, from: data) {
                            continuation.resume(throwing: WhisperTranscriptionError.apiError(errorResponse.error.message))
                            return
                        }
                        continuation.resume(throwing: WhisperTranscriptionError.httpError(httpResponse.statusCode))
                        return
                    }
                    
                    // Parse response
                    do {
                        let transcription = try JSONDecoder().decode(WhisperTranscriptionResponse.self, from: data)
                        self?.progress = 0.95
                        self?.statusMessage = "Processing response..."
                        continuation.resume(returning: transcription)
                    } catch {
                        print("❌ JSON decode error: \(error)")
                        // Try to get raw text if verbose_json parsing fails
                        if let text = String(data: data, encoding: .utf8) {
                            let simpleResponse = WhisperTranscriptionResponse(
                                text: text,
                                language: nil,
                                duration: nil,
                                segments: nil,
                                words: nil
                            )
                            continuation.resume(returning: simpleResponse)
                        } else {
                            continuation.resume(throwing: WhisperTranscriptionError.decodingError(error.localizedDescription))
                        }
                    }
                }
            }
            
            // Track upload progress
            self.uploadTask = task
            self.progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    // Map upload progress to 10-80% of total progress
                    self?.progress = 0.1 + (progress.fractionCompleted * 0.7)
                    if progress.fractionCompleted < 1.0 {
                        self?.statusMessage = "Uploading... \(Int(progress.fractionCompleted * 100))%"
                    } else {
                        self?.statusMessage = "Processing with System..."
                    }
                }
            }
            
            task.resume()
        }
    }
    
    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "mp3": return "audio/mpeg"
        case "mp4", "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "audio/mpeg"
        }
    }
}

// MARK: - Whisper Transcription Errors
enum WhisperTranscriptionError: Error, LocalizedError {
    case apiKeyMissing
    case fileNotFound
    case fileTooLarge
    case conversionFailed
    case networkError(String)
    case httpError(Int)
    case apiError(String)
    case invalidResponse
    case noData
    case decodingError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is not configured. Please add your API key in Settings."
        case .fileNotFound:
            return "Audio file not found."
        case .fileTooLarge:
            return "Audio file is too large. Maximum size is 25MB."
        case .conversionFailed:
            return "Failed to convert audio file to supported format."
        case .networkError(let message):
            return "Network error: \(message)"
        case .httpError(let code):
            return "Server error (HTTP \(code)). Please try again."
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        case .noData:
            return "No data received from server."
        case .decodingError(let message):
            return "Failed to process response: \(message)"
        case .cancelled:
            return "Transcription was cancelled."
        }
    }
}
