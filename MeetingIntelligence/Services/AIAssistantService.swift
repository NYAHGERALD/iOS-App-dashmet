//
//  AIAssistantService.swift
//  MeetingIntelligence
//
//  API service for the Workplace AI Assistant
//  Handles conversations, messages, TTS, and memory search
//

import Foundation
import Combine
import AVFoundation

// MARK: - AI Assistant Service

@MainActor
class AIAssistantService: ObservableObject {
    static let shared = AIAssistantService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var conversations: [AIConversationListItem] = []
    @Published var currentConversation: AIConversation?
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Conversations
    
    func fetchConversations() async {
        isLoading = true
        error = nil
        
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations?limit=50")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let httpResp = response as? HTTPURLResponse
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("❌ Fetch conversations failed: status=\(httpResp?.statusCode ?? 0), body=\(body)")
                throw AIAssistantError.serverError("Failed to fetch conversations")
            }
            
            let result = try JSONDecoder().decode(AIConversationListResponse.self, from: data)
            self.conversations = result.data ?? []
        } catch {
            self.error = error.localizedDescription
            print("❌ Fetch conversations error: \(error)")
        }
        
        isLoading = false
    }
    
    func createConversation(organizationId: String?) async -> AIConversation? {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            var body: [String: String] = [:]
            if let orgId = organizationId {
                body["organizationId"] = orgId
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                let httpResp = response as? HTTPURLResponse
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("❌ Create conversation failed: status=\(httpResp?.statusCode ?? 0), body=\(body)")
                throw AIAssistantError.serverError("Failed to create conversation")
            }
            
            let result = try JSONDecoder().decode(AIConversationResponse.self, from: data)
            return result.data
        } catch {
            self.error = error.localizedDescription
            print("❌ Create conversation error: \(error)")
            return nil
        }
    }
    
    func fetchConversation(conversationId: String) async -> AIConversation? {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations/\(conversationId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AIAssistantError.serverError("Failed to fetch conversation")
            }
            
            let result = try JSONDecoder().decode(AIConversationResponse.self, from: data)
            self.currentConversation = result.data
            return result.data
        } catch {
            self.error = error.localizedDescription
            print("❌ Fetch conversation error: \(error)")
            return nil
        }
    }
    
    func deleteConversation(conversationId: String) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations/\(conversationId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // Remove from local list
            conversations.removeAll { $0.id == conversationId }
            return true
        } catch {
            print("❌ Delete conversation error: \(error)")
            return false
        }
    }
    
    // MARK: - Streaming Message (SSE)
    
    /// Stream AI response via SSE. Tokens arrive instantly, audio arrives per-sentence.
    func streamMessage(
        conversationId: String,
        content: String,
        voice: String = "nova",
        onToken: @escaping (String) -> Void,
        onAudio: @escaping (Data, Int) -> Void,
        onUserMsgId: @escaping (String) -> Void,
        onDone: @escaping (String, String) -> Void,
        onError: @escaping (String) -> Void
    ) async {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations/\(conversationId)/messages/stream")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 120
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let body: [String: String] = ["content": content, "voice": voice]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let httpResp = response as? HTTPURLResponse
                await MainActor.run { onError("Server error: \(httpResp?.statusCode ?? 0)") }
                return
            }
            
            var currentEvent = ""
            
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    let dataStr = String(line.dropFirst(6))
                    guard let jsonData = dataStr.data(using: .utf8) else { continue }
                    
                    switch currentEvent {
                    case "token":
                        if let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let token = obj["t"] as? String {
                            await MainActor.run { onToken(token) }
                        }
                    case "audio":
                        if let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let base64 = obj["a"] as? String,
                           let index = obj["i"] as? Int,
                           let audioData = Data(base64Encoded: base64) {
                            await MainActor.run { onAudio(audioData, index) }
                        }
                    case "user_msg":
                        if let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let msgId = obj["id"] as? String {
                            await MainActor.run { onUserMsgId(msgId) }
                        }
                    case "done":
                        if let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let msgId = obj["id"] as? String,
                           let fullText = obj["text"] as? String {
                            await MainActor.run { onDone(msgId, fullText) }
                        }
                    case "error":
                        if let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let errMsg = obj["error"] as? String {
                            await MainActor.run { onError(errMsg) }
                        }
                    default:
                        break
                    }
                    currentEvent = ""
                }
            }
        } catch {
            print("❌ Stream message error: \(error)")
            await MainActor.run { onError(error.localizedDescription) }
        }
    }
    
    // MARK: - Send Message (legacy non-streaming fallback)
    
    func sendMessage(conversationId: String, content: String) async -> AISendMessageResult? {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/conversations/\(conversationId)/messages")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 120
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let body = ["content": content]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AIAssistantError.serverError("Failed to send message")
            }
            
            let result = try JSONDecoder().decode(AISendMessageResponse.self, from: data)
            return result.data
        } catch {
            self.error = error.localizedDescription
            print("❌ Send message error: \(error)")
            return nil
        }
    }
    
    // MARK: - Text-to-Speech
    
    func textToSpeech(text: String, voice: String = "nova") async -> Data? {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/tts")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let body: [String: String] = ["text": text, "voice": voice]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AIAssistantError.serverError("Failed to generate speech")
            }
            
            return data
        } catch {
            print("❌ TTS error: \(error)")
            return nil
        }
    }
    
    // MARK: - Memory Search
    
    func searchMemory(userId: String, query: String) async -> [AIMemorySearchResult] {
        do {
            let url = URL(string: "\(baseURL)/ai-assistant/memory/search")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let token = try? await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let body = ["userId": userId, "query": query]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            let result = try JSONDecoder().decode(AIMemorySearchResponse.self, from: data)
            return result.data ?? []
        } catch {
            print("❌ Memory search error: \(error)")
            return []
        }
    }
    
    // MARK: - Auth Token
    
    private func getAuthToken() async throws -> String? {
        return try await FirebaseAuthService.shared.getIDToken()
    }
}

// MARK: - Error

enum AIAssistantError: LocalizedError {
    case serverError(String)
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        case .networkError(let error): return error.localizedDescription
        case .invalidResponse: return "Invalid server response"
        }
    }
}
