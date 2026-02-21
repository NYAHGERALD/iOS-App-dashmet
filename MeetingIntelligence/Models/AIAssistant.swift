//
//  AIAssistant.swift
//  MeetingIntelligence
//
//  Models for the Workplace AI Assistant feature
//

import Foundation

// MARK: - Conversation

struct AIConversation: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let organizationId: String?
    let title: String
    let summary: String?
    let isActive: Bool
    let messages: [AIMessage]?
    let createdAt: String
    let updatedAt: String
    
    static func == (lhs: AIConversation, rhs: AIConversation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AIConversationListItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String?
    let messageCount: Int
    let lastMessage: AILastMessage?
    let createdAt: String
    let updatedAt: String
    
    static func == (lhs: AIConversationListItem, rhs: AIConversationListItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AILastMessage: Codable, Hashable {
    let content: String
    let role: String
    let createdAt: String
}

// MARK: - Message

struct AIMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let role: String // 'user' | 'assistant' | 'system'
    let content: String
    let metadata: AIMessageMetadata?
    let createdAt: String
    
    static func == (lhs: AIMessage, rhs: AIMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

struct AIMessageMetadata: Codable, Hashable {
    let model: String?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

// MARK: - API Responses

struct AIConversationListResponse: Codable {
    let success: Bool
    let data: [AIConversationListItem]?
    let error: String?
}

struct AIConversationResponse: Codable {
    let success: Bool
    let data: AIConversation?
    let error: String?
}

struct AISendMessageResult: Codable {
    let userMessage: AIMessage
    let aiMessage: AIMessage
}

struct AISendMessageResponse: Codable {
    let success: Bool
    let data: AISendMessageResult?
    let error: String?
}

struct AIMemorySearchResult: Codable, Identifiable, Hashable {
    var id: String { "\(conversationId)-\(createdAt)" }
    let conversationId: String
    let conversationTitle: String
    let role: String
    let content: String
    let createdAt: String
}

struct AIMemorySearchResponse: Codable {
    let success: Bool
    let data: [AIMemorySearchResult]?
    let error: String?
}

// MARK: - Assistant State

enum AssistantState: String {
    case idle = "idle"
    case listening = "listening"
    case thinking = "thinking"
    case speaking = "speaking"
    
    var displayText: String {
        switch self {
        case .idle: return "Tap to speak"
        case .listening: return "Listening... Tap to send"
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking... Tap to stop"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .thinking: return "brain"
        case .speaking: return "speaker.wave.3.fill"
        }
    }
}
