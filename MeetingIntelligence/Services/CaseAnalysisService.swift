//
//  CaseAnalysisService.swift
//  MeetingIntelligence
//
//  AI-Powered Conflict Analysis Service
//  Compares complaint statements and generates neutral analysis
//  Updated: Feb 2026
//

import Foundation

// MARK: - Request/Response Models

struct ComplaintData: Codable {
    let employeeName: String
    let originalText: String
    let translatedText: String?
    let cleanedText: String?
}

struct CaseDetailsData: Codable {
    let incidentDate: String
    let location: String
    let department: String
}

struct WitnessStatementData: Codable {
    let witnessName: String
    let text: String
}

struct CompareComplaintsRequest: Codable {
    let complaintA: ComplaintData
    let complaintB: ComplaintData
    let caseDetails: CaseDetailsData
    let witnessStatements: [WitnessStatementData]?
}

struct SideBySideItem: Codable, Identifiable {
    var id: String { topic }
    let topic: String
    let partyAVersion: String
    let partyBVersion: String
    let status: ComparisonStatus
    
    enum ComparisonStatus: String, Codable {
        case agreement
        case contradiction
        case partial
        case unclear
        
        var displayName: String {
            switch self {
            case .agreement: return "Agreement"
            case .contradiction: return "Contradiction"
            case .partial: return "Partial Agreement"
            case .unclear: return "Unclear"
            }
        }
        
        var iconName: String {
            switch self {
            case .agreement: return "checkmark.circle.fill"
            case .contradiction: return "xmark.circle.fill"
            case .partial: return "minus.circle.fill"
            case .unclear: return "questionmark.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .agreement: return "green"
            case .contradiction: return "red"
            case .partial: return "orange"
            case .unclear: return "gray"
            }
        }
    }
}

struct AnalysisResponse: Codable {
    let timelineDifferences: [String]
    let agreementPoints: [String]
    let contradictions: [String]
    let emotionalLanguage: [String]
    let missingDetails: [String]
    let neutralSummary: String
    let sideBySideComparison: [SideBySideItem]
    let generatedAt: String
    let partyAName: String
    let partyBName: String
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - Service Errors

enum CaseAnalysisError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError
    case missingDocuments
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from analysis service"
        case .apiError(let message):
            return message
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .missingDocuments:
            return "Both complaints are required for analysis"
        case .parsingError:
            return "Failed to parse analysis results"
        }
    }
}

// MARK: - Case Analysis Service

class CaseAnalysisService {
    static let shared = CaseAnalysisService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api/conflict-analysis"
    
    private init() {}
    
