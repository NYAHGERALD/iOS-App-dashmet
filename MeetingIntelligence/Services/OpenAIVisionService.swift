//
//  OpenAIVisionService.swift
//  MeetingIntelligence
//
//  OpenAI Vision API and Text-to-Speech Service (via Backend)
//

import Foundation

// MARK: - OpenAI Vision Service
class OpenAIVisionService {
    
    // MARK: - Configuration
    // Uses backend API which has OpenAI API key configured in environment
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    // MARK: - Analyze Frames with Vision API (via Backend)
    func analyzeFrames(frames: [CapturedFrame], question: String, topic: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/ai-vision/analyze") else {
            throw OpenAIError.invalidResponse
        }
        
        // Prepare frame data for backend
        let frameData = frames.map { frame in
            [
                "base64": frame.base64,
                "timestamp": ISO8601DateFormatter().string(from: frame.timestamp)
            ]
        }
        
        let requestBody: [String: Any] = [
            "frames": frameData,
            "question": question,
            "topic": topic
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // Vision API can take a while
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["response"] as? String else {
            throw OpenAIError.parseError
        }
        
        return content
    }
    
    // MARK: - Text-to-Speech (via Backend) - Female Voice
    func textToSpeech(text: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/ai-vision/tts") else {
            throw OpenAIError.ttsError
        }
        
        // Truncate text if too long (TTS has limits)
        let truncatedText = String(text.prefix(4000))
        
        let requestBody: [String: Any] = [
            "text": truncatedText,
            "voice": "nova",  // Confident female voice
            "speed": 1.0
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.ttsError
        }
        
        return data
    }
    
    // MARK: - Speech-to-Text using Whisper (via Backend)
    func transcribeAudio(audioData: Data) async throws -> String {
        guard let url = URL(string: "\(baseURL)/ai-vision/transcribe") else {
            throw OpenAIError.transcriptionError
        }
        
        // Convert audio data to base64
        let base64Audio = audioData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "audio": base64Audio
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.transcriptionError
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transcription = json["transcription"] as? String else {
            throw OpenAIError.parseError
        }
        
        return transcription
    }
    
    // MARK: - Session API Methods
    
    /// Save a session to the database
    func saveSession(_ session: VisionSession, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/ai-vision/sessions") else {
            throw OpenAIError.invalidResponse
        }
        
        // Convert session to dictionary
        let sessionDict: [String: Any] = [
            "id": session.id.uuidString,
            "topic": session.topic,
            "topicIcon": session.topicIcon,
            "messages": session.messages.map { msg in
                [
                    "id": msg.id.uuidString,
                    "role": msg.role.rawValue,
                    "content": msg.content,
                    "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
                ]
            },
            "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: session.updatedAt),
            "summary": session.summary as Any
        ]
        
        let requestBody: [String: Any] = [
            "userId": userId,
            "session": sessionDict
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    /// Fetch all sessions for a user from the database
    func fetchSessions(userId: String) async throws -> [VisionSession] {
        guard let url = URL(string: "\(baseURL)/ai-vision/sessions/\(userId)") else {
            throw OpenAIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionsArray = json["sessions"] as? [[String: Any]] else {
            throw OpenAIError.parseError
        }
        
        // Parse sessions
        let sessions = sessionsArray.compactMap { dict -> VisionSession? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let topic = dict["topic"] as? String,
                  let topicIcon = dict["topicIcon"] as? String,
                  let messagesArray = dict["messages"] as? [[String: Any]],
                  let createdAtString = dict["createdAt"] as? String,
                  let updatedAtString = dict["updatedAt"] as? String else {
                return nil
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            let updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
            let summary = dict["summary"] as? String
            
            let messages = messagesArray.compactMap { msgDict -> VisionMessage? in
                guard let msgIdString = msgDict["id"] as? String,
                      let msgId = UUID(uuidString: msgIdString),
                      let roleString = msgDict["role"] as? String,
                      let role = VisionMessage.MessageRole(rawValue: roleString),
                      let content = msgDict["content"] as? String,
                      let timestampString = msgDict["timestamp"] as? String else {
                    return nil
                }
                let timestamp = dateFormatter.date(from: timestampString) ?? Date()
                return VisionMessage(id: msgId, role: role, content: content, timestamp: timestamp)
            }
            
            return VisionSession(
                id: id,
                topic: topic,
                topicIcon: topicIcon,
                messages: messages,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isSaved: true,
                summary: summary
            )
        }
        
        return sessions
    }
    
    /// Delete a session from the database
    func deleteSession(sessionId: UUID, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/ai-vision/sessions/\(sessionId.uuidString)") else {
            throw OpenAIError.invalidResponse
        }
        
        let requestBody: [String: Any] = ["userId": userId]
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    /// Generate AI summary for a session
    func generateSummary(sessionId: UUID, userId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/ai-vision/sessions/\(sessionId.uuidString)/summarize") else {
            throw OpenAIError.invalidResponse
        }
        
        let requestBody: [String: Any] = ["userId": userId]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String else {
            throw OpenAIError.parseError
        }
        
        return summary
    }
}

// MARK: - OpenAI Errors
enum OpenAIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError
    case ttsError
    case transcriptionError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .parseError:
            return "Failed to parse API response"
        case .ttsError:
            return "Text-to-speech generation failed"
        case .transcriptionError:
            return "Speech transcription failed"
        }
    }
}
