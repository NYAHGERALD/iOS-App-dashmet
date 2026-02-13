//
//  ConflictCaseService.swift
//  MeetingIntelligence
//
//  Service for syncing conflict cases with backend database
//  Replaces local UserDefaults storage with encrypted database storage
//

import Foundation
import Combine

// MARK: - API Response Models

struct ConflictCaseAPIResponse: Codable {
    let success: Bool
    let data: ConflictCaseAPIData?
    let error: String?
    let details: String?
}

struct ConflictCaseListResponse: Codable {
    let success: Bool
    let data: [ConflictCaseAPIData]?
    let pagination: Pagination?
    let error: String?
}

struct Pagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - API Data Models (match backend schema)

struct ConflictCaseAPIData: Codable {
    let id: String
    let caseNumber: String
    let type: String  // Changed from caseType to match backend
    let status: String
    let description: String?
    let incidentDate: String  // Changed from reportedDate to match backend
    let location: String?
    let department: String?
    let shift: String?
    // AI fields - match backend database field names
    let comparisonResult: String?      // Was aiComparisonResultJson
    let recommendations: String?        // Was aiRecommendationsJson
    let selectedAction: String?         // Was selectedActionType
    let generatedDocument: String?      // Was generatedActionDocJson
    let policyMatches: String?          // Was policyMatchesJson
    let supervisorNotes: String?
    let createdBy: String?              // Changed from creatorId to match backend
    let organizationId: String
    let facilityId: String?
    let createdAt: String
    let updatedAt: String
    let involvedEmployees: [ConflictEmployeeAPIData]?  // Changed from employees
    let documents: [ConflictDocumentAPIData]?
    let auditLog: [ConflictAuditAPIData]?  // Changed from auditTrail
    let createdByUser: ConflictUserBasicInfo?  // Changed from creator
    let organization: ConflictOrgBasicInfo?
    let facility: ConflictFacilityBasicInfo?
    
    // Convert from API model to app model
    func toConflictCase() -> ConflictCase {
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let reportDate = dateFormatter.date(from: incidentDate) ?? Date()
        let created = dateFormatter.date(from: createdAt) ?? Date()
        let updated = dateFormatter.date(from: updatedAt) ?? Date()
        
        // Parse employees
        let parsedEmployees = involvedEmployees?.map { emp in
            emp.toInvolvedEmployee()
        } ?? []
        
        // Parse documents
        let caseDocuments = documents?.map { doc in
            doc.toCaseDocument()
        } ?? []
        
        // Parse audit trail
        let auditEntries = auditLog?.map { entry in
            entry.toCaseAuditEntry()
        } ?? []
        
        // Parse AI comparison result
        var aiComparison: AIComparisonResult?
        if let jsonString = comparisonResult,
           let data = jsonString.data(using: .utf8) {
            aiComparison = try? JSONDecoder().decode(AIComparisonResult.self, from: data)
        }
        
        // Parse AI recommendations
        var aiRecs: [AIRecommendation] = []
        if let jsonString = recommendations,
           let data = jsonString.data(using: .utf8) {
            aiRecs = (try? JSONDecoder().decode([AIRecommendation].self, from: data)) ?? []
        }
        
        // Parse policy matches
        var matches: [PolicyMatch] = []
        if let jsonString = policyMatches,
           let data = jsonString.data(using: .utf8) {
            matches = (try? JSONDecoder().decode([PolicyMatch].self, from: data)) ?? []
        }
        
        // Parse generated action document
        var actionDoc: GeneratedActionDocument?
        if let jsonString = generatedDocument,
           let data = jsonString.data(using: .utf8) {
            actionDoc = try? JSONDecoder().decode(GeneratedActionDocument.self, from: data)
        }
        
        // Parse action type
        let action = RecommendedAction(rawValue: selectedAction ?? "") 
        
        // Create conflict case
        var conflictCase = ConflictCase(
            caseNumber: caseNumber,
            type: CaseType(rawValue: type) ?? .other,
            status: CaseStatus(rawValue: status) ?? .draft,
            description: description ?? "",
            incidentDate: reportDate,
            location: location ?? facility?.name ?? "",
            department: department ?? "",
            shift: shift,
            involvedEmployees: parsedEmployees,
            createdBy: createdBy ?? createdByUser?.id ?? "",
            activePolicyId: nil
        )
        
        // Set backend ID
        conflictCase.backendId = id
        conflictCase.createdAt = created
        conflictCase.updatedAt = updated
        conflictCase.documents = caseDocuments
        conflictCase.auditLog = auditEntries
        conflictCase.comparisonResult = aiComparison
        conflictCase.recommendations = aiRecs
        conflictCase.policyMatches = matches
        conflictCase.selectedAction = action
        conflictCase.generatedDocument = actionDoc
        conflictCase.supervisorNotes = supervisorNotes
        // Note: supervisorDecision is stored locally only, not in database
        
        return conflictCase
    }
}

