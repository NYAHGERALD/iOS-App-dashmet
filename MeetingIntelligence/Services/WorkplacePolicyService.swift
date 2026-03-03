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
        
        // Parse sections from JSON string using backend section model
        var policySections: [PolicySection] = []
        if let sectionsString = sections,
           let data = sectionsString.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let apiSections = try? decoder.decode([PolicySectionAPIData].self, from: data) {
                policySections = apiSections.map { $0.toPolicySection() }
            }
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

// MARK: - Section API Data (matches backend JSON with 4 progression fields)

struct PolicySectionAPIData: Codable {
    let id: String?
    let sectionNumber: String?
    let title: String?
    let content: String?
    let type: String?
    let orderIndex: Int?
    let firstProgression: String?
    let secondProgression: String?
    let thirdProgression: String?
    let fourthProgression: String?
    
    func toPolicySection() -> PolicySection {
        PolicySection(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            sectionNumber: sectionNumber ?? "",
            title: title ?? "",
            content: content ?? "",
            type: PolicySectionType(rawValue: type ?? "OTHER") ?? .other,
            orderIndex: orderIndex ?? 0,
            firstProgression: firstProgression,
            secondProgression: secondProgression,
            thirdProgression: thirdProgression,
            fourthProgression: fourthProgression
        )
    }
}

// MARK: - AI Parse Response Models

struct AiParseSectionsResponse: Codable {
    let success: Bool
    let data: AiParsedData?
    let error: String?
}

struct AiParsedData: Codable {
    let sections: [PolicySectionAPIData]?
    let summary: AiParsedSummary?
    let parsedAt: String?
}

struct AiParsedSummary: Codable {
    let totalSections: Int?
    let sectionsWithDiscipline: Int?
    let policyType: String?
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
        
        // Add sections with progression fields
        if !policy.sections.isEmpty {
            let sectionsArray = policy.sections.map { section -> [String: Any] in
                var dict: [String: Any] = [
                    "id": section.id.uuidString,
                    "sectionNumber": section.sectionNumber,
                    "title": section.title,
                    "content": section.content,
                    "type": section.type.rawValue,
                    "orderIndex": section.orderIndex
                ]
                if let v = section.firstProgression { dict["firstProgression"] = v }
                if let v = section.secondProgression { dict["secondProgression"] = v }
                if let v = section.thirdProgression { dict["thirdProgression"] = v }
                if let v = section.fourthProgression { dict["fourthProgression"] = v }
                return dict
            }
            body["sections"] = sectionsArray
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
                let sectionsArray = policy.sections.map { section -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": section.id.uuidString,
                        "sectionNumber": section.sectionNumber,
                        "title": section.title,
                        "content": section.content,
                        "type": section.type.rawValue,
                        "orderIndex": section.orderIndex
                    ]
                    if let v = section.firstProgression { dict["firstProgression"] = v }
                    if let v = section.secondProgression { dict["secondProgression"] = v }
                    if let v = section.thirdProgression { dict["thirdProgression"] = v }
                    if let v = section.fourthProgression { dict["fourthProgression"] = v }
                    return dict
                }
                updates["sections"] = sectionsArray
            }
            
            return try await updatePolicy(id: id, updates: updates)
        } else {
            return try await createPolicy(policy, creatorId: creatorId, organizationId: organizationId, facilityId: facilityId)
        }
    }
    
    // MARK: - AI Parse Sections
    
    /// Call backend AI to parse policy text into structured sections with progressive discipline
    func aiParseSections(text: String, policyName: String) async throws -> [PolicySection] {
        guard let url = URL(string: "\(baseURL)/policy-parsing/parse-sections") else {
            throw PolicyServiceError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "extractedText": text,
            "policyName": policyName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(AiParseSectionsResponse.self, from: data)
            throw PolicyServiceError.serverError(errorResponse?.error ?? "AI parsing failed")
        }
        
        let apiResponse = try JSONDecoder().decode(AiParseSectionsResponse.self, from: data)
        
        guard let parsedData = apiResponse.data,
              let apiSections = parsedData.sections, !apiSections.isEmpty else {
            return []
        }
        
        return apiSections.map { $0.toPolicySection() }
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
