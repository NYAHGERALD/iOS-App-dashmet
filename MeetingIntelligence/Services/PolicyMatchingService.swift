//
//  PolicyMatchingService.swift
//  MeetingIntelligence
//
//  AI-Powered Policy Matching Service
//  Phase 6: Policy Alignment - Matches case details against policy sections
//

import Foundation

// MARK: - Policy Matching Service
class PolicyMatchingService {
    static let shared = PolicyMatchingService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/policy-matching"
    
    private init() {}
    
    // MARK: - Match Policies
    
    /// Matches case complaints against policy sections
    /// - Parameters:
    ///   - conflictCase: The conflict case with details
    ///   - complaintA: First complaint document
    ///   - complaintAEmployee: Employee who filed complaint A
    ///   - complaintB: Second complaint document
    ///   - complaintBEmployee: Employee who filed complaint B
    ///   - analysisResult: Optional existing AI analysis result
    ///   - witnessStatements: Optional witness statements
    ///   - policySections: Policy sections to match against
    /// - Returns: Policy matching result with relevant sections
    func matchPolicies(
        conflictCase: ConflictCase,
        complaintA: CaseDocument,
        complaintAEmployee: InvolvedEmployee,
        complaintB: CaseDocument,
        complaintBEmployee: InvolvedEmployee,
        analysisResult: AIComparisonResult? = nil,
        witnessStatements: [WitnessStatementInput] = [],
        policySections: [PolicySection]
    ) async throws -> PolicyMatchingResult {
        
        guard let url = URL(string: baseURL + "/match") else {
            throw PolicyMatchingError.invalidURL
        }
        
        // Build case details
        let caseDetails: [String: Any] = [
            "caseType": conflictCase.type.rawValue,
            "incidentDate": ISO8601DateFormatter().string(from: conflictCase.incidentDate),
            "location": conflictCase.location,
            "department": conflictCase.department
        ]
        
        // Build complaint A
        let complaintAData: [String: Any] = [
            "employeeName": complaintAEmployee.name,
            "text": complaintA.cleanedText
        ]
        
        // Build complaint B
        let complaintBData: [String: Any] = [
            "employeeName": complaintBEmployee.name,
            "text": complaintB.cleanedText
        ]
        
        // Build analysis result if available
        var analysisData: [String: Any]? = nil
        if let analysis = analysisResult {
            analysisData = [
                "contradictions": analysis.contradictions,
                "agreementPoints": analysis.agreementPoints,
                "neutralSummary": analysis.neutralSummary
            ]
        }
        
        // Build witness statements
        let witnessData: [[String: String]] = witnessStatements.map { witness in
            [
                "witnessName": witness.witnessName,
                "text": witness.text
            ]
        }
        
        // Build policy sections
        let policySectionsData: [[String: Any]] = policySections.map { section in
            [
                "id": section.id.uuidString,
                "sectionNumber": section.sectionNumber,
                "title": section.title,
                "content": section.content,
                "type": section.type.rawValue,
                "keywords": section.keywords
            ]
        }
        
        // Build full request body
        var requestBody: [String: Any] = [
            "caseDetails": caseDetails,
            "complaintA": complaintAData,
            "complaintB": complaintBData,
            "policySections": policySectionsData
        ]
        
        if let analysis = analysisData {
            requestBody["analysisResult"] = analysis
        }
        
        if !witnessData.isEmpty {
            requestBody["witnessStatements"] = witnessData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 90 // 1.5 minutes for policy matching
        
        print("PolicyMatchingService: Starting policy matching...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolicyMatchingError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PolicyMatchingError.invalidResponse
        }
        
        // Check for error
        if httpResponse.statusCode != 200 {
            if let errorMessage = json["message"] as? String {
                throw PolicyMatchingError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw PolicyMatchingError.apiError(errorMessage)
            }
            throw PolicyMatchingError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Check success
        guard let success = json["success"] as? Bool, success,
              let resultData = json["data"] as? [String: Any] else {
            throw PolicyMatchingError.parsingError
        }
        
        // Parse result
        return try parseMatchingResult(resultData)
    }
    
    // MARK: - Parse Result
    
    private func parseMatchingResult(_ data: [String: Any]) throws -> PolicyMatchingResult {
        let matchesData = data["matches"] as? [[String: Any]] ?? []
        let overallGuidance = data["overallGuidance"] as? String ?? ""
        let generatedAt = data["generatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
        
        let matches: [PolicyMatchResult] = matchesData.compactMap { matchData in
            guard let sectionId = matchData["sectionId"] as? String,
                  let sectionNumber = matchData["sectionNumber"] as? String,
                  let sectionTitle = matchData["sectionTitle"] as? String,
                  let relevanceExplanation = matchData["relevanceExplanation"] as? String,
                  let matchConfidence = matchData["matchConfidence"] as? Double else {
                return nil
            }
            
            let keyPhrases = matchData["keyPhrases"] as? [String] ?? []
            
            return PolicyMatchResult(
                sectionId: UUID(uuidString: sectionId) ?? UUID(),
                sectionNumber: sectionNumber,
                sectionTitle: sectionTitle,
                relevanceExplanation: relevanceExplanation,
                matchConfidence: matchConfidence,
                keyPhrases: keyPhrases
            )
        }
        
        return PolicyMatchingResult(
            matches: matches,
            overallGuidance: overallGuidance,
            generatedAt: ISO8601DateFormatter().date(from: generatedAt) ?? Date()
        )
    }
}

// MARK: - Policy Matching Errors

enum PolicyMatchingError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(String)
    case noPolicySections
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse policy matching results"
        case .apiError(let message):
            return message
        case .noPolicySections:
            return "No policy sections available for matching"
        }
    }
}

// MARK: - Policy Matching Models

/// Result of policy matching analysis
struct PolicyMatchingResult {
    let matches: [PolicyMatchResult]
    let overallGuidance: String
    let generatedAt: Date
    
    var hasMatches: Bool {
        !matches.isEmpty
    }
    
    var highConfidenceMatches: [PolicyMatchResult] {
        matches.filter { $0.matchConfidence >= 0.75 }
    }
    
    var moderateConfidenceMatches: [PolicyMatchResult] {
        matches.filter { $0.matchConfidence >= 0.5 && $0.matchConfidence < 0.75 }
    }
}

/// Individual policy match result
struct PolicyMatchResult: Identifiable {
    let id = UUID()
    let sectionId: UUID
    let sectionNumber: String
    let sectionTitle: String
    let relevanceExplanation: String
    let matchConfidence: Double
    let keyPhrases: [String]
    
    /// Confidence level category
    var confidenceLevel: ConfidenceLevel {
        if matchConfidence >= 0.8 {
            return .high
        } else if matchConfidence >= 0.65 {
            return .moderate
        } else {
            return .low
        }
    }
    
    /// Color for confidence indicator
    var confidenceColor: String {
        switch confidenceLevel {
        case .high: return "green"
        case .moderate: return "orange"
        case .low: return "gray"
        }
    }
    
    enum ConfidenceLevel {
        case high, moderate, low
        
        var label: String {
            switch self {
            case .high: return "High Relevance"
            case .moderate: return "Moderate Relevance"
            case .low: return "Low Relevance"
            }
        }
    }
}