struct ConflictEmployeeAPIData: Codable {
    let id: String
    let name: String
    let role: String?
    let department: String?
    let employeeId: String?
    let isComplainant: Bool
    let statement: String?
    
    func toInvolvedEmployee() -> InvolvedEmployee {
        InvolvedEmployee(
            name: name,
            role: role ?? "",
            department: department ?? "",
            employeeId: employeeId,
            isComplainant: isComplainant
        )
    }
}

struct ConflictDocumentAPIData: Codable {
    let id: String
    let name: String?
    let type: String
    let url: String?
    let uploadedAt: String
    let content: String?
    let extractedText: String?
    // Additional fields from backend
    let originalImageUrls: String?  // JSON array as encrypted string
    let processedImageUrls: String?
    let originalText: String?
    let translatedText: String?
    let cleanedText: String?
    let detectedLanguage: String?
    let isHandwritten: Bool?
    let employeeId: String?
    let submittedBy: String?
    let signatureImageData: String?
    let employeeReviewTimestamp: String?
    let employeeSignatureTimestamp: String?
    let supervisorCertificationTimestamp: String?
    let supervisorId: String?
    let supervisorName: String?
    let pageCount: Int?
    
    func toCaseDocument() -> CaseDocument {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse image URL arrays from JSON strings
        var originalURLs: [String] = []
        var processedURLs: [String] = []
        
        if let urlString = originalImageUrls,
           let data = urlString.data(using: .utf8),
           let urls = try? JSONSerialization.jsonObject(with: data) as? [String] {
            originalURLs = urls
        }
        
        if let urlString = processedImageUrls,
           let data = urlString.data(using: .utf8),
           let urls = try? JSONSerialization.jsonObject(with: data) as? [String] {
            processedURLs = urls
        }
        
        // Parse timestamps
        let reviewTime = employeeReviewTimestamp.flatMap { dateFormatter.date(from: $0) }
        let signTime = employeeSignatureTimestamp.flatMap { dateFormatter.date(from: $0) }
        let certTime = supervisorCertificationTimestamp.flatMap { dateFormatter.date(from: $0) }
        
        return CaseDocument(
            id: UUID(uuidString: id) ?? UUID(),
            type: CaseDocumentType(rawValue: type) ?? .other,
            originalImageURLs: originalURLs,
            processedImageURLs: processedURLs,
            originalText: originalText ?? extractedText ?? "",
            translatedText: translatedText,
            cleanedText: cleanedText ?? content ?? "",
            detectedLanguage: detectedLanguage,
            isHandwritten: isHandwritten,
            employeeId: employeeId.flatMap { UUID(uuidString: $0) },
            submittedBy: submittedBy,
            signatureImageBase64: signatureImageData,
            employeeReviewTimestamp: reviewTime,
            employeeSignatureTimestamp: signTime,
            supervisorCertificationTimestamp: certTime,
            supervisorId: supervisorId,
            supervisorName: supervisorName
        )
    }
}

struct ConflictAuditAPIData: Codable {
    let id: String
    let action: String
    let details: String?  // Changed from description
    let userId: String?
    let userName: String?  // Added to match backend
    let timestamp: String  // Changed from createdAt
    let user: ConflictUserBasicInfo?
    
    func toCaseAuditEntry() -> CaseAuditEntry {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let created = dateFormatter.date(from: timestamp) ?? Date()
        
        return CaseAuditEntry(
            action: action,
            details: details ?? "",
            userId: userId ?? "",
            userName: userName ?? (user != nil ? "\(user!.firstName ?? "") \(user!.lastName ?? "")" : "System"),
            timestamp: created
        )
    }
}

struct ConflictUserBasicInfo: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
}

struct ConflictOrgBasicInfo: Codable {
    let id: String
    let name: String
}

struct ConflictFacilityBasicInfo: Codable {
    let id: String
    let name: String
}

// MARK: - Conflict Case Service

@MainActor
class ConflictCaseService: ObservableObject {
    static let shared = ConflictCaseService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private init() {}
    
    // MARK: - Token Helper
    
    private func getAuthToken() async -> String? {
        do {
            return try await FirebaseAuthService.shared.getIDToken()
        } catch {
            print("Failed to get auth token: \(error)")
            return nil
        }
    }
    
    // MARK: - Create Case
    
