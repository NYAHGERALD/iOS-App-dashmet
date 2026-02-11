//
//  VisionSession.swift
//  MeetingIntelligence
//
//  Model for AI Vision conversation sessions
//

import Foundation
import Combine

// MARK: - Vision Message
struct VisionMessage: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
    
    // Init from API data
    init(id: UUID, role: MessageRole, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Vision Session
struct VisionSession: Codable, Identifiable {
    let id: UUID
    let topic: String
    let topicIcon: String
    var messages: [VisionMessage]
    let createdAt: Date
    var updatedAt: Date
    var isSaved: Bool
    var summary: String?
    
    init(topic: String, topicIcon: String) {
        self.id = UUID()
        self.topic = topic
        self.topicIcon = topicIcon
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSaved = false
        self.summary = nil
    }
    
    // Init from API data
    init(id: UUID, topic: String, topicIcon: String, messages: [VisionMessage], createdAt: Date, updatedAt: Date, isSaved: Bool, summary: String?) {
        self.id = id
        self.topic = topic
        self.topicIcon = topicIcon
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSaved = isSaved
        self.summary = summary
    }
    
    mutating func addMessage(role: VisionMessage.MessageRole, content: String) {
        let message = VisionMessage(role: role, content: content)
        messages.append(message)
        updatedAt = Date()
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var duration: String {
        guard let firstMessage = messages.first, let lastMessage = messages.last else {
            return "0 min"
        }
        let interval = lastMessage.timestamp.timeIntervalSince(firstMessage.timestamp)
        let minutes = Int(interval / 60)
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(minutes) min"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var previewText: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let text = firstUserMessage.content
            return text.count > 100 ? String(text.prefix(100)) + "..." : text
        }
        return "No messages"
    }
}

// MARK: - Vision Session Manager
class VisionSessionManager: ObservableObject {
    static let shared = VisionSessionManager()
    
    @Published var currentSession: VisionSession?
    @Published var savedSessions: [VisionSession] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    
    private let currentSessionKey = "ai_vision_current_session"
    private let savedSessionsKey = "ai_vision_saved_sessions"
    private let apiService = OpenAIVisionService()
    
    // User ID for database operations (should be set after login)
    var userId: String? {
        didSet {
            if userId != nil {
                Task { await syncWithDatabase() }
            }
        }
    }
    
    private init() {
        loadCurrentSession()
        loadSavedSessions()
    }
    
    // MARK: - Current Session (Local Storage - Temporary)
    
    func startNewSession(topic: String, topicIcon: String) {
        // Clear any unsaved previous session
        currentSession = VisionSession(topic: topic, topicIcon: topicIcon)
        saveCurrentSessionToLocal()
    }
    
    func addMessageToCurrentSession(role: VisionMessage.MessageRole, content: String) {
        currentSession?.addMessage(role: role, content: content)
        saveCurrentSessionToLocal()
    }
    
    func clearCurrentSession() {
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: currentSessionKey)
    }
    
    private func saveCurrentSessionToLocal() {
        guard let session = currentSession else { return }
        if let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: currentSessionKey)
        }
    }
    
    private func loadCurrentSession() {
        if let data = UserDefaults.standard.data(forKey: currentSessionKey),
           let session = try? JSONDecoder().decode(VisionSession.self, from: data) {
            // Only load if it's from the same day (auto-expire old sessions)
            if Calendar.current.isDateInToday(session.createdAt) {
                currentSession = session
            } else {
                // Clear old session
                UserDefaults.standard.removeObject(forKey: currentSessionKey)
            }
        }
    }
    
    // MARK: - Saved Sessions (Persistent Storage + Database)
    
    func saveCurrentSessionPermanently() {
        guard var session = currentSession else { return }
        session.isSaved = true
        savedSessions.insert(session, at: 0)
        saveSavedSessionsToStorage()
        clearCurrentSession()
        
        // Sync to database
        Task { await saveSessionToDatabase(session) }
    }
    
    func deleteSession(_ session: VisionSession) {
        savedSessions.removeAll { $0.id == session.id }
        saveSavedSessionsToStorage()
        
        // Delete from database
        Task { await deleteSessionFromDatabase(session.id) }
    }
    
    func updateSessionSummary(_ session: VisionSession, summary: String) {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index].summary = summary
            saveSavedSessionsToStorage()
        }
    }
    
    func updateSessionSummary(sessionId: UUID, summary: String) {
        // Update in current session
        if currentSession?.id == sessionId {
            currentSession?.summary = summary
            saveCurrentSessionToLocal()
        }
        // Update in saved sessions
        if let index = savedSessions.firstIndex(where: { $0.id == sessionId }) {
            savedSessions[index].summary = summary
            saveSavedSessionsToStorage()
        }
    }
    
    // Check if there's an active session for a topic
    func hasActiveSession(for topic: String) -> Bool {
        return currentSession?.topic == topic && !(currentSession?.messages.isEmpty ?? true)
    }
    
    private func saveSavedSessionsToStorage() {
        if let encoded = try? JSONEncoder().encode(savedSessions) {
            UserDefaults.standard.set(encoded, forKey: savedSessionsKey)
        }
    }
    
    private func loadSavedSessions() {
        if let data = UserDefaults.standard.data(forKey: savedSessionsKey),
           let sessions = try? JSONDecoder().decode([VisionSession].self, from: data) {
            savedSessions = sessions
        }
    }
    
    // MARK: - Export / Share
    
    func exportSession(_ session: VisionSession) -> String {
        var export = """
        AI Vision Analysis Session
        ==========================
        Topic: \(session.topic)
        Date: \(session.formattedDate)
        Duration: \(session.duration)
        
        """
        
        if let summary = session.summary {
            export += """
            Summary:
            \(summary)
            
            """
        }
        
        export += """
        Conversation:
        -------------
        
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        
        for message in session.messages {
            let time = dateFormatter.string(from: message.timestamp)
            let role = message.role == .user ? "You" : "AI"
            export += "[\(time)] \(role): \(message.content)\n\n"
        }
        
        return export
    }
    
    // MARK: - Database Sync Methods
    
    /// Sync saved sessions with the database
    @MainActor
    func syncWithDatabase() async {
        guard let userId = userId else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Fetch sessions from database
            let remoteSessions = try await apiService.fetchSessions(userId: userId)
            
            // Merge: Keep local sessions not in remote, add remote sessions
            var mergedSessions = savedSessions
            
            for remoteSession in remoteSessions {
                if !mergedSessions.contains(where: { $0.id == remoteSession.id }) {
                    mergedSessions.append(remoteSession)
                }
            }
            
            // Sort by date
            mergedSessions.sort { $0.createdAt > $1.createdAt }
            
            savedSessions = mergedSessions
            saveSavedSessionsToStorage()
            
            print("✅ Synced \(remoteSessions.count) sessions from database")
        } catch {
            print("⚠️ Database sync failed: \(error.localizedDescription)")
        }
    }
    
    /// Save a session to the database
    private func saveSessionToDatabase(_ session: VisionSession) async {
        guard let userId = userId else {
            print("⚠️ No userId set, session saved locally only")
            return
        }
        
        do {
            try await apiService.saveSession(session, userId: userId)
            print("✅ Session saved to database: \(session.id)")
        } catch {
            print("⚠️ Failed to save session to database: \(error.localizedDescription)")
        }
    }
    
    /// Delete a session from the database
    private func deleteSessionFromDatabase(_ sessionId: UUID) async {
        guard let userId = userId else { return }
        
        do {
            try await apiService.deleteSession(sessionId: sessionId, userId: userId)
            print("✅ Session deleted from database: \(sessionId)")
        } catch {
            print("⚠️ Failed to delete session from database: \(error.localizedDescription)")
        }
    }
    
    /// Generate AI summary using the backend
    @MainActor
    func generateAISummary(for session: VisionSession) async throws -> String {
        guard let userId = userId else {
            throw OpenAIError.apiError("User not logged in")
        }
        
        let summary = try await apiService.generateSummary(sessionId: session.id, userId: userId)
        
        // Update local storage
        updateSessionSummary(sessionId: session.id, summary: summary)
        
        return summary
    }
}
