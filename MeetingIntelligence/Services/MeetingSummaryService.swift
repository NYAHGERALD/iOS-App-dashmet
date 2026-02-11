//
//  MeetingSummaryService.swift
//  MeetingIntelligence
//
//  Professional AI Summary Generation with Text-to-Speech
//  Uses GPT-4o for intelligent narrative summaries and OpenAI TTS for voice
//

import Foundation
import AVFoundation
import Combine
import FirebaseAuth

// MARK: - Models

/// Input for generating a narrative summary
struct NarrativeSummaryRequest: Codable {
    let meetingTitle: String
    let meetingType: String
    let meetingDate: String
    let meetingTime: String
    let duration: Int?
    let transcript: String
    let language: String?
    let participantCount: Int?
}

/// AI-generated narrative summary
struct NarrativeSummary: Codable {
    let narrative: String
    let briefSummary: String
    let objectives: [String]
    let keyDiscussions: [String]
    let takeaways: [String]
    let tone: String
    let generatedAt: String
}

/// Response from narrative summary API
struct NarrativeSummaryResponse: Codable {
    let success: Bool
    let summary: NarrativeSummary?
    let error: String?
}

/// Request for TTS audio generation
struct TTSRequest: Codable {
    let text: String
    let voice: String
    let speed: Double
}

// MARK: - Voice Options
enum TTSVoice: String, CaseIterable {
    case onyx = "onyx"      // Deep, authoritative male voice (recommended)
    case echo = "echo"      // Warm, engaging male voice
    case alloy = "alloy"    // Neutral, balanced voice
    case fable = "fable"    // Expressive, storytelling voice
    case nova = "nova"      // Warm female voice
    case shimmer = "shimmer" // Clear female voice
    
    var displayName: String {
        switch self {
        case .onyx: return "Onyx (Professional Male)"
        case .echo: return "Echo (Warm Male)"
        case .alloy: return "Alloy (Neutral)"
        case .fable: return "Fable (Storytelling)"
        case .nova: return "Nova (Warm Female)"
        case .shimmer: return "Shimmer (Clear Female)"
        }
    }
    
    var icon: String {
        switch self {
        case .onyx, .echo: return "person.wave.2"
        case .nova, .shimmer: return "person.wave.2.fill"
        case .alloy, .fable: return "waveform"
        }
    }
}

// MARK: - Meeting Summary Service

@MainActor
class MeetingSummaryService: ObservableObject {
    static let shared = MeetingSummaryService()
    
    @Published var isGeneratingSummary = false
    @Published var isGeneratingAudio = false
    @Published var currentSummary: NarrativeSummary?
    @Published var audioData: Data?
    @Published var error: String?
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    private init() {}
    
    // MARK: - Generate Narrative Summary
    
    /// Generate an intelligent narrative summary of a meeting
    func generateNarrativeSummary(
        meetingTitle: String,
        meetingType: String,
        meetingDate: Date,
        duration: Int?,
        transcript: String,
        language: String = "English",
        participantCount: Int? = nil
    ) async throws -> NarrativeSummary {
        isGeneratingSummary = true
        error = nil
        
        defer { isGeneratingSummary = false }
        
        // Get auth token
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        // Format date and time
        let dateFormatter = ISO8601DateFormatter()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        let request = NarrativeSummaryRequest(
            meetingTitle: meetingTitle,
            meetingType: meetingType,
            meetingDate: dateFormatter.string(from: meetingDate),
            meetingTime: timeFormatter.string(from: meetingDate),
            duration: duration,
            transcript: transcript,
            language: language,
            participantCount: participantCount
        )
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/transcripts/narrative-summary") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        print("🧠 Generating narrative summary for: \(meetingTitle)")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(NarrativeSummaryResponse.self, from: data) {
                throw SummaryError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        let summaryResponse = try JSONDecoder().decode(NarrativeSummaryResponse.self, from: data)
        
        guard let summary = summaryResponse.summary else {
            throw SummaryError.noSummary
        }
        
        currentSummary = summary
        print("✅ Narrative summary generated: \(summary.narrative.prefix(100))...")
        
        return summary
    }
    
    // MARK: - Generate TTS Audio
    