    /// Create a new case in the database
    func createCase(_ conflictCase: ConflictCase, creatorId: String, organizationId: String, facilityId: String?, activePolicyBackendId: String? = nil) async throws -> ConflictCaseAPIData {
        guard let url = URL(string: "\(baseURL)/conflict-cases") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Build request body
        var body: [String: Any] = [
            "caseNumber": conflictCase.caseNumber,
            "caseType": conflictCase.type.rawValue,
            "status": conflictCase.status.rawValue,
            "incidentDate": ISO8601DateFormatter().string(from: conflictCase.incidentDate),
            "location": conflictCase.location,
            "department": conflictCase.department,
            "creatorId": creatorId,
            "organizationId": organizationId
        ]
        
        if let shift = conflictCase.shift, !shift.isEmpty {
            body["shift"] = shift
        }
        
        if let facilityId = facilityId {
            body["facilityId"] = facilityId
        }
        
        // Use backend policy ID if provided (not local UUID)
        if let backendPolicyId = activePolicyBackendId, !backendPolicyId.isEmpty {
            body["activePolicyId"] = backendPolicyId
        }
        
        if !conflictCase.description.isEmpty {
            body["description"] = conflictCase.description
        }
        
        // Add employees as JSON
        if !conflictCase.involvedEmployees.isEmpty {
            let employeesData = conflictCase.involvedEmployees.map { emp in
                [
                    "name": emp.name,
                    "role": emp.role,
                    "department": emp.department,
                    "employeeId": emp.employeeId ?? "",
                    "isComplainant": emp.isComplainant
                ] as [String : Any]
            }
            body["employeesJson"] = employeesData
        }
        
        // Add AI results if present
        if let aiComparison = conflictCase.comparisonResult,
           let data = try? JSONEncoder().encode(aiComparison) {
            body["aiComparisonResultJson"] = try? JSONSerialization.jsonObject(with: data)
        }
        
        if !conflictCase.recommendations.isEmpty,
           let data = try? JSONEncoder().encode(conflictCase.recommendations) {
            body["aiRecommendationsJson"] = try? JSONSerialization.jsonObject(with: data)
        }
        
        if !conflictCase.policyMatches.isEmpty,
           let data = try? JSONEncoder().encode(conflictCase.policyMatches) {
            body["policyMatchesJson"] = try? JSONSerialization.jsonObject(with: data)
        }
        
        if let selectedAction = conflictCase.selectedAction {
            body["selectedActionType"] = selectedAction.rawValue
        }
        
        if let actionDoc = conflictCase.generatedDocument,
           let data = try? JSONEncoder().encode(actionDoc) {
            body["generatedActionDocJson"] = try? JSONSerialization.jsonObject(with: data)
        }
        
        if let notes = conflictCase.supervisorNotes {
            body["supervisorNotes"] = notes
        }
        
        if let decision = conflictCase.supervisorDecision {
            body["finalDecision"] = decision
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Debug: Print the request body
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request body: \(bodyString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Debug: Print response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response (\(httpResponse.statusCode)): \(responseString)")
        }
        
        if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(ConflictCaseAPIResponse.self, from: data)
            if result.success, let caseData = result.data {
                return caseData
            } else {
                throw NSError(domain: "ConflictCaseService", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error"])
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(ConflictCaseAPIResponse.self, from: data) {
                let errorDetails = errorResponse.details ?? errorResponse.error ?? "Request failed"
                throw NSError(domain: "ConflictCaseService", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: errorDetails])
            }
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Fetch Cases
    
    /// Fetch all cases for an organization
    func fetchCases(organizationId: String, status: CaseStatus? = nil, limit: Int = 50) async throws -> [ConflictCaseAPIData] {
        var urlString = "\(baseURL)/conflict-cases?organizationId=\(organizationId)&limit=\(limit)"
        if let status = status {
            urlString += "&status=\(status.rawValue)"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
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
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(ConflictCaseListResponse.self, from: data)
            if result.success {
                return result.data ?? []
            } else {
                throw NSError(domain: "ConflictCaseService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: result.error ?? "Unknown error"])
            }
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Fetch Single Case
    
    /// Fetch a single case by ID
    func fetchCase(id: String) async throws -> ConflictCaseAPIData {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(id)") else {
            throw URLError(.badURL)
        }
        
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
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(ConflictCaseAPIResponse.self, from: data)
            if result.success, let caseData = result.data {
                return caseData
            } else {
                throw NSError(domain: "ConflictCaseService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: result.error ?? "Case not found"])
            }
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Update Case
    
    /// Update an existing case
    func updateCase(id: String, updates: [String: Any], userId: String) async throws -> ConflictCaseAPIData {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(id)") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = updates
        body["userId"] = userId
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(ConflictCaseAPIResponse.self, from: data)
            if result.success, let caseData = result.data {
                return caseData
            } else {
                throw NSError(domain: "ConflictCaseService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: result.error ?? "Update failed"])
            }
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Delete Case
    
    /// Delete a case
    func deleteCase(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(id)") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ConflictCaseAPIResponse.self, from: data) {
                throw NSError(domain: "ConflictCaseService", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: errorResponse.error ?? "Delete failed"])
            }
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Employee Management
    
    /// Add employee to case
    func addEmployee(caseId: String, employee: InvolvedEmployee, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(caseId)/employees") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "name": employee.name,
            "role": employee.role,
            "department": employee.department,
            "employeeId": employee.employeeId ?? "",
            "isComplainant": employee.isComplainant,
            "userId": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Remove employee from case
    func removeEmployee(caseId: String, employeeId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(caseId)/employees/\(employeeId)?userId=\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Document Management
    
    /// Add document to case
    func addDocument(caseId: String, document: CaseDocument, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(caseId)/documents") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "name": document.type.displayName,
            "type": document.type.rawValue,
            "originalText": document.originalText,
            "cleanedText": document.cleanedText,
            "userId": userId,
            "pageCount": document.pageCount
        ]
        
        // Add image URLs if available (Firebase storage URLs)
        if !document.originalImageURLs.isEmpty {
            body["originalImageUrls"] = document.originalImageURLs
        }
        if !document.processedImageURLs.isEmpty {
            body["processedImageUrls"] = document.processedImageURLs
        }
        
        // Add translated text if available
        if let translatedText = document.translatedText {
            body["translatedText"] = translatedText
        }
        
        // Add language detection info
        if let lang = document.detectedLanguage {
            body["detectedLanguage"] = lang
        }
        if let handwritten = document.isHandwritten {
            body["isHandwritten"] = handwritten
        }
        
        // Add employee info if this is a witness statement
        if let empId = document.employeeId {
            body["employeeId"] = empId.uuidString
        }
        if let submittedBy = document.submittedBy {
            body["submittedBy"] = submittedBy
        }
        
        // Add signature/audit data if available
        if let signature = document.signatureImageBase64 {
            body["signatureImageData"] = signature
        }
        if let reviewTime = document.employeeReviewTimestamp {
            body["employeeReviewTimestamp"] = ISO8601DateFormatter().string(from: reviewTime)
        }
        if let signTime = document.employeeSignatureTimestamp {
            body["employeeSignatureTimestamp"] = ISO8601DateFormatter().string(from: signTime)
        }
        if let certTime = document.supervisorCertificationTimestamp {
            body["supervisorCertificationTimestamp"] = ISO8601DateFormatter().string(from: certTime)
        }
        if let supId = document.supervisorId {
            body["supervisorId"] = supId
        }
        if let supName = document.supervisorName {
            body["supervisorName"] = supName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Remove document from case
    func removeDocument(caseId: String, documentId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/conflict-cases/\(caseId)/documents/\(documentId)?userId=\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Sync All Cases
    
    /// Sync local cases with database (upload any unsynced, download new ones)
    func syncCases(localCases: [ConflictCase], organizationId: String, creatorId: String, facilityId: String?) async -> [ConflictCase] {
        isSyncing = true
        defer { 
            isSyncing = false
            lastSyncDate = Date()
        }
        
        var syncedCases: [ConflictCase] = []
        
        // 1. Fetch all cases from server
        do {
            let remoteCases = try await fetchCases(organizationId: organizationId)
            let remoteCaseMap = Dictionary(uniqueKeysWithValues: remoteCases.map { ($0.id, $0) })
            
            // 2. For each local case
            for localCase in localCases {
                if let backendId = localCase.backendId {
                    // Case exists on server - check if we need to update
                    if let remoteCase = remoteCaseMap[backendId] {
                        // Use remote version (server is source of truth)
                        syncedCases.append(remoteCase.toConflictCase())
                    } else {
                        // Case was deleted on server, don't include
                        continue
                    }
                } else {
                    // Local-only case - upload to server
                    do {
                        let created = try await createCase(localCase, creatorId: creatorId, organizationId: organizationId, facilityId: facilityId)
                        var updatedCase = localCase
                        updatedCase.backendId = created.id
                        syncedCases.append(updatedCase)
                    } catch {
                        print("Failed to sync case \(localCase.caseNumber): \(error)")
                        // Keep local case if upload failed
                        syncedCases.append(localCase)
                    }
                }
            }
            
            // 3. Add any remote cases not in local
            let localBackendIds = Set(localCases.compactMap { $0.backendId })
            for remoteCase in remoteCases {
                if !localBackendIds.contains(remoteCase.id) {
                    syncedCases.append(remoteCase.toConflictCase())
                }
            }
            
        } catch {
            print("Sync failed: \(error)")
            errorMessage = "Sync failed: \(error.localizedDescription)"
            // Return local cases on sync failure
            return localCases
        }
        
        return syncedCases
    }
}
