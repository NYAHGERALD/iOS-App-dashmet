//
//  ToDoService.swift
//  MeetingIntelligence
//
//  Backend-synced To Do service with WebSocket real-time updates.
//  Replaces the local UserDefaults-based ToDoManager.
//

import Foundation
import SwiftUI
import Combine

// MARK: - API Models

struct APIToDoItem: Codable, Identifiable {
    let id: String
    let task: String
    let completed: Bool
    let completedAt: String?
    let dueDate: String?       // HH:MM time or full date
    let note: String?
    let priority: String?      // none, low, medium, high
    let category: String?
    let tags: String?           // JSON array string e.g. "[\"urgent\",\"work\"]"
    let isFlagged: Bool
    let reminderDate: String?
    let recurrence: String?    // none, daily, weekdays, weekly, biweekly, monthly, yearly
    let weekNumber: Int?
    let year: Int?
    let sortOrder: Int
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    var parsedTags: [String] {
        guard let tags = tags, !tags.isEmpty else { return [] }
        if let data = tags.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return []
    }
    
    var priorityLevel: ToDoPriority {
        switch priority?.lowercased() {
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .none
        }
    }
    
    var recurrenceType: RecurrenceType {
        switch recurrence?.lowercased() {
        case "daily": return .daily
        case "weekdays": return .weekdays
        case "weekly": return .weekly
        case "biweekly": return .biweekly
        case "monthly": return .monthly
        case "yearly": return .yearly
        default: return .none
        }
    }
    
    var formattedDueTime: String {
        guard let dueDate = dueDate, !dueDate.isEmpty else { return "" }
        // Parse HH:MM to 12h format
        let parts = dueDate.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            let ampm = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            return String(format: "%d:%02d %@", h12, m, ampm)
        }
        return dueDate
    }
    
    var isDueTimePast: Bool {
        guard let dueDate = dueDate, !dueDate.isEmpty else { return false }
        guard !completed else { return false }
        let parts = dueDate.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return false }
        let cal = Calendar.current
        let now = Date()
        let currentH = cal.component(.hour, from: now)
        let currentM = cal.component(.minute, from: now)
        return (currentH > h) || (currentH == h && currentM > m)
    }
    
    var parsedReminderDate: Date? {
        guard let reminderDate = reminderDate, !reminderDate.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: reminderDate) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: reminderDate)
    }
}

struct APIToDoItemsResponse: Codable {
    let success: Bool
    let data: [APIToDoItem]
}

struct APIToDoItemSingleResponse: Codable {
    let success: Bool
    let data: APIToDoItem
}

// MARK: - To Do Service

class ToDoService: ObservableObject {
    static let shared = ToDoService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var items: [APIToDoItem] = []
    @Published var isLoading = false
    
    // Filter & Search
    @Published var currentFilter: ToDoFilter = .all
    @Published var searchText: String = ""
    @Published var selectedCategory: String? = nil
    
    private var registeredHandlers = Set<String>()
    private var webSocketConnected = false
    
    private init() {}
    
    // MARK: - Computed
    