    /// Convert narrative text to speech using OpenAI TTS
    func generateAudio(
        text: String,
        voice: TTSVoice = .onyx,
        speed: Double = 1.0
    ) async throws -> Data {
        isGeneratingAudio = true
        error = nil
        
        defer { isGeneratingAudio = false }
        
        // Get auth token
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        let request = TTSRequest(text: text, voice: voice.rawValue, speed: speed)
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/transcripts/summary-audio") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 180 // TTS can take longer
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        print("🎙️ Generating TTS audio with voice: \(voice.displayName)")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        // Check if we got audio or an error
        if httpResponse.statusCode != 200 {
            // Try to parse error
            if let errorString = String(data: data, encoding: .utf8) {
                throw SummaryError.serverError(errorString)
            }
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        // Verify it's audio data
        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("audio") else {
            throw SummaryError.invalidAudioData
        }
        
        audioData = data
        print("✅ TTS audio generated: \(data.count) bytes")
        
        return data
    }
    
    // MARK: - Generate Both
    
    /// Generate narrative summary and TTS audio in sequence
    func generateSummaryWithAudio(
        meetingTitle: String,
        meetingType: String,
        meetingDate: Date,
        duration: Int?,
        transcript: String,
        voice: TTSVoice = .onyx,
        speed: Double = 1.0
    ) async throws -> (summary: NarrativeSummary, audioData: Data) {
        // Generate summary first
        let summary = try await generateNarrativeSummary(
            meetingTitle: meetingTitle,
            meetingType: meetingType,
            meetingDate: meetingDate,
            duration: duration,
            transcript: transcript
        )
        
        // Then generate audio from narrative
        let audio = try await generateAudio(text: summary.narrative, voice: voice, speed: speed)
        
        return (summary, audio)
    }
    
    // MARK: - Clear
    
    func clear() {
        currentSummary = nil
        audioData = nil
        error = nil
    }
    
    // MARK: - Save AI Summary to Database
    
    /// Save the AI summary to the backend database and upload audio to Firebase Storage
    /// - Parameters:
    ///   - meetingId: The meeting ID
    ///   - summary: The generated narrative summary
    ///   - audioData: Optional TTS audio data
    ///   - voice: The voice used for TTS
    /// - Returns: The saved summary response
    func saveAISummaryToDatabase(
        meetingId: String,
        summary: NarrativeSummary,
        audioData: Data?,
        voice: TTSVoice = .onyx
    ) async throws -> SavedAISummaryResponse {
        print("💾 Saving AI summary to database for meeting: \(meetingId)")
        
        // Get auth token and user ID
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        guard let userId = FirebaseAuthService.shared.currentUser?.uid else {
            throw SummaryError.unauthorized
        }
        
        // Step 1: Upload audio to Firebase Storage if we have audio data
        var audioUrl: String?
        var audioDuration: Int?
        
        if let data = audioData {
            print("📤 Uploading AI audio to Firebase Storage...")
            
            do {
                audioUrl = try await FirebaseStorageService.shared.uploadAISummaryAudio(
                    meetingId: meetingId,
                    audioData: data,
                    userId: userId,
                    voice: voice.rawValue
                )
                
                // Estimate duration (MP3 at 128kbps ≈ 16KB per second)
                audioDuration = max(1, data.count / 16000)
                
                print("✅ AI audio uploaded: \(audioUrl ?? "nil")")
            } catch {
                print("⚠️ Audio upload failed, continuing with summary save: \(error.localizedDescription)")
                // Continue without audio - summary is more important
            }
        }
        
        // Step 2: Save summary to backend database
        print("📝 Saving summary to backend database...")
        
        let saveRequest = SaveAISummaryRequest(
            meetingId: meetingId,
            narrative: summary.narrative,
            briefSummary: summary.briefSummary,
            tone: summary.tone,
            objectives: summary.objectives,
            keyDiscussions: summary.keyDiscussions,
            takeaways: summary.takeaways,
            audioUrl: audioUrl,
            audioVoice: voice.rawValue,
            audioDuration: audioDuration
        )
        
        guard let url = URL(string: "\(baseURL)/transcripts/save-ai-summary") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(saveRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Save failed: \(errorString)")
            }
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        let saveResponse = try JSONDecoder().decode(SaveAISummaryAPIResponse.self, from: data)
        
        guard let savedSummary = saveResponse.summary else {
            throw SummaryError.serverError("No summary in response")
        }
        
        print("✅ AI summary saved to database. ID: \(savedSummary.id)")
        
        return savedSummary
    }
    
    // MARK: - Fetch AI Summary from Database
    
    /// Fetch a previously saved AI summary from the backend database
    func fetchAISummary(meetingId: String) async throws -> SavedAISummaryResponse? {
        print("🔍 Fetching AI summary for meeting: \(meetingId)")
        
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/transcripts/ai-summary/\(meetingId)") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        // 404 means no summary found - not an error
        if httpResponse.statusCode == 404 {
            print("ℹ️ No AI summary found for meeting")
            return nil
        }
        
        if httpResponse.statusCode != 200 {
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        let fetchResponse = try JSONDecoder().decode(SaveAISummaryAPIResponse.self, from: data)
        
        print("✅ AI summary fetched from database")
        return fetchResponse.summary
    }
    
    // MARK: - Save Processed Transcript to Database
    
    /// Save the processed transcript to the backend database
    func saveProcessedTranscriptToDatabase(
        meetingId: String,
        rawTranscript: String,
        processedTranscript: String,
        wordCount: Int?,
        duration: Int?
    ) async throws -> SavedTranscriptResponse {
        print("💾 Saving processed transcript to database for meeting: \(meetingId)")
        
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        let saveRequest = SaveProcessedTranscriptRequest(
            meetingId: meetingId,
            rawTranscript: rawTranscript,
            processedTranscript: processedTranscript,
            wordCount: wordCount,
            duration: duration
        )
        
        guard let url = URL(string: "\(baseURL)/transcripts/save-processed") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(saveRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Save transcript failed: \(errorString)")
            }
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        let saveResponse = try JSONDecoder().decode(SaveTranscriptAPIResponse.self, from: data)
        
        guard let savedTranscript = saveResponse.transcript else {
            throw SummaryError.serverError("No transcript in response")
        }
        
        print("✅ Processed transcript saved to database. ID: \(savedTranscript.id)")
        
        return savedTranscript
    }
    
    // MARK: - Fetch Processed Transcript from Database
    
    /// Fetch a previously saved processed transcript from the backend database
    func fetchProcessedTranscript(meetingId: String) async throws -> SavedTranscriptResponse? {
        print("🔍 Fetching processed transcript for meeting: \(meetingId)")
        
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw SummaryError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/transcripts/processed/\(meetingId)") else {
            throw SummaryError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }
        
        // 404 means no transcript found - not an error
        if httpResponse.statusCode == 404 {
            print("ℹ️ No processed transcript found for meeting")
            return nil
        }
        
        if httpResponse.statusCode != 200 {
            throw SummaryError.serverError("Status code: \(httpResponse.statusCode)")
        }
        
        let fetchResponse = try JSONDecoder().decode(SaveTranscriptAPIResponse.self, from: data)
        
        print("✅ Processed transcript fetched from database")
        return fetchResponse.transcript
    }
}

// MARK: - Save Request/Response Models

struct SaveAISummaryRequest: Codable {
    let meetingId: String
    let narrative: String
    let briefSummary: String
    let tone: String
    let objectives: [String]
    let keyDiscussions: [String]
    let takeaways: [String]
    let audioUrl: String?
    let audioVoice: String?
    let audioDuration: Int?
}

struct SavedAISummaryResponse: Codable {
    let id: String
    let meetingId: String
    let narrative: String?
    let briefSummary: String?
    let tone: String?
    let objectives: [String]?
    let keyDiscussions: [String]?
    let takeaways: [String]?
    let audioUrl: String?
    let audioVoice: String?
    let audioDuration: Int?
    let generatedAt: String?
}

struct SaveAISummaryAPIResponse: Codable {
    let success: Bool
    let summary: SavedAISummaryResponse?
    let error: String?
}

// MARK: - Processed Transcript Models

struct SaveProcessedTranscriptRequest: Codable {
    let meetingId: String
    let rawTranscript: String
    let processedTranscript: String
    let wordCount: Int?
    let duration: Int?
}

struct SavedTranscriptResponse: Codable {
    let id: String
    let meetingId: String
    let rawTranscript: String?
    let processedTranscript: String?
    let wordCount: Int?
    let duration: Int?
    let savedAt: String?
}

struct SaveTranscriptAPIResponse: Codable {
    let success: Bool
    let transcript: SavedTranscriptResponse?
    let error: String?
}

// MARK: - Errors

enum SummaryError: LocalizedError {
    case unauthorized
    case invalidURL
    case invalidResponse
    case serverError(String)
    case noSummary
    case invalidAudioData
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please sign in."
        case .invalidURL:
            return "Invalid server URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let message):
            return "Server error: \(message)"
        case .noSummary:
            return "No summary was generated."
        case .invalidAudioData:
            return "Invalid audio data received."
        }
    }
}