    /// Compare two complaints and generate AI analysis
    func compareComplaints(
        complaintA: CaseDocument,
        complaintB: CaseDocument,
        caseDetails: (incidentDate: Date, location: String, department: String),
        witnessStatements: [CaseDocument] = [],
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> AIComparisonResult {
        
        guard let url = URL(string: baseURL + "/compare") else {
            throw CaseAnalysisError.invalidResponse
        }
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let incidentDateStr = dateFormatter.string(from: caseDetails.incidentDate)
        
        progressHandler?("Preparing documents for analysis...")
        
        // Build request
        let request = CompareComplaintsRequest(
            complaintA: ComplaintData(
                employeeName: complaintA.submittedBy ?? "Party A",
                originalText: complaintA.originalText ?? "",
                translatedText: complaintA.translatedText,
                cleanedText: complaintA.cleanedText
            ),
            complaintB: ComplaintData(
                employeeName: complaintB.submittedBy ?? "Party B",
                originalText: complaintB.originalText ?? "",
                translatedText: complaintB.translatedText,
                cleanedText: complaintB.cleanedText
            ),
            caseDetails: CaseDetailsData(
                incidentDate: incidentDateStr,
                location: caseDetails.location,
                department: caseDetails.department
            ),
            witnessStatements: witnessStatements.isEmpty ? nil : witnessStatements.map { doc in
                WitnessStatementData(
                    witnessName: doc.submittedBy ?? "Witness",
                    text: doc.translatedText ?? doc.cleanedText ?? doc.originalText ?? ""
                )
            }
        )
        
        progressHandler?("Sending to System for analysis...")
        
        // Make request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 120 // 2 minutes for AI analysis
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaseAnalysisError.invalidResponse
        }
        
        progressHandler?("Processing analysis results...")
        
        // Parse response
        let decoder = JSONDecoder()
        
        if httpResponse.statusCode == 200 {
            let apiResponse = try decoder.decode(APIResponse<AnalysisResponse>.self, from: data)
            
            if let analysisData = apiResponse.data {
                // Convert to AIComparisonResult
                return AIComparisonResult(
                    timelineDifferences: analysisData.timelineDifferences,
                    agreementPoints: analysisData.agreementPoints,
                    contradictions: analysisData.contradictions,
                    emotionalLanguage: analysisData.emotionalLanguage,
                    missingDetails: analysisData.missingDetails,
                    neutralSummary: analysisData.neutralSummary,
                    generatedAt: Date()
                )
            } else {
                throw CaseAnalysisError.parsingError
            }
        } else {
            // Try to parse error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["message"] as? String ?? json["error"] as? String {
                throw CaseAnalysisError.apiError(errorMessage)
            }
            throw CaseAnalysisError.apiError("Analysis failed with status \(httpResponse.statusCode)")
        }
    }
    
    /// Get full analysis with side-by-side comparison
    func getFullAnalysis(
        complaintA: CaseDocument,
        complaintB: CaseDocument,
        caseDetails: (incidentDate: Date, location: String, department: String),
        witnessStatements: [CaseDocument] = [],
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> (result: AIComparisonResult, sideBySide: [SideBySideItem], partyAName: String, partyBName: String) {
        
        guard let url = URL(string: baseURL + "/compare") else {
            throw CaseAnalysisError.invalidResponse
        }
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let incidentDateStr = dateFormatter.string(from: caseDetails.incidentDate)
        
        progressHandler?("Preparing documents for analysis...")
        
        // Build request
        let request = CompareComplaintsRequest(
            complaintA: ComplaintData(
                employeeName: complaintA.submittedBy ?? "Party A",
                originalText: complaintA.originalText ?? "",
                translatedText: complaintA.translatedText,
                cleanedText: complaintA.cleanedText
            ),
            complaintB: ComplaintData(
                employeeName: complaintB.submittedBy ?? "Party B",
                originalText: complaintB.originalText ?? "",
                translatedText: complaintB.translatedText,
                cleanedText: complaintB.cleanedText
            ),
            caseDetails: CaseDetailsData(
                incidentDate: incidentDateStr,
                location: caseDetails.location,
                department: caseDetails.department
            ),
            witnessStatements: witnessStatements.isEmpty ? nil : witnessStatements.map { doc in
                WitnessStatementData(
                    witnessName: doc.submittedBy ?? "Witness",
                    text: doc.translatedText ?? doc.cleanedText ?? doc.originalText ?? ""
                )
            }
        )
        
        progressHandler?("Analyzing statements with System...")
        
        // Make request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 120
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaseAnalysisError.invalidResponse
        }
        
        progressHandler?("Processing results...")
        
        if httpResponse.statusCode == 200 {
            let apiResponse = try JSONDecoder().decode(APIResponse<AnalysisResponse>.self, from: data)
            
            if let analysisData = apiResponse.data {
                let result = AIComparisonResult(
                    timelineDifferences: analysisData.timelineDifferences,
                    agreementPoints: analysisData.agreementPoints,
                    contradictions: analysisData.contradictions,
                    emotionalLanguage: analysisData.emotionalLanguage,
                    missingDetails: analysisData.missingDetails,
                    neutralSummary: analysisData.neutralSummary,
                    generatedAt: Date()
                )
                
                return (
                    result: result,
                    sideBySide: analysisData.sideBySideComparison,
                    partyAName: analysisData.partyAName,
                    partyBName: analysisData.partyBName
                )
            } else {
                throw CaseAnalysisError.parsingError
            }
        } else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["message"] as? String ?? json["error"] as? String {
                throw CaseAnalysisError.apiError(errorMessage)
            }
            throw CaseAnalysisError.apiError("Analysis failed with status \(httpResponse.statusCode)")
        }
    }
}