    var filteredItems: [APIToDoItem] {
        var result = items
        
        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.task.lowercased().contains(q) ||
                ($0.note ?? "").lowercased().contains(q) ||
                $0.parsedTags.contains(where: { $0.lowercased().contains(q) })
            }
        }
        
        // Category
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        
        // Filter
        switch currentFilter {
        case .all:
            result = result.filter { !$0.completed }
        case .today:
            result = result.filter { !$0.completed }
        case .upcoming:
            result = result.filter { !$0.completed && $0.dueDate != nil }
        case .flagged:
            result = result.filter { $0.isFlagged && !$0.completed }
        case .completed:
            result = result.filter { $0.completed }
        case .overdue:
            result = result.filter { $0.isDueTimePast }
        }
        
        return result
    }
    
    var todayCount: Int { items.filter { !$0.completed }.count }
    var overdueCount: Int { items.filter { $0.isDueTimePast }.count }
    var completedCount: Int { items.filter { $0.completed }.count }
    var flaggedCount: Int { items.filter { $0.isFlagged && !$0.completed }.count }
    
    // MARK: - WebSocket
    
    private func ensureWebSocketConnected() {
        guard !webSocketConnected else { return }
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
        webSocketConnected = true
    }
    
    func connectWebSocket() {
        guard !registeredHandlers.contains("todo") else {
            ensureWebSocketConnected()
            return
        }
        registeredHandlers.insert("todo")
        
        SocketIOClient.shared.on("lsw:todo-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let action = dict["action"] as? String else { return }
            
            Task { @MainActor in
                switch action {
                case "todo-created":
                    if let itemDict = dict["item"] as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: itemDict),
                       let item = try? JSONDecoder().decode(APIToDoItem.self, from: jsonData) {
                        if !self.items.contains(where: { $0.id == item.id }) {
                            self.items.append(item)
                        }
                    }
                case "todo-updated":
                    if let itemDict = dict["item"] as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: itemDict),
                       let item = try? JSONDecoder().decode(APIToDoItem.self, from: jsonData) {
                        if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items[idx] = item
                        }
                    }
                case "todo-deleted":
                    if let itemId = dict["itemId"] as? String {
                        self.items.removeAll { $0.id == itemId }
                    }
                default:
                    break
                }
            }
        }
        
        ensureWebSocketConnected()
    }
    
    // MARK: - Auth Helper
    
    private func authorizedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let token = try await FirebaseAuthService.shared.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("⚠️ [ToDo] Failed to get auth token: \(error.localizedDescription)")
        }
        return request
    }
    
    // MARK: - CRUD
    
    func fetchItems(weekNumber: Int? = nil, year: Int? = nil) async {
        await MainActor.run { isLoading = true }
        
        var urlString = "\(baseURL)/lsw/todo-items"
        if let wk = weekNumber, let yr = year {
            urlString += "?weekNumber=\(wk)&year=\(yr)"
        }
        guard let url = URL(string: urlString) else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { isLoading = false }
                return
            }
            let result = try JSONDecoder().decode(APIToDoItemsResponse.self, from: data)
            await MainActor.run {
                self.items = result.data
                self.isLoading = false
            }
        } catch {
            print("❌ [ToDo] fetchItems error: \(error.localizedDescription)")
            await MainActor.run { isLoading = false }
        }
    }
    
    func createItem(task: String, dueDate: String? = nil, note: String? = nil,
                    priority: String = "none", category: String? = nil,
                    tags: [String]? = nil, isFlagged: Bool = false,
                    reminderDate: String? = nil, recurrence: String = "none",
                    weekNumber: Int? = nil, year: Int? = nil) async -> APIToDoItem? {
        guard let url = URL(string: "\(baseURL)/lsw/todo-items") else { return nil }
        var body: [String: Any] = ["task": task, "priority": priority, "isFlagged": isFlagged, "recurrence": recurrence]
        if let d = dueDate { body["dueDate"] = d }
        if let n = note, !n.isEmpty { body["note"] = n }
        if let c = category, !c.isEmpty { body["category"] = c }
        if let t = tags, !t.isEmpty {
            if let jsonData = try? JSONEncoder().encode(t),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                body["tags"] = jsonStr
            }
        }
        if let r = reminderDate { body["reminderDate"] = r }
        if let wk = weekNumber { body["weekNumber"] = wk }
        if let yr = year { body["year"] = yr }
        
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else { return nil }
            let result = try JSONDecoder().decode(APIToDoItemSingleResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [ToDo] createItem error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateItem(id: String, data: [String: Any]) async -> APIToDoItem? {
        guard let url = URL(string: "\(baseURL)/lsw/todo-items/\(id)") else { return nil }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(APIToDoItemSingleResponse.self, from: responseData)
            return result.data
        } catch {
            print("❌ [ToDo] updateItem error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteItem(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/todo-items/\(id)") else { return false }
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("❌ [ToDo] deleteItem error: \(error.localizedDescription)")
            return false
        }
    }
    
    func toggleCompleted(id: String, completed: Bool) async -> APIToDoItem? {
        return await updateItem(id: id, data: ["completed": completed])
    }
    
    func toggleFlagged(id: String, isFlagged: Bool) async -> APIToDoItem? {
        return await updateItem(id: id, data: ["isFlagged": isFlagged])
    }
}
