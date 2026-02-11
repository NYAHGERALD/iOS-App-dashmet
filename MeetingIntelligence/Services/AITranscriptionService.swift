//
//  AITranscriptionService.swift
//  MeetingIntelligence
//
//  AI-powered transcription correction using GPT-4o
//

import Foundation

// MARK: - AI Transcription Service
class AITranscriptionService {
    
    // MARK: - Singleton
    static let shared = AITranscriptionService()
    
    // MARK: - Properties
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    private let session: URLSession
    
    // Cache for recent corrections to avoid duplicate requests
    private var correctionCache: [String: String] = [:]
    private let cacheLimit = 100
    
    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Transcription Correction
    
    /// Correct transcription text using AI
    /// - Parameters:
    ///   - text: The raw transcribed text
    ///   - context: Previous transcript context for better understanding
    ///   - speakerLabel: Optional speaker label for context
    /// - Returns: Corrected text
    func correctTranscription(text: String, context: String? = nil, speakerLabel: String? = nil) async throws -> String {
        // Check cache first
        let cacheKey = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = correctionCache[cacheKey] {
            return cached
        }
        
        // Skip very short or empty text
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count > 3 else {
            return text
        }
        
        // Build request
        let url = URL(string: "\(baseURL)/mobile/ai/correct-transcription")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CorrectionRequest(
            text: text,
            context: context,
            speakerLabel: speakerLabel,
            language: "en"
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AITranscriptionError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let result = try JSONDecoder().decode(CorrectionResponse.self, from: data)
                
                // Cache the result
                if correctionCache.count >= cacheLimit {
                    correctionCache.removeAll()
                }
                correctionCache[cacheKey] = result.correctedText
                
                return result.correctedText
                
            case 429:
                // Rate limited - return original text
                print("⚠️ AI correction rate limited")
                return text
                
            default:
                // Try to parse error
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw AITranscriptionError.serverError(errorResponse.error)
                }
                throw AITranscriptionError.serverError("Status code: \(httpResponse.statusCode)")
            }
        } catch is URLError {
            // Network error - return original text silently
            return text
        }
    }
    
    /// Correct multiple segments in batch for efficiency
    func correctBatch(segments: [TranscriptionSegmentInput]) async throws -> [String: String] {
        guard !segments.isEmpty else { return [:] }
        
        let url = URL(string: "\(baseURL)/mobile/ai/correct-transcription-batch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = BatchCorrectionRequest(segments: segments)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AITranscriptionError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(BatchCorrectionResponse.self, from: data)
        return result.corrections
    }
    
    /// Identify likely speaker changes based on content analysis
    func analyzeSpeakerPatterns(transcript: [TranscriptionSegmentInput]) async throws -> [SpeakerAnalysisResult] {
        let url = URL(string: "\(baseURL)/mobile/ai/analyze-speakers")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SpeakerAnalysisRequest(segments: transcript)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AITranscriptionError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(SpeakerAnalysisResponse.self, from: data)
        return result.analysis
    }
    
    // MARK: - Cache Management
    func clearCache() {
        correctionCache.removeAll()
    }
}

// MARK: - Request/Response Models

struct CorrectionRequest: Codable {
    let text: String
    let context: String?
    let speakerLabel: String?
    let language: String
}

struct CorrectionResponse: Codable {
    let correctedText: String
    let wasModified: Bool
    let confidence: Float?
}

struct TranscriptionSegmentInput: Codable {
    let id: String
    let text: String
    let speakerId: Int?
    let timestamp: Double?
}

struct BatchCorrectionRequest: Codable {
    let segments: [TranscriptionSegmentInput]
}

struct BatchCorrectionResponse: Codable {
    let corrections: [String: String] // id -> corrected text
}

struct SpeakerAnalysisRequest: Codable {
    let segments: [TranscriptionSegmentInput]
}

struct SpeakerAnalysisResult: Codable {
    let segmentId: String
    let suggestedSpeakerId: Int
    let confidence: Float
    let reasoning: String?
}

struct SpeakerAnalysisResponse: Codable {
    let analysis: [SpeakerAnalysisResult]
    let suggestedSpeakerCount: Int
}

struct APIErrorResponse: Codable {
    let error: String
}

// MARK: - Errors
enum AITranscriptionError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from System"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError:
            return "Network error - please check your connection"
        }
    }
}
