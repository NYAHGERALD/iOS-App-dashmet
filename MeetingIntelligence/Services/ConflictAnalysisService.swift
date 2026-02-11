//
//  ConflictAnalysisService.swift
//  MeetingIntelligence
//
//  AI-Powered Conflict Analysis Service for comparing complaint statements
//  Phase 4: Initial AI Comparison
//

import Foundation

// MARK: - Conflict Analysis Service
class ConflictAnalysisService {
    static let shared = ConflictAnalysisService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/conflict-analysis"
    
    private init() {}
    
    // MARK: - Compare Complaints
    
    /// Compares two complaints and generates AI analysis
    /// - Parameters:
    ///   - complaintA: First complaint document
    ///   - complaintB: Second complaint document
    ///   - caseDetails: Case details (date, location, department)
    ///   - witnessStatements: Optional witness statements
    /// - Returns: AI comparison result
    func compareComplaints(
        complaintA: CaseDocument,
        complaintAEmployee: InvolvedEmployee,
        complaintB: CaseDocument,
        complaintBEmployee: InvolvedEmployee,
        caseDetails: CaseComparisonDetails,
        witnessStatements: [WitnessStatementInput] = []
    ) async throws -> AIComparisonResult {
        
        guard let url = URL(string: baseURL + "/compare") else {
            throw ConflictAnalysisError.invalidURL
        }
        
        // Build request body
        var requestBody: [String: Any] = [
            "complaintA": [
                "employeeName": complaintAEmployee.name,
                "originalText": complaintA.originalText,
                "translatedText": complaintA.translatedText as Any,
                "cleanedText": complaintA.cleanedText
            ],
            "complaintB": [
                "employeeName": complaintBEmployee.name,
                "originalText": complaintB.originalText,
                "translatedText": complaintB.translatedText as Any,
                "cleanedText": complaintB.cleanedText
            ],
            "caseDetails": [
                "incidentDate": caseDetails.incidentDate,
                "location": caseDetails.location,
                "department": caseDetails.department
            ]
        ]
        
        // Add witness statements if available
        if !witnessStatements.isEmpty {
            requestBody["witnessStatements"] = witnessStatements.map { witness in
                [
                    "witnessName": witness.witnessName,
                    "text": witness.text
                ]
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120 // 2 minutes for AI analysis
        
        print("ConflictAnalysisService: Starting comparison...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConflictAnalysisError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConflictAnalysisError.invalidResponse
        }
        
        // Check for error
        if httpResponse.statusCode != 200 {
            if let errorMessage = json["message"] as? String {
                throw ConflictAnalysisError.apiError(errorMessage)
            }
            if let errorMessage = json["error"] as? String {
                throw ConflictAnalysisError.apiError(errorMessage)
            }
            throw ConflictAnalysisError.apiError("Server error: HTTP \(httpResponse.statusCode)")
        }
        
        // Check success
        guard let success = json["success"] as? Bool, success,
              let resultData = json["data"] as? [String: Any] else {
            throw ConflictAnalysisError.parsingError
        }
        
        // Parse result
        return try parseComparisonResult(resultData)
    }
    
    // MARK: - Parse Result
    
    private func parseComparisonResult(_ data: [String: Any]) throws -> AIComparisonResult {
        let timelineDifferences = data["timelineDifferences"] as? [String] ?? []
        let agreementPoints = data["agreementPoints"] as? [String] ?? []
        let contradictions = data["contradictions"] as? [String] ?? []
        let emotionalLanguage = data["emotionalLanguage"] as? [String] ?? []
        let missingDetails = data["missingDetails"] as? [String] ?? []
        let neutralSummary = data["neutralSummary"] as? String ?? ""
        let partyAName = data["partyAName"] as? String ?? "Party A"
        let partyBName = data["partyBName"] as? String ?? "Party B"
        
        // Parse generated date
        var generatedAt = Date()
        if let dateString = data["generatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                generatedAt = date
            }
        }
        
        // Parse side-by-side comparison
        var sideBySideComparison: [SideBySideComparisonItem] = []
        if let comparisonItems = data["sideBySideComparison"] as? [[String: Any]] {
            for item in comparisonItems {
                let topic = item["topic"] as? String ?? ""
                let partyAVersion = item["partyAVersion"] as? String ?? ""
                let partyBVersion = item["partyBVersion"] as? String ?? ""
                let statusString = item["status"] as? String ?? "unclear"
                let status = ComparisonStatus(rawValue: statusString) ?? .unclear
                
                sideBySideComparison.append(
                    SideBySideComparisonItem(
                        topic: topic,
                        partyAVersion: partyAVersion,
                        partyBVersion: partyBVersion,
                        status: status
                    )
                )
            }
        }
        
        return AIComparisonResult(
            timelineDifferences: timelineDifferences,
            agreementPoints: agreementPoints,
            contradictions: contradictions,
            emotionalLanguage: emotionalLanguage,
            missingDetails: missingDetails,
            neutralSummary: neutralSummary,
            sideBySideComparison: sideBySideComparison,
            partyAName: partyAName,
            partyBName: partyBName,
            generatedAt: generatedAt
        )
    }
    
    // MARK: - Health Check
    
    func checkHealth() async -> Bool {
        guard let url = URL(string: baseURL + "/health") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String,
                  status == "ok" else {
                return false
            }
            return json["aiAvailable"] as? Bool ?? false
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

struct CaseComparisonDetails {
    let incidentDate: String
    let location: String
    let department: String
}

struct WitnessStatementInput {
    let witnessName: String
    let text: String
}

// MARK: - Errors

enum ConflictAnalysisError: LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case apiError(String)
    case missingDocuments
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .invalidResponse:
            return "Invalid response from analysis service"
        case .parsingError:
            return "Failed to parse analysis results"
        case .apiError(let message):
            return message
        case .missingDocuments:
            return "Both complaints are required for analysis"
        }
    }
}
