//
//  WorkplacePolicyService.swift
//  MeetingIntelligence
//
//  Service for syncing workplace policies with backend database
//  Replaces local UserDefaults storage with encrypted database storage
//

import Foundation
import Combine

// MARK: - API Response Models

struct PolicyAPIResponse: Codable {
    let success: Bool
    let data: PolicyAPIData?
    let error: String?
    let details: String?
}

struct PolicyListResponse: Codable {
    let success: Bool
    let data: [PolicyAPIData]?
    let error: String?
}

// MARK: - API Data Models (match backend schema)

struct PolicyAPIData: Codable {
    let id: String
    let name: String
    let version: String
    let effectiveDate: String
    let status: String
    let description: String?
    let documentFileName: String?
    let documentFileUrl: String?
    let documentFileType: String?
    let documentPageCount: Int?
    let originalText: String?
    let sections: String? // JSON string
    let organizationId: String
    let facilityId: String?
    let createdBy: String
    let createdAt: String
    let updatedAt: String
    let createdByUser: PolicyUserBasicInfo?
    let organization: PolicyOrgBasicInfo?
    
    // Convert from API model to app model
    func toWorkplacePolicy() -> WorkplacePolicy {
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let effectiveDt = dateFormatter.date(from: effectiveDate) ?? Date()
        let createdDt = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDt = dateFormatter.date(from: updatedAt) ?? Date()
        
        // Parse status
        let policyStatus = PolicyStatus(rawValue: status) ?? .draft
        
        // Parse sections from JSON string
        var policySections: [PolicySection] = []
        if let sectionsString = sections,
           let data = sectionsString.data(using: .utf8) {
            policySections = (try? JSONDecoder().decode([PolicySection].self, from: data)) ?? []
        }
        
        // Create document source if available
        var docSource: PolicyDocumentSource? = nil
        if let fileName = documentFileName {
            docSource = PolicyDocumentSource(
                fileName: fileName,
                fileURL: documentFileUrl ?? "",
                fileType: documentFileType ?? "PDF",
                pageCount: documentPageCount ?? 0,
                originalText: originalText
            )
        }
        
        return WorkplacePolicy(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            version: version,
            effectiveDate: effectiveDt,
            status: policyStatus,
            description: description ?? "",
            documentSource: docSource,
            sections: policySections,
            organizationId: organizationId,
            createdBy: createdBy,
            createdAt: createdDt,
            updatedAt: updatedDt
        )
    }
}

struct PolicyUserBasicInfo: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
}

struct PolicyOrgBasicInfo: Codable {
    let id: String
    let name: String
}

// MARK: - Workplace Policy Service

@MainActor
class WorkplacePolicyService: ObservableObject {
    static let shared = WorkplacePolicyService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private init() {}
    
    // MARK: - Token Helper
    
