//
//  ConflictAnalyticsService.swift
//  MeetingIntelligence
//
//  Enterprise-Grade Analytics Service for Conflict Resolution
//  Fetches analytics data from backend API with proper authentication
//

import Foundation
import Combine

// MARK: - Analytics Response Models

struct ConflictAnalyticsResponse: Codable {
    let success: Bool
    let data: ConflictAnalyticsData?
    let error: String?
    let details: String?
}

struct ConflictAnalyticsData: Codable {
    let summary: AnalyticsSummary
    let resolutionMetrics: ResolutionMetrics
    let statusBreakdown: [StatusBreakdownItem]
    let typeBreakdown: [TypeBreakdownItem]
    let closureReasonBreakdown: [ClosureReasonItem]
    let actionTypeBreakdown: [ActionTypeItem]
    let monthlyTrends: [MonthlyTrendItem]
    let departmentBreakdown: [DepartmentBreakdownItem]
    let generatedAt: String
}

struct AnalyticsSummary: Codable {
    let totalCases: Int
    let activeCases: Int
    let closedCases: Int
    let escalatedCases: Int
    let resolutionRate: Double
}

struct ResolutionMetrics: Codable {
    let averageDays: Double
    let minDays: Int
    let maxDays: Int
    let totalResolved: Int
}

struct StatusBreakdownItem: Codable, Identifiable {
    let status: String
    let count: Int
    
    var id: String { status }
    
    var displayName: String {
        switch status {
        case "DRAFT": return "Draft"
        case "IN_PROGRESS": return "In Progress"
        case "PENDING_REVIEW": return "Pending Review"
        case "AWAITING_ACTION": return "Awaiting Action"
        case "CLOSED": return "Closed"
        case "ESCALATED": return "Escalated"
        default: return status
        }
    }
}

struct TypeBreakdownItem: Codable, Identifiable {
    let type: String
    let count: Int
    
    var id: String { type }
    
    var displayName: String {
        switch type {
        case "CONFLICT": return "Conflict"
        case "CONDUCT": return "Conduct"
        case "SAFETY": return "Safety"
        case "OTHER": return "Other"
        default: return type
        }
    }
}

struct ClosureReasonItem: Codable, Identifiable {
    let reason: String
    let count: Int
    
    var id: String { reason }
    
    var displayName: String {
        switch reason {
        case "RESOLVED": return "Resolved"
        case "NO_FURTHER_ACTION": return "No Further Action"
        case "EMPLOYEE_SEPARATION": return "Employee Separation"
        case "COMPLAINT_WITHDRAWN": return "Complaint Withdrawn"
        case "INSUFFICIENT_EVIDENCE": return "Insufficient Evidence"
        case "OTHER": return "Other"
        case "Not Specified": return "Not Specified"
        default: return reason
        }
    }
}

struct ActionTypeItem: Codable, Identifiable {
    let actionType: String?
    let count: Int
    
    var id: String { actionType ?? "none" }
    
    var displayName: String {
        guard let action = actionType else { return "None" }
        switch action {
        case "COACHING": return "Coaching"
        case "COUNSELING": return "Counseling"
        case "WRITTEN_WARNING": return "Written Warning"
        case "ESCALATE_TO_HR": return "Escalate to HR"
        default: return action
        }
    }
}

struct MonthlyTrendItem: Codable, Identifiable {
    let month: String
    let created: Int
    let closed: Int
    
    var id: String { month }
    
    var displayMonth: String {
        let components = month.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let monthNum = Int(components[1]) else {
            return month
        }
        
        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let shortYear = year % 100
        return "\(monthNames[monthNum]) '\(String(format: "%02d", shortYear))"
    }
}

struct DepartmentBreakdownItem: Codable, Identifiable {
    let department: String
    let total: Int
    let active: Int
    let closed: Int
    
    var id: String { department }
}

// MARK: - Analytics Service

@MainActor
class ConflictAnalyticsService: ObservableObject {
    static let shared = ConflictAnalyticsService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var analyticsData: ConflictAnalyticsData?
    @Published var isLoading = false
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
    
    // MARK: - Fetch Analytics
    
    /// Fetch analytics data for an organization
    /// - Parameters:
    ///   - organizationId: The organization ID to fetch analytics for
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    ///   - facilityId: Optional facility filter
    func fetchAnalytics(
        organizationId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        facilityId: String? = nil
    ) async throws {
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(baseURL)/conflict-cases/analytics")
        var queryItems = [URLQueryItem(name: "organizationId", value: organizationId)]
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: isoFormatter.string(from: startDate)))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: isoFormatter.string(from: endDate)))
        }
        
        if let facilityId = facilityId {
            queryItems.append(URLQueryItem(name: "facilityId", value: facilityId))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        print("📊 Fetching analytics from: \(url.absoluteString)")
        
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
        
        print("📊 Analytics response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let result = try decoder.decode(ConflictAnalyticsResponse.self, from: data)
            
            if result.success, let analyticsData = result.data {
                self.analyticsData = analyticsData
                self.lastFetchDate = Date()
                print("✅ Analytics data loaded successfully")
            } else {
                let errorMsg = result.error ?? "Unknown error"
                self.errorMessage = errorMsg
                throw NSError(domain: "ConflictAnalytics", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } else {
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ConflictAnalyticsResponse.self, from: data) {
                let errorMsg = errorResponse.error ?? "Server error"
                self.errorMessage = errorMsg
                throw NSError(domain: "ConflictAnalytics", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            } else {
                self.errorMessage = "Server error: \(httpResponse.statusCode)"
                throw URLError(.badServerResponse)
            }
        }
    }
    
    /// Clear cached analytics data
    func clearCache() {
        analyticsData = nil
        lastFetchDate = nil
        errorMessage = nil
    }
}
