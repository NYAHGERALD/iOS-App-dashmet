//
//  DashboardService.swift
//  MeetingIntelligence
//
//  Enterprise Dashboard Data Service
//  Fetches real-time dashboard statistics from backend API
//

import Foundation
import Combine

// MARK: - Dashboard Response Models

struct DashboardStatsResponse: Codable {
    let success: Bool
    let data: DashboardData?
    let error: String?
}

struct DashboardData: Codable {
    let user: DashboardUser?
    let period: DashboardPeriod
    let meetings: MeetingsStats
    let tasks: TasksStats
    let conflictResolution: ConflictResolutionStats
    let productivity: ProductivityStats
    let generatedAt: String
}

struct DashboardUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let profilePicture: String?
}

struct DashboardPeriod: Codable {
    let type: String
    let startDate: String
    let endDate: String
}

struct MeetingsStats: Codable {
    let total: Int
    let trend: Int
    let trendDirection: String
    let totalDurationSeconds: Int
    let totalDurationFormatted: String
    let durationTrend: Int
    let durationTrendDirection: String
    let byType: [TypeCount]
    let byStatus: [StatusCount]
    let recentMeetings: [RecentMeeting]
}

struct TypeCount: Codable, Identifiable {
    let type: String
    let count: Int
    var id: String { type }
}

struct StatusCount: Codable, Identifiable {
    let status: String
    let count: Int
    var id: String { status }
}

struct RecentMeeting: Codable, Identifiable {
    let id: String
    let title: String
    let meetingType: String
    let status: String
    let duration: Int?
    let durationFormatted: String?
    let createdAt: String
    let actionItemsCount: Int
    let participantsCount: Int
    
    var displayTitle: String {
        title.isEmpty ? "Untitled Meeting" : title
    }
    
    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: createdAt) else {
            return createdAt
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TasksStats: Codable {
    let total: Int
    let pending: Int
    let pendingTrend: Int
    let pendingTrendDirection: String
    let completed: Int
    let completedTrend: Int
    let completedTrendDirection: String
    let overdue: Int
    let aiExtracted: Int
    let byPriority: [PriorityCount]
    let pendingItems: [PendingTaskItem]
}

struct PriorityCount: Codable, Identifiable {
    let priority: String
    let count: Int
    var id: String { priority }
}

struct PendingTaskItem: Codable, Identifiable {
    let id: String
    let title: String
    let status: String
    let priority: String
    let dueDate: String?
    let isOverdue: Bool
    let isAiExtracted: Bool
    let meetingId: String?
    let meetingTitle: String?
    
    var dueDateFormatted: String? {
        guard let dueDateStr = dueDate else { return nil }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dueDateStr) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct ConflictResolutionStats: Codable {
    let totalCases: Int
    let activeCases: Int
    let closedCases: Int
    let escalatedCases: Int
    let byType: [TypeCount]
    let resolutionRate: Int
}

struct ProductivityStats: Codable {
    let completionRate: Int
    let avgMeetingDuration: Int
    let avgMeetingDurationFormatted: String
    let actionItemsPerMeeting: Double
}

// MARK: - Activity Feed Models

struct ActivityFeedResponse: Codable {
    let success: Bool
    let data: [ActivityItem]?
    let error: String?
}

struct ActivityItem: Codable, Identifiable {
    let id: String
    let type: String
    let entityId: String
    let title: String
    let subtitle: String
    let status: String
    let timestamp: String
    let icon: String
    let color: String
    
    var formattedTimestamp: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: timestamp) else {
            return timestamp
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Dashboard Service

@MainActor
class DashboardService: ObservableObject {
    static let shared = DashboardService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var dashboardData: DashboardData?
    @Published var activityFeed: [ActivityItem] = []
    @Published var isLoading = false
    @Published var isLoadingActivity = false
    @Published var errorMessage: String?
    @Published var lastFetchDate: Date?
    
    private init() {}
    
    // MARK: - Token Helper
    
    private func getAuthToken() async -> String? {
        do {
            return try await FirebaseAuthService.shared.getIDToken()
        } catch {
            print("❌ Failed to get auth token: \(error)")
            return nil
        }
    }
    
    // MARK: - Fetch Dashboard Stats
    
    func fetchDashboardStats(
        userId: String,
        organizationId: String,
        facilityId: String? = nil,
        period: String = "week"
    ) async throws {
        var urlComponents = URLComponents(string: "\(baseURL)/mobile/dashboard/stats")
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "organizationId", value: organizationId),
            URLQueryItem(name: "period", value: period)
        ]
        
        if let facilityId = facilityId {
            queryItems.append(URLQueryItem(name: "facilityId", value: facilityId))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        print("📊 Fetching dashboard stats from: \(url.absoluteString)")
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📊 Dashboard response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let result = try decoder.decode(DashboardStatsResponse.self, from: data)
            
            if result.success, let dashboardData = result.data {
                self.dashboardData = dashboardData
                self.lastFetchDate = Date()
                print("✅ Dashboard data loaded successfully")
            } else {
                let errorMsg = result.error ?? "Unknown error"
                self.errorMessage = errorMsg
                throw NSError(domain: "Dashboard", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(DashboardStatsResponse.self, from: data) {
                let errorMsg = errorResponse.error ?? "Server error"
                self.errorMessage = errorMsg
                throw NSError(domain: "Dashboard", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            } else {
                self.errorMessage = "Server error: \(httpResponse.statusCode)"
                throw URLError(.badServerResponse)
            }
        }
    }
    
    // MARK: - Fetch Activity Feed
    
    func fetchActivityFeed(
        userId: String,
        organizationId: String,
        limit: Int = 20
    ) async throws {
        var urlComponents = URLComponents(string: "\(baseURL)/mobile/dashboard/activity")
        urlComponents?.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "organizationId", value: organizationId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        print("📋 Fetching activity feed from: \(url.absoluteString)")
        
        isLoadingActivity = true
        defer { isLoadingActivity = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let result = try decoder.decode(ActivityFeedResponse.self, from: data)
            
            if result.success, let activities = result.data {
                self.activityFeed = activities
                print("✅ Activity feed loaded: \(activities.count) items")
            }
        }
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        dashboardData = nil
        activityFeed = []
        lastFetchDate = nil
        errorMessage = nil
    }
}