    private func getAuthToken() async throws -> String {
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw PolicyServiceError.noAuthToken
        }
        return token
    }
    
    // MARK: - Create Policy
    
    func createPolicy(_ policy: WorkplacePolicy, creatorId: String, organizationId: String, facilityId: String?) async throws -> PolicyAPIData {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/conflict-cases/workplace-policies") else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Build request body
        var body: [String: Any] = [
            "name": policy.name,
            "version": policy.version,
            "effectiveDate": ISO8601DateFormatter().string(from: policy.effectiveDate),
            "status": policy.status.rawValue,
            "createdBy": creatorId,
            "organizationId": organizationId
        ]
        
        if let facilityId = facilityId {
            body["facilityId"] = facilityId
        }
        
        if !policy.description.isEmpty {
            body["description"] = policy.description
        }
        
        // Add document source info
        if let docSource = policy.documentSource {
            body["documentFileName"] = docSource.fileName
            body["documentFileUrl"] = docSource.fileURL
            body["documentFileType"] = docSource.fileType
            body["documentPageCount"] = docSource.pageCount
            if let originalText = docSource.originalText {
                body["originalText"] = originalText
            }
        }
        
        // Add sections as JSON
        if !policy.sections.isEmpty {
            if let sectionsData = try? JSONEncoder().encode(policy.sections),
               let sectionsArray = try? JSONSerialization.jsonObject(with: sectionsData) {
                body["sections"] = sectionsArray
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            let errorResponse = try? JSONDecoder().decode(PolicyAPIResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "Failed to create policy")
        }
        
        let apiResponse = try JSONDecoder().decode(PolicyAPIResponse.self, from: data)
        
        guard let policyData = apiResponse.data else {
            throw PolicyServiceError.invalidResponse
        }
        
        return policyData
    }
    
    // MARK: - Fetch Policies
    
    func fetchPolicies(organizationId: String, status: String? = nil) async throws -> [PolicyAPIData] {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        var urlString = "\(baseURL)/conflict-cases/workplace-policies?organizationId=\(organizationId)"
        
        if let status = status {
            urlString += "&status=\(status)"
        }
        
        guard let url = URL(string: urlString) else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(PolicyListResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "Failed to fetch policies")
        }
        
        let apiResponse = try JSONDecoder().decode(PolicyListResponse.self, from: data)
        
        lastSyncDate = Date()
        
        return apiResponse.data ?? []
    }
    
    // MARK: - Get Single Policy
    
    func getPolicy(id: String) async throws -> PolicyAPIData {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/conflict-cases/workplace-policies/\(id)") else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            throw PolicyServiceError.notFound
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(PolicyAPIResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "Failed to fetch policy")
        }
        
        let apiResponse = try JSONDecoder().decode(PolicyAPIResponse.self, from: data)
        
        guard let policyData = apiResponse.data else {
            throw PolicyServiceError.invalidResponse
        }
        
        return policyData
    }
    
    // MARK: - Update Policy
    
    func updatePolicy(id: String, updates: [String: Any]) async throws -> PolicyAPIData {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/conflict-cases/workplace-policies/\(id)") else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            throw PolicyServiceError.notFound
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(PolicyAPIResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "Failed to update policy")
        }
        
        let apiResponse = try JSONDecoder().decode(PolicyAPIResponse.self, from: data)
        
        guard let policyData = apiResponse.data else {
            throw PolicyServiceError.invalidResponse
        }
        
        return policyData
    }
    
    // MARK: - Delete Policy
    
    func deletePolicy(id: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/conflict-cases/workplace-policies/\(id)") else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            throw PolicyServiceError.notFound
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(PolicyAPIResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "Failed to delete policy")
        }
    }
    
    // MARK: - Sync Policy (Create or Update)
    
    func syncPolicy(_ policy: WorkplacePolicy, creatorId: String, organizationId: String, facilityId: String?, backendId: String?) async throws -> PolicyAPIData {
        if let id = backendId {
            // Update existing policy
            var updates: [String: Any] = [
                "name": policy.name,
                "version": policy.version,
                "effectiveDate": ISO8601DateFormatter().string(from: policy.effectiveDate),
                "status": policy.status.rawValue,
                "description": policy.description
            ]
            
            if let docSource = policy.documentSource {
                updates["documentFileName"] = docSource.fileName
                updates["documentFileUrl"] = docSource.fileURL
                updates["documentFileType"] = docSource.fileType
                updates["documentPageCount"] = docSource.pageCount
                if let originalText = docSource.originalText {
                    updates["originalText"] = originalText
                }
            }
            
            if !policy.sections.isEmpty {
                if let sectionsData = try? JSONEncoder().encode(policy.sections),
                   let sectionsArray = try? JSONSerialization.jsonObject(with: sectionsData) {
                    updates["sections"] = sectionsArray
                }
            }
            
            return try await updatePolicy(id: id, updates: updates)
        } else {
            // Create new policy
            return try await createPolicy(policy, creatorId: creatorId, organizationId: organizationId, facilityId: facilityId)
        }
    }
}

// MARK: - Errors

enum PolicyServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noAuthToken
    case notFound
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noAuthToken:
            return "Not authenticated"
        case .notFound:
            return "Policy not found"
        case .serverError(let message):
            return message
        }
    }
}
